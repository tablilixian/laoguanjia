import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
import '../../core/sync/sync_engine.dart';
import '../supabase/supabase_client.dart';
import '../../core/utils/retry_utils.dart';

class OfflineItemRepository {
  final _client = SupabaseClientManager.client;
  final db.AppDatabase _localDb = db.AppDatabase();
  late final SyncEngine _syncEngine;

  OfflineItemRepository() {
    _syncEngine = SyncEngine(localDb: _localDb, remoteDb: _client);
  }

  SyncEngine get syncEngine => _syncEngine;

  Future<List<HouseholdItem>> getItems(String householdId) async {
    try {
      final localItems = await _localDb.itemsDao.getByHousehold(householdId);
      final activeItems = localItems.where((i) => i.deletedAt == null).toList();
      
      if (activeItems.isNotEmpty) {
        return activeItems.map((i) => i.toHouseholdItemModel()).toList();
      }
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取本地物品失败: $e');
    }

    final remoteItems = await _fetchRemoteItems(householdId);
    
    for (final item in remoteItems) {
      await _syncItemToLocal(item);
    }

    return remoteItems;
  }

  Future<HouseholdItem?> getItem(String id) async {
    try {
      final localItem = await _localDb.itemsDao.getById(id);
      if (localItem != null && localItem.deletedAt == null) {
        return localItem.toHouseholdItemModel();
      }
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取本地物品失败: $e');
    }

    final remoteItem = await _fetchRemoteItem(id);
    if (remoteItem != null) {
      await _syncItemToLocal(remoteItem);
    }

    return remoteItem;
  }

  Future<HouseholdItem> createItem(HouseholdItem item) async {
    final newItem = item.copyWith(
      id: const Uuid().v4(),
      syncStatus: SyncStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _localDb.itemsDao.insertItem(
      db.HouseholdItemsCompanion(
        id: Value(newItem.id),
        householdId: Value(newItem.householdId),
        name: Value(newItem.name),
        description: Value(newItem.description),
        itemType: Value(newItem.itemType),
        locationId: Value(newItem.locationId),
        ownerId: Value(newItem.ownerId),
        quantity: Value(newItem.quantity),
        brand: Value(newItem.brand),
        model: Value(newItem.model),
        purchaseDate: Value(newItem.purchaseDate),
        purchasePrice: Value(newItem.purchasePrice),
        warrantyExpiry: Value(newItem.warrantyExpiry),
        condition: Value(newItem.condition.dbValue),
        imageUrl: Value(newItem.imageUrl),
        thumbnailUrl: Value(newItem.thumbnailUrl),
        notes: Value(newItem.notes),
        syncStatus: Value(newItem.syncStatus.name),
        remoteId: Value(newItem.remoteId),
        createdBy: Value(newItem.createdBy),
        createdAt: Value(newItem.createdAt),
        updatedAt: Value(newItem.updatedAt),
        slotPosition: Value(newItem.slotPosition?.toString()),
        syncPending: const Value(true),
      ),
    );

    return newItem;
  }

  Future<HouseholdItem> updateItem(HouseholdItem item) async {
    final updatedItem = item.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    await _localDb.itemsDao.updateItem(
      db.HouseholdItemsCompanion(
        id: Value(updatedItem.id),
        householdId: Value(updatedItem.householdId),
        name: Value(updatedItem.name),
        description: Value(updatedItem.description),
        itemType: Value(updatedItem.itemType),
        locationId: Value(updatedItem.locationId),
        ownerId: Value(updatedItem.ownerId),
        quantity: Value(updatedItem.quantity),
        brand: Value(updatedItem.brand),
        model: Value(updatedItem.model),
        purchaseDate: Value(updatedItem.purchaseDate),
        purchasePrice: Value(updatedItem.purchasePrice),
        warrantyExpiry: Value(updatedItem.warrantyExpiry),
        condition: Value(updatedItem.condition.dbValue),
        imageUrl: Value(updatedItem.imageUrl),
        thumbnailUrl: Value(updatedItem.thumbnailUrl),
        notes: Value(updatedItem.notes),
        syncStatus: Value(updatedItem.syncStatus.name),
        remoteId: Value(updatedItem.remoteId),
        createdBy: Value(updatedItem.createdBy),
        createdAt: Value(updatedItem.createdAt),
        updatedAt: Value(updatedItem.updatedAt),
        slotPosition: Value(updatedItem.slotPosition?.toString()),
        syncPending: const Value(true),
      ),
    );

    return updatedItem;
  }

  Future<void> deleteItem(String id) async {
    await _localDb.itemsDao.softDelete(id, DateTime.now());
  }

  Future<List<HouseholdItem>> searchItems(String householdId, String query) async {
    final localItems = await _localDb.itemsDao.search(householdId, query);
    return localItems.map((i) => i.toHouseholdItemModel()).toList();
  }

  Future<List<ItemLocation>> getLocations(String householdId) async {
    try {
      final localLocations = await _localDb.locationsDao.getByHousehold(householdId);
      
      if (localLocations.isNotEmpty) {
        return localLocations.map((l) => l.toItemLocationModel()).toList();
      }
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取本地位置失败: $e');
    }

    final remoteLocations = await _fetchRemoteLocations(householdId);
    
    for (final location in remoteLocations) {
      await _syncLocationToLocal(location);
    }

    return remoteLocations;
  }

  Future<ItemLocation?> getLocation(String id) async {
    try {
      final localLocation = await _localDb.locationsDao.getById(id);
      if (localLocation != null) {
        return localLocation.toItemLocationModel();
      }
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取本地位置失败: $e');
    }

    final remoteLocation = await _fetchRemoteLocation(id);
    if (remoteLocation != null) {
      await _syncLocationToLocal(remoteLocation);
    }

    return remoteLocation;
  }

  Future<ItemLocation> createLocation(ItemLocation location) async {
    final newLocation = location.copyWith(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _localDb.locationsDao.insertLocation(
      db.ItemLocationsCompanion(
        id: Value(newLocation.id),
        householdId: Value(newLocation.householdId),
        name: Value(newLocation.name),
        description: Value(newLocation.description),
        icon: Value(newLocation.icon),
        color: Value(newLocation.color),
        parentId: Value(newLocation.parentId),
        depth: Value(newLocation.depth),
        path: Value(newLocation.path),
        sortOrder: Value(newLocation.sortOrder),
        templateType: Value(newLocation.templateType?.dbValue),
        templateConfig: Value(newLocation.templateConfig?.toString()),
        positionInParent: Value(newLocation.positionInParent?.toString()),
        positionDescription: Value(newLocation.positionDescription),
        createdAt: Value(newLocation.createdAt),
        updatedAt: Value(newLocation.updatedAt),
        syncPending: const Value(true),
      ),
    );

    return newLocation;
  }

  Future<ItemLocation> updateLocation(ItemLocation location) async {
    final updatedLocation = location.copyWith(
      updatedAt: DateTime.now(),
    );

    await _localDb.locationsDao.updateLocation(
      db.ItemLocationsCompanion(
        id: Value(updatedLocation.id),
        householdId: Value(updatedLocation.householdId),
        name: Value(updatedLocation.name),
        description: Value(updatedLocation.description),
        icon: Value(updatedLocation.icon),
        color: Value(updatedLocation.color),
        parentId: Value(updatedLocation.parentId),
        depth: Value(updatedLocation.depth),
        path: Value(updatedLocation.path),
        sortOrder: Value(updatedLocation.sortOrder),
        templateType: Value(updatedLocation.templateType?.dbValue),
        templateConfig: Value(updatedLocation.templateConfig?.toString()),
        positionInParent: Value(updatedLocation.positionInParent?.toString()),
        positionDescription: Value(updatedLocation.positionDescription),
        createdAt: Value(updatedLocation.createdAt),
        updatedAt: Value(updatedLocation.updatedAt),
        syncPending: const Value(true),
      ),
    );

    return updatedLocation;
  }

  Future<void> deleteLocation(String id) async {
    await _localDb.locationsDao.deleteLocation(id);
  }

  Future<List<ItemTag>> getTags(String householdId) async {
    try {
      final localTags = await _localDb.tagsDao.getByHousehold(householdId);
      
      if (localTags.isNotEmpty) {
        return localTags.map((t) => t.toItemTagModel()).toList();
      }
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取本地标签失败: $e');
    }

    final remoteTags = await _fetchRemoteTags(householdId);
    
    for (final tag in remoteTags) {
      await _syncTagToLocal(tag);
    }

    return remoteTags;
  }

  Future<ItemTag?> getTag(String id) async {
    try {
      final localTag = await _localDb.tagsDao.getById(id);
      if (localTag != null) {
        return localTag.toItemTagModel();
      }
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取本地标签失败: $e');
    }

    final remoteTag = await _fetchRemoteTag(id);
    if (remoteTag != null) {
      await _syncTagToLocal(remoteTag);
    }

    return remoteTag;
  }

  Future<ItemTag> createTag(ItemTag tag) async {
    final newTag = tag.copyWith(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
    );

    await _localDb.tagsDao.insertTag(
      db.ItemTagsCompanion(
        id: Value(newTag.id),
        householdId: Value(newTag.householdId),
        name: Value(newTag.name),
        color: Value(newTag.color),
        icon: Value(newTag.icon),
        category: Value(newTag.category),
        applicableTypes: Value(newTag.applicableTypes.toString()),
        createdAt: Value(newTag.createdAt),
        syncPending: const Value(true),
      ),
    );

    return newTag;
  }

  Future<ItemTag> updateTag(ItemTag tag) async {
    await _localDb.tagsDao.updateTag(
      db.ItemTagsCompanion(
        id: Value(tag.id),
        householdId: Value(tag.householdId),
        name: Value(tag.name),
        color: Value(tag.color),
        icon: Value(tag.icon),
        category: Value(tag.category),
        applicableTypes: Value(tag.applicableTypes.toString()),
        createdAt: Value(tag.createdAt),
        syncPending: const Value(true),
      ),
    );

    return tag;
  }

  Future<void> deleteTag(String id) async {
    await _localDb.tagsDao.deleteTag(id);
  }

  Future<List<ItemTypeConfig>> getTypeConfigs(String householdId) async {
    try {
      final localTypes = await _localDb.typesDao.getByHousehold(householdId);
      
      if (localTypes.isNotEmpty) {
        return localTypes.map((t) => t.toItemTypeConfigModel()).toList();
      }
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取本地类型失败: $e');
    }

    final remoteTypes = await _fetchRemoteTypeConfigs(householdId);
    
    for (final type in remoteTypes) {
      await _syncTypeToLocal(type);
    }

    return remoteTypes;
  }

  Future<List<HouseholdItem>> _fetchRemoteItems(String householdId) async {
    return retryWithBackoff(
      () async {
        final response = await _client
            .from('household_items')
            .select()
            .eq('household_id', householdId)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false);

        final items = (response as List)
            .map((json) => HouseholdItem.fromMap(json as Map<String, dynamic>))
            .toList();
        print('✅ [OfflineItemRepository] 从远程获取了 ${items.length} 个物品');
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
          .select()
          .eq('id', id)
          .single();

      return HouseholdItem.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取远程物品失败: $e');
      return null;
    }
  }

  Future<void> _syncItemToLocal(HouseholdItem item) async {
    try {
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
          syncStatus: Value(item.syncStatus.name),
          remoteId: Value(item.remoteId),
          createdBy: Value(item.createdBy),
          createdAt: Value(item.createdAt),
          updatedAt: Value(item.updatedAt),
          deletedAt: Value(item.deletedAt),
          slotPosition: Value(item.slotPosition?.toString()),
          syncPending: const Value(false),
        ),
      );
    } catch (e) {
      print('🔴 [OfflineItemRepository] 同步物品到本地失败: $e');
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
        print('✅ [OfflineItemRepository] 从远程获取了 ${locations.length} 个位置');
        return locations;
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote locations',
      shouldRetry: shouldRetryOnNetworkError,
    );
  }

  Future<ItemLocation?> _fetchRemoteLocation(String id) async {
    try {
      final response = await _client
          .from('item_locations')
          .select()
          .eq('id', id)
          .single();

      return ItemLocation.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取远程位置失败: $e');
      return null;
    }
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
      print('🔴 [OfflineItemRepository] 同步位置到本地失败: $e');
      rethrow;
    }
  }

  Future<List<ItemTag>> _fetchRemoteTags(String householdId) async {
    return retryWithBackoff(
      () async {
        final response = await _client
            .from('item_tags')
            .select()
            .eq('household_id', householdId)
            .order('created_at', ascending: false);

        if (response == null) {
          throw Exception('Remote fetch returned null');
        }

        final tags = (response as List).map((e) => ItemTag.fromMap(e)).toList();
        print('✅ [OfflineItemRepository] 从远程获取了 ${tags.length} 个标签');
        return tags;
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote tags',
      shouldRetry: shouldRetryOnNetworkError,
    );
  }

  Future<ItemTag?> _fetchRemoteTag(String id) async {
    try {
      final response = await _client
          .from('item_tags')
          .select()
          .eq('id', id)
          .single();

      return ItemTag.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取远程标签失败: $e');
      return null;
    }
  }

  Future<void> _syncTagToLocal(ItemTag tag) async {
    try {
      await _localDb.tagsDao.insertOrUpdateTag(
        db.ItemTagsCompanion(
          id: Value(tag.id),
          householdId: Value(tag.householdId),
          name: Value(tag.name),
          color: Value(tag.color),
          icon: Value(tag.icon),
          category: Value(tag.category),
          applicableTypes: Value(tag.applicableTypes.toString()),
          createdAt: Value(tag.createdAt),
          syncPending: const Value(false),
        ),
      );
    } catch (e) {
      print('🔴 [OfflineItemRepository] 同步标签到本地失败: $e');
      rethrow;
    }
  }

  Future<List<ItemTypeConfig>> _fetchRemoteTypeConfigs(String householdId) async {
    return retryWithBackoff(
      () async {
        final response = await _client
            .from('item_type_configs')
            .select()
            .or('household_id.eq.$householdId,is_preset.eq.true')
            .order('sort_order', ascending: true);

        if (response == null) {
          throw Exception('Remote fetch returned null');
        }

        final types = (response as List).map((e) => ItemTypeConfig.fromMap(e)).toList();
        print('✅ [OfflineItemRepository] 从远程获取了 ${types.length} 个类型');
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
          syncPending: const Value(false),
        ),
      );
    } catch (e) {
      print('🔴 [OfflineItemRepository] 同步类型到本地失败: $e');
      rethrow;
    }
  }

  // ========== 统计方法 ==========

  Future<Map<String, dynamic>> getItemOverview(String householdId) async {
    try {
      final items = await _localDb.itemsDao.getByHousehold(householdId);
      final activeItems = items.where((i) => i.deletedAt == null).toList();

      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);

      final total = activeItems.length;
      final newThisMonth = activeItems
          .where((i) => i.createdAt != null && i.createdAt!.isAfter(thisMonth))
          .length;

      final attentionNeeded = activeItems
          .where((i) =>
              i.warrantyExpiry != null &&
              i.warrantyExpiry!.isBefore(now.add(const Duration(days: 30))))
          .length;

      final byType = <String, int>{};
      for (final item in activeItems) {
        final type = item.itemType ?? '未分类';
        byType[type] = (byType[type] ?? 0) + 1;
      }

      final byTypeList = byType.entries
          .map((e) => {'type_key': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return {
        'total': total,
        'newThisMonth': newThisMonth,
        'attentionNeeded': attentionNeeded,
        'byType': byTypeList,
      };
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取概览统计失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getItemCountByType(
    String householdId,
  ) async {
    try {
      final items = await _localDb.itemsDao.getByHousehold(householdId);
      final activeItems = items.where((i) => i.deletedAt == null).toList();

      final typeCounts = <String, int>{};
      for (final item in activeItems) {
        final type = item.itemType ?? '未分类';
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }

      final result = typeCounts.entries
          .map((e) => {'type_key': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return result;
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取按类型统计失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getItemCountByOwner(
    String householdId,
  ) async {
    try {
      final items = await _localDb.itemsDao.getByHousehold(householdId);
      final activeItems = items.where((i) => i.deletedAt == null).toList();

      final ownerCounts = <String, int>{};
      for (final item in activeItems) {
        final owner = item.ownerId ?? '未分配';
        ownerCounts[owner] = (ownerCounts[owner] ?? 0) + 1;
      }

      final result = ownerCounts.entries
          .map((e) => {'owner_id': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return result;
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取按成员统计失败: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> getAllLocationItemCounts(
    String householdId,
  ) async {
    try {
      final items = await _localDb.itemsDao.getByHousehold(householdId);
      final activeItems = items.where((i) => i.deletedAt == null).toList();

      final locationCounts = <String, int>{};
      for (final item in activeItems) {
        final locationId = item.locationId;
        if (locationId != null) {
          locationCounts[locationId] = (locationCounts[locationId] ?? 0) + 1;
        }
      }

      return locationCounts;
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取位置物品数量失败: $e');
      rethrow;
    }
  }
}
