import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/item_tags.dart';

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
  
  Future<List<ItemTag>> getSyncPending() =>
      (select(itemTags)..where((t) => t.syncPending.equals(true))).get();
  
  Future<int> markSynced(String id) =>
      (update(itemTags)..where((t) => t.id.equals(id))).write(
        ItemTagsCompanion(
          syncPending: const Value(false),
          updatedAt: Value(DateTime.now()),
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
      createdAt: Value(DateTime.parse(remoteTag['created_at'])),
      updatedAt: Value(DateTime.parse(remoteTag['updated_at'])),
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
}
