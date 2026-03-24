import 'package:flutter_test/flutter_test.dart';
import 'package:home_manager/data/models/household_item.dart';
import 'package:home_manager/data/models/item_location.dart';
import 'package:home_manager/data/models/item_tag.dart';
import 'package:home_manager/data/models/item_type_config.dart';

void main() {
  group('OfflineItemRepository Model Tests', () {
    group('Item Model Tests', () {
      test('should create item with valid properties', () {
        final item = HouseholdItem(
          id: 'test-item-1',
          householdId: 'household-1',
          name: 'Test Item',
          itemType: 'electronics',
          locationId: 'location-1',
          ownerId: 'user-1',
          quantity: 1,
          condition: ItemCondition.good,
          syncStatus: SyncStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(item.id, 'test-item-1');
        expect(item.name, 'Test Item');
        expect(item.itemType, 'electronics');
        expect(item.syncStatus, SyncStatus.pending);
      });

      test('should update item properties', () {
        final item = HouseholdItem(
          id: 'test-item-1',
          householdId: 'household-1',
          name: 'Test Item',
          itemType: 'electronics',
          locationId: 'location-1',
          ownerId: 'user-1',
          quantity: 1,
          condition: ItemCondition.good,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updatedItem = item.copyWith(
          name: 'Updated Test Item',
          quantity: 2,
          syncStatus: SyncStatus.pending,
        );

        expect(updatedItem.name, 'Updated Test Item');
        expect(updatedItem.quantity, 2);
        expect(updatedItem.syncStatus, SyncStatus.pending);
        expect(updatedItem.id, 'test-item-1');
      });

      test('should mark item as deleted', () {
        final item = HouseholdItem(
          id: 'test-item-1',
          householdId: 'household-1',
          name: 'Test Item',
          itemType: 'electronics',
          locationId: 'location-1',
          ownerId: 'user-1',
          quantity: 1,
          condition: ItemCondition.good,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final deletedItem = item.copyWith(
          deletedAt: DateTime.now(),
          syncStatus: SyncStatus.pending,
        );

        expect(deletedItem.deletedAt, isNotNull);
        expect(deletedItem.syncStatus, SyncStatus.pending);
      });

      test('should handle item condition enum', () {
        expect(ItemCondition.new_.dbValue, 'new');
        expect(ItemCondition.good.dbValue, 'good');
        expect(ItemCondition.fair.dbValue, 'fair');
        expect(ItemCondition.poor.dbValue, 'poor');
        
        expect(ItemCondition.fromString('good'), ItemCondition.good);
        expect(ItemCondition.fromString('unknown'), ItemCondition.good);
      });
    });

    group('Location Model Tests', () {
      test('should create location with valid properties', () {
        final location = ItemLocation(
          id: 'location-1',
          householdId: 'household-1',
          name: 'Living Room',
          icon: '🛋️',
          color: '#FF5733',
          depth: 0,
          sortOrder: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(location.id, 'location-1');
        expect(location.name, 'Living Room');
        expect(location.icon, '🛋️');
        expect(location.depth, 0);
      });

      test('should create nested location structure', () {
        final parentLocation = ItemLocation(
          id: 'location-1',
          householdId: 'household-1',
          name: 'Living Room',
          depth: 0,
          sortOrder: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final childLocation = ItemLocation(
          id: 'location-2',
          householdId: 'household-1',
          name: 'Bookshelf',
          parentId: 'location-1',
          depth: 1,
          path: 'Living Room/Bookshelf',
          sortOrder: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(childLocation.parentId, 'location-1');
        expect(childLocation.depth, 1);
        expect(childLocation.path, 'Living Room/Bookshelf');
        expect(parentLocation.depth, 0);
      });

      test('should handle location template types', () {
        expect(LocationTemplateType.direction.dbValue, 'direction');
        expect(LocationTemplateType.numbering.dbValue, 'index');
        expect(LocationTemplateType.grid.dbValue, 'grid');
        expect(LocationTemplateType.stack.dbValue, 'stack');
        expect(LocationTemplateType.none.dbValue, 'none');
        
        expect(LocationTemplateType.fromString('direction'), LocationTemplateType.direction);
      });
    });

    group('Tag Model Tests', () {
      test('should create tag with valid properties', () {
        final tag = ItemTag(
          id: 'tag-1',
          householdId: 'household-1',
          name: 'Important',
          color: '#FF0000',
          icon: '⭐',
          category: 'priority',
          applicableTypes: ['electronics', 'furniture'],
          createdAt: DateTime.now(),
        );

        expect(tag.id, 'tag-1');
        expect(tag.name, 'Important');
        expect(tag.category, 'priority');
        expect(tag.applicableTypes, contains('electronics'));
        expect(tag.applicableTypes, contains('furniture'));
      });

      test('should handle tag with empty applicable types', () {
        final tag = ItemTag(
          id: 'tag-1',
          householdId: 'household-1',
          name: 'General',
          color: '#FF0000',
          applicableTypes: [],
          createdAt: DateTime.now(),
        );

        expect(tag.applicableTypes, isEmpty);
      });
    });

    group('Type Config Model Tests', () {
      test('should create type config with valid properties', () {
        final typeConfig = ItemTypeConfig(
          id: 'type-1',
          householdId: 'household-1',
          typeKey: 'electronics',
          typeLabel: 'Electronics',
          icon: '📱',
          color: '#3498db',
          sortOrder: 1,
          isActive: true,
          createdAt: DateTime.now(),
        );

        expect(typeConfig.id, 'type-1');
        expect(typeConfig.typeKey, 'electronics');
        expect(typeConfig.typeLabel, 'Electronics');
        expect(typeConfig.isActive, true);
      });

      test('should handle inactive type config', () {
        final typeConfig = ItemTypeConfig(
          id: 'type-1',
          householdId: 'household-1',
          typeKey: 'obsolete',
          typeLabel: 'Obsolete Type',
          icon: '🗑️',
          color: '#95a5a6',
          sortOrder: 99,
          isActive: false,
          createdAt: DateTime.now(),
        );

        expect(typeConfig.isActive, false);
        expect(typeConfig.sortOrder, 99);
      });
    });

    group('Sync Status Tests', () {
      test('should handle all sync status values', () {
        expect(SyncStatus.pending.name, 'pending');
        expect(SyncStatus.synced.name, 'synced');
        expect(SyncStatus.error.name, 'error');
        
        expect(SyncStatus.fromString('synced'), SyncStatus.synced);
        expect(SyncStatus.fromString('pending'), SyncStatus.pending);
        expect(SyncStatus.fromString('error'), SyncStatus.error);
      });

      test('should track sync status changes', () {
        final item = HouseholdItem(
          id: 'test-item-1',
          householdId: 'household-1',
          name: 'Test Item',
          itemType: 'electronics',
          locationId: 'location-1',
          ownerId: 'user-1',
          quantity: 1,
          condition: ItemCondition.good,
          syncStatus: SyncStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(item.syncStatus, SyncStatus.pending);

        final syncedItem = item.copyWith(syncStatus: SyncStatus.synced);
        expect(syncedItem.syncStatus, SyncStatus.synced);

        final errorItem = syncedItem.copyWith(syncStatus: SyncStatus.error);
        expect(errorItem.syncStatus, SyncStatus.error);
      });
    });

    group('Item Serialization Tests', () {
      test('should serialize item to map', () {
        final item = HouseholdItem(
          id: 'test-item-1',
          householdId: 'household-1',
          name: 'Test Item',
          itemType: 'electronics',
          locationId: 'location-1',
          ownerId: 'user-1',
          quantity: 1,
          condition: ItemCondition.good,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final map = item.toMap();
        
        expect(map['id'], 'test-item-1');
        expect(map['name'], 'Test Item');
        expect(map['item_type'], 'electronics');
        expect(map['quantity'], 1);
        expect(map['condition'], 'good');
      });

      test('should deserialize item from map', () {
        final map = {
          'id': 'test-item-1',
          'household_id': 'household-1',
          'name': 'Test Item',
          'item_type': 'electronics',
          'location_id': 'location-1',
          'owner_id': 'user-1',
          'quantity': 1,
          'condition': 'good',
          'sync_status': 'synced',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        final item = HouseholdItem.fromMap(map);
        
        expect(item.id, 'test-item-1');
        expect(item.name, 'Test Item');
        expect(item.itemType, 'electronics');
        expect(item.quantity, 1);
        expect(item.condition, ItemCondition.good);
      });
    });
  });
}
