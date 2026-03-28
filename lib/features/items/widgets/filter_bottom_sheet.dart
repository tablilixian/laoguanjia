import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/item_location.dart';
import '../../../data/models/item_tag.dart';
import '../../../data/models/item_type_config.dart';
import '../../../data/repositories/item_repository.dart';
import '../../household/providers/household_provider.dart';
import '../providers/offline_item_types_provider.dart';
import '../providers/locations_provider.dart';
import '../providers/tags_provider.dart';
import '../providers/paginated_items_provider.dart';

/// 筛选结果回调
class FilterResult {
  final String? itemType;
  final String? locationId;
  final String? tagId;

  const FilterResult({
    this.itemType,
    this.locationId,
    this.tagId,
  });

  bool get hasFilter => itemType != null || locationId != null || tagId != null;
}

/// 显示筛选底部面板
Future<void> showFilterBottomSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final paginatedState = ref.read(paginatedItemsProvider);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FilterBottomSheet(
      initialItemType: paginatedState.itemType,
      initialLocationId: paginatedState.locationId,
      initialTagId: paginatedState.tagId,
    ),
  );
}

class _FilterBottomSheet extends ConsumerStatefulWidget {
  final String? initialItemType;
  final String? initialLocationId;
  final String? initialTagId;

  const _FilterBottomSheet({
    this.initialItemType,
    this.initialLocationId,
    this.initialTagId,
  });

  @override
  ConsumerState<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  String? _selectedItemType;
  String? _selectedLocationId;
  String? _selectedTagId;
  int? _filteredCount;

  @override
  void initState() {
    super.initState();
    _selectedItemType = widget.initialItemType;
    _selectedLocationId = widget.initialLocationId;
    _selectedTagId = widget.initialTagId;
    _loadFilteredCount();
  }

  void _loadFilteredCount() async {
    final householdState = ref.read(householdProvider);
    final householdId = householdState.currentHousehold?.id;
    if (householdId == null) return;

    final repository = ItemRepository();
    final result = await repository.getItemsPaginated(
      householdId,
      limit: 1,
      offset: 0,
      itemType: _selectedItemType,
      locationId: _selectedLocationId,
    );

    if (mounted) {
      setState(() {
        _filteredCount = result.totalCount;
      });
    }
  }

  void _applyFilters() {
    final notifier = ref.read(paginatedItemsProvider.notifier);

    notifier.setItemTypeFilter(_selectedItemType);
    notifier.setLocationFilter(_selectedLocationId);
    notifier.setTagFilter(_selectedTagId);

    Navigator.pop(context);
  }

  void _clearFilters() {
    setState(() {
      _selectedItemType = null;
      _selectedLocationId = null;
      _selectedTagId = null;
    });
    _loadFilteredCount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typesAsync = ref.watch(itemTypesProvider);
    final locationsAsync = ref.watch(locationsProvider);
    final tagsAsync = ref.watch(tagsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示器
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '筛选条件',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('清除全部'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 筛选内容
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                // 类型筛选
                _FilterSection(
                  title: '📦 类型',
                  child: typesAsync.when(
                    loading: () => const _LoadingShimmer(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (types) => _FilterChipGroup(
                      items: types
                          .map((t) => _FilterItem(
                                id: t.typeKey,
                                label: '${t.icon} ${t.typeLabel}',
                                color: _parseColor(t.color),
                              ))
                          .toList(),
                      selectedId: _selectedItemType,
                      onSelected: (id) {
                        setState(() {
                          _selectedItemType = _selectedItemType == id ? null : id;
                        });
                        _loadFilteredCount();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 位置筛选
                _FilterSection(
                  title: '📍 位置',
                  child: locationsAsync.isLoading
                      ? const _LoadingShimmer()
                      : _FilterChipGroup(
                          items: locationsAsync.rootLocations
                              .map((l) => _FilterItem(
                                    id: l.id,
                                    label: '${l.icon ?? "📍"} ${l.name}',
                                    color: AppTheme.primaryGold,
                                  ))
                              .toList(),
                          selectedId: _selectedLocationId,
                          onSelected: (id) {
                            setState(() {
                              _selectedLocationId =
                                  _selectedLocationId == id ? null : id;
                            });
                            _loadFilteredCount();
                          },
                        ),
                ),
                const SizedBox(height: 16),
                // 标签筛选
                _FilterSection(
                  title: '🏷️ 标签',
                  child: tagsAsync.isLoading
                      ? const _LoadingShimmer()
                      : tagsAsync.tags.isEmpty
                          ? Text(
                              '暂无标签',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : _FilterChipGroup(
                              items: tagsAsync.tags
                                  .map((t) => _FilterItem(
                                        id: t.id,
                                        label: '${t.icon ?? "🏷️"} ${t.name}',
                                        color: _parseColor(t.color),
                                      ))
                                  .toList(),
                              selectedId: _selectedTagId,
                              onSelected: (id) {
                                setState(() {
                                  _selectedTagId = _selectedTagId == id ? null : id;
                                });
                                _loadFilteredCount();
                              },
                            ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 筛选结果数量
          if (_filteredCount != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '筛选结果: $_filteredCount 个物品',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          // 底部按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _clearFilters();
                        final notifier =
                            ref.read(paginatedItemsProvider.notifier);
                        notifier.resetFilters();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('清除筛选'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _applyFilters,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '应用筛选',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      final hex = colorStr.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppTheme.primaryGold;
    }
  }
}

/// 筛选区域组件
class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// 筛选项数据
class _FilterItem {
  final String id;
  final String label;
  final Color color;

  const _FilterItem({
    required this.id,
    required this.label,
    required this.color,
  });
}

/// 筛选芯片组
class _FilterChipGroup extends StatelessWidget {
  final List<_FilterItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const _FilterChipGroup({
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = selectedId == item.id;
        return FilterChip(
          selected: isSelected,
          label: Text(
            item.label,
            style: TextStyle(
              color: isSelected ? Colors.white : null,
              fontSize: 13,
            ),
          ),
          selectedColor: item.color,
          checkmarkColor: Colors.white,
          backgroundColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onSelected: (_) => onSelected(item.id),
        );
      }).toList(),
    );
  }
}

/// 加载中占位
class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: 80,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}
