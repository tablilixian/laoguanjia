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
import '../services/item_query_service.dart';
import '../services/item_command_service.dart';
import '../services/item_sync_service.dart';

/// 分页查询结果（保持向后兼容）
/// 
/// 注意：这个类现在也定义在 ItemQueryService 中，这里保留是为了向后兼容
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

/// 离线物品仓库 - 向后兼容的门面类
/// 
/// 这个类现在是一个门面（Facade），委托给三个专门的服务：
/// - [ItemQueryService] - 负责所有读操作
/// - [ItemCommandService] - 负责所有写操作
/// - [ItemSyncService] - 负责所有同步操作
/// 
/// 使用方式保持不变，但内部实现已经优化：
/// - 统计使用 SQL 聚合，不再加载所有数据到内存
/// - 支持分页查询
/// - 搜索支持大小写不敏感和多字段
/// - 离线崩溃修复（远程请求失败时优雅降级）
class OfflineItemRepository {
  final _client = SupabaseClientManager.client;
  final db.AppDatabase _localDb = db.AppDatabase();
  late final SyncEngine _syncEngine;
  
  // 新的服务架构
  late final ItemQueryService _queryService;
  late final ItemCommandService _commandService;
  late final ItemSyncService _syncService;

  OfflineItemRepository() {
    _syncEngine = SyncEngine(localDb: _localDb, remoteDb: _client);
    
    // 初始化服务
    _queryService = ItemQueryService(localDb: _localDb);
    _commandService = ItemCommandService(
      localDb: _localDb,
      onDataChanged: (householdId) {
        // 写操作后自动触发同步
        _syncService.autoSync(householdId);
      },
    );
    _syncService = ItemSyncService(
      localDb: _localDb,
      onSyncStateChanged: () {
        // 同步状态变化时可以通知 UI
      },
    );
  }

  SyncEngine get syncEngine => _syncEngine;
  
  // 暴露服务实例（可选，供高级用法使用）
  ItemQueryService get queryService => _queryService;
  ItemCommandService get commandService => _commandService;
  ItemSyncService get syncService => _syncService;

  // ========== 查询操作（委托给 ItemQueryService） ==========

  /// 获取物品列表（全量）
  Future<List<HouseholdItem>> getItems(String householdId) async {
    return _queryService.getItems(householdId);
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
    final result = await _queryService.getItemsPaginated(
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
    
    // 转换为向后兼容的类型
    return PaginatedItemsResult(
      items: result.items,
      totalCount: result.totalCount,
      hasMore: result.hasMore,
    );
  }

  /// 获取单个物品
  Future<HouseholdItem?> getItem(String id) async {
    return _queryService.getItem(id);
  }

  /// 搜索物品（大小写不敏感，多字段）
  Future<List<HouseholdItem>> searchItems(
    String householdId, 
    String query, {
    int limit = 50,
  }) async {
    return _queryService.searchItems(householdId, query, limit: limit);
  }

  /// 获取搜索结果总数
  Future<int> getSearchCount(String householdId, String query) async {
    return _queryService.getSearchCount(householdId, query);
  }

  // ========== 统计操作（委托给 ItemQueryService） ==========

  /// 获取物品概览统计
  Future<Map<String, dynamic>> getItemOverview(String householdId) async {
    return _queryService.getItemOverview(householdId);
  }

  /// 获取按类型统计
  Future<List<Map<String, dynamic>>> getItemCountByType(String householdId) async {
    return _queryService.getItemCountByType(householdId);
  }

  /// 获取按归属人统计
  Future<List<Map<String, dynamic>>> getItemCountByOwner(String householdId) async {
    return _queryService.getItemCountByOwner(householdId);
  }

  /// 获取按位置统计
  Future<Map<String, int>> getAllLocationItemCounts(String householdId) async {
    return _queryService.getAllLocationItemCounts(householdId);
  }

  // ========== 位置操作 ==========

  /// 获取位置列表
  Future<List<ItemLocation>> getLocations(String householdId) async {
    return _queryService.getLocations(householdId);
  }

  /// 获取单个位置
  Future<ItemLocation?> getLocation(String id) async {
    return _queryService.getLocation(id);
  }

  /// 创建位置
  Future<ItemLocation> createLocation(ItemLocation location) async {
    final newLocation = await _commandService.createLocation(location);
    // 触发同步
    _syncLocationToRemote(newLocation);
    return newLocation;
  }

  /// 更新位置
  Future<ItemLocation> updateLocation(ItemLocation location) async {
    final updatedLocation = await _commandService.updateLocation(location);
    // 触发同步
    _syncLocationToRemote(updatedLocation);
    return updatedLocation;
  }

  /// 删除位置
  Future<void> deleteLocation(String id) async {
    await _commandService.deleteLocation(id);
    await _deleteLocationFromRemote(id);
  }

  // ========== 标签操作 ==========

  /// 获取标签列表
  Future<List<ItemTag>> getTags(String householdId) async {
    return _queryService.getTags(householdId);
  }

  /// 获取单个标签
  Future<ItemTag?> getTag(String id) async {
    return _queryService.getTag(id);
  }

  /// 创建标签
  Future<ItemTag> createTag(ItemTag tag) async {
    final newTag = await _commandService.createTag(tag);
    // 触发同步
    _syncTagToRemote(newTag);
    return newTag;
  }

  /// 更新标签
  Future<ItemTag> updateTag(ItemTag tag) async {
    final updatedTag = await _commandService.updateTag(tag);
    // 触发同步
    _syncTagToRemote(updatedTag);
    return updatedTag;
  }

  /// 删除标签
  Future<void> deleteTag(String id) async {
    await _commandService.deleteTag(id);
    await _deleteTagFromRemote(id);
  }

  // ========== 标签关联操作 ==========

  /// 获取物品的标签 ID 列表
  Future<List<String>> getItemTagIds(String itemId) async {
    return _queryService.getItemTagIds(itemId);
  }

  /// 设置物品标签
  Future<void> setItemTags(String itemId, List<String> tagIds) async {
    await _commandService.setItemTags(itemId, tagIds);
    // 位图方式：不再需要同步关系表
  }

  /// 添加标签到物品
  Future<void> addTagToItem(String itemId, String tagId) async {
    await _commandService.addTagToItem(itemId, tagId);
    // 位图方式：不再需要同步关系表
  }

  /// 从物品移除标签
  Future<void> removeTagFromItem(String itemId, String tagId) async {
    await _commandService.removeTagFromItem(itemId, tagId);
    // 位图方式：不再需要同步关系表
  }

  /// 更新物品标签
  Future<void> updateItemTags(String itemId, List<String> tagIds) async {
    await _commandService.setItemTags(itemId, tagIds);
    // 位图方式：不再需要同步关系表
  }

  // ========== 类型配置操作 ==========

  /// 获取类型配置列表
  Future<List<ItemTypeConfig>> getTypeConfigs(String householdId) async {
    return _queryService.getTypeConfigs(householdId);
  }

  /// 创建类型配置
  Future<ItemTypeConfig> createTypeConfig(ItemTypeConfig type) async {
    final newType = await _commandService.createTypeConfig(type);
    // 触发同步
    _syncTypeToRemote(newType);
    return newType;
  }

  /// 更新类型配置
  Future<ItemTypeConfig> updateTypeConfig(ItemTypeConfig type) async {
    final updatedType = await _commandService.updateTypeConfig(type);
    // 触发同步
    _syncTypeToRemote(updatedType);
    return updatedType;
  }

  /// 删除类型配置
  Future<void> deleteTypeConfig(String id) async {
    await _commandService.deleteTypeConfig(id);
    await _deleteTypeFromRemote(id);
  }

  // ========== 物品 CRUD 操作（委托给 ItemCommandService） ==========

  /// 创建物品
  Future<HouseholdItem> createItem(HouseholdItem item) async {
    return _commandService.createItem(item);
  }

  /// 更新物品
  Future<HouseholdItem> updateItem(HouseholdItem item) async {
    return _commandService.updateItem(item);
  }

  /// 删除物品
  Future<void> deleteItem(String id) async {
    await _commandService.deleteItem(id);
  }

  // ========== 同步操作（委托给 ItemSyncService） ==========

  /// 自动同步
  Future<void> autoSync(String householdId) async {
    return _syncService.autoSync(householdId);
  }

  /// 初始化数据
  Future<void> initialize(String householdId) async {
    return _syncService.initialize(householdId);
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

      print('🔧 [OfflineItemRepository] 修复了 $fixedCount 个物品的同步状态');
    } catch (e) {
      print('🔴 [OfflineItemRepository] 修复同步状态失败: $e');
    }
  }

  // ========== 内部同步方法（保持向后兼容） ==========

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

  Future<void> _syncTagToRemote(ItemTag tag) async {
    try {
      final existing = await _client
          .from('item_tags')
          .select('id')
          .eq('id', tag.id)
          .maybeSingle();
      
      if (existing == null) {
        await _client.from('item_tags').insert(tag.toRemoteJson());
      } else {
        await _client.from('item_tags').update(tag.toRemoteJson()).eq('id', tag.id);
      }
      
      await _localDb.tagsDao.markSynced(tag.id);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 同步标签到远程失败: $e');
    }
  }

  Future<void> _deleteTagFromRemote(String id) async {
    try {
      await _client.from('item_tags').delete().eq('id', id);
    } catch (e) {
      print('🔴 [OfflineItemRepository] 删除远程标签失败: $e');
    }
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
}
