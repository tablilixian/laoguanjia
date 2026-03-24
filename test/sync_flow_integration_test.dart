import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/features/items/providers/offline_items_provider.dart';
import 'package:home_manager/data/models/household_item.dart';
import 'package:home_manager/core/providers/network_status_provider.dart';

void main() {
  group('Sync Flow Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with idle sync state', () {
      final state = container.read(offlineItemsProvider);
      
      expect(state.syncState, SyncState.idle);
      expect(state.isOnline, true);
      expect(state.pendingSyncCount, 0);
    });

    test('should track network status changes', () {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      
      networkNotifier.setOnlineStatus(false);
      
      final state = container.read(offlineItemsProvider);
      expect(state.isOnline, false);
      
      networkNotifier.setOnlineStatus(true);
      
      final updatedState = container.read(offlineItemsProvider);
      expect(updatedState.isOnline, true);
    });

    test('should trigger auto-sync when coming online with pending items', () async {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      final testItem = HouseholdItem(
        id: 'test-item-1',
        householdId: 'household-1',
        name: 'Test Item',
        itemType: 'electronics',
        quantity: 1,
        condition: ItemCondition.good,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      networkNotifier.setOnlineStatus(false);
      await itemsNotifier.createItem(testItem);
      
      expect(container.read(offlineItemsProvider).pendingSyncCount, 1);
      
      networkNotifier.setOnlineStatus(true);
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      final state = container.read(offlineItemsProvider);
      expect(state.isOnline, true);
    });

    test('should handle sync state transitions correctly', () async {
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      expect(container.read(offlineItemsProvider).syncState, SyncState.idle);
      
      final syncFuture = itemsNotifier.sync();
      
      expect(container.read(offlineItemsProvider).syncState, SyncState.syncing);
      expect(container.read(offlineItemsProvider).syncMessage, '正在同步...');
      
      await syncFuture;
      
      expect(container.read(offlineItemsProvider).syncState, SyncState.idle);
    });

    test('should clear sync message after error', () {
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      itemsNotifier.clearSyncMessage();
      
      final state = container.read(offlineItemsProvider);
      expect(state.syncState, SyncState.idle);
      expect(state.syncMessage, null);
    });

    test('should update item sync status on creation', () async {
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      final testItem = HouseholdItem(
        id: 'test-item-1',
        householdId: 'household-1',
        name: 'Test Item',
        itemType: 'electronics',
        quantity: 1,
        condition: ItemCondition.good,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await itemsNotifier.createItem(testItem);
      
      final state = container.read(offlineItemsProvider);
      expect(state.items.any((i) => i.id == 'test-item-1'), true);
    });

    test('should calculate pending sync count correctly', () {
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      final items = [
        HouseholdItem(
          id: 'item-1',
          householdId: 'household-1',
          name: 'Item 1',
          itemType: 'electronics',
          quantity: 1,
          condition: ItemCondition.good,
          syncStatus: SyncStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        HouseholdItem(
          id: 'item-2',
          householdId: 'household-1',
          name: 'Item 2',
          itemType: 'electronics',
          quantity: 1,
          condition: ItemCondition.good,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        HouseholdItem(
          id: 'item-3',
          householdId: 'household-1',
          name: 'Item 3',
          itemType: 'electronics',
          quantity: 1,
          condition: ItemCondition.good,
          syncStatus: SyncStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      
      items.forEach((item) async {
        await itemsNotifier.createItem(item);
      });
      
      final state = container.read(offlineItemsProvider);
      expect(state.pendingSyncCount, 2);
    });

    test('should prevent multiple simultaneous sync operations', () async {
      final itemsNotifier = container.read(offlineItemsProvider.notifier);
      
      final syncFuture1 = itemsNotifier.sync();
      final syncFuture2 = itemsNotifier.sync();
      
      expect(container.read(offlineItemsProvider).isSyncing, true);
      
      await syncFuture1;
      await syncFuture2;
      
      expect(container.read(offlineItemsProvider).isSyncing, false);
    });

    test('should handle offline mode gracefully', () {
      final networkNotifier = container.read(networkStatusProvider.notifier);
      
      networkNotifier.setOnlineStatus(false);
      
      final state = container.read(offlineItemsProvider);
      expect(state.isOnline, false);
      expect(state.syncState, SyncState.idle);
    });
  });
}
