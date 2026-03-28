import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item_tag.dart';
import '../../../data/repositories/item_repository.dart';
import '../../household/providers/household_provider.dart';

class TagsState {
  final List<ItemTag> tags;
  final bool isLoading;
  final String? errorMessage;
  /// 待恢复的已删除标签（创建同名标签时用于预填数据）
  final ItemTag? deletedTagForRestore;

  TagsState({
    this.tags = const [],
    this.isLoading = false,
    this.errorMessage,
    this.deletedTagForRestore,
  });

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
    ItemTag? deletedTagForRestore,
    bool clearDeletedTagForRestore = false,
  }) {
    return TagsState(
      tags: tags ?? this.tags,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      deletedTagForRestore: clearDeletedTagForRestore ? null : (deletedTagForRestore ?? this.deletedTagForRestore),
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
      state = state.copyWith(tags: tags, isLoading: false, clearDeletedTagForRestore: true);
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

  /// 检查是否可以创建标签
  /// 返回值：
  /// - null: 可以正常创建
  /// - deletedTag: 有同名已删除标签，可以恢复
  Future<ItemTag?> checkTagForCreate(String tagName) async {
    final householdId = _getHouseholdId();
    if (householdId == null) return null;

    // 先检查是否有同名未删除标签
    final existingTag = state.tags.firstWhere(
      (t) => t.name.toLowerCase() == tagName.toLowerCase(),
      orElse: () => ItemTag(
        id: '',
        householdId: '',
        name: '',
        category: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    if (existingTag.id.isNotEmpty) {
      // 有同名未删除标签，不能创建
      state = state.copyWith(errorMessage: '标签 "${tagName}" 已存在');
      return null;
    }

    // 检查是否有同名已删除标签
    final deletedTag = await _repository.findDeletedTagByName(householdId, tagName);
    if (deletedTag != null) {
      // 有同名已删除标签，可以恢复
      state = state.copyWith(deletedTagForRestore: deletedTag);
      return deletedTag;
    }

    return null;
  }

  /// 恢复已删除的标签（带更新后的数据）
  Future<void> restoreTag(ItemTag updatedTag) async {
    try {
      await _repository.restoreTag(updatedTag);
      // 重新加载标签列表
      await _loadTags();
      
      // 触发同步到云端
      final householdId = _getHouseholdId();
      if (householdId != null) {
        try {
          await _repository.autoSync(householdId);
        } catch (e) {
          print('🔴 [TagsNotifier] 自动同步失败: $e');
        }
      }
    } catch (e) {
      state = state.copyWith(errorMessage: '恢复标签失败: ${e.toString()}');
    }
  }

  /// 创建新标签（无同名已删除标签时调用）
  Future<void> createTag(ItemTag tag) async {
    try {
      final newTag = await _repository.createTag(tag);
      print('🔍 [TagsNotifier] createTag 返回: id=${newTag.id}, name=${newTag.name}, tagIndex=${newTag.tagIndex}');
      state = state.copyWith(tags: [...state.tags, newTag], clearDeletedTagForRestore: true);
      print('🔍 [TagsNotifier] state.tags 数量: ${state.tags.length}');
      
      // 触发同步到云端
      final householdId = _getHouseholdId();
      if (householdId != null) {
        try {
          await _repository.autoSync(householdId);
        } catch (e) {
          print('🔴 [TagsNotifier] 自动同步失败: $e');
        }
      }
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
      
      // 触发同步到云端
      final householdId = _getHouseholdId();
      if (householdId != null) {
        try {
          await _repository.autoSync(householdId);
        } catch (e) {
          print('🔴 [TagsNotifier] 自动同步失败: $e');
        }
      }
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
      
      // 触发同步到云端
      final householdId = _getHouseholdId();
      if (householdId != null) {
        try {
          await _repository.autoSync(householdId);
        } catch (e) {
          print('🔴 [TagsNotifier] 自动同步失败: $e');
        }
      }
    } catch (e) {
      state = state.copyWith(errorMessage: '删除标签失败: ${e.toString()}');
    }
  }

  /// 清除待恢复的已删除标签状态
  void clearDeletedTagForRestore() {
    state = state.copyWith(clearDeletedTagForRestore: true);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final tagsProvider = StateNotifierProvider<TagsNotifier, TagsState>((ref) {
  return TagsNotifier(ref);
});
