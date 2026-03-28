import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/household_item.dart';
import '../../../data/repositories/item_repository.dart';
import '../../household/providers/household_provider.dart';
import '../../../core/providers/network_status_provider.dart';

enum ItemFilter { all, byType, byLocation, byOwner }

class ItemFilters {
  final String? itemType;
  final String? locationId;
  final String? ownerId;
  final String? searchQuery;
  final String sortBy;
  final bool sortAsc;

  const ItemFilters({
    this.itemType,
    this.locationId,
    this.ownerId,
    this.searchQuery,
    this.sortBy = 'updated_at',
    this.sortAsc = false,
  });

  ItemFilters copyWith({
    String? itemType,
    String? locationId,
    String? ownerId,
    String? searchQuery,
    String? sortBy,
    bool? sortAsc,
    bool clearItemType = false,
    bool clearLocation = false,
    bool clearOwner = false,
    bool clearSearch = false,
  }) {
    return ItemFilters(
      itemType: clearItemType ? null : (itemType ?? this.itemType),
      locationId: clearLocation ? null : (locationId ?? this.locationId),
      ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      sortBy: sortBy ?? this.sortBy,
      sortAsc: sortAsc ?? this.sortAsc,
    );
  }
}

enum SyncState {
  idle,
  syncing,
  success,
  error,
}

class ItemsState {
  final List<HouseholdItem> items;
  final ItemFilters filters;
  final bool isLoading;
  final String? errorMessage;
  final SyncState syncState;
  final String? syncMessage;
  final bool isOnline;

  ItemsState({
    this.items = const [],
    this.filters = const ItemFilters(),
    this.isLoading = false,
    this.errorMessage,
    this.syncState = SyncState.idle,
    this.syncMessage,
    this.isOnline = true,
  });

  List<HouseholdItem> get filteredItems {
    var result = items.where((i) => !i.isDeleted).toList();

    if (filters.itemType != null) {
      result = result.where((i) => i.itemType == filters.itemType).toList();
    }
    if (filters.locationId != null) {
      result = result.where((i) => i.locationId == filters.locationId).toList();
    }
    if (filters.ownerId != null) {
      result = result.where((i) => i.ownerId == filters.ownerId).toList();
    }
    if (filters.searchQuery != null && filters.searchQuery!.isNotEmpty) {
      final query = filters.searchQuery!.toLowerCase();
      result = result
          .where(
            (i) =>
                i.name.toLowerCase().contains(query) ||
                (i.brand?.toLowerCase().contains(query) ?? false) ||
                (i.model?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return result;
  }

  int get totalCount => items.where((i) => !i.isDeleted).length;

  int get pendingSyncCount => items.where((i) => i.syncStatus == SyncStatus.pending).length;

  bool get isSyncing => syncState == SyncState.syncing;

  bool get hasSyncError => syncState == SyncState.error;

  ItemsState copyWith({
    List<HouseholdItem>? items,
    ItemFilters? filters,
    bool? isLoading,
    String? errorMessage,
    SyncState? syncState,
    String? syncMessage,
    bool? isOnline,
  }) {
    return ItemsState(
      items: items ?? this.items,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      syncState: syncState ?? this.syncState,
      syncMessage: syncMessage,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class ItemsNotifier extends StateNotifier<ItemsState> {
  final ItemRepository _repository = ItemRepository();
  final Ref _ref;

  ItemsNotifier(this._ref) : super(ItemsState()) {
    _initialize();
    _listenToNetworkStatus();
  }

  void _listenToNetworkStatus() {
    _ref.listen<NetworkStatus>(
      networkStatusProvider,
      (previous, next) {
        setOnlineStatus(next.isOnline);
      },
    );
  }

  String? _getHouseholdId() {
    final householdState = _ref.read(householdProvider);
    return householdState.currentHousehold?.id;
  }

  Future<void> _initialize() async {
    final householdId = _getHouseholdId();
    if (householdId == null) return;

    try {
      await _repository.initialize(householdId);
      await _loadItems();
    } catch (e) {
      print('🔴 [OfflineItemsNotifier] 初始化失败: $e');
    }
  }

  Future<void> _loadItems() async {
    final householdId = _getHouseholdId();
    if (householdId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final items = await _repository.getItems(householdId);
      print('🔵 [OfflineItemsNotifier] 加载物品: ${items.length} 个');
      print('   - 已删除: ${items.where((i) => i.isDeleted).length} 个');
      print('   - 有效: ${items.where((i) => !i.isDeleted).length} 个');
      print('   - 待同步: ${items.where((i) => i.syncStatus == SyncStatus.pending).length} 个');
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      print('🔴 [OfflineItemsNotifier] 加载失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载物品失败: ${e.toString()}',
      );
    }
  }

  Future<void> refresh() async {
    await _loadItems();
  }

  void setFilters(ItemFilters filters) {
    state = state.copyWith(filters: filters);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(searchQuery: query));
  }

  void setItemTypeFilter(String? typeKey) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        itemType: typeKey,
        clearItemType: typeKey == null,
      ),
    );
  }

  Future<void> createItem(HouseholdItem item) async {
    state = state.copyWith(isLoading: true);

    try {
      final newItem = await _repository.createItem(item);
      state = state.copyWith(
        items: [newItem, ...state.items],
        isLoading: false,
      );

      await _triggerAutoSync();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '创建物品失败: $e');
    }
  }

  Future<void> updateItem(HouseholdItem item) async {
    state = state.copyWith(isLoading: true);

    try {
      final updatedItem = await _repository.updateItem(item);

      final index = state.items.indexWhere((i) => i.id == item.id);
      final newItems = [...state.items];
      newItems[index] = updatedItem;
      state = state.copyWith(items: newItems, isLoading: false);

      await _triggerAutoSync();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '更新物品失败: $e');
    }
  }

  Future<void> deleteItem(String itemId) async {
    state = state.copyWith(isLoading: true);

    try {
      await _repository.deleteItem(itemId);
      final newItems = state.items.where((i) => i.id != itemId).toList();
      state = state.copyWith(items: newItems, isLoading: false);

      await _triggerAutoSync();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '删除物品失败: ${e.toString()}',
      );
    }
  }

  Future<void> updateItemOwner(String itemId, String? ownerId) async {
    try {
      final item = state.items.firstWhere((i) => i.id == itemId);
      final updatedItem = item.copyWith(ownerId: ownerId);
      await _repository.updateItem(updatedItem);

      final index = state.items.indexWhere((i) => i.id == itemId);
      final newItems = [...state.items];
      newItems[index] = updatedItem;
      state = state.copyWith(items: newItems);

      await _triggerAutoSync();
    } catch (e) {
      state = state.copyWith(errorMessage: '更新归属人失败: $e');
    }
  }

  Future<void> sync() async {
    if (state.isSyncing) return;

    state = state.copyWith(
      syncState: SyncState.syncing,
      syncMessage: '正在同步...',
    );

    try {
      final householdId = _getHouseholdId();
      if (householdId == null) {
        throw Exception('未选择家庭');
      }

      // 使用 ItemRepository 的 autoSync 方法
      await _repository.autoSync(householdId);

      await _loadItems();

      state = state.copyWith(
        syncState: SyncState.success,
        syncMessage: '同步成功',
      );

      Future.delayed(const Duration(seconds: 2), () {
        state = state.copyWith(
          syncState: SyncState.idle,
          syncMessage: null,
        );
      });
    } catch (e) {
      print('🔴 [OfflineItemsNotifier] 同步失败: $e');
      state = state.copyWith(
        syncState: SyncState.error,
        syncMessage: '同步失败: ${e.toString()}',
      );

      Future.delayed(const Duration(seconds: 3), () {
        state = state.copyWith(
          syncState: SyncState.idle,
          syncMessage: null,
        );
      });
    }
  }

  Future<void> _triggerAutoSync() async {
    if (state.isOnline && !state.isSyncing) {
      final pendingCount = state.pendingSyncCount;
      if (pendingCount > 0) {
        print('🔄 [OfflineItemsNotifier] 触发自动同步: $pendingCount 个待同步项');
        await sync();
      }
    }
  }

  void setOnlineStatus(bool isOnline) {
    if (state.isOnline != isOnline) {
      print('📡 [OfflineItemsNotifier] 网络状态变化: ${isOnline ? "在线" : "离线"}');
      state = state.copyWith(isOnline: isOnline);

      if (isOnline) {
        _triggerAutoSync();
      }
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void clearSyncMessage() {
    state = state.copyWith(
      syncState: SyncState.idle,
      syncMessage: null,
    );
  }
}

final offlineItemsProvider = StateNotifierProvider<ItemsNotifier, ItemsState>((ref) {
  return ItemsNotifier(ref);
});
