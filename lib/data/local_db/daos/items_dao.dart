import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/household_items.dart';

part 'items_dao.g.dart';

@DriftAccessor(tables: [HouseholdItems])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);
  
  Future<List<HouseholdItem>> getAll() => select(householdItems).get();
  
  Future<HouseholdItem?> getById(String id) =>
      (select(householdItems)..where((i) => i.id.equals(id))).getSingleOrNull();
  
  Stream<List<HouseholdItem>> watchAll() => select(householdItems).watch();
  
  Stream<HouseholdItem?> watchById(String id) =>
      (select(householdItems)..where((i) => i.id.equals(id))).watchSingleOrNull();
  
  Future<int> insertItem(HouseholdItemsCompanion item) =>
      into(householdItems).insert(item);
  
  Future<int> updateItem(HouseholdItemsCompanion item) =>
      (update(householdItems)..where((i) => i.id.equals(item.id.value))).write(item);
  
  Future<int> deleteItem(String id) =>
      (delete(householdItems)..where((i) => i.id.equals(id))).go();
  
  Future<List<HouseholdItem>> getSyncPending() =>
      (select(householdItems)..where((i) => i.syncPending.equals(true) | i.syncStatus.equals('pending'))).get();
  
  Future<int> markSynced(String id) =>
      (update(householdItems)..where((i) => i.id.equals(id))).write(
        HouseholdItemsCompanion(
          syncPending: const Value(false),
          syncStatus: const Value('synced'),
          updatedAt: Value(DateTime.now()),
        ),
      );
  
  Future<void> upsertItemFromRemote(Map<String, dynamic> remoteItem) async {
    final existing = await getById(remoteItem['id']);
    
    final companion = HouseholdItemsCompanion(
      id: Value(remoteItem['id']),
      householdId: Value(remoteItem['household_id']),
      name: Value(remoteItem['name']),
      description: Value(remoteItem['description']),
      itemType: Value(remoteItem['item_type']),
      locationId: Value(remoteItem['location_id']),
      ownerId: Value(remoteItem['owner_id']),
      quantity: Value(remoteItem['quantity'] ?? 1),
      brand: Value(remoteItem['brand']),
      model: Value(remoteItem['model']),
      purchaseDate: remoteItem['purchase_date'] != null
          ? Value(DateTime.parse(remoteItem['purchase_date']))
          : const Value.absent(),
      purchasePrice: remoteItem['purchase_price'] != null
          ? Value((remoteItem['purchase_price'] as num).toDouble())
          : const Value.absent(),
      warrantyExpiry: remoteItem['warranty_expiry'] != null
          ? Value(DateTime.parse(remoteItem['warranty_expiry']))
          : const Value.absent(),
      condition: Value(remoteItem['condition'] ?? 'good'),
      imageUrl: Value(remoteItem['image_url']),
      thumbnailUrl: Value(remoteItem['thumbnail_url']),
      notes: Value(remoteItem['notes']),
      syncStatus: const Value('synced'),
      remoteId: Value(remoteItem['remote_id']),
      createdBy: Value(remoteItem['created_by']),
      createdAt: Value(DateTime.parse(remoteItem['created_at'])),
      updatedAt: Value(DateTime.parse(remoteItem['updated_at'])),
      deletedAt: remoteItem['deleted_at'] != null
          ? Value(DateTime.parse(remoteItem['deleted_at']))
          : const Value.absent(),
      version: Value(remoteItem['version'] ?? 1),
      syncPending: const Value(false),
      slotPosition: Value(remoteItem['slot_position']?.toString()),
    );
    
    if (existing == null) {
      await into(householdItems).insert(companion);
    } else {
      await (update(householdItems)..where((i) => i.id.equals(remoteItem['id']))).write(companion);
    }
  }
  
  Future<List<HouseholdItem>> getByHousehold(String householdId) =>
      (select(householdItems)..where((i) => i.householdId.equals(householdId))).get();
  
  Stream<List<HouseholdItem>> watchByHousehold(String householdId) =>
      (select(householdItems)..where((i) => i.householdId.equals(householdId))).watch();
  
  Future<List<HouseholdItem>> getByLocation(String locationId) =>
      (select(householdItems)..where((i) => i.locationId.equals(locationId))).get();
  
  Future<List<HouseholdItem>> getByType(String itemType) =>
      (select(householdItems)..where((i) => i.itemType.equals(itemType))).get();
  
  Future<List<HouseholdItem>> getByOwner(String ownerId) =>
      (select(householdItems)..where((i) => i.ownerId.equals(ownerId))).get();
  
  Future<int> deleteByHousehold(String householdId) =>
      (delete(householdItems)..where((i) => i.householdId.equals(householdId))).go();
  
  Future<List<HouseholdItem>> search(String householdId, String query) =>
      (select(householdItems)..where((i) => i.householdId.equals(householdId) & i.name.contains(query))).get();
  
  Future<void> softDelete(String id, DateTime deletedAt) =>
      (update(householdItems)..where((i) => i.id.equals(id))).write(
        HouseholdItemsCompanion(
          deletedAt: Value(deletedAt),
          syncPending: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
  
  Future<void> updateSyncStatus(String id, bool pending) =>
      (update(householdItems)..where((i) => i.id.equals(id))).write(
        HouseholdItemsCompanion(
          syncPending: Value(pending),
          updatedAt: Value(DateTime.now()),
        ),
      );
  
  Future<void> insertOrUpdateItem(HouseholdItemsCompanion item) async {
    final existing = await getById(item.id.value);
    if (existing == null) {
      await into(householdItems).insert(item);
    } else {
      await (update(householdItems)..where((i) => i.id.equals(item.id.value))).write(item);
    }
  }
}
