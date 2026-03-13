import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item_tag.dart';
import '../../../data/repositories/item_repository.dart';
import '../../household/providers/household_provider.dart';

class TagsState {
  final List<ItemTag> tags;
  final bool isLoading;
  final String? errorMessage;

  TagsState({this.tags = const [], this.isLoading = false, this.errorMessage});

  Map<String, List<ItemTag>> get tagsByCategory {
    final map = <String, List<ItemTag>>{};
    for (final tag in tags) {
      map.putIfAbsent(tag.category, () => []).add(tag);
    }
    return map;
  }

  TagsState copyWith({
    List<ItemTag>? tags,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TagsState(
      tags: tags ?? this.tags,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TagsNotifier extends StateNotifier<TagsState> {
  final ItemRepository _repository = ItemRepository();
  final Ref _ref;

  TagsNotifier(this._ref) : super(TagsState()) {
    _loadTags();
  }

  String? _getHouseholdId() {
    final householdState = _ref.read(householdProvider);
    return householdState.currentHousehold?.id;
  }

  Future<void> _loadTags() async {
    final householdId = _getHouseholdId();
    if (householdId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final tags = await _repository.getTags(householdId);
      state = state.copyWith(tags: tags, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载标签失败: ${e.toString()}',
      );
    }
  }

  Future<void> refresh() async {
    await _loadTags();
  }

  Future<void> createTag(ItemTag tag) async {
    try {
      final newTag = await _repository.createTag(tag);
      state = state.copyWith(tags: [...state.tags, newTag]);
    } catch (e) {
      state = state.copyWith(errorMessage: '创建标签失败: ${e.toString()}');
    }
  }

  Future<void> updateTag(ItemTag tag) async {
    try {
      final updated = await _repository.updateTag(tag);
      final index = state.tags.indexWhere((t) => t.id == tag.id);
      final newTags = [...state.tags];
      newTags[index] = updated;
      state = state.copyWith(tags: newTags);
    } catch (e) {
      state = state.copyWith(errorMessage: '更新标签失败: ${e.toString()}');
    }
  }

  Future<void> deleteTag(String tagId) async {
    try {
      await _repository.deleteTag(tagId);
      state = state.copyWith(
        tags: state.tags.where((t) => t.id != tagId).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: '删除标签失败: ${e.toString()}');
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final tagsProvider = StateNotifierProvider<TagsNotifier, TagsState>((ref) {
  return TagsNotifier(ref);
});
