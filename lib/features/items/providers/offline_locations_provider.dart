import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item_location.dart';
import '../../../data/repositories/item_repository.dart';
import '../../household/providers/household_provider.dart';

class LocationsState {
  final List<ItemLocation> locations;
  final bool isLoading;
  final String? errorMessage;

  LocationsState({
    this.locations = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  int get totalCount => locations.length;

  List<ItemLocation> get rootLocations => locations.where((l) => l.parentId == null).toList();

  List<ItemLocation> getChildLocations(String parentId) => 
      locations.where((l) => l.parentId == parentId).toList();

  LocationsState copyWith({
    List<ItemLocation>? locations,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LocationsState(
      locations: locations ?? this.locations,
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
      print('🔵 [LocationsNotifier] 加载位置: ${locations.length} 个');
      state = state.copyWith(locations: locations, isLoading: false);
    } catch (e) {
      print('🔴 [LocationsNotifier] 加载失败: $e');
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
    state = state.copyWith(isLoading: true);

    try {
      final newLocation = await _repository.createLocation(location);
      state = state.copyWith(
        locations: [newLocation, ...state.locations],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '创建位置失败: $e');
    }
  }

  Future<void> updateLocation(ItemLocation location) async {
    state = state.copyWith(isLoading: true);

    try {
      final updatedLocation = await _repository.updateLocation(location);

      final index = state.locations.indexWhere((l) => l.id == location.id);
      final newLocations = [...state.locations];
      newLocations[index] = updatedLocation;
      state = state.copyWith(locations: newLocations, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '更新位置失败: $e');
    }
  }

  Future<void> deleteLocation(String locationId) async {
    state = state.copyWith(isLoading: true);

    try {
      await _repository.deleteLocation(locationId);
      final newLocations = state.locations.where((l) => l.id != locationId).toList();
      state = state.copyWith(locations: newLocations, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '删除位置失败: ${e.toString()}',
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final offlineLocationsProvider = StateNotifierProvider<LocationsNotifier, LocationsState>((ref) {
  return LocationsNotifier(ref);
});
