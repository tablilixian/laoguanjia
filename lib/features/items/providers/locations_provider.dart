import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item_location.dart';
import '../../../data/repositories/item_repository.dart';
import '../../household/providers/household_provider.dart';

class LocationsState {
  final List<ItemLocation> locations;
  final Map<String, int> itemCounts; // 直接物品数量
  final bool isLoading;
  final String? errorMessage;

  LocationsState({
    this.locations = const [],
    this.itemCounts = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  List<ItemLocation> get rootLocations =>
      locations.where((l) => l.isRoot).toList();

  List<ItemLocation> getChildLocations(String parentId) =>
      locations.where((l) => l.parentId == parentId).toList();

  /// 获取直接物品数量
  int getItemCount(String locationId) => itemCounts[locationId] ?? 0;

  /// 获取包含子位置的物品总数
  int getTotalItemCount(String locationId) {
    int total = getItemCount(locationId);
    final children = getChildLocations(locationId);
    for (final child in children) {
      total += getTotalItemCount(child.id);
    }
    return total;
  }

  /// 获取所有子位置的物品总数（不含当前位置）
  int getChildrenItemCount(String locationId) {
    int total = 0;
    final children = getChildLocations(locationId);
    for (final child in children) {
      total += getTotalItemCount(child.id);
    }
    return total;
  }

  LocationsState copyWith({
    List<ItemLocation>? locations,
    Map<String, int>? itemCounts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LocationsState(
      locations: locations ?? this.locations,
      itemCounts: itemCounts ?? this.itemCounts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class LocationsNotifier extends StateNotifier<LocationsState> {
  final ItemRepository _repository = ItemRepository();
  final Ref _ref;

  LocationsNotifier(this._ref) : super(LocationsState()) {
    _loadLocations();
  }

  String? _getHouseholdId() {
    final householdState = _ref.read(householdProvider);
    return householdState.currentHousehold?.id;
  }

  Future<void> _loadLocations() async {
    final householdId = _getHouseholdId();
    if (householdId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final locations = await _repository.getLocations(householdId);
      final itemCounts = await _repository.getAllLocationItemCounts(
        householdId,
      );
      state = state.copyWith(
        locations: locations,
        itemCounts: itemCounts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载位置失败: ${e.toString()}',
      );
    }
  }

  Future<void> refresh() async {
    await _loadLocations();
  }

  Future<void> createLocation(ItemLocation location) async {
    try {
      final newLocation = await _repository.createLocation(location);
      state = state.copyWith(locations: [...state.locations, newLocation]);
    } catch (e) {
      state = state.copyWith(errorMessage: '创建位置失败: ${e.toString()}');
    }
  }

  Future<void> updateLocation(ItemLocation location) async {
    try {
      final updated = await _repository.updateLocation(location);
      final index = state.locations.indexWhere((l) => l.id == location.id);
      final newLocations = [...state.locations];
      newLocations[index] = updated;
      state = state.copyWith(locations: newLocations);
    } catch (e) {
      state = state.copyWith(errorMessage: '更新位置失败: ${e.toString()}');
    }
  }

  Future<void> deleteLocation(String locationId) async {
    try {
      await _repository.deleteLocation(locationId);
      state = state.copyWith(
        locations: state.locations.where((l) => l.id != locationId).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: '删除位置失败: ${e.toString()}');
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final locationsProvider =
    StateNotifierProvider<LocationsNotifier, LocationsState>((ref) {
      return LocationsNotifier(ref);
    });
