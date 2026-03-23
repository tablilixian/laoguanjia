import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/item_tag_relations.dart';

part 'item_tag_relations_dao.g.dart';

@DriftAccessor(tables: [ItemTagRelations])
class ItemTagRelationsDao extends DatabaseAccessor<AppDatabase> with _$ItemTagRelationsDaoMixin {
  ItemTagRelationsDao(super.db);
  
  Future<List<ItemTagRelation>> getAll() => select(itemTagRelations).get();
  
  Future<List<ItemTagRelation>> getByItem(String itemId) =>
      (select(itemTagRelations)..where((r) => r.itemId.equals(itemId))).get();
  
  Future<List<ItemTagRelation>> getByTag(String tagId) =>
      (select(itemTagRelations)..where((r) => r.tagId.equals(tagId))).get();
  
  Future<int> insertRelation(ItemTagRelationsCompanion relation) =>
      into(itemTagRelations).insert(relation);
  
  Future<int> deleteRelation(String itemId, String tagId) =>
      (delete(itemTagRelations)
        ..where((r) => r.itemId.equals(itemId) & r.tagId.equals(tagId)))
      .go();
  
  Future<int> deleteByItem(String itemId) =>
      (delete(itemTagRelations)..where((r) => r.itemId.equals(itemId))).go();
  
  Future<int> deleteByTag(String tagId) =>
      (delete(itemTagRelations)..where((r) => r.tagId.equals(tagId))).go();
  
  Future<List<String>> getTagIdsForItem(String itemId) async {
    final relations = await getByItem(itemId);
    return relations.map((r) => r.tagId).toList();
  }
  
  Future<List<String>> getItemIdsForTag(String tagId) async {
    final relations = await getByTag(tagId);
    return relations.map((r) => r.itemId).toList();
  }
  
  Future<void> setTagsForItem(String itemId, List<String> tagIds) async {
    await deleteByItem(itemId);
    for (final tagId in tagIds) {
      await insertRelation(ItemTagRelationsCompanion(
        itemId: Value(itemId),
        tagId: Value(tagId),
        createdAt: Value(DateTime.now()),
      ));
    }
  }
}
