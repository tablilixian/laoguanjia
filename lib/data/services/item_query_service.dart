import 'package:drift/drift.dart';

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

/// 物品查询服务 - 负责所有只读操作
/// 
/// 职责：
/// - 物品列表查询（分页、筛选、排序）
/// - 物品详情查询
/// - 物品搜索
/// - 统计查询
/// - 位置/标签/类型配置查询
class ItemQueryService {
  final _client = SupabaseClientManager.client;
  final db.AppDatabase _localDb;

  ItemQueryService({db.AppDatabase? localDb}) 
      : _localDb = localDb ?? db.AppDatabase();

  // ========== 远程数据获取辅助方法 ==========

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
      print('🔴 [ItemQueryService] 获取远程位置失败: $e');
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
      print('🔴 [ItemQueryService] 获取远程位置列表失败: $e');
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
      print('🔴 [ItemQueryService] 同步位置到本地失败: $e');
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
      print('🔴 [ItemQueryService] 获取远程标签失败: $e');
      return null;
    }
  }

  Future<List<ItemTag>> _fetchRemoteTags(String householdId) async {
    try {
      final response = await _client
          .from('item_tags')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);
      if (response != null) {
        return (response as List).map((e) => ItemTag.fromMap(e)).toList();
      }
      return [];
    } catch (e) {
      print('🔴 [ItemQueryService] 获取远程标签列表失败: $e');
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
          createdAt: Value(tag.createdAt),
          updatedAt: Value(DateTime.now()),
          syncPending: const Value(false),
        ),
      );
    } catch (e) {
      print('🔴 [ItemQueryService] 同步标签到本地失败: $e');
    }
  }

  // ========== 物品查询 ==========

  /// 获取物品列表（全量，用于小数据量场景）
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
        locationName: item.locationId != null && locationMap.containsKey(item.locationId) 
            ? locationMap[item.locationId]!.name : null,
        locationIcon: item.locationId != null && locationMap.containsKey(item.locationId) 
            ? locationMap[item.locationId]!.icon : null,
        locationPath: item.locationId != null && locationMap.containsKey(item.locationId) 
            ? locationMap[item.locationId]!.path : null,
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
    final tagMap = {for (var t in tags) t.id: t};
    
    final itemTagRelations = await _localDb.itemTagRelationsDao.getAll();
    final itemTagMap = <String, List<String>>{};
    for (final relation in itemTagRelations) {
      if (!itemTagMap.containsKey(relation.itemId)) {
        itemTagMap[relation.itemId] = [];
      }
      itemTagMap[relation.itemId]!.add(relation.tagId);
    }
    
    // 4. 组装数据
    final items = localItems.map((i) {
      final item = i.toHouseholdItemModel();
      final tagIds = itemTagMap[item.id] ?? [];
      final itemTags = tagIds.map((tagId) => tagMap[tagId]).whereType<ItemTag>().toList();
      
      return item.copyWith(
        locationName: item.locationId != null && locationMap.containsKey(item.locationId) 
            ? locationMap[item.locationId]!.name : null,
        locationIcon: item.locationId != null && locationMap.containsKey(item.locationId) 
            ? locationMap[item.locationId]!.icon : null,
        locationPath: item.locationId != null && locationMap.containsKey(item.locationId) 
            ? locationMap[item.locationId]!.path : null,
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
        
        if (item.locationId != null) {
          final location = await getLocation(item.locationId!);
          if (location != null) {
            locationName = location.name;
            locationIcon = location.icon;
            locationPath = location.path;
          }
        }
        
        final tagIds = await _localDb.itemTagRelationsDao.getTagIdsForItem(id);
        final tags = <ItemTag>[];
        for (final tagId in tagIds) {
          final tag = await getTag(tagId);
          if (tag != null) {
            tags.add(tag);
          }
        }
        
        return item.copyWith(
          locationName: locationName,
          locationIcon: locationIcon,
          locationPath: locationPath,
          tags: tags,
        );
      }
    } catch (e) {
      print('🔴 [ItemQueryService] 获取本地物品失败: $e');
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

  /// 获取搜索结果总数
  Future<int> getSearchCount(String householdId, String query) async {
    return await _localDb.itemsDao.getSearchCount(householdId, query);
  }

  // ========== 统计查询 ==========

  /// 获取物品概览统计（使用 SQL 聚合，高效）
  Future<Map<String, dynamic>> getItemOverview(String householdId) async {
    try {
      // 1. 获取基础统计（SQL 聚合）
      final stats = await _localDb.itemsDao.getOverviewStats(householdId);
      
      // 2. 获取按类型统计（SQL GROUP BY）
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
      print('🔴 [ItemQueryService] 获取概览统计失败: $e');
      rethrow;
    }
  }

  /// 获取按类型统计（使用 SQL GROUP BY，高效）
  Future<List<Map<String, dynamic>>> getItemCountByType(String householdId) async {
    try {
      final typeCounts = await _localDb.itemsDao.getCountByType(householdId);
      return typeCounts
          .map((tc) => {'type_key': tc.typeKey, 'count': tc.count})
          .toList();
    } catch (e) {
      print('🔴 [ItemQueryService] 获取按类型统计失败: $e');
      rethrow;
    }
  }

  /// 获取按归属人统计（使用 SQL GROUP BY，高效）
  Future<List<Map<String, dynamic>>> getItemCountByOwner(String householdId) async {
    try {
      final ownerCounts = await _localDb.itemsDao.getCountByOwner(householdId);
      return ownerCounts
          .map((oc) => {'owner_id': oc.ownerId, 'count': oc.count})
          .toList();
    } catch (e) {
      print('🔴 [ItemQueryService] 获取按归属人统计失败: $e');
      rethrow;
    }
  }

  /// 获取按位置统计（使用 SQL GROUP BY，高效）
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
      print('🔴 [ItemQueryService] 获取位置物品数量失败: $e');
      rethrow;
    }
  }

  // ========== 位置查询 ==========

  /// 获取位置列表
  Future<List<ItemLocation>> getLocations(String householdId) async {
    try {
      final localLocations = await _localDb.locationsDao.getByHousehold(householdId);
      if (localLocations.isNotEmpty) {
        return localLocations.map((l) => l.toItemLocationModel()).toList();
      }
    } catch (e) {
      print('🔴 [ItemQueryService] 获取本地位置失败: $e');
    }
    
    // 本地为空，尝试从远程获取
    try {
      final locations = await _fetchRemoteLocations(householdId);
      for (final location in locations) {
        await _syncLocationToLocal(location);
      }
      return locations;
    } catch (e) {
      print('⚠️ [ItemQueryService] 获取远程位置失败: $e');
      return []; // 降级返回空列表
    }
  }

  /// 获取单个位置
  Future<ItemLocation?> getLocation(String id) async {
    try {
      final localLocation = await _localDb.locationsDao.getById(id);
      if (localLocation != null) {
        return localLocation.toItemLocationModel();
      }
    } catch (e) {
      print('🔴 [ItemQueryService] 获取本地位置失败: $e');
    }
    
    // 本地为空，尝试从远程获取
    try {
      final location = await _fetchRemoteLocation(id);
      if (location != null) {
        await _syncLocationToLocal(location);
      }
      return location;
    } catch (e) {
      print('⚠️ [ItemQueryService] 获取远程位置失败: $e');
      return null;
    }
  }

  // ========== 标签查询 ==========

  /// 获取标签列表
  Future<List<ItemTag>> getTags(String householdId) async {
    try {
      final localTags = await _localDb.tagsDao.getByHousehold(householdId);
      if (localTags.isNotEmpty) {
        return localTags.map((t) => t.toItemTagModel()).toList();
      }
    } catch (e) {
      print('🔴 [ItemQueryService] 获取本地标签失败: $e');
    }
    
    // 本地为空，尝试从远程获取
    try {
      final tags = await _fetchRemoteTags(householdId);
      for (final tag in tags) {
        await _syncTagToLocal(tag);
      }
      return tags;
    } catch (e) {
      print('⚠️ [ItemQueryService] 获取远程标签失败: $e');
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
      print('🔴 [ItemQueryService] 获取本地标签失败: $e');
    }
    
    // 本地为空，尝试从远程获取
    try {
      final tag = await _fetchRemoteTag(id);
      if (tag != null) {
        await _syncTagToLocal(tag);
      }
      return tag;
    } catch (e) {
      print('⚠️ [ItemQueryService] 获取远程标签失败: $e');
      return null;
    }
  }

  /// 获取物品的标签 ID 列表
  Future<List<String>> getItemTagIds(String itemId) async {
    try {
      return await _localDb.itemTagRelationsDao.getTagIdsForItem(itemId);
    } catch (e) {
      print('🔴 [ItemQueryService] 获取物品标签失败: $e');
      return [];
    }
  }

  // ========== 类型配置查询 ==========

  /// 获取类型配置列表
  Future<List<ItemTypeConfig>> getTypeConfigs(String householdId) async {
    try {
      final localTypes = await _localDb.typesDao.getByHousehold(householdId);
      final allLocalTypes = await _localDb.typesDao.getAll();
      
      if (allLocalTypes.isEmpty) {
        return [];
      }
      
      return allLocalTypes.map((t) => t.toItemTypeConfigModel()).toList();
    } catch (e) {
      print('🔴 [ItemQueryService] 获取本地类型失败: $e');
      return [];
    }
  }
}

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
