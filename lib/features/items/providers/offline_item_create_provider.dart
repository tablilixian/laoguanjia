import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/household_item.dart';
import '../../../data/models/item_location.dart';
import '../../../data/models/item_tag.dart';
import '../../../data/models/item_type_config.dart';
import '../../../data/repositories/item_repository.dart';
import 'offline_item_stats_provider.dart';

/// 物品创建/编辑状态
class ItemCreateState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final HouseholdItem? currentItem;
  final List<ItemLocation> locations;
  final List<ItemTag> tags;
  final List<ItemTypeConfig> types;

  ItemCreateState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.currentItem,
    this.locations = const [],
    this.tags = const [],
    this.types = const [],
  });

  ItemCreateState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    HouseholdItem? currentItem,
    List<ItemLocation>? locations,
    List<ItemTag>? tags,
    List<ItemTypeConfig>? types,
  }) {
    return ItemCreateState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      currentItem: currentItem ?? this.currentItem,
      locations: locations ?? this.locations,
      tags: tags ?? this.tags,
      types: types ?? this.types,
    );
  }
}

/// 物品创建/编辑 Notifier
class ItemCreateNotifier extends StateNotifier<ItemCreateState> {
  final ItemRepository _repository;
  final String householdId;

  ItemCreateNotifier({
    required ItemRepository repository,
    required this.householdId,
  }) : _repository = repository,
       super(ItemCreateState());

  /// 加载物品数据（编辑模式）
  Future<void> loadItem(String itemId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final item = await _repository.getItem(itemId);
      final locations = await _repository.getLocations(householdId);
      final tags = await _repository.getTags(householdId);
      final types = await _repository.getTypeConfigs(householdId);

      state = state.copyWith(
        isLoading: false,
        currentItem: item,
        locations: locations,
        tags: tags,
        types: types,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载失败: $e',
      );
      rethrow;
    }
  }

  /// 获取物品标签 ID 列表
  Future<List<String>> getItemTagIds(String itemId) async {
    return await _repository.getItemTagIds(itemId);
  }

  /// 加载初始化数据（创建模式）
  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final locations = await _repository.getLocations(householdId);
      final tags = await _repository.getTags(householdId);
      final types = await _repository.getTypeConfigs(householdId);

      state = state.copyWith(
        isLoading: false,
        locations: locations,
        tags: tags,
        types: types,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载失败: $e',
      );
    }
  }

  /// 创建物品
  Future<HouseholdItem> createItem(
    HouseholdItem item,
    List<String> tagIds,
  ) async {
    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final newItem = item.copyWith(
        id: const Uuid().v4(),
        householdId: householdId,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createdItem = await _repository.createItem(newItem);

      for (final tagId in tagIds) {
        await _repository.addTagToItem(createdItem.id, tagId);
      }

      state = state.copyWith(isSaving: false, currentItem: createdItem);
      return createdItem;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: '创建失败: $e',
      );
      rethrow;
    }
  }

  /// 更新物品
  Future<HouseholdItem> updateItem(
    HouseholdItem item,
    List<String> tagIds,
  ) async {
    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final updatedItem = await _repository.updateItem(item);

      await _repository.updateItemTags(item.id, tagIds);

      state = state.copyWith(isSaving: false, currentItem: updatedItem);
      return updatedItem;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: '更新失败: $e',
      );
      rethrow;
    }
  }

  /// 清除错误信息
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// 物品创建/编辑 Provider
final itemCreateProvider = StateNotifierProvider.family<
  ItemCreateNotifier,
  ItemCreateState,
  String
>((ref, householdId) {
  final repository = ref.watch(offlineItemRepositoryProvider);
  return ItemCreateNotifier(
    repository: repository,
    householdId: householdId,
  );
});
