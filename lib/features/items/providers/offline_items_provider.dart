import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_scheduler.dart';
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

enum SyncState { idle, syncing, success, error }

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

  int get pendingSyncCount =>
      items.where((i) => i.syncStatus == SyncStatus.pending).length;

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
    _ref.listen<NetworkStatus>(networkStatusProvider, (previous, next) {
      setOnlineStatus(next.isOnline);
    });
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
      print(
        '   - 待同步: ${items.where((i) => i.syncStatus == SyncStatus.pending).length} 个',
      );
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

    } catch (e) {
      state = state.copyWith(errorMessage: '更新归属人失败: $e');
    }
  }

  // ==================== 批量操作方法 ====================

  /// 批量删除物品（软删除）
  ///
  /// 遍历所有选中的物品，逐个调用 repository.deleteItem 执行软删除。
  /// 软删除会递增版本号并标记为待同步，确保云端同步。
  ///
  /// [itemIds] 要删除的物品 ID 列表
  Future<void> batchDeleteItems(List<String> itemIds) async {
    if (itemIds.isEmpty) return;

    print('🗑️ [批量操作] 开始批量删除: ${itemIds.length} 个物品');
    state = state.copyWith(isLoading: true);

    try {
      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < itemIds.length; i++) {
        final itemId = itemIds[i];
        try {
          final item = state.items.firstWhere(
            (i) => i.id == itemId,
            orElse: () => HouseholdItem(
              id: '',
              householdId: '',
              name: '未知',
              quantity: 1,
              itemType: 'other',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          print(
            '🗑️ [批量操作] [$i/${itemIds.length}] 删除物品: ${item.name} ($itemId)',
          );

          await _repository.deleteItem(itemId);
          successCount++;
          print('✅ [批量操作] [$i/${itemIds.length}] 删除成功: ${item.name}');
        } catch (e) {
          failCount++;
          print('❌ [批量操作] [$i/${itemIds.length}] 删除物品 $itemId 失败: $e');
        }
      }

      // 从本地状态中移除已删除的物品
      final newItems = state.items
          .where((i) => !itemIds.contains(i.id))
          .toList();
      state = state.copyWith(items: newItems, isLoading: false);

      // pendingSyncCount 会变成 0。直接调用 sync() 确保同步执行。
      await sync();

      print('🗑️ [批量操作] 批量删除完成: 成功=$successCount, 失败=$failCount');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '批量删除失败: ${e.toString()}',
      );
      print('❌ [批量操作] 批量删除异常: $e');
    }
  }

  /// 批量更改物品位置
  ///
  /// 将所有选中物品的位置更新为新的 locationId。
  /// 使用 copyWith 创建新对象，保持不可变性。
  ///
  /// [itemIds] 要更新的物品 ID 列表
  /// [newLocationId] 新的位置 ID
  Future<void> batchUpdateLocation(
    List<String> itemIds,
    String newLocationId,
  ) async {
    if (itemIds.isEmpty) return;

    print('📍 [批量操作] 开始批量更改位置: ${itemIds.length} 个物品 → 位置 $newLocationId');
    state = state.copyWith(isLoading: true);

    try {
      int successCount = 0;
      int failCount = 0;
      final updatedItems = <HouseholdItem>[];

      for (int i = 0; i < itemIds.length; i++) {
        final itemId = itemIds[i];
        try {
          final item = state.items.firstWhere((i) => i.id == itemId);
          print(
            '📍 [批量操作] [$i/${itemIds.length}] 更新物品: ${item.name} ($itemId), 旧位置=${item.locationId} → 新位置=$newLocationId',
          );

          // 使用 repository.updateItem 会自动递增版本号、设置 syncStatus=pending
          final updatedItem = await _repository.updateItem(
            item.copyWith(locationId: newLocationId),
          );
          updatedItems.add(updatedItem);
          successCount++;
          print(
            '✅ [批量操作] [$i/${itemIds.length}] 更新成功: ${item.name}, 新版本=${updatedItem.version}, syncStatus=${updatedItem.syncStatus}',
          );
        } catch (e) {
          failCount++;
          print('❌ [批量操作] [$i/${itemIds.length}] 更新物品 $itemId 位置失败: $e');
        }
      }

      // 更新本地状态：用 repository 返回的已更新对象替换原对象
      final newItems = state.items.map((item) {
        final updated = updatedItems.firstWhere(
          (u) => u.id == item.id,
          orElse: () => item,
        );
        return updated;
      }).toList();

      state = state.copyWith(items: newItems, isLoading: false);

      // 统计待同步数量
      final pendingCount = state.items
          .where((i) => i.syncStatus == SyncStatus.pending)
          .length;
      print(
        '📍 [批量操作] 批量更改位置完成: 成功=$successCount, 失败=$failCount, 当前待同步物品数=$pendingCount',
      );


      print('✅ [批量操作] 批量更改位置全部完成');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '批量更新位置失败: ${e.toString()}',
      );
      print('❌ [批量操作] 批量更改位置异常: $e');
    }
  }

  /// 批量追加标签（保留原有标签）
  ///
  /// 为所有选中物品追加新的标签，不会移除已有的标签。
  /// 使用位图运算（TagsMaskHelper.addTag）来高效更新。
  ///
  /// [itemIds] 要追加标签的物品 ID 列表
  /// [tagIds] 要追加的标签 ID 列表
  Future<void> batchAddTags(List<String> itemIds, List<String> tagIds) async {
    if (itemIds.isEmpty || tagIds.isEmpty) return;

    print('🏷️ [批量操作] 开始批量追加标签: ${itemIds.length} 个物品, 标签IDs=$tagIds');
    state = state.copyWith(isLoading: true);

    try {
      int successCount = 0;
      int failCount = 0;
      final updatedItems = <HouseholdItem>[];

      for (int i = 0; i < itemIds.length; i++) {
        final itemId = itemIds[i];
        try {
          // 获取物品当前的 tagsMask，然后逐个追加新标签
          final item = state.items.firstWhere((i) => i.id == itemId);
          int newMask = item.tagsMask;
          print(
            '🏷️ [批量操作] [$i/${itemIds.length}] 追加标签: ${item.name} ($itemId), 旧mask=$newMask',
          );

          for (final tagId in tagIds) {
            final tag = await _repository.getTag(tagId);
            if (tag != null && tag.tagIndex != null) {
              // 使用位图运算追加标签
              newMask = newMask | (1 << tag.tagIndex!);
              print('🏷️ [批量操作]   追加标签: ${tag.name} (index=${tag.tagIndex})');
            }
          }

          // 使用 repository.updateItem 会自动递增版本号、设置 syncStatus=pending
          final updatedItem = await _repository.updateItem(
            item.copyWith(tagsMask: newMask),
          );
          updatedItems.add(updatedItem);
          successCount++;
          print(
            '✅ [批量操作] [$i/${itemIds.length}] 追加成功: ${item.name}, 新mask=$newMask, 版本=${updatedItem.version}',
          );
        } catch (e) {
          failCount++;
          print('❌ [批量操作] [$i/${itemIds.length}] 为物品 $itemId 追加标签失败: $e');
        }
      }

      // 更新本地状态
      final newItems = state.items.map((item) {
        final updated = updatedItems.firstWhere(
          (u) => u.id == item.id,
          orElse: () => item,
        );
        return updated;
      }).toList();

      state = state.copyWith(items: newItems, isLoading: false);

      final pendingCount = state.items
          .where((i) => i.syncStatus == SyncStatus.pending)
          .length;
      print(
        '🏷️ [批量操作] 批量追加标签完成: 成功=$successCount, 失败=$failCount, 当前待同步物品数=$pendingCount',
      );


      print('✅ [批量操作] 批量追加标签全部完成');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '批量追加标签失败: ${e.toString()}',
      );
      print('❌ [批量操作] 批量追加标签异常: $e');
    }
  }

  /// 批量设置标签（覆盖原有标签）
  ///
  /// 将所有选中物品的标签替换为新的标签列表。
  /// 使用 repository.setItemTags 来完全替换 tags_mask。
  ///
  /// [itemIds] 要设置标签的物品 ID 列表
  /// [tagIds] 新的标签 ID 列表（会完全替换原有标签）
  Future<void> batchSetTags(List<String> itemIds, List<String> tagIds) async {
    if (itemIds.isEmpty) return;

    print('🏷️ [批量操作] 开始批量设置标签(覆盖): ${itemIds.length} 个物品, 标签IDs=$tagIds');
    state = state.copyWith(isLoading: true);

    try {
      int successCount = 0;
      int failCount = 0;
      final updatedItems = <HouseholdItem>[];

      for (int i = 0; i < itemIds.length; i++) {
        final itemId = itemIds[i];
        try {
          final item = state.items.firstWhere((i) => i.id == itemId);
          print(
            '🏷️ [批量操作] [$i/${itemIds.length}] 设置标签(覆盖): ${item.name} ($itemId), 旧mask=${item.tagsMask}',
          );

          // setItemTags 内部已经处理了版本号递增和 syncPending 标记
          await _repository.setItemTags(itemId, tagIds);

          // 重新从本地数据库读取更新后的物品，确保状态一致
          final householdId = _getHouseholdId();
          if (householdId != null) {
            final allItems = await _repository.getItems(householdId);
            final updatedItem = allItems.firstWhere(
              (i) => i.id == itemId,
              orElse: () => state.items.firstWhere((i) => i.id == itemId),
            );
            updatedItems.add(updatedItem);
            print(
              '✅ [批量操作] [$i/${itemIds.length}] 设置成功: ${item.name}, 新mask=${updatedItem.tagsMask}',
            );
          }
          successCount++;
        } catch (e) {
          failCount++;
          print('❌ [批量操作] [$i/${itemIds.length}] 为物品 $itemId 设置标签失败: $e');
        }
      }

      // 更新本地状态
      final newItems = state.items.map((item) {
        final updated = updatedItems.firstWhere(
          (u) => u.id == item.id,
          orElse: () => item,
        );
        return updated;
      }).toList();

      state = state.copyWith(items: newItems, isLoading: false);

      final pendingCount = state.items
          .where((i) => i.syncStatus == SyncStatus.pending)
          .length;
      print(
        '🏷️ [批量操作] 批量设置标签完成: 成功=$successCount, 失败=$failCount, 当前待同步物品数=$pendingCount',
      );


      print('✅ [批量操作] 批量设置标签全部完成');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '批量设置标签失败: ${e.toString()}',
      );
      print('❌ [批量操作] 批量设置标签异常: $e');
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

      await SyncScheduler().forceSync();

      await _loadItems();

      state = state.copyWith(syncState: SyncState.success, syncMessage: '同步成功');

      Future.delayed(const Duration(seconds: 2), () {
        state = state.copyWith(syncState: SyncState.idle, syncMessage: null);
      });
    } catch (e) {
      print('🔴 [OfflineItemsNotifier] 同步失败: $e');
      state = state.copyWith(
        syncState: SyncState.error,
        syncMessage: '同步失败: ${e.toString()}',
      );

      Future.delayed(const Duration(seconds: 3), () {
        state = state.copyWith(syncState: SyncState.idle, syncMessage: null);
      });
    }
  }

  void setOnlineStatus(bool isOnline) {
    if (state.isOnline != isOnline) {
      print('📡 [OfflineItemsNotifier] 网络状态变化: ${isOnline ? "在线" : "离线"}');
      state = state.copyWith(isOnline: isOnline);
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void clearSyncMessage() {
    state = state.copyWith(syncState: SyncState.idle, syncMessage: null);
  }
}

final offlineItemsProvider = StateNotifierProvider<ItemsNotifier, ItemsState>((
  ref,
) {
  return ItemsNotifier(ref);
});
