import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/household_item.dart';
import '../../../data/repositories/item_repository.dart';
import '../../household/providers/household_provider.dart';

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

class ItemsState {
  final List<HouseholdItem> items;
  final ItemFilters filters;
  final bool isLoading;
  final String? errorMessage;

  ItemsState({
    this.items = const [],
    this.filters = const ItemFilters(),
    this.isLoading = false,
    this.errorMessage,
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

    return result;
  }

  int get totalCount => items.where((i) => !i.isDeleted).length;

  ItemsState copyWith({
    List<HouseholdItem>? items,
    ItemFilters? filters,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ItemsState(
      items: items ?? this.items,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ItemsNotifier extends StateNotifier<ItemsState> {
  final ItemRepository _repository = ItemRepository();
  final Ref _ref;

  ItemsNotifier(this._ref) : super(ItemsState()) {
    _loadItems();
  }

  String? _getHouseholdId() {
    final householdState = _ref.read(householdProvider);
    return householdState.currentHousehold?.id;
  }

  Future<void> _loadItems() async {
    final householdId = _getHouseholdId();
    if (householdId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final items = await _repository.getItems(householdId);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
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

  Future<void> createItem(HouseholdItem item, {List<String>? tagIds}) async {
    state = state.copyWith(isLoading: true);

    try {
      final newItem = await _repository.createItem(item);

      // 保存标签关联
      if (tagIds != null && tagIds.isNotEmpty) {
        for (final tagId in tagIds) {
          await _repository.addTagToItem(newItem.id, tagId);
        }
        // 重新加载物品以获取完整的标签数据
        final items = await _repository.getItems(_getHouseholdId()!);
        final createdItem = items.firstWhere((i) => i.id == newItem.id);
        state = state.copyWith(
          items: [createdItem, ...state.items],
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          items: [newItem, ...state.items],
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '创建物品失败: $e');
    }
  }

  Future<void> updateItem(HouseholdItem item, {List<String>? tagIds}) async {
    state = state.copyWith(isLoading: true);

    try {
      final updatedItem = await _repository.updateItem(item);

      // 更新标签关联
      if (tagIds != null) {
        // 获取当前关联的标签
        final currentTags = await _repository.getItemTags(item.id);
        final currentTagIds = currentTags.map((t) => t.id).toSet();
        final newTagIds = tagIds.toSet();

        // 添加新标签
        for (final tagId in newTagIds.difference(currentTagIds)) {
          await _repository.addTagToItem(item.id, tagId);
        }

        // 移除不再关联的标签
        for (final tagId in currentTagIds.difference(newTagIds)) {
          await _repository.removeTagFromItem(item.id, tagId);
        }

        // 重新加载物品以获取完整的标签数据
        final items = await _repository.getItems(_getHouseholdId()!);
        final refreshedItem = items.firstWhere((i) => i.id == item.id);
        final index = state.items.indexWhere((i) => i.id == item.id);
        final newItems = [...state.items];
        newItems[index] = refreshedItem;
        state = state.copyWith(items: newItems, isLoading: false);
      } else {
        final index = state.items.indexWhere((i) => i.id == item.id);
        final newItems = [...state.items];
        newItems[index] = updatedItem;
        state = state.copyWith(items: newItems, isLoading: false);
      }
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

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final itemsProvider = StateNotifierProvider<ItemsNotifier, ItemsState>((ref) {
  return ItemsNotifier(ref);
});
