import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item_type_config.dart';
import '../../../data/repositories/offline_item_repository.dart';
import '../../household/providers/household_provider.dart';

class TypeConfigsState {
  final List<ItemTypeConfig> types;
  final bool isLoading;
  final String? errorMessage;

  TypeConfigsState({
    this.types = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  int get totalCount => types.length;

  List<ItemTypeConfig> get activeTypes => types.where((t) => t.isActive).toList();

  TypeConfigsState copyWith({
    List<ItemTypeConfig>? types,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TypeConfigsState(
      types: types ?? this.types,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TypeConfigsNotifier extends StateNotifier<TypeConfigsState> {
  final OfflineItemRepository _repository = OfflineItemRepository();
  final Ref _ref;

  TypeConfigsNotifier(this._ref) : super(TypeConfigsState()) {
    _loadTypes();
  }

  String? _getHouseholdId() {
    final householdState = _ref.read(householdProvider);
    return householdState.currentHousehold?.id;
  }

  Future<void> _loadTypes() async {
    final householdId = _getHouseholdId();
    if (householdId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final types = await _repository.getTypeConfigs(householdId);
      print('🔵 [TypeConfigsNotifier] 加载类型: ${types.length} 个');
      state = state.copyWith(types: types, isLoading: false);
    } catch (e) {
      print('🔴 [TypeConfigsNotifier] 加载失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载类型失败: ${e.toString()}',
      );
    }
  }

  Future<void> refresh() async {
    await _loadTypes();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final offlineTypeConfigsProvider = StateNotifierProvider<TypeConfigsNotifier, TypeConfigsState>((ref) {
  return TypeConfigsNotifier(ref);
});
