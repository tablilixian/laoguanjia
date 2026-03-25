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
    final localItems = await _localDb.itemsDao.getByHousehold(householdId);
    final activeItems = localItems.where((i) => i.deletedAt == null).toList();
    
    final locations = await getLocations(householdId);
    final locationMap = {for (var l in locations) l.id: l};
    
    final tags = await getTags(householdId);
    final tagMap = {for (var t in tags) t.id: t};
    
    final itemTagRelations = await _localDb.itemTagRelationsDao.getAll();
    final itemTagMap = <String, List<String>>{};
    for (final relation in itemTagRelations) {
      if (!itemTagMap.containsKey(relation.itemId)) {
        itemTagMap[relation.itemId] = [];
      }
      itemTagMap[relation.itemId]!.add(relation.tagId);
    }
    
    return activeItems.map((i) {
      final item = i.toHouseholdItemModel();
      
      final tagIds = itemTagMap[item.id] ?? [];
      final itemTags = tagIds.map((tagId) => tagMap[tagId]).whereType<ItemTag>().toList();
      
      return item.copyWith(
        locationName: item.locationId != null && locationMap.containsKey(item.locationId) ? locationMap[item.locationId]!.name : null,
        locationIcon: item.locationId != null && locationMap.containsKey(item.locationId) ? locationMap[item.locationId]!.icon : null,
        locationPath: item.locationId != null && locationMap.containsKey(item.locationId) ? locationMap[item.locationId]!.path : null,
        tags: itemTags,
      );
    }).toList();
  }

  Future<void> _fetchAndSyncItems(String householdId) async {
    final remoteItems = await _fetchRemoteItems(householdId);
    
    if (remoteItems.isEmpty) {
      print('📭 [OfflineItemRepository] 远程没有物品数据');
      return;
    }
    
    print('📥 [OfflineItemRepository] 从远程获取了 ${remoteItems.length} 个物品');
    
    for (final item in remoteItems) {
      await _syncItemToLocal(item);
    }
    
    await _syncAllTagRelationsFromRemote();
  }

  Future<HouseholdItem?> getItem(String id) async {
    try {
      final localItem = await _localDb.itemsDao.getById(id);
      if (localItem != null && localItem.deletedAt == null) {
        final item = localItem.toHouseholdItemModel();
        
        String? locationName;
        String? locationIcon;
        String? locationPath;
        
        if (item.locationId != null) {
          final location = await getLocation(item.locationId!);
          if (location != null) {
            locationName = location.name;
            locationIcon = location.icon;
            locationPath = location.path;
          }
        }
        
        final tagIds = await _localDb.itemTagRelationsDao.getTagIdsForItem(id);
        print('🏷️ [OfflineItemRepository] 物品 $id 的标签ID列表: $tagIds');
        
        final tags = <ItemTag>[];
        for (final tagId in tagIds) {
          print('🔍 [OfflineItemRepository] 正在获取标签: $tagId');
          final tag = await getTag(tagId);
          if (tag != null) {
            print('✅ [OfflineItemRepository] 找到标签: ${tag.name}');
            tags.add(tag);
          } else {
            print('⚠️ [OfflineItemRepository] 标签 $tagId 不存在');
          }
        }
        
        print('📦 [OfflineItemRepository] 获取物品 ${item.name} ($id): ${tags.length}个标签');
        return item.copyWith(
          locationName: locationName,
          locationIcon: locationIcon,
          locationPath: locationPath,
          tags: tags,
        );
      }
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取本地物品失败: $e');
    }

    final remoteItem = await _fetchRemoteItem(id);
    if (remoteItem != null) {
      await _syncItemToLocal(remoteItem);
      
      final tagIds = await _localDb.itemTagRelationsDao.getTagIdsForItem(id);
      print('🏷️ [OfflineItemRepository] 物品 $id 的标签ID列表: $tagIds');
      
      final tags = <ItemTag>[];
      for (final tagId in tagIds) {
        final tag = await getTag(tagId);
        if (tag != null) {
          tags.add(tag);
        }
      }
      
      if (remoteItem.locationId != null) {
        final location = await getLocation(remoteItem.locationId!);
        if (location != null) {
          return remoteItem.copyWith(
            locationName: location.name,
            locationIcon: location.icon,
            locationPath: location.path,
            tags: tags,
          );
        }
      }
      
      return remoteItem.copyWith(tags: tags);
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

    autoSync(newItem.householdId);

    return newItem;
  }

  Future<void> setItemTags(String itemId, List<String> tagIds) async {
    try {
      await _localDb.itemTagRelationsDao.setTagsForItem(itemId, tagIds);
      await _syncTagRelationsToRemote(itemId, tagIds);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 设置物品标签失败: $e');
    }
  }

  Future<HouseholdItem> updateItem(HouseholdItem item) async {
    final current = await _localDb.itemsDao.getById(item.id);
    final newVersion = (current?.version ?? 0) + 1;
    
    final updatedItem = item.copyWith(
      version: newVersion,
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
        version: Value(newVersion),
        slotPosition: Value(updatedItem.slotPosition?.toString()),
        syncPending: const Value(true),
      ),
    );

    autoSync(updatedItem.householdId);

    return updatedItem;
  }

  Future<void> deleteItem(String id) async {
    final current = await _localDb.itemsDao.getById(id);
    final newVersion = (current?.version ?? 0) + 1;
    
    await _localDb.itemsDao.softDeleteWithVersion(id, DateTime.now(), newVersion);
    
    if (current != null) {
      autoSync(current.householdId);
    }
  }

  Future<void> autoSync(String householdId) async {
    try {
      print('🔄 [OfflineItemRepository] 开始自动同步...');
      
      final pendingItems = await _localDb.itemsDao.getSyncPending();
      
      if (pendingItems.isEmpty) {
        print('✅ [OfflineItemRepository] 没有待同步的物品');
        return;
      }
      
      print('📋 [OfflineItemRepository] 待同步物品数量: ${pendingItems.length}');
      
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
        print('➕ [OfflineItemRepository] 自动同步: 插入 ${itemsToInsert.length} 个新物品...');
        await _client.from('household_items').insert(itemsToInsert);
        for (final item in itemsToInsert) {
          await _localDb.itemsDao.markSynced(item['id']);
        }
      }

      if (itemsToUpdate.isNotEmpty) {
        print('🔄 [OfflineItemRepository] 自动同步: 更新 ${itemsToUpdate.length} 个物品...');
        for (final item in itemsToUpdate) {
          await _client.from('household_items').update(item).eq('id', item['id']);
          await _localDb.itemsDao.markSynced(item['id']);
        }
      }

      if (itemsToPull.isNotEmpty) {
        print('⚠️ [OfflineItemRepository] 自动同步: 拉取 ${itemsToPull.length} 个远程物品...');
        for (final itemId in itemsToPull) {
          final remoteItem = await _fetchRemoteItem(itemId);
          if (remoteItem != null) {
            await _syncItemToLocal(remoteItem);
          }
        }
      }

      print('✅ [OfflineItemRepository] 自动同步完成');
    } catch (e) {
      print('🔴 [OfflineItemRepository] 自动同步失败: $e');
    }
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

    _syncLocationToRemote(newLocation);

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

    _syncLocationToRemote(updatedLocation);

    return updatedLocation;
  }

  Future<void> deleteLocation(String id) async {
    await _localDb.locationsDao.deleteLocation(id);
    await _deleteLocationFromRemote(id);
  }

  Future<void> _syncLocationToRemote(ItemLocation location) async {
    try {
      final existing = await _client
          .from('item_locations')
          .select('id')
          .eq('id', location.id)
          .maybeSingle();
      
      if (existing == null) {
        await _client.from('item_locations').insert(location.toRemoteJson());
      } else {
        await _client.from('item_locations').update(location.toRemoteJson()).eq('id', location.id);
      }
      
      await _localDb.locationsDao.markSynced(location.id);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 同步位置到远程失败: $e');
    }
  }

  Future<void> _deleteLocationFromRemote(String id) async {
    try {
      await _client.from('item_locations').delete().eq('id', id);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 删除远程位置失败: $e');
    }
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
        updatedAt: Value(DateTime.now()),
        syncPending: const Value(true),
      ),
    );

    print('📝 [OfflineItemRepository] 创建标签: ${newTag.name} (${newTag.id})');
    _syncTagToRemote(newTag);

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
        updatedAt: Value(DateTime.now()),
        syncPending: const Value(true),
      ),
    );

    print('📝 [OfflineItemRepository] 更新标签: ${tag.name} (${tag.id})');
    _syncTagToRemote(tag);

    return tag;
  }

  Future<void> deleteTag(String id) async {
    print('🗑️ [OfflineItemRepository] 删除标签: $id');
    await _localDb.tagsDao.deleteTag(id);
    await _deleteTagFromRemote(id);
  }

  Future<void> _syncTagToRemote(ItemTag tag) async {
    try {
      print('🔄 [OfflineItemRepository] 开始同步标签到远程: ${tag.name} (${tag.id})');
      final existing = await _client
          .from('item_tags')
          .select('id')
          .eq('id', tag.id)
          .maybeSingle();
      
      if (existing == null) {
        print('➕ [OfflineItemRepository] 标签不存在，插入新标签');
        await _client.from('item_tags').insert(tag.toRemoteJson());
      } else {
        print('✏️ [OfflineItemRepository] 标签已存在，更新标签');
        await _client.from('item_tags').update(tag.toRemoteJson()).eq('id', tag.id);
      }
      
      await _localDb.tagsDao.markSynced(tag.id);
      print('✅ [OfflineItemRepository] 标签同步到远程完成');
    } catch (e) {
      print('🔴 [OfflineItemRepository] 同步标签到远程失败: $e');
    }
  }

  Future<void> _deleteTagFromRemote(String id) async {
    try {
      print('🔄 [OfflineItemRepository] 开始从远程删除标签: $id');
      await _client.from('item_tags').delete().eq('id', id);
      print('✅ [OfflineItemRepository] 标签从远程删除完成');
    } catch (e) {
      print('🔴 [OfflineItemRepository] 删除远程标签失败: $e');
    }
  }

  Future<void> addTagToItem(String itemId, String tagId) async {
    try {
      print('➕ [OfflineItemRepository] 添加标签到物品: $itemId <- $tagId');
      await _localDb.itemTagRelationsDao.insertRelation(
        db.ItemTagRelationsCompanion(
          itemId: Value(itemId),
          tagId: Value(tagId),
          createdAt: Value(DateTime.now()),
        ),
      );
      print('✅ [OfflineItemRepository] 标签关联插入本地成功');
      
      final currentTagIds = await _localDb.itemTagRelationsDao.getTagIdsForItem(itemId);
      print('🔍 [OfflineItemRepository] 当前物品的所有标签ID: $currentTagIds');
      await _syncTagRelationsToRemote(itemId, currentTagIds);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 添加标签到物品失败: $e');
      rethrow;
    }
  }

  Future<void> removeTagFromItem(String itemId, String tagId) async {
    try {
      print('➖ [OfflineItemRepository] 从物品移除标签: $itemId <- $tagId');
      await _localDb.itemTagRelationsDao.deleteRelation(itemId, tagId);
      
      final currentTagIds = await _localDb.itemTagRelationsDao.getTagIdsForItem(itemId);
      await _syncTagRelationsToRemote(itemId, currentTagIds);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 从物品移除标签失败: $e');
      rethrow;
    }
  }

  Future<void> updateItemTags(String itemId, List<String> tagIds) async {
    try {
      print('🔄 [OfflineItemRepository] 更新物品标签: $itemId -> ${tagIds.length}个标签');
      await _localDb.itemTagRelationsDao.setTagsForItem(itemId, tagIds);
      await _syncTagRelationsToRemote(itemId, tagIds);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 更新物品标签失败: $e');
      rethrow;
    }
  }

  Future<List<String>> getItemTagIds(String itemId) async {
    try {
      return await _localDb.itemTagRelationsDao.getTagIdsForItem(itemId);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 获取物品标签失败: $e');
      return [];
    }
  }

  Future<List<ItemTypeConfig>> getTypeConfigs(String householdId) async {
    try {
      final localTypes = await _localDb.typesDao.getByHousehold(householdId);
      final allLocalTypes = await _localDb.typesDao.getAll();
      
      if (localTypes.isNotEmpty && allLocalTypes.length > localTypes.length) {
        return allLocalTypes.map((t) => t.toItemTypeConfigModel()).toList();
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

  Future<ItemTypeConfig> createTypeConfig(ItemTypeConfig type) async {
    final newType = type.copyWith(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
    );

    await _localDb.typesDao.insertType(
      db.ItemTypeConfigsCompanion(
        id: Value(newType.id),
        householdId: Value(newType.householdId),
        typeKey: Value(newType.typeKey),
        typeLabel: Value(newType.typeLabel),
        icon: Value(newType.icon),
        color: Value(newType.color),
        sortOrder: Value(newType.sortOrder),
        isActive: Value(newType.isActive),
        createdAt: Value(newType.createdAt),
        updatedAt: Value(DateTime.now()),
        syncPending: const Value(true),
      ),
    );

    _syncTypeToRemote(newType);

    return newType;
  }

  Future<ItemTypeConfig> updateTypeConfig(ItemTypeConfig type) async {
    await _localDb.typesDao.updateType(
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
        syncPending: const Value(true),
      ),
    );

    _syncTypeToRemote(type);

    return type;
  }

  Future<void> deleteTypeConfig(String id) async {
    await _localDb.typesDao.deleteType(id);
    await _deleteTypeFromRemote(id);
  }

  Future<void> _syncTypeToRemote(ItemTypeConfig type) async {
    try {
      final existing = await _client
          .from('item_type_configs')
          .select('id')
          .eq('id', type.id)
          .maybeSingle();
      
      if (existing == null) {
        await _client.from('item_type_configs').insert(type.toRemoteJson());
      } else {
        await _client.from('item_type_configs').update(type.toRemoteJson()).eq('id', type.id);
      }
      
      await _localDb.typesDao.markSynced(type.id);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 同步类型到远程失败: $e');
    }
  }

  Future<void> _deleteTypeFromRemote(String id) async {
    try {
      await _client.from('item_type_configs').delete().eq('id', id);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 删除远程类型失败: $e');
    }
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
          syncStatus: const Value('synced'),
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
          updatedAt: Value(DateTime.now()),
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
            .or('household_id.eq.$householdId,household_id.is.null')
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
          updatedAt: Value(DateTime.now()),
          syncPending: const Value(false),
        ),
      );
    } catch (e) {
      print('🔴 [OfflineItemRepository] 同步类型到本地失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRemoteTagRelations(String itemId) async {
    print('🔍 [OfflineItemRepository] 开始获取物品 $itemId 的标签关联...');
    return retryWithBackoff(
      () async {
        final response = await _client
            .from('item_tag_relations')
            .select('tag_id, created_at')
            .eq('item_id', itemId);

        final relations = (response as List).cast<Map<String, dynamic>>();
        print('✅ [OfflineItemRepository] 获取到 ${relations.length} 个标签关联');
        return relations;
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote tag relations',
      shouldRetry: shouldRetryOnNetworkError,
    );
  }

  Future<void> _syncTagRelationsToLocal(String itemId, List<Map<String, dynamic>> relations) async {
    try {
      print('🔄 [OfflineItemRepository] 开始同步 ${relations.length} 个标签关联到本地...');
      await _localDb.itemTagRelationsDao.deleteByItem(itemId);
      
      for (final relation in relations) {
        await _localDb.itemTagRelationsDao.insertRelation(
          db.ItemTagRelationsCompanion(
            itemId: Value(itemId),
            tagId: Value(relation['tag_id'] as String),
            createdAt: Value(DateTime.parse(relation['created_at'] as String)),
          ),
        );
      }
      print('✅ [OfflineItemRepository] 标签关联同步到本地完成');
    } catch (e) {
      print('🔴 [OfflineItemRepository] 同步标签关联到本地失败: $e');
    }
  }

  Future<void> _syncTagRelationsToRemote(String itemId, List<String> tagIds) async {
    try {
      print('🔄 [OfflineItemRepository] 开始同步 ${tagIds.length} 个标签关联到远程...');
      await _client.from('item_tag_relations').delete().eq('item_id', itemId);
      
      for (final tagId in tagIds) {
        await _client.from('item_tag_relations').insert({
          'item_id': itemId,
          'tag_id': tagId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      print('✅ [OfflineItemRepository] 标签关联同步到远程完成');
    } catch (e) {
      print('🔴 [OfflineItemRepository] 同步标签关联到远程失败: $e');
    }
  }

  Future<void> _syncAllTagRelationsFromRemote() async {
    try {
      print('🔄 [OfflineItemRepository] 开始批量同步所有标签关联...');
      
      final response = await _client
          .from('item_tag_relations')
          .select()
          .order('created_at', ascending: true);
      
      if (response == null) {
        print('⚠️ [OfflineItemRepository] 远程标签关联数据为空');
        return;
      }
      
      final relations = (response as List).cast<Map<String, dynamic>>();
      print('📥 [OfflineItemRepository] 从远程获取了 ${relations.length} 个标签关联');
      
      await _localDb.itemTagRelationsDao.deleteAll();
      
      for (final relation in relations) {
        await _localDb.itemTagRelationsDao.insertRelation(
          db.ItemTagRelationsCompanion(
            itemId: Value(relation['item_id'] as String),
            tagId: Value(relation['tag_id'] as String),
            createdAt: Value(DateTime.parse(relation['created_at'] as String)),
          ),
        );
      }
      
      print('✅ [OfflineItemRepository] 批量标签关联同步完成，共 ${relations.length} 条');
    } catch (e) {
      print('🔴 [OfflineItemRepository] 批量同步标签关联失败: $e');
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
      final items = await getItems(householdId);
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

  Future<void> fixSyncStatus() async {
    try {
      final allItems = await _localDb.itemsDao.getAll();
      int fixedCount = 0;

      for (final item in allItems) {
        if (item.syncPending == false && item.syncStatus != 'synced') {
          await _localDb.itemsDao.updateItem(
            db.HouseholdItemsCompanion(
              id: Value(item.id),
              syncStatus: const Value('synced'),
            ),
          );
          fixedCount++;
        }
      }

      print('🔧 [OfflineItemRepository] 修复了 $fixedCount 个物品的同步状态');
    } catch (e) {
      print('🔴 [OfflineItemRepository] 修复同步状态失败: $e');
    }
  }

  Future<void> initialize(String householdId) async {
    try {
      print('🚀 [OfflineItemRepository] 开始初始化数据...');
      
      final localItems = await _localDb.itemsDao.getByHousehold(householdId);
      
      if (localItems.isEmpty) {
        print('📥 [OfflineItemRepository] 本地为空，从远程拉取完整数据...');
        await Future.wait([
          _fetchAndSyncItems(householdId),
          getLocations(householdId),
          getTags(householdId),
          getTypeConfigs(householdId),
        ]);
      } else {
        print('📦 [OfflineItemRepository] 本地已有数据，只拉取基础数据...');
        await Future.wait([
          getLocations(householdId),
          getTags(householdId),
          getTypeConfigs(householdId),
        ]);
      }
      
      print('✅ [OfflineItemRepository] 数据初始化完成');
    } catch (e) {
      print('🔴 [OfflineItemRepository] 数据初始化失败: $e');
    }
  }
}
