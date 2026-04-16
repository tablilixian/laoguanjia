import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import '../local_db/app_database.dart' as db;
import '../local_db/connection/connection_native.dart';
import '../local_db/item_extensions.dart';
import '../models/household_item.dart';
import '../models/item_location.dart';
import '../models/item_tag.dart';
import '../models/item_type_config.dart';
import '../utils/tags_mask_helper.dart';
import '../services/location_path_service.dart';
import '../../core/utils/datetime_utils.dart';

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
/// 物品 Repository — 纯离线优先架构
/// 
/// 职责边界：
/// - 查询：仅从本地数据库读取
/// - 写入：仅写入本地数据库，标记 syncPending
/// - 同步：由 SyncEngine/SyncScheduler 负责远程交互
class ItemRepository {
  final db.AppDatabase _localDb = getDatabase();

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
    final tagMap = {
      for (var t in tags)
        if (t.tagIndex != null) t.tagIndex!: t,
    };

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
          locationPath = LocationPathService.buildLocationPath(
            locations,
            location.id,
          );
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
    String? tagId,
    String sortBy = 'updatedAt',
    bool ascending = false,
  }) async {
    // 如果指定了位置，获取该位置及其所有子位置的ID列表
    List<String>? locationIds;
    if (locationId != null && locationId.isNotEmpty) {
      final locations = await getLocations(householdId);
      locationIds = _getAllDescendantLocationIds(locations, locationId);
    }

    // 获取 tagIndex（用于位图过滤）
    int? tagIndex;
    if (tagId != null && tagId.isNotEmpty) {
      final tag = await getTag(tagId);
      tagIndex = tag?.tagIndex;
    }

    // 1. 获取分页数据
    final localItems = await _localDb.itemsDao.getByHouseholdPaginated(
      householdId,
      limit: limit,
      offset: offset,
      searchQuery: searchQuery,
      itemType: itemType,
      locationIds: locationIds,
      ownerId: ownerId,
      tagIndex: tagIndex,
      sortBy: sortBy,
      ascending: ascending,
    );

    // 2. 获取总数
    final totalCount = await _localDb.itemsDao.getCountByHousehold(
      householdId,
      searchQuery: searchQuery,
      itemType: itemType,
      locationIds: locationIds,
      ownerId: ownerId,
      tagIndex: tagIndex,
    );

    // 3. 获取关联数据（位置、标签）
    final locations = await getLocations(householdId);
    final locationMap = {for (var l in locations) l.id: l};

    final tags = await getTags(householdId);
    final tagMap = {
      for (var t in tags)
        if (t.tagIndex != null) t.tagIndex!: t,
    };

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
          locationPath = LocationPathService.buildLocationPath(
            locations,
            location.id,
          );
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
              locationPath = LocationPathService.buildLocationPath(
                locations,
                location.id,
              );
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
    final localItems = await _localDb.itemsDao.searchSmart(
      householdId,
      query,
      limit: limit,
    );
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
      createdAt: DateTimeUtils.nowUtc(),
      updatedAt: DateTimeUtils.nowUtc(),
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
      updatedAt: DateTimeUtils.nowUtc(),
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

    print(
      '💾 [本地DB] 更新物品: ${updatedItem.name} (${updatedItem.id}), '
      '旧version=${current?.version} → 新version=$newVersion, '
      'locationId=${updatedItem.locationId}, ownerId=${updatedItem.ownerId}, '
      'tagsMask=${updatedItem.tagsMask}, syncStatus=pending, syncPending=true',
    );
    return updatedItem;
  }

  /// 删除物品（软删除）
  ///
  /// 递增版本号、标记待同步
  Future<void> deleteItem(String id) async {
    final current = await _localDb.itemsDao.getById(id);
    final newVersion = (current?.version ?? 0) + 1;

    await _localDb.itemsDao.softDeleteWithVersion(
      id,
      DateTimeUtils.nowUtc(),
      newVersion,
    );
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
      final tagMap = {
        for (var tag in tags)
          if (tag.tagIndex != null) tag.id: tag.tagIndex!,
      };

      print(
        '🔍 [ItemRepository] setItemTags: 标签总数=${tags.length}, tagMap=${tagMap}, 传入的tagIds=$tagIds',
      );

      final tagIndices = tagIds
          .map((tagId) => tagMap[tagId])
          .whereType<int>()
          .toList();

      print('🔍 [ItemRepository] setItemTags: tagIndices=$tagIndices');

      final newTagsMask = TagsMaskHelper.createMask(tagIndices);
      final newVersion = (item.version ?? 0) + 1;

      await _localDb.itemsDao.updateItem(
        db.HouseholdItemsCompanion(
          id: Value(itemId),
          tagsMask: Value(newTagsMask),
          version: Value(newVersion),
          updatedAt: Value(DateTimeUtils.nowUtc()),
          syncPending: const Value(true),
        ),
      );

      print(
        '🏷️ [本地DB] 设置物品标签: $itemId, 旧mask=${item.tagsMask} → 新mask=$newTagsMask, '
        '旧version=${item.version} → 新version=$newVersion, syncPending=true',
      );
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
      print(
        '🔍 [ItemRepository] addTagToItem: 从DB读取的标签: id=${tag?.id}, name=${tag?.name}, tagIndex=${tag?.tagIndex}',
      );
      if (tag == null || tag.tagIndex == null) {
        throw Exception('标签不存在或没有序号: $tagId');
      }

      final newTagsMask = TagsMaskHelper.addTag(item.tagsMask, tag.tagIndex!);
      final newVersion = (item.version ?? 0) + 1;

      await _localDb.itemsDao.updateItem(
        db.HouseholdItemsCompanion(
          id: Value(itemId),
          tagsMask: Value(newTagsMask),
          version: Value(newVersion),
          updatedAt: Value(DateTimeUtils.nowUtc()),
          syncPending: const Value(true),
        ),
      );

      print(
        '✅ [ItemRepository] 添加标签到物品: $itemId <- $tagId (index: ${tag.tagIndex}, mask: $newTagsMask, version: $newVersion)',
      );
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

      final newTagsMask = TagsMaskHelper.removeTag(
        item.tagsMask,
        tag.tagIndex!,
      );
      final newVersion = (item.version ?? 0) + 1;

      await _localDb.itemsDao.updateItem(
        db.HouseholdItemsCompanion(
          id: Value(itemId),
          tagsMask: Value(newTagsMask),
          version: Value(newVersion),
          updatedAt: Value(DateTimeUtils.nowUtc()),
          syncPending: const Value(true),
        ),
      );

      print(
        '✅ [ItemRepository] 从物品移除标签: $itemId <- $tagId (index: ${tag.tagIndex}, mask: $newTagsMask)',
      );
    } catch (e) {
      print('🔴 [ItemRepository] 从物品移除标签失败: $e');
      rethrow;
    }
  }

  /// 从位图获取标签列表
  Future<List<ItemTag>> _getTagsFromMask(
    int tagsMask,
    String householdId,
  ) async {
    try {
      final allTags = await getTags(householdId);
      final tagMap = {
        for (var t in allTags)
          if (t.tagIndex != null) t.tagIndex!: t,
      };
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
      final indexToIdMap = {
        for (var t in allTags)
          if (t.tagIndex != null) t.tagIndex!: t.id,
      };

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
  /// 获取指定位置及其所有子位置的ID列表
  ///
  /// 用于位置筛选时包含子位置下的物品。
  List<String> _getAllDescendantLocationIds(
    List<ItemLocation> locations,
    String parentId,
  ) {
    final ids = <String>[parentId];
    final children = locations.where((l) => l.parentId == parentId).toList();
    for (final child in children) {
      ids.addAll(_getAllDescendantLocationIds(locations, child.id));
    }
    return ids;
  }

  Future<List<ItemLocation>> getLocations(String householdId) async {
    // 离线优先：只查询本地数据库
    // 远程同步由 SyncEngine 负责
    try {
      final localLocations = await _localDb.locationsDao.getByHousehold(
        householdId,
      );
      return localLocations.map((l) => l.toItemLocationModel()).toList();
    } catch (e) {
      print('🔴 [ItemRepository] 获取本地位置失败: $e');
      return [];
    }
  }

  /// 获取单个位置（纯本地查询）
  Future<ItemLocation?> getLocation(String id) async {
    try {
      final localLocation = await _localDb.locationsDao.getById(id);
      if (localLocation != null) {
        return localLocation.toItemLocationModel();
      }
      return null;
    } catch (e) {
      print('🔴 [ItemRepository] 获取本地位置失败: $e');
      return null;
    }
  }

  /// 创建位置
  Future<ItemLocation> createLocation(ItemLocation location) async {
    final newLocation = location.copyWith(
      id: const Uuid().v4(),
      createdAt: DateTimeUtils.nowUtc(),
      updatedAt: DateTimeUtils.nowUtc(),
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
    // 获取当前版本
    final currentLocation = await _localDb.locationsDao.getById(location.id);
    final currentVersion = (currentLocation?.version ?? 0) + 1;

    final updatedLocation = location.copyWith(updatedAt: DateTimeUtils.nowUtc());

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
        version: Value(currentVersion),
        syncPending: const Value(true),
      ),
    );

    print(
      '✅ [ItemRepository] 更新位置: ${updatedLocation.name} (${updatedLocation.id}), version: $currentVersion',
    );
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

  /// 获取标签列表（纯本地查询，只返回未删除的标签）
  Future<List<ItemTag>> getTags(String householdId) async {
    try {
      final localTags = await _localDb.tagsDao.getActiveTags();
      final filtered = localTags.where((t) => t.householdId == householdId).toList();
      return filtered.map((t) => t.toItemTagModel()).toList();
    } catch (e) {
      print('🔴 [ItemRepository] 获取本地标签失败: $e');
      return [];
    }
  }

  /// 获取单个标签（纯本地查询）
  Future<ItemTag?> getTag(String id) async {
    try {
      final localTag = await _localDb.tagsDao.getById(id);
      if (localTag != null) {
        return localTag.toItemTagModel();
      }
      return null;
    } catch (e) {
      print('🔴 [ItemRepository] 获取本地标签失败: $e');
      return null;
    }
  }

  /// 创建标签
  Future<ItemTag> createTag(ItemTag tag) async {
    // 分配 tagIndex
    final tagIndex = await _localDb.tagsDao.getNextTagIndex(tag.householdId);
    if (tagIndex == null) {
      throw Exception('标签数量已达上限（最多63个）');
    }

    final newTag = tag.copyWith(
      id: const Uuid().v4(),
      tagIndex: tagIndex,
      createdAt: DateTimeUtils.nowUtc(),
      updatedAt: DateTimeUtils.nowUtc(),
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
        tagIndex: Value(newTag.tagIndex),
        createdAt: Value(newTag.createdAt),
        updatedAt: Value(DateTimeUtils.nowUtc()),
        syncPending: const Value(true),
      ),
    );

    print(
      '✅ [ItemRepository] 创建标签: ${newTag.name} (${newTag.id}), tagIndex: $tagIndex',
    );
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
        updatedAt: Value(DateTimeUtils.nowUtc()),
        syncPending: const Value(true),
      ),
    );

    print('✅ [ItemRepository] 更新标签: ${tag.name} (${tag.id})');
    return tag;
  }

  Future<void> deleteTag(String id) async {
    await _localDb.tagsDao.softDeleteTag(id);
    print('✅ [ItemRepository] 软删除标签: $id');
  }

  Future<ItemTag> restoreTag(ItemTag tag) async {
    final restoredTag = tag.copyWith(updatedAt: DateTimeUtils.nowUtc());
    await _localDb.tagsDao.restoreTag(restoredTag.id);
    // 同时更新标签数据（允许用户修改后恢复）
    await _localDb.tagsDao.updateTag(
      db.ItemTagsCompanion(
        id: Value(restoredTag.id),
        householdId: Value(restoredTag.householdId),
        name: Value(restoredTag.name),
        color: Value(restoredTag.color),
        icon: Value(restoredTag.icon),
        category: Value(restoredTag.category),
        applicableTypes: Value(restoredTag.applicableTypes.join(',')),
        tagIndex: Value(restoredTag.tagIndex),
        createdAt: Value(restoredTag.createdAt),
        updatedAt: Value(restoredTag.updatedAt),
        deletedAt: const Value(null), // 恢复时清除删除标记
        syncPending: const Value(true),
      ),
    );
    print('✅ [ItemRepository] 恢复标签: ${restoredTag.name}');
    return restoredTag;
  }

  /// 查找已删除的标签（用于恢复时预填数据）
  Future<ItemTag?> findDeletedTagByName(String householdId, String name) async {
    final dbTag = await _localDb.tagsDao.findDeletedTagByName(
      householdId,
      name,
    );
    if (dbTag == null) return null;
    return dbTag.toItemTagModel();
  }

  // ==================== 类型配置操作 ====================

  /// 获取类型配置列表（纯本地查询）
  Future<List<ItemTypeConfig>> getTypeConfigs(String householdId) async {
    try {
      final localTypes = await _localDb.typesDao.getAll();
      return localTypes.map((t) => t.toItemTypeConfigModel()).toList();
    } catch (e) {
      print('🔴 [ItemRepository] 获取本地类型失败: $e');
      return [];
    }
  }

  /// 创建类型配置
  Future<ItemTypeConfig> createTypeConfig(ItemTypeConfig type) async {
    final newType = type.copyWith(
      id: const Uuid().v4(),
      createdAt: DateTimeUtils.nowUtc(),
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
        updatedAt: Value(DateTimeUtils.nowUtc()),
        syncPending: const Value(true),
      ),
    );

    print('✅ [ItemRepository] 创建类型配置: ${newType.typeLabel} (${newType.id})');
    return newType;
  }

  /// 更新类型配置
  Future<ItemTypeConfig> updateTypeConfig(ItemTypeConfig type) async {
    // 获取当前版本
    final currentType = await _localDb.typesDao.getById(type.id);
    final currentVersion = (currentType?.version ?? 0) + 1;

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
        updatedAt: Value(DateTimeUtils.nowUtc()),
        version: Value(currentVersion),
        syncPending: const Value(true),
      ),
    );

    print(
      '✅ [ItemRepository] 更新类型配置: ${type.typeLabel} (${type.id}), version: $currentVersion',
    );
    return type;
  }

  /// 删除类型配置
  Future<void> deleteTypeConfig(String id) async {
    await _localDb.typesDao.deleteType(id);
    print('✅ [ItemRepository] 删除类型配置: $id');
  }

  /// 获取所有类型配置（包括停用的）
  Future<List<ItemTypeConfig>> getAllTypeConfigs(String householdId) async {
    final localTypes = await _localDb.typesDao.getByHousehold(householdId);
    return localTypes.map((t) => t.toItemTypeConfigModel()).toList();
  }

  /// 停用类型配置
  Future<void> deactivateTypeConfig(String typeId) async {
    final existing = await _localDb.typesDao.getById(typeId);
    if (existing != null) {
      final currentVersion = (existing.version ?? 0) + 1;
      await _localDb.typesDao.updateType(
        db.ItemTypeConfigsCompanion(
          id: Value(typeId),
          isActive: const Value(false),
          updatedAt: Value(DateTimeUtils.nowUtc()),
          version: Value(currentVersion),
          syncPending: const Value(true),
        ),
      );
    }
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
  Future<List<Map<String, dynamic>>> getItemCountByType(
    String householdId,
  ) async {
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
  Future<List<Map<String, dynamic>>> getItemCountByOwner(
    String householdId,
  ) async {
    try {
      final ownerCounts = await _localDb.itemsDao.getCountByOwner(householdId);

      // 从本地获取成员信息
      final members = await _localDb.membersDao.getByHousehold(householdId);
      final memberMap = {for (var m in members) m.id: m};

      return ownerCounts.map((oc) {
        final ownerId = oc.ownerId;
        final member = ownerId != null ? memberMap[ownerId] : null;

        return {
          'owner_id': ownerId,
          'name': ownerId == null ? '全家所有' : (member?.name ?? '未知'),
          'avatar_url': member?.avatarUrl,
          'count': oc.count,
        };
      }).toList();
    } catch (e) {
      print('🔴 [ItemRepository] 获取按归属人统计失败: $e');
      rethrow;
    }
  }

  // ==================== 初始化 ====================

  /// 初始化数据（首次启动时调用）
  /// 
  /// 离线优先架构下，此方法仅检查本地数据是否存在。
  /// 远程数据拉取由 SyncEngine/SyncScheduler 负责。
  Future<void> initialize(String householdId) async {
    try {
      final localItems = await _localDb.itemsDao.getByHousehold(householdId);
      if (localItems.isEmpty) {
        print('📦 [ItemRepository] 本地数据为空，请调用 SyncEngine.forceFullSync() 进行首次同步');
      } else {
        print('📦 [ItemRepository] 本地已有 ${localItems.length} 条数据');
      }
    } catch (e) {
      print('🔴 [ItemRepository] 数据初始化检查失败: $e');
    }
  }

  /// 获取按位置统计
  Future<Map<String, int>> getAllLocationItemCounts(String householdId) async {
    try {
      final locationCounts = await _localDb.itemsDao.getCountByLocation(
        householdId,
      );
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
  Future<List<Map<String, dynamic>>> getItemCountByTag(
    String householdId,
  ) async {
    try {
      final tagWithCounts = await _localDb.tagsDao.getTagWithCounts(
        householdId,
      );
      return tagWithCounts
          .map(
            (tc) => {
              'tag_id': tc.id,
              'name': tc.name,
              'color': tc.color,
              'icon': tc.icon,
              'category': tc.category,
              'count': tc.count,
            },
          )
          .toList();
    } catch (e) {
      print('🔴 [ItemRepository] 获取按标签统计失败: $e');
      rethrow;
    }
  }

  // ==================== 响应式监听（watch Stream） ====================

  /// 监听位置列表变化（数据库更新时自动推送）
  Stream<List<db.ItemLocation>> watchLocations(String householdId) =>
      _localDb.locationsDao.watchByHousehold(householdId);

  /// 监听单个位置变化
  Stream<db.ItemLocation?> watchLocation(String locationId) =>
      _localDb.locationsDao.watchById(locationId);

  /// 监听标签列表变化
  Stream<List<db.ItemTag>> watchTags(String householdId) =>
      _localDb.tagsDao.watchByHousehold(householdId);

  /// 监听单个标签变化
  Stream<db.ItemTag?> watchTag(String tagId) =>
      _localDb.tagsDao.watchById(tagId);

  /// 监听类型配置列表变化
  Stream<List<db.ItemTypeConfig>> watchTypeConfigs(String householdId) =>
      _localDb.typesDao.watchByHousehold(householdId);

  /// 监听物品列表变化
  Stream<List<db.HouseholdItem>> watchItems(String householdId) =>
      _localDb.itemsDao.watchByHousehold(householdId);

  // ==================== 同步状态修复 ====================

  /// 获取已占用的槽位（本地查询）
  Future<Set<String>> getOccupiedSlots(String locationId) async {
    final localItems = await _localDb.itemsDao.getByLocation(locationId);
    final occupiedSlots = <String>{};
    for (final item in localItems) {
      if (item.deletedAt != null) continue;
      if (item.slotPosition != null && item.slotPosition!.isNotEmpty) {
        try {
          final slotMap = jsonDecode(item.slotPosition!) as Map<String, dynamic>;
          final slotKey = _generateSlotKey(slotMap);
          if (slotKey != null) {
            occupiedSlots.add(slotKey);
          }
        } catch (_) {}
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
}
