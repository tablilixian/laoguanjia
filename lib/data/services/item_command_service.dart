import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local_db/app_database.dart' as db;
import '../local_db/daos/items_dao.dart';
import '../local_db/daos/locations_dao.dart';
import '../local_db/daos/tags_dao.dart';
import '../local_db/daos/types_dao.dart';
import '../models/household_item.dart';
import '../models/item_location.dart';
import '../models/item_tag.dart';
import '../models/item_type_config.dart';
import '../utils/tags_mask_helper.dart';
import '../local_db/connection/connection_native.dart';

/// 物品命令服务 - 负责所有写操作
/// 
/// 职责：
/// - 物品 CRUD（创建、更新、删除）
/// - 位置 CRUD
/// - 标签 CRUD
/// - 类型配置 CRUD
/// - 物品-标签关联管理
class ItemCommandService {
  final db.AppDatabase _localDb;
  final void Function(String householdId)? _onDataChanged;

  ItemCommandService({
    db.AppDatabase? localDb,
    void Function(String householdId)? onDataChanged,
  })  : _localDb = localDb ?? getDatabase(),
        _onDataChanged = onDataChanged;

  // ========== 物品 CRUD ==========

  /// 创建物品
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

    print('✅ [ItemCommandService] 创建物品: ${newItem.name} (${newItem.id})');
    _onDataChanged?.call(newItem.householdId);

    return newItem;
  }

  /// 更新物品
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

    print('✅ [ItemCommandService] 更新物品: ${updatedItem.name} (${updatedItem.id})');
    _onDataChanged?.call(updatedItem.householdId);

    return updatedItem;
  }

  /// 删除物品（软删除）
  Future<void> deleteItem(String id) async {
    final current = await _localDb.itemsDao.getById(id);
    final newVersion = (current?.version ?? 0) + 1;
    
    await _localDb.itemsDao.softDeleteWithVersion(id, DateTime.now(), newVersion);
    
    print('✅ [ItemCommandService] 删除物品: $id');
    
    if (current != null) {
      _onDataChanged?.call(current.householdId);
    }
  }

  // ========== 物品-标签关联 ==========

  /// 设置物品标签（使用位图）
  Future<void> setItemTags(String itemId, List<String> tagIds) async {
    try {
      // 获取物品信息
      final item = await _localDb.itemsDao.getById(itemId);
      if (item == null) {
        throw Exception('物品不存在: $itemId');
      }

      // 获取标签的序号
      final tags = await _localDb.tagsDao.getByHousehold(item.householdId);
      final tagMap = {for (var tag in tags) tag.id: tag.tagIndex};
      
      // 计算新的标签位图
      final tagIndices = tagIds
          .map((tagId) => tagMap[tagId])
          .whereType<int>()
          .toList();
      
      final newTagsMask = TagsMaskHelper.createMask(tagIndices);
      
      // 更新物品的标签位图
      await _localDb.itemsDao.updateItem(
        db.HouseholdItemsCompanion(
          id: Value(itemId),
          tagsMask: Value(newTagsMask),
          updatedAt: Value(DateTime.now()),
          syncPending: const Value(true),
        ),
      );
      
      print('✅ [ItemCommandService] 设置物品标签: $itemId -> ${tagIds.length}个标签 (mask: $newTagsMask)');
    } catch (e) {
      print('🔴 [ItemCommandService] 设置物品标签失败: $e');
      rethrow;
    }
  }

  /// 添加标签到物品（使用位图）
  Future<void> addTagToItem(String itemId, String tagId) async {
    try {
      // 获取物品信息
      final item = await _localDb.itemsDao.getById(itemId);
      if (item == null) {
        throw Exception('物品不存在: $itemId');
      }

      // 获取标签的序号
      final tag = await _localDb.tagsDao.getById(tagId);
      if (tag == null || tag.tagIndex == null) {
        throw Exception('标签不存在或没有序号: $tagId');
      }

      // 添加标签到位图
      final newTagsMask = TagsMaskHelper.addTag(item.tagsMask, tag.tagIndex!);
      
      // 更新物品的标签位图
      await _localDb.itemsDao.updateItem(
        db.HouseholdItemsCompanion(
          id: Value(itemId),
          tagsMask: Value(newTagsMask),
          updatedAt: Value(DateTime.now()),
          syncPending: const Value(true),
        ),
      );
      
      print('✅ [ItemCommandService] 添加标签到物品: $itemId <- $tagId (index: ${tag.tagIndex}, mask: $newTagsMask)');
    } catch (e) {
      print('🔴 [ItemCommandService] 添加标签到物品失败: $e');
      rethrow;
    }
  }

  /// 从物品移除标签（使用位图）
  Future<void> removeTagFromItem(String itemId, String tagId) async {
    try {
      // 获取物品信息
      final item = await _localDb.itemsDao.getById(itemId);
      if (item == null) {
        throw Exception('物品不存在: $itemId');
      }

      // 获取标签的序号
      final tag = await _localDb.tagsDao.getById(tagId);
      if (tag == null || tag.tagIndex == null) {
        throw Exception('标签不存在或没有序号: $tagId');
      }

      // 从位图移除标签
      final newTagsMask = TagsMaskHelper.removeTag(item.tagsMask, tag.tagIndex!);
      
      // 更新物品的标签位图
      await _localDb.itemsDao.updateItem(
        db.HouseholdItemsCompanion(
          id: Value(itemId),
          tagsMask: Value(newTagsMask),
          updatedAt: Value(DateTime.now()),
          syncPending: const Value(true),
        ),
      );
      
      print('✅ [ItemCommandService] 从物品移除标签: $itemId <- $tagId (index: ${tag.tagIndex}, mask: $newTagsMask)');
    } catch (e) {
      print('🔴 [ItemCommandService] 从物品移除标签失败: $e');
      rethrow;
    }
  }

  // ========== 位置 CRUD ==========

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

    print('✅ [ItemCommandService] 创建位置: ${newLocation.name} (${newLocation.id})');
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

    print('✅ [ItemCommandService] 更新位置: ${updatedLocation.name} (${updatedLocation.id})');
    return updatedLocation;
  }

  /// 删除位置
  Future<void> deleteLocation(String id) async {
    await _localDb.locationsDao.deleteLocation(id);
    print('✅ [ItemCommandService] 删除位置: $id');
  }

  // ========== 标签 CRUD ==========

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

    print('✅ [ItemCommandService] 创建标签: ${newTag.name} (${newTag.id})');
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

    print('✅ [ItemCommandService] 更新标签: ${tag.name} (${tag.id})');
    return tag;
  }

  /// 删除标签
  Future<void> deleteTag(String id) async {
    await _localDb.tagsDao.deleteTag(id);
    print('✅ [ItemCommandService] 删除标签: $id');
  }

  // ========== 类型配置 CRUD ==========

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

    print('✅ [ItemCommandService] 创建类型配置: ${newType.typeLabel} (${newType.id})');
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

    print('✅ [ItemCommandService] 更新类型配置: ${type.typeLabel} (${type.id})');
    return type;
  }

  /// 删除类型配置
  Future<void> deleteTypeConfig(String id) async {
    await _localDb.typesDao.deleteType(id);
    print('✅ [ItemCommandService] 删除类型配置: $id');
  }
}
