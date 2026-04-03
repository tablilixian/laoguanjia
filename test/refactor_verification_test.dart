import 'package:flutter_test/flutter_test.dart';
import 'package:home_manager/data/models/household_item.dart';
import 'package:home_manager/data/models/item_location.dart';
import 'package:home_manager/data/models/item_tag.dart';
import 'package:home_manager/data/models/item_type_config.dart';
import 'package:home_manager/data/utils/tags_mask_helper.dart';
import 'package:home_manager/core/sync/sync_scheduler.dart';
import 'package:home_manager/core/sync/app_lifecycle_sync.dart';

void main() {
  group('ItemLocation Model Tests', () {
    test('should create location with deletedAt field', () {
      final location = ItemLocation(
        id: 'location-1',
        householdId: 'household-1',
        name: 'Living Room',
        icon: '🛋️',
        depth: 0,
        sortOrder: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: null,
      );

      expect(location.id, 'location-1');
      expect(location.deletedAt, isNull);
    });

    test('should create soft-deleted location', () {
      final now = DateTime.now();
      final location = ItemLocation(
        id: 'location-1',
        householdId: 'household-1',
        name: 'Deleted Room',
        depth: 0,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );

      expect(location.deletedAt, isNotNull);
    });

    test('should copyWith deletedAt', () {
      final now = DateTime.now();
      final location = ItemLocation(
        id: 'location-1',
        householdId: 'household-1',
        name: 'Living Room',
        depth: 0,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      );

      final deleted = location.copyWith(deletedAt: now);
      expect(deleted.deletedAt, isNotNull);
      expect(deleted.name, 'Living Room');
    });

    test('should serialize deletedAt to remote json', () {
      final now = DateTime.now();
      final location = ItemLocation(
        id: 'location-1',
        householdId: 'household-1',
        name: 'Living Room',
        depth: 0,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );

      final json = location.toRemoteJson();
      expect(json['deleted_at'], isNotNull);
    });
  });

  group('TagsMaskHelper Tests', () {
    test('should create empty mask', () {
      expect(TagsMaskHelper.createMask([]), 0);
    });

    test('should add and check tag', () {
      var mask = TagsMaskHelper.addTag(0, 1);
      expect(TagsMaskHelper.hasTag(mask, 1), true);
      expect(TagsMaskHelper.hasTag(mask, 2), false);
    });

    test('should remove tag', () {
      var mask = TagsMaskHelper.addTag(0, 1);
      mask = TagsMaskHelper.removeTag(mask, 1);
      expect(TagsMaskHelper.hasTag(mask, 1), false);
    });

    test('should handle multiple tags', () {
      var mask = 0;
      mask = TagsMaskHelper.addTag(mask, 1);
      mask = TagsMaskHelper.addTag(mask, 3);
      mask = TagsMaskHelper.addTag(mask, 5);

      expect(TagsMaskHelper.getTagIds(mask), containsAll([1, 3, 5]));
      expect(TagsMaskHelper.getTagCount(mask), 3);
    });

    test('should create mask from id list', () {
      final mask = TagsMaskHelper.createMask([2, 4, 6]);
      expect(TagsMaskHelper.hasTag(mask, 2), true);
      expect(TagsMaskHelper.hasTag(mask, 4), true);
      expect(TagsMaskHelper.hasTag(mask, 6), true);
      expect(TagsMaskHelper.hasTag(mask, 1), false);
    });
  });

  group('HouseholdItem Tests', () {
    test('should create item with tagsMask', () {
      final item = HouseholdItem(
        id: 'item-1',
        householdId: 'household-1',
        name: 'Test Item',
        itemType: 'electronics',
        quantity: 1,
        condition: ItemCondition.good,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tagsMask: 7,
      );

      expect(item.tagsMask, 7);
    });

    test('should handle slotPosition as Map', () {
      final item = HouseholdItem(
        id: 'item-1',
        householdId: 'household-1',
        name: 'Test Item',
        itemType: 'electronics',
        quantity: 1,
        condition: ItemCondition.good,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        slotPosition: {'index': 4},
      );

      expect(item.slotPosition, isA<Map>());
      expect(item.slotPosition!['index'], 4);
    });

    test('should serialize toMap with all fields', () {
      final now = DateTime.now();
      final item = HouseholdItem(
        id: 'item-1',
        householdId: 'household-1',
        name: 'Test Item',
        itemType: 'electronics',
        quantity: 1,
        condition: ItemCondition.good,
        syncStatus: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
        tagsMask: 7,
        slotPosition: {'index': 4},
      );

      final map = item.toMap();
      expect(map['id'], 'item-1');
      expect(map['tags_mask'], 7);
      expect(map['slot_position'], isA<Map>());
    });
  });

  group('ItemTypeConfig Tests', () {
    test('should create config with all fields', () {
      final now = DateTime.now();
      final config = ItemTypeConfig(
        id: 'type-1',
        householdId: 'household-1',
        typeKey: 'electronics',
        typeLabel: '电子产品',
        icon: '📱',
        color: '#3498db',
        sortOrder: 1,
        isActive: true,
        createdAt: now,
      );

      expect(config.typeKey, 'electronics');
      expect(config.isActive, true);
    });

    test('should copyWith isActive', () {
      final now = DateTime.now();
      final config = ItemTypeConfig(
        id: 'type-1',
        householdId: 'household-1',
        typeKey: 'electronics',
        typeLabel: '电子产品',
        icon: '📱',
        color: '#3498db',
        sortOrder: 1,
        isActive: true,
        createdAt: now,
      );

      final deactivated = config.copyWith(isActive: false);
      expect(deactivated.isActive, false);
      expect(deactivated.typeKey, 'electronics');
    });
  });

  group('SyncScheduler Tests', () {
    test('should have sync method', () {
      final scheduler = SyncScheduler();
      expect(scheduler, isNotNull);
      expect(scheduler.isSyncing, false);
    });
  });

  group('AppLifecycleSync Tests', () {
    test('should create singleton instance', () {
      final instance1 = AppLifecycleSync();
      final instance2 = AppLifecycleSync();
      expect(identical(instance1, instance2), true);
    });

    test('should not be registered initially', () {
      expect(AppLifecycleSync().isRegistered, false);
    });
  });
}
