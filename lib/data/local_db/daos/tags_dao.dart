import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/item_tags.dart';
import '../tables/household_items.dart';
import '../../../core/utils/datetime_utils.dart';

part 'tags_dao.g.dart';

@DriftAccessor(tables: [ItemTags])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.db);
  
  Future<List<ItemTag>> getAll() => select(itemTags).get();
  
  Future<ItemTag?> getById(String id) =>
      (select(itemTags)..where((t) => t.id.equals(id))).getSingleOrNull();
  
  Stream<List<ItemTag>> watchAll() => select(itemTags).watch();
  
  Stream<ItemTag?> watchById(String id) =>
      (select(itemTags)..where((t) => t.id.equals(id))).watchSingleOrNull();
  
  Future<int> insertTag(ItemTagsCompanion tag) =>
      into(itemTags).insert(tag);
  
  Future<int> updateTag(ItemTagsCompanion tag) =>
      (update(itemTags)..where((t) => t.id.equals(tag.id.value))).write(tag);
  
  Future<int> deleteTag(String id) =>
      (delete(itemTags)..where((t) => t.id.equals(id))).go();
  
  /// 软删除标签
  Future<void> softDeleteTag(String id) =>
      (update(itemTags)..where((t) => t.id.equals(id))).write(
        ItemTagsCompanion(
          deletedAt: Value(DateTimeUtils.nowUtc()),
          updatedAt: Value(DateTimeUtils.nowUtc()),
          syncPending: const Value(true),
        ),
      );
  
  /// 恢复已删除的标签
  Future<void> restoreTag(String id) =>
      (update(itemTags)..where((t) => t.id.equals(id))).write(
        ItemTagsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTimeUtils.nowUtc()),
          syncPending: const Value(true),
        ),
      );
  
  /// 获取所有未删除的标签
  Future<List<ItemTag>> getActiveTags() =>
      (select(itemTags)..where((t) => t.deletedAt.isNull())).get();
  
  /// 获取所有已删除的标签
  Future<List<ItemTag>> getDeletedTags() =>
      (select(itemTags)..where((t) => t.deletedAt.isNotNull())).get();
  
  /// 根据名称查找未删除的标签
  Future<ItemTag?> findActiveTagByName(String householdId, String name) =>
      (select(itemTags)
        ..where((t) => t.householdId.equals(householdId) & 
                       t.name.lower().equals(name.toLowerCase()) &
                       t.deletedAt.isNull()))
      .getSingleOrNull();
  
  /// 根据名称查找已删除的标签
  Future<ItemTag?> findDeletedTagByName(String householdId, String name) =>
      (select(itemTags)
        ..where((t) => t.householdId.equals(householdId) & 
                       t.name.lower().equals(name.toLowerCase()) &
                       t.deletedAt.isNotNull()))
      .getSingleOrNull();
  
  Future<int> getAllCount() => select(itemTags).get().then((list) => list.length);
  
  Future<int> deleteAll() => delete(itemTags).go();
  
  Future<List<ItemTag>> getSyncPending() =>
      (select(itemTags)..where((t) => t.syncPending.equals(true))).get();
  
  Future<int> markSynced(String id, {DateTime? updatedAt}) =>
      (update(itemTags)..where((t) => t.id.equals(id))).write(
        ItemTagsCompanion(
          syncPending: const Value(false),
          updatedAt: Value(updatedAt ?? DateTimeUtils.nowUtc()),
        ),
      );
  
  Future<void> upsertTagFromRemote(Map<String, dynamic> remoteTag) async {
    final existing = await getById(remoteTag['id']);
    
    final companion = ItemTagsCompanion(
      id: Value(remoteTag['id']),
      householdId: Value(remoteTag['household_id']),
      name: Value(remoteTag['name']),
      color: Value(remoteTag['color'] ?? '#6B7280'),
      icon: Value(remoteTag['icon']),
      category: Value(remoteTag['category'] ?? 'other'),
      applicableTypes: Value(remoteTag['applicable_types']?.toString()),
      tagIndex: remoteTag['tag_index'] != null ? Value(remoteTag['tag_index'] as int) : const Value.absent(),
      createdAt: Value(DateTime.parse(remoteTag['created_at']).toUtc()),
      updatedAt: Value(DateTime.parse(remoteTag['updated_at']).toUtc()),
      deletedAt: remoteTag['deleted_at'] != null 
          ? Value(DateTime.parse(remoteTag['deleted_at']).toUtc()) 
          : const Value.absent(),
      version: Value(remoteTag['version'] ?? 1),
      syncPending: const Value(false),
    );
    
    if (existing == null) {
      await into(itemTags).insert(companion);
    } else {
      await (update(itemTags)..where((t) => t.id.equals(remoteTag['id']))).write(companion);
    }
  }
  
  Future<List<ItemTag>> getByHousehold(String householdId) =>
      (select(itemTags)..where((t) => t.householdId.equals(householdId))).get();
  
  Stream<List<ItemTag>> watchByHousehold(String householdId) =>
      (select(itemTags)..where((t) => t.householdId.equals(householdId))).watch();
  
  Future<List<ItemTag>> getByCategory(String householdId, String category) =>
      (select(itemTags)..where((t) => t.householdId.equals(householdId) & t.category.equals(category))).get();
  
  Future<int> deleteByHousehold(String householdId) =>
      (delete(itemTags)..where((t) => t.householdId.equals(householdId))).go();
  
  Future<List<ItemTag>> getByIds(List<String> ids) =>
      (select(itemTags)..where((t) => t.id.isIn(ids))).get();
  
  Future<void> insertOrUpdateTag(ItemTagsCompanion tag) async {
    final existing = await getById(tag.id.value);
    if (existing == null) {
      await into(itemTags).insert(tag);
    } else {
      final tagIndex = tag.tagIndex.present ? tag.tagIndex : Value(existing.tagIndex);
      await (update(itemTags)..where((t) => t.id.equals(tag.id.value))).write(
        tag.copyWith(tagIndex: tagIndex),
      );
    }
  }
  
  Future<void> updateSyncStatus(String id, bool pending) =>
      (update(itemTags)..where((t) => t.id.equals(id))).write(
        ItemTagsCompanion(
          syncPending: Value(pending),
          updatedAt: Value(DateTimeUtils.nowUtc()),
        ),
      );

  /// 获取标签及其物品数量（用于统计页面，只统计未删除的标签）
  Future<List<TagWithCount>> getTagWithCounts(String householdId) async {
    // 只获取未删除的标签
    final allTags = await getActiveTags();
    final tags = allTags.where((t) => t.householdId == householdId).toList();
    final results = <TagWithCount>[];
    
    for (final tag in tags) {
      final tagIndex = tag.tagIndex;
      if (tagIndex == null) continue;
      
      final tagMask = 1 << tagIndex;
      final items = await db.itemsDao.getByHousehold(householdId);
      final count = items.where((item) => (item.tagsMask & tagMask) != 0).length;
      
      results.add(TagWithCount(
        id: tag.id,
        name: tag.name,
        color: tag.color,
        icon: tag.icon,
        category: tag.category,
        count: count,
      ));
    }
    
    return results;
  }
  
  /// 获取下一个可用的 tagIndex（0-62）
  /// 位图最多支持 64 个标签（0-62，63 保留）
  Future<int?> getNextTagIndex(String householdId) async {
    final tags = await getByHousehold(householdId);
    final usedIndices = <int>{};
    
    for (final tag in tags) {
      if (tag.tagIndex != null && tag.deletedAt == null) {
        usedIndices.add(tag.tagIndex!);
      }
    }
    
    // 找一个未使用的 index（0-62）
    for (int i = 0; i < 63; i++) {
      if (!usedIndices.contains(i)) {
        return i;
      }
    }
    
    return null; // 所有索引都用完了
  }
}

/// 标签及其物品数量
class TagWithCount {
  final String id;
  final String name;
  final String color;
  final String? icon;
  final String category;
  final int count;

  const TagWithCount({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
    required this.category,
    required this.count,
  });
}
