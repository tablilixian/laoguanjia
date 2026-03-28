import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local_db/app_database.dart' as db;
import '../local_db/item_extensions.dart';
import '../models/household_item.dart';
import '../models/item_location.dart';
import '../models/item_tag.dart';
import '../models/item_type_config.dart';
import '../supabase/supabase_client.dart';
import '../../core/utils/retry_utils.dart';
import '../utils/tags_mask_helper.dart';
import '../local_db/connection/connection_native.dart';
import '../services/location_path_service.dart';

/// 分页查询结果
class PaginatedItemsResult {
  final List<HouseholdItem> items;
  final int totalCount;
  final bool hasMore;

  const PaginatedItemsResult({
    required this.items,
    required this.totalCount,
    required this.hasMore,
  });
}

/// 物品仓库 - 离线优先架构的统一入口
/// 
/// 职责：
/// - 查询：从本地数据库读取，支持分页、筛选、排序
/// - 写入：写入本地数据库，标记待同步
/// - 同步：与远程数据库同步，处理冲突
/// - 业务：数据组装、远程回退、位图标签操作
class ItemRepository {
  final _client = SupabaseClientManager.client;
  final db.AppDatabase _localDb = getDatabase();
  
  bool _isSyncing = false;

  // ==================== 查询操作 ====================

  /// 获取物品列表（带位置和标签信息）
  /// 
  /// 使用本地数据库，数据组装包括：
  /// - 位置名称、图标、路径
  /// - 标签列表（从位图解析）
  Future<List<HouseholdItem>> getItems(String householdId) async {
    final localItems = await _localDb.itemsDao.getByHousehold(householdId);
    final activeItems = localItems.where((i) => i.deletedAt == null).toList();
    
    final locations = await getLocations(householdId);
    final locationMap = {for (var l in locations) l.id: l};
    
    final tags = await getTags(householdId);
    final tagMap = {for (var t in tags) if (t.tagIndex != null) t.tagIndex!: t};
    
    return activeItems.map((i) {
      final item = i.toHouseholdItemModel();
      
      // 从位图解析标签ID
      final tagIndices = TagsMaskHelper.getTagIds(i.tagsMask);
      final itemTags = tagIndices
          .map((index) => tagMap[index])
          .whereType<ItemTag>()
          .toList();
      
      // ==================== 构建位置完整路径 ====================
      // 如果 ItemLocation.path 字段存在，直接使用
      // 否则使用 LocationPathService.buildLocationPath() 动态构建
      // 路径格式：用 " → " 分隔的层级路径（如 "卧室 → 柜子 → 第三个格子"）
      // ====================
      String? locationPath;
      String? locationName;
      String? locationIcon;
      String? locationPositionDescription;
      
      if (item.locationId != null && locationMap.containsKey(item.locationId)) {
        final location = locationMap[item.locationId]!;
        locationName = location.name;
        locationIcon = location.icon;
        locationPositionDescription = location.positionDescription;
        
        // 优先使用 ItemLocation.path（数据库中已存储的完整路径）
        if (location.path != null && location.path!.isNotEmpty) {
          locationPath = location.path;
        } else {
          // 如果 path 为空，使用 buildLocationPath 动态构建完整路径
          locationPath = LocationPathService.buildLocationPath(locations, location.id);
        }
      }
      
      return item.copyWith(
        locationName: locationName,
        locationIcon: locationIcon,
        locationPath: locationPath,
        locationPositionDescription: locationPositionDescription,
        tags: itemTags,
      );
    }).toList();
  }

  /// 分页获取物品列表（高效，支持筛选和排序）
  Future<PaginatedItemsResult> getItemsPaginated(
    String householdId, {
    required int limit,
    required int offset,
    String? searchQuery,
    String? itemType,
    String? locationId,
    String? ownerId,
    String sortBy = 'updatedAt',
    bool ascending = false,
  }) async {
    // 1. 获取分页数据
    final localItems = await _localDb.itemsDao.getByHouseholdPaginated(
      householdId,
      limit: limit,
      offset: offset,
      searchQuery: searchQuery,
      itemType: itemType,
      locationId: locationId,
      ownerId: ownerId,
      sortBy: sortBy,
      ascending: ascending,
    );
    
    // 2. 获取总数
    final totalCount = await _localDb.itemsDao.getCountByHousehold(
      householdId,
      searchQuery: searchQuery,
      itemType: itemType,
      locationId: locationId,
      ownerId: ownerId,
    );
    
    // 3. 获取关联数据（位置、标签）
    final locations = await getLocations(householdId);
    final locationMap = {for (var l in locations) l.id: l};
    
    final tags = await getTags(householdId);
    final tagMap = {for (var t in tags) if (t.tagIndex != null) t.tagIndex!: t};
    
    // 4. 组装数据
    final items = localItems.map((i) {
      final item = i.toHouseholdItemModel();
      
      // 从位图解析标签ID
      final tagIndices = TagsMaskHelper.getTagIds(i.tagsMask);
      final itemTags = tagIndices
          .map((index) => tagMap[index])
          .whereType<ItemTag>()
          .toList();
      
      // ==================== 构建位置完整路径 ====================
      // 如果 ItemLocation.path 字段存在，直接使用
      // 否则使用 LocationPathService.buildLocationPath() 动态构建
      // 路径格式：用 " → " 分隔的层级路径（如 "卧室 → 柜子 → 第三个格子"）
      // ====================
      String? locationPath;
      String? locationName;
      String? locationIcon;
      String? locationPositionDescription;
      
      if (item.locationId != null && locationMap.containsKey(item.locationId)) {
        final location = locationMap[item.locationId]!;
        locationName = location.name;
        locationIcon = location.icon;
        locationPositionDescription = location.positionDescription;
        
        // 优先使用 ItemLocation.path（数据库中已存储的完整路径）
        if (location.path != null && location.path!.isNotEmpty) {
          locationPath = location.path;
        } else {
          // 如果 path 为空，使用 buildLocationPath 动态构建完整路径
          locationPath = LocationPathService.buildLocationPath(locations, location.id);
        }
      }
      
      return item.copyWith(
        locationName: locationName,
        locationIcon: locationIcon,
        locationPath: locationPath,
        locationPositionDescription: locationPositionDescription,
        tags: itemTags,
      );
    }).toList();
    
    return PaginatedItemsResult(
      items: items,
      totalCount: totalCount,
      hasMore: offset + items.length < totalCount,
    );
  }

  /// 获取单个物品详情
  Future<HouseholdItem?> getItem(String id) async {
    try {
      final localItem = await _localDb.itemsDao.getById(id);
      if (localItem != null && localItem.deletedAt == null) {
        final item = localItem.toHouseholdItemModel();
        
        String? locationName;
        String? locationIcon;
        String? locationPath;
        String? locationPositionDescription;
        
        if (item.locationId != null) {
          final location = await getLocation(item.locationId!);
          if (location != null) {
            locationName = location.name;
            locationIcon = location.icon;
            locationPositionDescription = location.positionDescription;
            
            // ==================== 构建位置完整路径 ====================
            // 优先使用 ItemLocation.path（数据库中已存储的完整路径）
            // 如果 path 为空，使用 buildLocationPath 动态构建完整路径
            // ====================
            if (location.path != null && location.path!.isNotEmpty) {
              locationPath = location.path;
            } else {
              // 获取所有位置，用于构建完整路径
              final locations = await getLocations(item.householdId);
              locationPath = LocationPathService.buildLocationPath(locations, location.id);
            }
          }
        }
        
        // 从位图解析标签
        final tags = await _getTagsFromMask(item.tagsMask, item.householdId);
        
        return item.copyWith(
          locationName: locationName,
          locationIcon: locationIcon,
          locationPath: locationPath,
          locationPositionDescription: locationPositionDescription,
          tags: tags,
        );
      }
    } catch (e) {
      print('🔴 [ItemRepository] 获取本地物品失败: $e');
    }
    return null;
  }

  /// 智能搜索物品（大小写不敏感，多字段）
  Future<List<HouseholdItem>> searchItems(
    String householdId, 
    String query, {
    int limit = 50,
  }) async {
    final localItems = await _localDb.itemsDao.searchSmart(householdId, query, limit: limit);
    return localItems.map((i) => i.toHouseholdItemModel()).toList();
  }

  // ==================== 写入操作 ====================

  /// 创建物品
  /// 
  /// 自动生成 UUID、设置时间戳、标记待同步
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
        tagsMask: Value(newItem.tagsMask),
        slotPosition: Value(newItem.slotPosition?.toString()),
        syncPending: const Value(true),
      ),
    );

    print('✅ [ItemRepository] 创建物品: ${newItem.name} (${newItem.id})');
    return newItem;
  }

  /// 更新物品
  /// 
  /// 自动递增版本号、设置时间戳、标记待同步
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
        tagsMask: Value(updatedItem.tagsMask),
        slotPosition: Value(updatedItem.slotPosition?.toString()),
        syncPending: const Value(true),
      ),
    );

    print('✅ [ItemRepository] 更新物品: ${updatedItem.name} (${updatedItem.id})');
    return updatedItem;
  }

  /// 删除物品（软删除）
  /// 
  /// 递增版本号、标记待同步
  Future<void> deleteItem(String id) async {
    final current = await _localDb.itemsDao.getById(id);
    final newVersion = (current?.version ?? 0) + 1;
    
    await _localDb.itemsDao.softDeleteWithVersion(id, DateTime.now(), newVersion);
    print('✅ [ItemRepository] 删除物品: $id');
  }

  // ==================== 标签操作 ====================

  /// 设置物品标签（使用位图）
  Future<void> setItemTags(String itemId, List<String> tagIds) async {
    try {
      final item = await _localDb.itemsDao.getById(itemId);
      if (item == null) {
        throw Exception('物品不存在: $itemId');
      }

      final tags = await _localDb.tagsDao.getByHousehold(item.householdId);
      final tagMap = {for (var tag in tags) tag.id: tag.tagIndex};
      
      final tagIndices = tagIds
          .map((tagId) => tagMap[tagId])
          .whereType<int>()
          .toList();
      
      final newTagsMask = TagsMaskHelper.createMask(tagIndices);
      
      await _localDb.itemsDao.updateItem(
        db.HouseholdItemsCompanion(
          id: Value(itemId),
          tagsMask: Value(newTagsMask),
          updatedAt: Value(DateTime.now()),
          syncPending: const Value(true),
        ),
      );
      
      print('✅ [ItemRepository] 设置物品标签: $itemId -> ${tagIds.length}个标签 (mask: $newTagsMask)');
    } catch (e) {
      print('🔴 [ItemRepository] 设置物品标签失败: $e');
      rethrow;
    }
  }

  /// 更新物品标签（别名，兼容旧接口）
  Future<void> updateItemTags(String itemId, List<String> tagIds) async {
    await setItemTags(itemId, tagIds);
  }

  /// 添加标签到物品（使用位图）
  Future<void> addTagToItem(String itemId, String tagId) async {
    try {
      final item = await _localDb.itemsDao.getById(itemId);
      if (item == null) {
        throw Exception('物品不存在: $itemId');
      }

      final tag = await _localDb.tagsDao.getById(tagId);
      if (tag == null || tag.tagIndex == null) {
        throw Exception('标签不存在或没有序号: $tagId');
      }

      final newTagsMask = TagsMaskHelper.addTag(item.tagsMask, tag.tagIndex!);
      
      await _localDb.itemsDao.updateItem(
        db.HouseholdItemsCompanion(
          id: Value(itemId),
          tagsMask: Value(newTagsMask),
          updatedAt: Value(DateTime.now()),
          syncPending: const Value(true),
        ),
      );
      
      print('✅ [ItemRepository] 添加标签到物品: $itemId <- $tagId (index: ${tag.tagIndex}, mask: $newTagsMask)');
    } catch (e) {
      print('🔴 [ItemRepository] 添加标签到物品失败: $e');
      rethrow;
    }
  }

  /// 从物品移除标签（使用位图）
  Future<void> removeTagFromItem(String itemId, String tagId) async {
    try {
      final item = await _localDb.itemsDao.getById(itemId);
      if (item == null) {
        throw Exception('物品不存在: $itemId');
      }

      final tag = await _localDb.tagsDao.getById(tagId);
      if (tag == null || tag.tagIndex == null) {
        throw Exception('标签不存在或没有序号: $tagId');
      }

      final newTagsMask = TagsMaskHelper.removeTag(item.tagsMask, tag.tagIndex!);
      
      await _localDb.itemsDao.updateItem(
        db.HouseholdItemsCompanion(
          id: Value(itemId),
          tagsMask: Value(newTagsMask),
          updatedAt: Value(DateTime.now()),
          syncPending: const Value(true),
        ),
      );
      
      print('✅ [ItemRepository] 从物品移除标签: $itemId <- $tagId (index: ${tag.tagIndex}, mask: $newTagsMask)');
    } catch (e) {
      print('🔴 [ItemRepository] 从物品移除标签失败: $e');
      rethrow;
    }
  }

  /// 从位图获取标签列表
  Future<List<ItemTag>> _getTagsFromMask(int tagsMask, String householdId) async {
    try {
      final allTags = await getTags(householdId);
      final tagMap = {for (var t in allTags) if (t.tagIndex != null) t.tagIndex!: t};
      final tagIndices = TagsMaskHelper.getTagIds(tagsMask);
      
      return tagIndices
          .map((index) => tagMap[index])
          .whereType<ItemTag>()
          .toList();
    } catch (e) {
      print('🔴 [ItemRepository] 从位图获取标签失败: $e');
      return [];
    }
  }

  /// 获取物品的标签 ID 列表
  Future<List<String>> getItemTagIds(String itemId) async {
    try {
      final item = await _localDb.itemsDao.getById(itemId);
      if (item == null) return [];
      
      final tagIndices = TagsMaskHelper.getTagIds(item.tagsMask);
      final allTags = await getTags(item.householdId);
      final indexToIdMap = {for (var t in allTags) if (t.tagIndex != null) t.tagIndex!: t.id};
      
      return tagIndices
          .map((index) => indexToIdMap[index])
          .whereType<String>()
          .toList();
    } catch (e) {
      print('🔴 [ItemRepository] 获取物品标签失败: $e');
      return [];
    }
  }

  // ==================== 位置操作 ====================

  /// 获取位置列表（带远程回退）
  /// 
  /// 优先从本地数据库读取，本地为空时从远程获取
  Future<List<ItemLocation>> getLocations(String householdId) async {
    try {
      final localLocations = await _localDb.locationsDao.getByHousehold(householdId);
      if (localLocations.isNotEmpty) {
        return localLocations.map((l) => l.toItemLocationModel()).toList();
      }
    } catch (e) {
      print('🔴 [ItemRepository] 获取本地位置失败: $e');
    }
    
    // 本地为空，尝试从远程获取
    try {
      final locations = await _fetchRemoteLocations(householdId);
      for (final location in locations) {
        await _syncLocationToLocal(location);
      }
      return locations;
    } catch (e) {
      print('⚠️ [ItemRepository] 获取远程位置失败: $e');
      return []; // 降级返回空列表
    }
  }

  /// 获取单个位置（带远程回退）
  Future<ItemLocation?> getLocation(String id) async {
    try {
      final localLocation = await _localDb.locationsDao.getById(id);
      if (localLocation != null) {
        return localLocation.toItemLocationModel();
      }
    } catch (e) {
      print('🔴 [ItemRepository] 获取本地位置失败: $e');
    }
    
    try {
      final location = await _fetchRemoteLocation(id);
      if (location != null) {
        await _syncLocationToLocal(location);
      }
      return location;
    } catch (e) {
      print('⚠️ [ItemRepository] 获取远程位置失败: $e');
      return null;
    }
  }

  /// 创建位置
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

    print('✅ [ItemRepository] 创建位置: ${newLocation.name} (${newLocation.id})');
    return newLocation;
  }

  /// 更新位置
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

    print('✅ [ItemRepository] 更新位置: ${updatedLocation.name} (${updatedLocation.id})');
    return updatedLocation;
  }

  /// 删除位置
  Future<void> deleteLocation(String id) async {
    await _localDb.locationsDao.deleteLocation(id);
    print('✅ [ItemRepository] 删除位置: $id');
  }

  /// 从位置ID构建层级路径名称
  Future<String?> buildLocationPath(String? locationId) async {
    if (locationId == null) return null;
    
    final location = await getLocation(locationId);
    return location?.path;
  }

  // ==================== 标签操作 ====================

  /// 获取标签列表（带远程回退）
  Future<List<ItemTag>> getTags(String householdId) async {
    try {
      final localTags = await _localDb.tagsDao.getByHousehold(householdId);
      if (localTags.isNotEmpty) {
        return localTags.map((t) => t.toItemTagModel()).toList();
      }
    } catch (e) {
      print('🔴 [ItemRepository] 获取本地标签失败: $e');
    }
    
    try {
      final tags = await _fetchRemoteTags(householdId);
      for (final tag in tags) {
        await _syncTagToLocal(tag);
      }
      return tags;
    } catch (e) {
      print('⚠️ [ItemRepository] 获取远程标签失败: $e');
      return [];
    }
  }

  /// 获取单个标签
  Future<ItemTag?> getTag(String id) async {
    try {
      final localTag = await _localDb.tagsDao.getById(id);
      if (localTag != null) {
        return localTag.toItemTagModel();
      }
    } catch (e) {
      print('🔴 [ItemRepository] 获取本地标签失败: $e');
    }
    
    try {
      final tag = await _fetchRemoteTag(id);
      if (tag != null) {
        await _syncTagToLocal(tag);
      }
      return tag;
    } catch (e) {
      print('⚠️ [ItemRepository] 获取远程标签失败: $e');
      return null;
    }
  }

  /// 创建标签
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

    print('✅ [ItemRepository] 创建标签: ${newTag.name} (${newTag.id})');
    return newTag;
  }

  /// 更新标签
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

    print('✅ [ItemRepository] 更新标签: ${tag.name} (${tag.id})');
    return tag;
  }

  /// 删除标签
  Future<void> deleteTag(String id) async {
    await _localDb.tagsDao.deleteTag(id);
    print('✅ [ItemRepository] 删除标签: $id');
  }

  // ==================== 类型配置操作 ====================

  /// 获取类型配置列表（带远程回退）
  Future<List<ItemTypeConfig>> getTypeConfigs(String householdId) async {
    try {
      final localTypes = await _localDb.typesDao.getAll();
      if (localTypes.isNotEmpty) {
        return localTypes.map((t) => t.toItemTypeConfigModel()).toList();
      }
    } catch (e) {
      print('🔴 [ItemRepository] 获取本地类型失败: $e');
    }
    
    // 本地为空，尝试从远程获取
    try {
      final types = await _fetchRemoteTypeConfigs(householdId);
      for (final type in types) {
        await _syncTypeToLocal(type);
      }
      return types;
    } catch (e) {
      print('⚠️ [ItemRepository] 获取远程类型失败: $e');
      return [];
    }
  }

  /// 创建类型配置
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

    print('✅ [ItemRepository] 创建类型配置: ${newType.typeLabel} (${newType.id})');
    return newType;
  }

  /// 更新类型配置
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

    print('✅ [ItemRepository] 更新类型配置: ${type.typeLabel} (${type.id})');
    return type;
  }

  /// 删除类型配置
  Future<void> deleteTypeConfig(String id) async {
    await _localDb.typesDao.deleteType(id);
    print('✅ [ItemRepository] 删除类型配置: $id');
  }

  // ==================== 统计操作 ====================

  /// 获取物品概览统计
  Future<Map<String, dynamic>> getItemOverview(String householdId) async {
    try {
      final stats = await _localDb.itemsDao.getOverviewStats(householdId);
      final typeCounts = await _localDb.itemsDao.getCountByType(householdId);
      final byTypeList = typeCounts
          .map((tc) => {'type_key': tc.typeKey, 'count': tc.count})
          .toList();

      return {
        'total': stats.total,
        'newThisMonth': stats.newThisMonth,
        'attentionNeeded': stats.attentionNeeded,
        'byType': byTypeList,
      };
    } catch (e) {
      print('🔴 [ItemRepository] 获取概览统计失败: $e');
      rethrow;
    }
  }

  /// 获取按类型统计
  Future<List<Map<String, dynamic>>> getItemCountByType(String householdId) async {
    try {
      final typeCounts = await _localDb.itemsDao.getCountByType(householdId);
      return typeCounts
          .map((tc) => {'type_key': tc.typeKey, 'count': tc.count})
          .toList();
    } catch (e) {
      print('🔴 [ItemRepository] 获取按类型统计失败: $e');
      rethrow;
    }
  }

  /// 获取按归属人统计
  Future<List<Map<String, dynamic>>> getItemCountByOwner(String householdId) async {
    try {
      final ownerCounts = await _localDb.itemsDao.getCountByOwner(householdId);
      return ownerCounts
          .map((oc) => {'owner_id': oc.ownerId, 'count': oc.count})
          .toList();
    } catch (e) {
      print('🔴 [ItemRepository] 获取按归属人统计失败: $e');
      rethrow;
    }
  }

  /// 获取按位置统计
  Future<Map<String, int>> getAllLocationItemCounts(String householdId) async {
    try {
      final locationCounts = await _localDb.itemsDao.getCountByLocation(householdId);
      final result = <String, int>{};
      for (final lc in locationCounts) {
        if (lc.locationId != null) {
          result[lc.locationId!] = lc.count;
        }
      }
      return result;
    } catch (e) {
      print('🔴 [ItemRepository] 获取位置物品数量失败: $e');
      rethrow;
    }
  }

  /// 获取按标签统计
  Future<List<Map<String, dynamic>>> getItemCountByTag(String householdId) async {
    try {
      final tagWithCounts = await _localDb.tagsDao.getTagWithCounts(householdId);
      return tagWithCounts.map((tc) => {
        'tag_id': tc.id,
        'name': tc.name,
        'color': tc.color,
        'icon': tc.icon,
        'category': tc.category,
        'count': tc.count,
      }).toList();
    } catch (e) {
      print('🔴 [ItemRepository] 获取按标签统计失败: $e');
      rethrow;
    }
  }

  // ==================== 同步操作 ====================

  /// 自动同步（写操作后调用）
  Future<void> autoSync(String householdId) async {
    if (_isSyncing) {
      print('⚠️ [ItemRepository] 同步已在进行中，跳过');
      return;
    }

    try {
      _isSyncing = true;
      print('🔄 [ItemRepository] 开始自动同步...');
      
      final pendingItems = await _localDb.itemsDao.getSyncPending();
      
      if (pendingItems.isEmpty) {
        print('✅ [ItemRepository] 没有待同步的物品');
        return;
      }
      
      print('📋 [ItemRepository] 待同步物品数量: ${pendingItems.length}');
      
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
        print('➕ [ItemRepository] 插入 ${itemsToInsert.length} 个新物品...');
        await _client.from('household_items').insert(itemsToInsert);
        for (final item in itemsToInsert) {
          await _localDb.itemsDao.markSynced(item['id']);
        }
      }

      if (itemsToUpdate.isNotEmpty) {
        print('🔄 [ItemRepository] 更新 ${itemsToUpdate.length} 个物品...');
        for (final item in itemsToUpdate) {
          await _client.from('household_items').update(item).eq('id', item['id']);
          await _localDb.itemsDao.markSynced(item['id']);
        }
      }

      if (itemsToPull.isNotEmpty) {
        print('📥 [ItemRepository] 拉取 ${itemsToPull.length} 个远程物品...');
        for (final itemId in itemsToPull) {
          final remoteItem = await _fetchRemoteItem(itemId);
          if (remoteItem != null) {
            await _syncItemToLocal(remoteItem);
          }
        }
      }

      print('✅ [ItemRepository] 自动同步完成');
    } catch (e) {
      print('🔴 [ItemRepository] 自动同步失败: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// 初始化数据（首次启动或本地数据为空时）
  Future<void> initialize(String householdId) async {
    try {
      print('🚀 [ItemRepository] 开始初始化数据...');
      
      final localItems = await _localDb.itemsDao.getByHousehold(householdId);
      
      if (localItems.isEmpty) {
        print('📥 [ItemRepository] 本地为空，从远程拉取完整数据...');
        await Future.wait([
          _fetchAndSyncRemoteItems(householdId),
          _fetchAndSyncRemoteLocations(householdId),
          _fetchAndSyncRemoteTags(householdId),
          _fetchAndSyncRemoteTypeConfigs(householdId),  // 添加类型配置同步
        ]);
      } else {
        print('📦 [ItemRepository] 本地已有数据，进行增量同步...');
        await Future.wait([
          _fetchAndSyncRemoteItemsIncremental(householdId),
          _fetchAndSyncRemoteLocations(householdId),
          _fetchAndSyncRemoteTags(householdId),
          _fetchAndSyncRemoteTypeConfigs(householdId),  // 添加类型配置同步
        ]);
      }
      
      print('✅ [ItemRepository] 数据初始化完成');
    } catch (e) {
      print('🔴 [ItemRepository] 数据初始化失败: $e');
    }
  }

  // ==================== 内部辅助方法 ====================

  Future<ItemLocation?> _fetchRemoteLocation(String id) async {
    try {
      final response = await _client
          .from('item_locations')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response != null) {
        return ItemLocation.fromMap(response);
      }
      return null;
    } catch (e) {
      print('🔴 [ItemRepository] 获取远程位置失败: $e');
      return null;
    }
  }

  Future<List<ItemLocation>> _fetchRemoteLocations(String householdId) async {
    try {
      final response = await _client
          .from('item_locations')
          .select()
          .eq('household_id', householdId)
          .order('sort_order', ascending: true);
      if (response != null) {
        return (response as List).map((e) => ItemLocation.fromMap(e)).toList();
      }
      return [];
    } catch (e) {
      print('🔴 [ItemRepository] 获取远程位置列表失败: $e');
      return [];
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
      print('🔴 [ItemRepository] 同步位置到本地失败: $e');
    }
  }

  Future<ItemTag?> _fetchRemoteTag(String id) async {
    try {
      final response = await _client
          .from('item_tags')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response != null) {
        return ItemTag.fromMap(response);
      }
      return null;
    } catch (e) {
      print('🔴 [ItemRepository] 获取远程标签失败: $e');
      return null;
    }
  }

  Future<List<ItemTag>> _fetchRemoteTags(String householdId) async {
    try {
      final response = await _client
          .from('item_tags')
          .select('id, household_id, name, color, icon, category, applicable_types, created_at, tag_index')
          .eq('household_id', householdId)
          .order('created_at', ascending: false);
      if (response != null) {
        return (response as List).map((e) => ItemTag.fromMap(e)).toList();
      }
      return [];
    } catch (e) {
      print('🔴 [ItemRepository] 获取远程标签列表失败: $e');
      return [];
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
          tagIndex: Value(tag.tagIndex),
          createdAt: Value(tag.createdAt),
          updatedAt: Value(DateTime.now()),
          syncPending: const Value(false),
        ),
      );
    } catch (e) {
      print('🔴 [ItemRepository] 同步标签到本地失败: $e');
    }
  }

  Future<void> _fetchAndSyncRemoteItems(String householdId) async {
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
        
        for (final item in items) {
          await _syncItemToLocal(item);
        }
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote items',
      shouldRetry: shouldRetryOnNetworkError,
    );
  }

  Future<void> _fetchAndSyncRemoteItemsIncremental(String householdId) async {
    final localItems = await _localDb.itemsDao.getByHousehold(householdId);
    final localItemMap = {for (var item in localItems) item.id: item};
    
    return retryWithBackoff(
      () async {
        final response = await _client
            .from('household_items')
            .select('id, household_id, name, description, item_type, location_id, owner_id, quantity, brand, model, purchase_date, purchase_price, warranty_expiry, condition, image_url, thumbnail_url, notes, created_by, created_at, updated_at, deleted_at, version, tags_mask, slot_position')
            .eq('household_id', householdId)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false);

        final remoteItems = (response as List)
            .map((json) => HouseholdItem.fromMap(json as Map<String, dynamic>))
            .toList();
        
        for (final remoteItem in remoteItems) {
          final localItem = localItemMap[remoteItem.id];
          if (localItem == null || remoteItem.updatedAt.isAfter(localItem.updatedAt)) {
            await _syncItemToLocal(remoteItem);
          }
        }
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote items incremental',
      shouldRetry: shouldRetryOnNetworkError,
    );
  }

  Future<void> _fetchAndSyncRemoteLocations(String householdId) async {
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
        for (final location in locations) {
          await _syncLocationToLocal(location);
        }
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote locations',
      shouldRetry: shouldRetryOnNetworkError,
    );
  }

  Future<void> _fetchAndSyncRemoteTags(String householdId) async {
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
        for (final tag in tags) {
          await _syncTagToLocal(tag);
        }
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote tags',
      shouldRetry: shouldRetryOnNetworkError,
    );
  }

  Future<void> _fetchAndSyncRemoteTypeConfigs(String householdId) async {
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
        for (final type in types) {
          await _syncTypeToLocal(type);
        }
      },
      config: const RetryConfig(maxAttempts: 3),
      operationName: 'Fetch remote type configs',
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
      print('🔴 [ItemRepository] 获取远程物品失败: $e');
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
          tagsMask: Value(item.tagsMask),
          slotPosition: Value(item.slotPosition?.toString()),
          syncPending: const Value(false),
        ),
      );
    } catch (e) {
      print('🔴 [ItemRepository] 同步物品到本地失败: $e');
      rethrow;
    }
  }

  // ==================== 类型配置操作（从旧 ItemRepository 迁移） ====================

  /// 获取类型配置列表（从远程）
  Future<List<ItemTypeConfig>> getItemTypes(String? householdId) async {
    final query = _client
        .from('item_type_configs')
        .select()
        .eq('is_active', true);

    if (householdId != null) {
      query.or('household_id.is.null,household_id.eq.$householdId');
    } else {
      query.isFilter('household_id', null);
    }

    final response = await query.order('sort_order');
    return (response as List).map((e) => ItemTypeConfig.fromMap(e)).toList();
  }

  /// 获取所有类型配置（包括停用的）
  Future<List<ItemTypeConfig>> getAllItemTypes(String? householdId) async {
    final query = _client.from('item_type_configs').select();

    if (householdId != null) {
      query.or('household_id.is.null,household_id.eq.$householdId');
    } else {
      query.isFilter('household_id', null);
    }

    final response = await query.order('sort_order');
    return (response as List).map((e) => ItemTypeConfig.fromMap(e)).toList();
  }

  /// 创建类型配置（从远程）
  Future<ItemTypeConfig> createItemType(ItemTypeConfig typeConfig) async {
    final response = await _client
        .from('item_type_configs')
        .insert({
          'household_id': typeConfig.householdId,
          'type_key': typeConfig.typeKey,
          'type_label': typeConfig.typeLabel,
          'icon': typeConfig.icon,
          'color': typeConfig.color,
          'sort_order': typeConfig.sortOrder,
        })
        .select()
        .single();

    return ItemTypeConfig.fromMap(response);
  }

  /// 停用类型配置
  Future<void> deactivateItemType(String typeId) async {
    await _client
        .from('item_type_configs')
        .update({'is_active': false})
        .eq('id', typeId);
  }

  /// 更新类型配置（从远程）
  Future<ItemTypeConfig> updateItemTypeConfig(ItemTypeConfig typeConfig) async {
    final response = await _client
        .from('item_type_configs')
        .update({
          'type_label': typeConfig.typeLabel,
          'icon': typeConfig.icon,
          'color': typeConfig.color,
          'is_active': typeConfig.isActive,
        })
        .eq('id', typeConfig.id)
        .select()
        .single();

    return ItemTypeConfig.fromMap(response);
  }

  /// 删除类型配置（从远程）
  Future<void> deleteItemType(String typeId) async {
    await _client.from('item_type_configs').delete().eq('id', typeId);
  }

  // ==================== 槽位操作（从旧 ItemRepository 迁移） ====================

  /// 获取已占用的槽位
  Future<Set<String>> getOccupiedSlots(String locationId) async {
    final response = await _client
        .from('household_items')
        .select('slot_position')
        .eq('location_id', locationId)
        .isFilter('deleted_at', null);

    final occupiedSlots = <String>{};
    for (final item in response) {
      final slotPosition = item['slot_position'] as Map<String, dynamic>?;
      if (slotPosition != null) {
        final slotKey = _generateSlotKey(slotPosition);
        if (slotKey != null) {
          occupiedSlots.add(slotKey);
        }
      }
    }
    return occupiedSlots;
  }

  String? _generateSlotKey(Map<String, dynamic> slotPosition) {
    if (slotPosition.containsKey('direction')) {
      final dir = slotPosition['direction'] as String?;
      final height = slotPosition['height'] as String?;
      return height != null ? '$dir$height' : dir;
    }
    if (slotPosition.containsKey('index')) {
      return 'index_${slotPosition['index']}';
    }
    if (slotPosition.containsKey('row') && slotPosition.containsKey('col')) {
      return 'grid_${slotPosition['row']}_${slotPosition['col']}';
    }
    if (slotPosition.containsKey('level')) {
      return 'stack_${slotPosition['level']}';
    }
    return null;
  }

  // ==================== 同步引擎 ====================

  /// 修复同步状态
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

      print('🔧 [ItemRepository] 修复了 $fixedCount 个物品的同步状态');
    } catch (e) {
      print('🔴 [ItemRepository] 修复同步状态失败: $e');
    }
  }

  // ==================== 远程类型配置辅助方法 ====================

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
      print('🔴 [ItemRepository] 同步类型到本地失败: $e');
    }
  }
}
