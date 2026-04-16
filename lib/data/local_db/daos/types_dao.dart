import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/item_type_configs.dart';
import '../../../core/utils/datetime_utils.dart';

part 'types_dao.g.dart';

@DriftAccessor(tables: [ItemTypeConfigs])
class TypesDao extends DatabaseAccessor<AppDatabase> with _$TypesDaoMixin {
  TypesDao(super.db);
  
  Future<List<ItemTypeConfig>> getAll() => select(itemTypeConfigs).get();
  
  Future<ItemTypeConfig?> getById(String id) =>
      (select(itemTypeConfigs)..where((t) => t.id.equals(id))).getSingleOrNull();
  
  Stream<List<ItemTypeConfig>> watchAll() => select(itemTypeConfigs).watch();
  
  Stream<ItemTypeConfig?> watchById(String id) =>
      (select(itemTypeConfigs)..where((t) => t.id.equals(id))).watchSingleOrNull();
  
  Future<int> insertType(ItemTypeConfigsCompanion type) =>
      into(itemTypeConfigs).insert(type);
  
  Future<int> updateType(ItemTypeConfigsCompanion type) =>
      (update(itemTypeConfigs)..where((t) => t.id.equals(type.id.value))).write(type);
  
  Future<int> deleteType(String id) =>
      (delete(itemTypeConfigs)..where((t) => t.id.equals(id))).go();
  
  Future<int> getAllCount() => select(itemTypeConfigs).get().then((list) => list.length);
  
  Future<int> deleteAll() => delete(itemTypeConfigs).go();
  
  Future<List<ItemTypeConfig>> getSyncPending() =>
      (select(itemTypeConfigs)..where((t) => t.syncPending.equals(true))).get();
  
  Future<int> markSynced(String id, {DateTime? updatedAt}) =>
      (update(itemTypeConfigs)..where((t) => t.id.equals(id))).write(
        ItemTypeConfigsCompanion(
          syncPending: const Value(false),
          updatedAt: Value(updatedAt ?? DateTimeUtils.nowUtc()),
        ),
      );
  
  Future<void> upsertTypeFromRemote(Map<String, dynamic> remoteType) async {
    final existing = await getById(remoteType['id']);
    
    final companion = ItemTypeConfigsCompanion(
      id: Value(remoteType['id']),
      householdId: Value(remoteType['household_id']),
      typeKey: Value(remoteType['type_key']),
      typeLabel: Value(remoteType['type_label']),
      icon: Value(remoteType['icon'] ?? '📦'),
      color: Value(remoteType['color'] ?? '#6B7280'),
      sortOrder: Value(remoteType['sort_order'] ?? 0),
      isActive: Value(remoteType['is_active'] ?? true),
      createdAt: Value(DateTime.parse(remoteType['created_at']).toUtc()),
      updatedAt: Value(DateTime.parse(remoteType['updated_at']).toUtc()),
      version: Value(remoteType['version'] ?? 1),
      syncPending: const Value(false),
    );
    
    if (existing == null) {
      await into(itemTypeConfigs).insert(companion);
    } else {
      await (update(itemTypeConfigs)..where((t) => t.id.equals(remoteType['id']))).write(companion);
    }
  }
  
  Future<List<ItemTypeConfig>> getByHousehold(String? householdId) {
    if (householdId == null) {
      return (select(itemTypeConfigs)..where((t) => t.householdId.isNull())).get();
    }
    return (select(itemTypeConfigs)..where((t) => t.householdId.equals(householdId))).get();
  }
  
  Stream<List<ItemTypeConfig>> watchByHousehold(String? householdId) {
    if (householdId == null) {
      return (select(itemTypeConfigs)..where((t) => t.householdId.isNull())).watch();
    }
    return (select(itemTypeConfigs)..where((t) => t.householdId.equals(householdId))).watch();
  }
  
  Future<List<ItemTypeConfig>> getActiveTypes(String? householdId) {
    if (householdId == null) {
      return (select(itemTypeConfigs)
        ..where((t) => t.isActive.equals(true) & t.householdId.isNull()))
        .get();
    }
    return (select(itemTypeConfigs)
      ..where((t) => t.isActive.equals(true) & 
        (t.householdId.equals(householdId) | t.householdId.isNull())))
      .get();
  }
  
  Future<int> deleteByHousehold(String householdId) =>
      (delete(itemTypeConfigs)..where((t) => t.householdId.equals(householdId))).go();
  
  Future<void> insertOrUpdateType(ItemTypeConfigsCompanion type) async {
    final existing = await getById(type.id.value);
    if (existing == null) {
      await into(itemTypeConfigs).insert(type);
    } else {
      await (update(itemTypeConfigs)..where((t) => t.id.equals(type.id.value))).write(type);
    }
  }
}
