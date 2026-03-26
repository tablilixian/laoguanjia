import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local_db/app_database.dart' as db;
import '../local_db/daos/items_dao.dart';
import '../local_db/daos/locations_dao.dart';
import '../local_db/daos/tags_dao.dart';
import '../local_db/daos/types_dao.dart';
import '../local_db/daos/item_tag_relations_dao.dart';
import '../local_db/item_extensions.dart';
import '../models/household_item.dart';
import '../models/item_location.dart';
import '../models/item_tag.dart';
import '../models/item_type_config.dart';
import '../supabase/supabase_client.dart';
import '../../core/utils/retry_utils.dart';

/// 物品同步服务 - 负责所有同步逻辑
/// 
/// 职责：
/// - 自动同步（写操作后触发）
/// - 手动同步
/// - 数据拉取（远程 -> 本地）
/// - 数据推送（本地 -> 远程）
/// - 冲突解决
class ItemSyncService {
  final _client = SupabaseClientManager.client;
  final db.AppDatabase _localDb;
  final void Function()? _onSyncStateChanged;

  bool _isSyncing = false;

  ItemSyncService({
    db.AppDatabase? localDb,
    void Function()? onSyncStateChanged,
  })  : _localDb = localDb ?? db.AppDatabase(),
        _onSyncStateChanged = onSyncStateChanged;

  bool get isSyncing => _isSyncing;

  // ========== 自动同步 ==========

  /// 自动同步（写操作后调用）
  Future<void> autoSync(String householdId) async {
    if (_isSyncing) {
      print('⚠️ [ItemSyncService] 同步已在进行中，跳过');
      return;
    }

    try {
      _isSyncing = true;
      _onSyncStateChanged?.call();
      
      print('🔄 [ItemSyncService] 开始自动同步...');
      
      final pendingItems = await _localDb.itemsDao.getSyncPending();
      
      if (pendingItems.isEmpty) {
        print('✅ [ItemSyncService] 没有待同步的物品');
        return;
      }
      
      print('📋 [ItemSyncService] 待同步物品数量: ${pendingItems.length}');
      
      final itemIds = pendingItems.map((i) => i.id).toList();
      
      final remoteItems = await _client
          .from('household_items')
          .select('id, updated_at, version, deleted_at')
          .or('id.in.(${itemIds.join(',')})');
      
      final remoteItemMap = {for (var item in remoteItems) item['id']: item};

      final itemsToInsert = <Map<String, dynamic>>[];
      final itemsToUpdate = <Map<String, dynamic>>[];
      final itemsToPull = <String>[];

      for (final localItem in pendingItems) {
        final remoteItem = remoteItemMap[localItem.id];

        if (localItem.deletedAt != null) {
          if (remoteItem != null && remoteItem['deleted_at'] == null) {
            await _client.from('household_items').update({'deleted_at': DateTime.now().toIso8601String()}).eq('id', localItem.id);
            await _localDb.itemsDao.markSynced(localItem.id);
          }
          continue;
        }

        if (remoteItem == null) {
          itemsToInsert.add(localItem.toRemoteJson());
        } else {
          final remoteVersion = remoteItem['version'] as int? ?? 0;
          
          if (localItem.version > remoteVersion) {
            itemsToUpdate.add(localItem.toRemoteJson());
          } else {
            itemsToPull.add(localItem.id);
          }
        }
      }

      if (itemsToInsert.isNotEmpty) {
        print('➕ [ItemSyncService] 插入 ${itemsToInsert.length} 个新物品...');
        await _client.from('household_items').insert(itemsToInsert);
        for (final item in itemsToInsert) {
          await _localDb.itemsDao.markSynced(item['id']);
        }
      }

      if (itemsToUpdate.isNotEmpty) {
        print('🔄 [ItemSyncService] 更新 ${itemsToUpdate.length} 个物品...');
        for (final item in itemsToUpdate) {
          await _client.from('household_items').update(item).eq('id', item['id']);
          await _localDb.itemsDao.markSynced(item['id']);
        }
      }

      if (itemsToPull.isNotEmpty) {
        print('📥 [ItemSyncService] 拉取 ${itemsToPull.length} 个远程物品...');
        for (final itemId in itemsToPull) {
          final remoteItem = await _fetchRemoteItem(itemId);
          if (remoteItem != null) {
            await _syncItemToLocal(remoteItem);
          }
        }
      }

      print('✅ [ItemSyncService] 自动同步完成');
    } catch (e) {
      print('🔴 [ItemSyncService] 自动同步失败: $e');
    } finally {
      _isSyncing = false;
      _onSyncStateChanged?.call();
    }
  }

  // ========== 数据拉取 ==========

  /// 拉取远程物品数据
  Future<void> fetchRemoteItems(String householdId) async {
    try {
      final remoteItems = await _fetchRemoteItems(householdId);
      
      if (remoteItems.isEmpty) {
        print('📭 [ItemSyncService] 远程没有物品数据');
        return;
      }
      
      print('📥 [ItemSyncService] 从远程获取了 ${remoteItems.length} 个物品');
      
      for (final item in remoteItems) {
        await _syncItemToLocal(item);
      }
      
      // 位图方式：不再需要同步标签关联
    } catch (e) {
      print('🔴 [ItemSyncService] 拉取远程物品失败: $e');
    }
  }

  /// 增量拉取远程物品数据（混合方案）
  Future<void> fetchRemoteItemsIncremental(String householdId) async {
    try {
      final localItems = await _localDb.itemsDao.getByHousehold(householdId);
      final localItemMap = {for (var item in localItems) item.id: item};
      
      final remoteItems = await _fetchRemoteItems(householdId);
      
      final itemsToSync = remoteItems.where((remoteItem) {
        final localItem = localItemMap[remoteItem.id];
        
        return localItem == null || 
               remoteItem.updatedAt.isAfter(localItem.updatedAt);
      }).toList();
      
      if (itemsToSync.isEmpty) {
        print('📭 [ItemSyncService] 没有需要同步的物品');
        return;
      }
      
      print('📥 [ItemSyncService] 从远程获取了 ${remoteItems.length} 个物品，需要同步 ${itemsToSync.length} 个');
      
      for (final item in itemsToSync) {
        await _syncItemToLocal(item);
      }
      
      // 位图方式：不再需要同步标签关联
    } catch (e) {
      print('🔴 [ItemSyncService] 增量拉取远程物品失败: $e');
    }
  }

  /// 拉取远程位置数据
  Future<void> fetchRemoteLocations(String householdId) async {
    try {
      final remoteLocations = await _fetchRemoteLocations(householdId);
      
      for (final location in remoteLocations) {
        await _syncLocationToLocal(location);
      }
      
      print('📥 [ItemSyncService] 从远程获取了 ${remoteLocations.length} 个位置');
    } catch (e) {
      print('🔴 [ItemSyncService] 拉取远程位置失败: $e');
    }
  }

  /// 拉取远程标签数据
  Future<void> fetchRemoteTags(String householdId) async {
    try {
      final remoteTags = await _fetchRemoteTags(householdId);
      
      for (final tag in remoteTags) {
        await _syncTagToLocal(tag);
      }
      
      print('📥 [ItemSyncService] 从远程获取了 ${remoteTags.length} 个标签');
    } catch (e) {
      print('🔴 [ItemSyncService] 拉取远程标签失败: $e');
    }
  }

  /// 拉取远程类型配置数据
  Future<void> fetchRemoteTypeConfigs(String householdId) async {
    try {
      final remoteTypes = await _fetchRemoteTypeConfigs(householdId);
      
      for (final type in remoteTypes) {
        await _syncTypeToLocal(type);
      }
      
      print('📥 [ItemSyncService] 从远程获取了 ${remoteTypes.length} 个类型配置');
    } catch (e) {
      print('🔴 [ItemSyncService] 拉取远程类型配置失败: $e');
    }
  }

  // ========== 数据初始化 ==========

  /// 初始化数据（首次启动或本地数据为空时）
  Future<void> initialize(String householdId) async {
    try {
      print('🚀 [ItemSyncService] 开始初始化数据...');
      
      final localItems = await _localDb.itemsDao.getByHousehold(householdId);
      
      if (localItems.isEmpty) {
        print('📥 [ItemSyncService] 本地为空，从远程拉取完整数据...');
        await Future.wait([
          fetchRemoteItems(householdId),
          fetchRemoteLocations(householdId),
          fetchRemoteTags(householdId),
          fetchRemoteTypeConfigs(householdId),
        ]);
      } else {
        print('📦 [ItemSyncService] 本地已有数据，进行增量同步...');
        await Future.wait([
          fetchRemoteItemsIncremental(householdId),
          fetchRemoteLocations(householdId),
          fetchRemoteTags(householdId),
          fetchRemoteTypeConfigs(householdId),
        ]);
      }
      
      print('✅ [ItemSyncService] 数据初始化完成');
    } catch (e) {
      print('🔴 [ItemSyncService] 数据初始化失败: $e');
    }
  }

  // ========== 内部方法 ==========

  Future<List<HouseholdItem>> _fetchRemoteItems(String householdId) async {
    return retryWithBackoff(
      () async {
        final response = await _client
            .from('household_items')
            .select('id, household_id, name, description, item_type, location_id, owner_id, quantity, brand, model, purchase_date, purchase_price, warranty_expiry, condition, image_url, thumbnail_url, notes, created_by, created_at, updated_at, deleted_at, version, tags_mask, slot_position')
            .eq('household_id', householdId)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false);

        final items = (response as List)
            .map((json) => HouseholdItem.fromMap(json as Map<String, dynamic>))
            .toList();
        return items;
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote items',
      shouldRetry: shouldRetryOnNetworkError,
    );
  }

  Future<HouseholdItem?> _fetchRemoteItem(String id) async {
    try {
      final response = await _client
          .from('household_items')
          .select('id, household_id, name, description, item_type, location_id, owner_id, quantity, brand, model, purchase_date, purchase_price, warranty_expiry, condition, image_url, thumbnail_url, notes, created_by, created_at, updated_at, deleted_at, version, tags_mask, slot_position')
          .eq('id', id)
          .single();

      return HouseholdItem.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      print('🔴 [ItemSyncService] 获取远程物品失败: $e');
      return null;
    }
  }

  Future<void> _syncItemToLocal(HouseholdItem item) async {
    try {
      print('📦 [ItemSyncService] 同步物品到本地: ${item.name}, tagsMask=${item.tagsMask}');
      
      await _localDb.itemsDao.insertOrUpdateItem(
        db.HouseholdItemsCompanion(
          id: Value(item.id),
          householdId: Value(item.householdId),
          name: Value(item.name),
          description: Value(item.description),
          itemType: Value(item.itemType),
          locationId: Value(item.locationId),
          ownerId: Value(item.ownerId),
          quantity: Value(item.quantity),
          brand: Value(item.brand),
          model: Value(item.model),
          purchaseDate: Value(item.purchaseDate),
          purchasePrice: Value(item.purchasePrice),
          warrantyExpiry: Value(item.warrantyExpiry),
          condition: Value(item.condition.dbValue),
          imageUrl: Value(item.imageUrl),
          thumbnailUrl: Value(item.thumbnailUrl),
          notes: Value(item.notes),
          syncStatus: const Value('synced'),
          remoteId: Value(item.remoteId),
          createdBy: Value(item.createdBy),
          createdAt: Value(item.createdAt),
          updatedAt: Value(item.updatedAt),
          deletedAt: Value(item.deletedAt),
          tagsMask: Value(item.tagsMask),
          slotPosition: Value(item.slotPosition?.toString()),
          syncPending: const Value(false),
        ),
      );
    } catch (e) {
      print('🔴 [ItemSyncService] 同步物品到本地失败: $e');
      rethrow;
    }
  }

  Future<List<ItemLocation>> _fetchRemoteLocations(String householdId) async {
    return retryWithBackoff(
      () async {
        final response = await _client
            .from('item_locations')
            .select()
            .eq('household_id', householdId)
            .order('sort_order', ascending: true);

        if (response == null) {
          throw Exception('Remote fetch returned null');
        }

        final locations = (response as List).map((e) => ItemLocation.fromMap(e)).toList();
        return locations;
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote locations',
      shouldRetry: shouldRetryOnNetworkError,
    );
  }

  Future<void> _syncLocationToLocal(ItemLocation location) async {
    try {
      await _localDb.locationsDao.insertOrUpdateLocation(
        db.ItemLocationsCompanion(
          id: Value(location.id),
          householdId: Value(location.householdId),
          name: Value(location.name),
          description: Value(location.description),
          icon: Value(location.icon),
          color: Value(location.color),
          parentId: Value(location.parentId),
          depth: Value(location.depth),
          path: Value(location.path),
          sortOrder: Value(location.sortOrder),
          templateType: Value(location.templateType?.dbValue),
          templateConfig: Value(location.templateConfig?.toString()),
          positionInParent: Value(location.positionInParent?.toString()),
          positionDescription: Value(location.positionDescription),
          createdAt: Value(location.createdAt),
          updatedAt: Value(location.updatedAt),
          syncPending: const Value(false),
        ),
      );
    } catch (e) {
      print('🔴 [ItemSyncService] 同步位置到本地失败: $e');
      rethrow;
    }
  }

  Future<List<ItemTag>> _fetchRemoteTags(String householdId) async {
    return retryWithBackoff(
      () async {
        final response = await _client
            .from('item_tags')
            .select('id, household_id, name, color, icon, category, applicable_types, created_at, tag_index')
            .eq('household_id', householdId)
            .order('created_at', ascending: false);

        if (response == null) {
          throw Exception('Remote fetch returned null');
        }

        final tags = (response as List).map((e) => ItemTag.fromMap(e)).toList();
        return tags;
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote tags',
      shouldRetry: shouldRetryOnNetworkError,
    );
  }

  Future<void> _syncTagToLocal(ItemTag tag) async {
    try {
      print('🏷️ [ItemSyncService] 同步标签到本地: ${tag.name}, tagIndex=${tag.tagIndex}');
      
      await _localDb.tagsDao.insertOrUpdateTag(
        db.ItemTagsCompanion(
          id: Value(tag.id),
          householdId: Value(tag.householdId),
          name: Value(tag.name),
          color: Value(tag.color),
          icon: Value(tag.icon),
          category: Value(tag.category),
          applicableTypes: Value(tag.applicableTypes.toString()),
          tagIndex: Value(tag.tagIndex),
          createdAt: Value(tag.createdAt),
          updatedAt: Value(DateTime.now()),
          syncPending: const Value(false),
        ),
      );
    } catch (e) {
      print('🔴 [ItemSyncService] 同步标签到本地失败: $e');
      rethrow;
    }
  }

  Future<List<ItemTypeConfig>> _fetchRemoteTypeConfigs(String householdId) async {
    return retryWithBackoff(
      () async {
        final response = await _client
            .from('item_type_configs')
            .select()
            .or('household_id.eq.$householdId,household_id.is.null')
            .order('sort_order', ascending: true);

        if (response == null) {
          throw Exception('Remote fetch returned null');
        }

        final types = (response as List).map((e) => ItemTypeConfig.fromMap(e)).toList();
        return types;
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote types',
      shouldRetry: shouldRetryOnNetworkError,
    );
  }

  Future<void> _syncTypeToLocal(ItemTypeConfig type) async {
    try {
      await _localDb.typesDao.insertOrUpdateType(
        db.ItemTypeConfigsCompanion(
          id: Value(type.id),
          householdId: Value(type.householdId),
          typeKey: Value(type.typeKey),
          typeLabel: Value(type.typeLabel),
          icon: Value(type.icon),
          color: Value(type.color),
          sortOrder: Value(type.sortOrder),
          isActive: Value(type.isActive),
          createdAt: Value(type.createdAt),
          updatedAt: Value(DateTime.now()),
          syncPending: const Value(false),
        ),
      );
    } catch (e) {
      print('🔴 [ItemSyncService] 同步类型到本地失败: $e');
      rethrow;
    }
  }
}
