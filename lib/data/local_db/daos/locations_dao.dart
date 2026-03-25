import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/item_locations.dart';

part 'locations_dao.g.dart';

@DriftAccessor(tables: [ItemLocations])
class LocationsDao extends DatabaseAccessor<AppDatabase> with _$LocationsDaoMixin {
  LocationsDao(super.db);
  
  Future<List<ItemLocation>> getAll() => select(itemLocations).get();
  
  Future<ItemLocation?> getById(String id) =>
      (select(itemLocations)..where((l) => l.id.equals(id))).getSingleOrNull();
  
  Stream<List<ItemLocation>> watchAll() => select(itemLocations).watch();
  
  Stream<ItemLocation?> watchById(String id) =>
      (select(itemLocations)..where((l) => l.id.equals(id))).watchSingleOrNull();
  
  Future<int> insertLocation(ItemLocationsCompanion location) =>
      into(itemLocations).insert(location);
  
  Future<int> updateLocation(ItemLocationsCompanion location) =>
      (update(itemLocations)..where((l) => l.id.equals(location.id.value))).write(location);
  
  Future<int> deleteLocation(String id) =>
      (delete(itemLocations)..where((l) => l.id.equals(id))).go();
  
  Future<int> getAllCount() => select(itemLocations).get().then((list) => list.length);
  
  Future<int> deleteAll() => delete(itemLocations).go();
  
  Future<List<ItemLocation>> getSyncPending() =>
      (select(itemLocations)..where((l) => l.syncPending.equals(true))).get();
  
  Future<int> markSynced(String id) =>
      (update(itemLocations)..where((l) => l.id.equals(id))).write(
        ItemLocationsCompanion(
          syncPending: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
  
  Future<void> upsertLocationFromRemote(Map<String, dynamic> remoteLocation) async {
    final existing = await getById(remoteLocation['id']);
    
    final companion = ItemLocationsCompanion(
      id: Value(remoteLocation['id']),
      householdId: Value(remoteLocation['household_id']),
      name: Value(remoteLocation['name']),
      description: Value(remoteLocation['description']),
      icon: Value(remoteLocation['icon'] ?? '📍'),
      color: Value(remoteLocation['color']),
      parentId: Value(remoteLocation['parent_id']),
      depth: Value(remoteLocation['depth'] ?? 0),
      path: Value(remoteLocation['path']),
      sortOrder: Value(remoteLocation['sort_order'] ?? 0),
      templateType: Value(remoteLocation['template_type']),
      templateConfig: Value(remoteLocation['template_config']?.toString()),
      positionInParent: Value(remoteLocation['position_in_parent']?.toString()),
      positionDescription: Value(remoteLocation['position_description']),
      createdAt: Value(DateTime.parse(remoteLocation['created_at'])),
      updatedAt: Value(DateTime.parse(remoteLocation['updated_at'])),
      version: Value(remoteLocation['version'] ?? 1),
      syncPending: const Value(false),
    );
    
    if (existing == null) {
      await into(itemLocations).insert(companion);
    } else {
      await (update(itemLocations)..where((l) => l.id.equals(remoteLocation['id']))).write(companion);
    }
  }
  
  Future<List<ItemLocation>> getByHousehold(String householdId) =>
      (select(itemLocations)..where((l) => l.householdId.equals(householdId))).get();
  
  Stream<List<ItemLocation>> watchByHousehold(String householdId) =>
      (select(itemLocations)..where((l) => l.householdId.equals(householdId))).watch();
  
  Future<List<ItemLocation>> getRootLocations() =>
      (select(itemLocations)..where((l) => l.parentId.isNull())).get();
  
  Future<List<ItemLocation>> getChildLocations(String parentId) =>
      (select(itemLocations)..where((l) => l.parentId.equals(parentId))).get();
  
  Future<int> deleteByHousehold(String householdId) =>
      (delete(itemLocations)..where((l) => l.householdId.equals(householdId))).go();
  
  Future<void> insertOrUpdateLocation(ItemLocationsCompanion location) async {
    final existing = await getById(location.id.value);
    if (existing == null) {
      await into(itemLocations).insert(location);
    } else {
      await (update(itemLocations)..where((l) => l.id.equals(location.id.value))).write(location);
    }
  }
  
  Future<void> updateSyncStatus(String id, bool pending) =>
      (update(itemLocations)..where((l) => l.id.equals(id))).write(
        ItemLocationsCompanion(
          syncPending: Value(pending),
          updatedAt: Value(DateTime.now()),
        ),
      );
}
