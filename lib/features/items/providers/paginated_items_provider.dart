import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/household_item.dart';
import '../../../data/services/item_query_service.dart';
import '../../../data/repositories/offline_item_repository.dart';
import '../../household/providers/household_provider.dart';
import 'offline_items_provider.dart';

/// 分页物品状态
class PaginatedItemsState {
  final List<HouseholdItem> items;
  final int totalCount;
  final int currentPage;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? searchQuery;
  final String? itemType;
  final String? locationId;
  final String? ownerId;
  final String sortBy;
  final bool sortAsc;

  const PaginatedItemsState({
    this.items = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.searchQuery,
    this.itemType,
    this.locationId,
    this.ownerId,
    this.sortBy = 'updatedAt',
    this.sortAsc = false,
  });

  PaginatedItemsState copyWith({
    List<HouseholdItem>? items,
    int? totalCount,
    int? currentPage,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    String? searchQuery,
    String? itemType,
    String? locationId,
    String? ownerId,
    String? sortBy,
    bool? sortAsc,
    bool clearSearch = false,
    bool clearItemType = false,
    bool clearLocation = false,
    bool clearOwner = false,
  }) {
    return PaginatedItemsState(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      itemType: clearItemType ? null : (itemType ?? this.itemType),
      locationId: clearLocation ? null : (locationId ?? this.locationId),
      ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
      sortBy: sortBy ?? this.sortBy,
      sortAsc: sortAsc ?? this.sortAsc,
    );
  }
}

/// 分页物品通知器
class PaginatedItemsNotifier extends StateNotifier<PaginatedItemsState> {
  final ItemQueryService _queryService;
  final Ref _ref;
  
  static const int _pageSize = 20;
  String? _initializedHouseholdId;

  PaginatedItemsNotifier(this._ref)
      : _queryService = ItemQueryService(),
        super(const PaginatedItemsState()) {
    _listenToHouseholdChanges();
    _listenToOfflineItemsChanges();
    _checkInitialHousehold();
  }

  void _checkInitialHousehold() {
    final householdState = _ref.read(householdProvider);
    final householdId = householdState.currentHousehold?.id;
    print('🔵 [PaginatedItemsNotifier] 检查初始家庭状态: householdId=$householdId, isLoading=${householdState.isLoading}');
    
    if (householdId != null) {
      print('🔵 [PaginatedItemsNotifier] 初始家庭ID存在，开始初始化: $householdId');
      _initialize();
    }
  }

  void _listenToOfflineItemsChanges() {
    // 监听 offlineItemsProvider 的变化，自动刷新分页列表
    _ref.listen(offlineItemsProvider, (previous, next) {
      if (previous != null && previous.items.length != next.items.length) {
        print('🔄 [PaginatedItemsNotifier] 检测到物品数量变化: ${previous.items.length} -> ${next.items.length}，自动刷新分页');
        refresh();
      }
    });
  }

  void _listenToHouseholdChanges() {
    _ref.listen(householdProvider, (previous, next) {
      final householdId = next.currentHousehold?.id;
      print('🔵 [PaginatedItemsNotifier] 家庭状态变化: householdId=$householdId, previous=${previous?.currentHousehold?.id}, isLoading=${next.isLoading}');
      
      if (householdId != null && householdId != previous?.currentHousehold?.id && householdId != _initializedHouseholdId) {
        print('🔵 [PaginatedItemsNotifier] 家庭ID变化，重新初始化: $householdId');
        _initialize();
      } else if (householdId == null && !next.isLoading) {
        print('🔴 [PaginatedItemsNotifier] 家庭ID为空且不在加载中，清空数据');
        state = const PaginatedItemsState();
        _initializedHouseholdId = null;
      }
    });
  }

  String? _getHouseholdId() {
    final householdState = _ref.read(householdProvider);
    return householdState.currentHousehold?.id;
  }

  Future<void> _initialize() async {
    final householdId = _getHouseholdId();
    if (householdId == null) {
      print('🔴 [PaginatedItemsNotifier] householdId 为空，跳过初始化');
      return;
    }

    try {
      print('🔵 [PaginatedItemsNotifier] 开始初始化，householdId: $householdId');
      _initializedHouseholdId = householdId;
      
      final repository = OfflineItemRepository();
      print('🔵 [PaginatedItemsNotifier] 开始初始化数据库...');
      await repository.initialize(householdId);
      print('🔵 [PaginatedItemsNotifier] 数据库初始化完成，开始加载第一页');
      
      await loadFirstPage();
    } catch (e, stackTrace) {
      print('🔴 [PaginatedItemsNotifier] 初始化失败: $e');
      print('🔴 [PaginatedItemsNotifier] 堆栈: $stackTrace');
      _initializedHouseholdId = null;
    }
  }

  Future<void> loadFirstPage() async {
    final householdId = _getHouseholdId();
    if (householdId == null) {
      print('🔴 [PaginatedItemsNotifier] householdId 为空，跳过加载第一页');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      print('🔵 [PaginatedItemsNotifier] 开始加载第一页，householdId: $householdId');
      final result = await _queryService.getItemsPaginated(
        householdId,
        limit: _pageSize,
        offset: 0,
        searchQuery: state.searchQuery,
        itemType: state.itemType,
        locationId: state.locationId,
        ownerId: state.ownerId,
        sortBy: state.sortBy,
        ascending: state.sortAsc,
      );

      print('🔵 [PaginatedItemsNotifier] 加载第一页完成，物品数量: ${result.items.length}，总数: ${result.totalCount}');
      state = state.copyWith(
        items: result.items,
        totalCount: result.totalCount,
        hasMore: result.hasMore,
        currentPage: 1,
        isLoading: false,
      );
    } catch (e) {
      print('🔴 [PaginatedItemsNotifier] 加载第一页失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载物品失败: ${e.toString()}',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    final householdId = _getHouseholdId();
    if (householdId == null) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final offset = state.currentPage * _pageSize;
      final result = await _queryService.getItemsPaginated(
        householdId,
        limit: _pageSize,
        offset: offset,
        searchQuery: state.searchQuery,
        itemType: state.itemType,
        locationId: state.locationId,
        ownerId: state.ownerId,
        sortBy: state.sortBy,
        ascending: state.sortAsc,
      );

      state = state.copyWith(
        items: [...state.items, ...result.items],
        totalCount: result.totalCount,
        currentPage: state.currentPage + 1,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      print('🔴 [PaginatedItemsNotifier] 加载更多失败: $e');
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: '加载更多失败: ${e.toString()}',
      );
    }
  }

  Future<void> refresh() async {
    final householdId = _getHouseholdId();
    if (householdId == null) {
      print('🔴 [PaginatedItemsNotifier] refresh: householdId 为空，跳过刷新');
      return;
    }

    print('🔄 [PaginatedItemsNotifier] 开始强制刷新，householdId: $householdId');
    
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final result = await _queryService.getItemsPaginated(
        householdId,
        limit: _pageSize,
        offset: 0,
        searchQuery: state.searchQuery,
        itemType: state.itemType,
        locationId: state.locationId,
        ownerId: state.ownerId,
        sortBy: state.sortBy,
        ascending: state.sortAsc,
      );

      print('🔄 [PaginatedItemsNotifier] 强制刷新完成，物品数量: ${result.items.length}，总数: ${result.totalCount}');
      
      state = state.copyWith(
        items: result.items,
        totalCount: result.totalCount,
        hasMore: result.hasMore,
        currentPage: 1,
        isLoading: false,
      );
    } catch (e) {
      print('🔴 [PaginatedItemsNotifier] 强制刷新失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '刷新失败: ${e.toString()}',
      );
    }
  }

  void setSearchQuery(String? query) {
    if (state.searchQuery != query) {
      state = state.copyWith(searchQuery: query, currentPage: 1);
      loadFirstPage();
    }
  }

  void setItemTypeFilter(String? typeKey) {
    if (state.itemType != typeKey) {
      state = state.copyWith(
        itemType: typeKey,
        clearItemType: typeKey == null,
        currentPage: 1,
      );
      loadFirstPage();
    }
  }

  void setLocationFilter(String? locationId) {
    if (state.locationId != locationId) {
      state = state.copyWith(
        locationId: locationId,
        clearLocation: locationId == null,
        currentPage: 1,
      );
      loadFirstPage();
    }
  }

  void setOwnerFilter(String? ownerId) {
    if (state.ownerId != ownerId) {
      state = state.copyWith(
        ownerId: ownerId,
        clearOwner: ownerId == null,
        currentPage: 1,
      );
      loadFirstPage();
    }
  }

  void setSort(String sortBy, bool sortAsc) {
    if (state.sortBy != sortBy || state.sortAsc != sortAsc) {
      state = state.copyWith(
        sortBy: sortBy,
        sortAsc: sortAsc,
        currentPage: 1,
      );
      loadFirstPage();
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: null,
      itemType: null,
      locationId: null,
      ownerId: null,
      sortBy: 'updatedAt',
      sortAsc: false,
      currentPage: 1,
      clearSearch: true,
      clearItemType: true,
      clearLocation: true,
      clearOwner: true,
    );
    loadFirstPage();
  }
}

/// 分页物品Provider
final paginatedItemsProvider =
    StateNotifierProvider<PaginatedItemsNotifier, PaginatedItemsState>((ref) {
  return PaginatedItemsNotifier(ref);
});
