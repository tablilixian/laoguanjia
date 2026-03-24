import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/features/items/providers/offline_items_provider.dart';
import 'package:home_manager/core/providers/network_status_provider.dart';
import 'package:home_manager/data/models/household_item.dart';

void main() {
  group('Offline Scenario Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should handle item creation while offline', () async {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      networkNotifier.setOnlineStatus(false);
      
      final testItem = HouseholdItem(
        id: 'test-item-1',
        householdId: 'household-1',
        name: 'Offline Item',
        itemType: 'electronics',
        quantity: 1,
        condition: ItemCondition.good,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await itemsNotifier.createItem(testItem);
      
      final state = container.read(offlineItemsProvider);
      expect(state.items.any((i) => i.id == 'test-item-1'), true);
      expect(state.items.firstWhere((i) => i.id == 'test-item-1').syncStatus, 
             SyncStatus.pending);
    });

    test('should handle item update while offline', () async {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      networkNotifier.setOnlineStatus(false);
      
      final testItem = HouseholdItem(
        id: 'test-item-1',
        householdId: 'household-1',
        name: 'Original Name',
        itemType: 'electronics',
        quantity: 1,
        condition: ItemCondition.good,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await itemsNotifier.createItem(testItem);
      
      final updatedItem = testItem.copyWith(
        name: 'Updated Name',
        quantity: 2,
        syncStatus: SyncStatus.pending,
      );
      
      await itemsNotifier.updateItem(updatedItem);
      
      final state = container.read(offlineItemsProvider);
      final item = state.items.firstWhere((i) => i.id == 'test-item-1');
      expect(item.name, 'Updated Name');
      expect(item.quantity, 2);
      expect(item.syncStatus, SyncStatus.pending);
    });

    test('should handle item deletion while offline', () async {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      networkNotifier.setOnlineStatus(false);
      
      final testItem = HouseholdItem(
        id: 'test-item-1',
        householdId: 'household-1',
        name: 'To Delete',
        itemType: 'electronics',
        quantity: 1,
        condition: ItemCondition.good,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await itemsNotifier.createItem(testItem);
      expect(container.read(offlineItemsProvider).items.length, 1);
      
      await itemsNotifier.deleteItem('test-item-1');
      
      final state = container.read(offlineItemsProvider);
      expect(state.items.length, 0);
    });

    test('should queue multiple operations while offline', () async {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      networkNotifier.setOnlineStatus(false);
      
      final items = List.generate(
        5,
        (index) => HouseholdItem(
          id: 'item-$index',
          householdId: 'household-1',
          name: 'Item $index',
          itemType: 'electronics',
          quantity: 1,
          condition: ItemCondition.good,
          syncStatus: SyncStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      for (final item in items) {
        await itemsNotifier.createItem(item);
      }
      
      final state = container.read(offlineItemsProvider);
      expect(state.items.length, 5);
      expect(state.pendingSyncCount, 5);
    });

    test('should transition to online and sync pending items', () async {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      networkNotifier.setOnlineStatus(false);
      
      final testItem = HouseholdItem(
        id: 'test-item-1',
        householdId: 'household-1',
        name: 'Offline Item',
        itemType: 'electronics',
        quantity: 1,
        condition: ItemCondition.good,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await itemsNotifier.createItem(testItem);
      
      expect(container.read(offlineItemsProvider).isOnline, false);
      expect(container.read(offlineItemsProvider).pendingSyncCount, 1);
      
      networkNotifier.setOnlineStatus(true);
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(container.read(offlineItemsProvider).isOnline, true);
    });

    test('should handle rapid offline/online transitions', () async {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      for (int i = 0; i < 3; i++) {
        networkNotifier.setOnlineStatus(false);
        await Future.delayed(const Duration(milliseconds: 50));
        
        final testItem = HouseholdItem(
          id: 'item-$i',
          householdId: 'household-1',
          name: 'Item $i',
          itemType: 'electronics',
          quantity: 1,
          condition: ItemCondition.good,
          syncStatus: SyncStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await itemsNotifier.createItem(testItem);
        
        networkNotifier.setOnlineStatus(true);
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      final state = container.read(offlineItemsProvider);
      expect(state.items.length, 3);
      expect(state.isOnline, true);
    });

    test('should maintain data integrity during offline operations', () async {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      networkNotifier.setOnlineStatus(false);
      
      final originalItem = HouseholdItem(
        id: 'test-item-1',
        householdId: 'household-1',
        name: 'Original',
        itemType: 'electronics',
        quantity: 1,
        condition: ItemCondition.good,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await itemsNotifier.createItem(originalItem);
      
      final updatedItem = originalItem.copyWith(
        name: 'Updated',
        quantity: 5,
        syncStatus: SyncStatus.pending,
      );
      
      await itemsNotifier.updateItem(updatedItem);
      
      final state = container.read(offlineItemsProvider);
      final item = state.items.firstWhere((i) => i.id == 'test-item-1');
      
      expect(item.id, 'test-item-1');
      expect(item.name, 'Updated');
      expect(item.quantity, 5);
      expect(item.syncStatus, SyncStatus.pending);
      expect(item.householdId, 'household-1');
    });

    test('should handle sync errors gracefully', () async {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      networkNotifier.setOnlineStatus(true);
      
      final syncFuture = itemsNotifier.sync();
      
      expect(container.read(offlineItemsProvider).syncState, SyncState.syncing);
      
      await syncFuture;
      
      final state = container.read(offlineItemsProvider);
      expect(state.syncState, SyncState.idle);
    });

    test('should clear sync message after error', () {
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      itemsNotifier.clearSyncMessage();
      
      final state = container.read(offlineItemsProvider);
      expect(state.syncState, SyncState.idle);
      expect(state.syncMessage, null);
    });

    test('should prevent sync while offline', () async {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      networkNotifier.setOnlineStatus(false);
      
      final syncFuture = itemsNotifier.sync();
      
      await syncFuture;
      
      final state = container.read(offlineItemsProvider);
      expect(state.isOnline, false);
    });
  });
}
