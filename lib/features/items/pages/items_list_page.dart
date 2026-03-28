import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/location_path_service.dart';
import '../../household/providers/household_provider.dart';
import '../providers/offline_item_types_provider.dart';
import '../providers/locations_provider.dart';
import '../providers/offline_item_stats_provider.dart';
import '../providers/offline_items_provider.dart';
import '../providers/paginated_items_provider.dart';
import '../../../data/models/household_item.dart';
import '../../../data/models/item_type_config.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/network_status_indicator.dart';
import '../widgets/sync_action_bar.dart';
import '../widgets/sync_status_badge.dart';
import '../widgets/offline_banner.dart';
import '../widgets/sync_refresh_indicator.dart';
import '../widgets/sync_error_snackbar.dart';
import '../widgets/infinite_scroll_list.dart';
import '../widgets/visibility_lazy_image.dart';
import '../widgets/filter_bottom_sheet.dart';

class ItemsListPage extends ConsumerStatefulWidget {
  const ItemsListPage({super.key});

  @override
  ConsumerState<ItemsListPage> createState() => _ItemsListPageState();
}

class _ItemsListPageState extends ConsumerState<ItemsListPage> {
  final _searchController = TextEditingController();
  bool _isMultiSelectMode = false;
  final Set<String> _selectedItemIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paginatedState = ref.watch(paginatedItemsProvider);
    final itemsState = ref.watch(offlineItemsProvider);
    final typesAsync = ref.watch(itemTypesProvider);
    final locationsState = ref.watch(locationsProvider);
    final householdState = ref.watch(householdProvider);
    final theme = Theme.of(context);

    print('🔵 [ItemsListPage] paginatedState: ${paginatedState.items.length} 个物品, isLoading=${paginatedState.isLoading}, hasMore=${paginatedState.hasMore}, totalCount=${paginatedState.totalCount}');
    print('🔵 [ItemsListPage] householdId: ${householdState.currentHousehold?.id}');

    ref.listen<ItemsState>(
      offlineItemsProvider,
      (previous, next) {
        if (previous?.syncState != SyncState.error &&
            next.syncState == SyncState.error &&
            next.syncMessage != null) {
          SyncErrorSnackBar.show(
            context,
            message: next.syncMessage!,
            onRetry: () {
              ref.read(offlineItemsProvider.notifier).sync();
            },
          );
        }
      },
    );

    if (householdState.currentHousehold == null) {
      return Scaffold(body: _buildNoHousehold(context, theme));
    }

    final items = paginatedState.items;

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo is ScrollUpdateNotification || scrollInfo is ScrollEndNotification) {
          final metrics = scrollInfo.metrics;
          final threshold = metrics.maxScrollExtent * 0.5;
          
          print('🔵 [ItemsListPage] 外层滚动事件: pixels=${metrics.pixels}, maxScrollExtent=${metrics.maxScrollExtent}, threshold=$threshold');
          print('🔵 [ItemsListPage] hasMore=${paginatedState.hasMore}, isLoading=${paginatedState.isLoading}, isLoadingMore=${paginatedState.isLoadingMore}');
          
          if (metrics.pixels >= threshold) {
            if (paginatedState.hasMore && !paginatedState.isLoading && !paginatedState.isLoadingMore) {
              print('🔵 [ItemsListPage] 外层触发加载更多');
              ref.read(paginatedItemsProvider.notifier).loadMore();
            }
          }
        }
        return false;
      },
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            print('🔄 [ItemsListPage] 用户触发下拉刷新');
            ref.invalidate(itemOverviewProvider);
            await ref.read(paginatedItemsProvider.notifier).refresh();
            await ref.read(offlineItemsProvider.notifier).sync();
            print('🔄 [ItemsListPage] 下拉刷新完成');
          },
          child: CustomScrollView(
            slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              title: Text(
                '家庭物品',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: false,
              elevation: 0,
              backgroundColor: theme.colorScheme.surface,
              actions: [
                SyncStatusIndicator(
                  syncState: itemsState.syncState,
                  syncMessage: itemsState.syncMessage,
                ),
                const SizedBox(width: 8),
                NetworkStatusIndicator(
                  isOnline: itemsState.isOnline,
                ),
                const SizedBox(width: 8),
                if (_isMultiSelectMode) ...[
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedItemIds.length == items.length) {
                          _selectedItemIds.clear();
                        } else {
                          _selectedItemIds.addAll(
                            items.map((i) => i.id),
                          );
                        }
                      });
                    },
                    child: Text(
                      _selectedItemIds.length == items.length
                          ? '取消全选'
                          : '全选',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _isMultiSelectMode = false;
                        _selectedItemIds.clear();
                      });
                    },
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.checklist),
                    tooltip: '多选',
                    onPressed: () {
                      setState(() {
                        _isMultiSelectMode = true;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      paginatedState.hasActiveFilter
                          ? Icons.filter_list
                          : Icons.filter_list_outlined,
                      color: paginatedState.hasActiveFilter
                          ? AppTheme.primaryGold
                          : null,
                    ),
                    onPressed: () {
                      showFilterBottomSheet(context, ref);
                    },
                  ),
                ],
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'locations':
                        context.push('/home/items/locations');
                        break;
                      case 'tags':
                        context.push('/home/items/tags');
                        break;
                      case 'types':
                        context.push('/home/items/types');
                        break;
                      case 'batch':
                        context.push('/home/items/batch-add');
                        break;
                      case 'ai':
                        context.push('/home/items/ai');
                        break;
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem(
                      value: 'locations',
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined),
                          SizedBox(width: 12),
                          Text('位置管理'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'tags',
                      child: Row(
                        children: [
                          Icon(Icons.label_outline),
                          SizedBox(width: 12),
                          Text('标签管理'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'types',
                      child: Row(
                        children: [
                          Icon(Icons.category_outlined),
                          SizedBox(width: 12),
                          Text('类型管理'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'batch',
                      child: Row(
                        children: [
                          Icon(Icons.playlist_add, color: AppTheme.primaryGold),
                          SizedBox(width: 12),
                          Text(
                            '批量录入',
                            style: TextStyle(color: AppTheme.primaryGold),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'ai',
                      child: Row(
                        children: [
                          Icon(Icons.smart_toy, color: AppTheme.primaryGold),
                          SizedBox(width: 12),
                          Text(
                            'AI 物品助手',
                            style: TextStyle(color: AppTheme.primaryGold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: _buildSearchBar(context, theme, itemsState),
              ),
            ),
            // 离线状态横幅
            if (!itemsState.isOnline)
              SliverToBoxAdapter(
                child: OfflineBanner(
                  onClose: () {
                    ref.read(offlineItemsProvider.notifier).clearSyncMessage();
                  },
                ),
              ),
            // 物品概览统计摘要
            SliverToBoxAdapter(child: _buildStatsOverview(context, theme)),
            // 已激活的筛选条件
            if (paginatedState.hasActiveFilter)
              SliverToBoxAdapter(
                child: _buildActiveFilterBar(theme, paginatedState, typesAsync),
              ),
            paginatedState.isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : items.isEmpty
                ? SliverFillRemaining(child: _buildEmptyState(context, theme))
                : SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: InfiniteScrollSliverList(
                      children: items.map((item) {
                        final isSelected = _selectedItemIds.contains(item.id);

                        // Get type config for this item
                        final typeConfig = typesAsync.whenOrNull(
                          data: (types) {
                            try {
                              return types.firstWhere(
                                (t) => t.typeKey == item.itemType,
                              );
                            } catch (_) {
                              return null;
                            }
                          },
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _isMultiSelectMode
                              ? _MultiSelectItemCard(
                                  item: item,
                                  isSelected: isSelected,
                                  typeConfig: typeConfig,
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedItemIds.remove(item.id);
                                      } else {
                                        _selectedItemIds.add(item.id);
                                      }
                                    });
                                  },
                                )
                              : _ItemCard(
                                      item: item,
                                      onTap: () => context.push(
                                        '/home/items/${item.id}',
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(
                                      delay: Duration(milliseconds: items.indexOf(item) * 30),
                                    )
                                    .slideX(begin: 0.05, end: 0),
                        );
                      }).toList(),
                      hasMore: paginatedState.hasMore,
                      isLoading: paginatedState.isLoading,
                      isLoadingMore: paginatedState.isLoadingMore,
                      onLoadMore: () {
                        ref.read(paginatedItemsProvider.notifier).loadMore();
                      },
                      onRefresh: () async {
                        await ref.read(paginatedItemsProvider.notifier).refresh();
                      },
                    ),
                  ),
          ],
        ),
      ),
      bottomNavigationBar: _isMultiSelectMode && _selectedItemIds.isNotEmpty
          ? _buildBatchActionBar(context)
          : const SyncActionBar(),
      floatingActionButton: _isMultiSelectMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // AI 助手小按钮
                // FloatingActionButton.small(
                //   heroTag: 'ai_assistant',
                //   onPressed: () => context.push('/home/items/ai'),
                //   backgroundColor: Colors.white,
                //   child: const Icon(
                //     Icons.smart_toy,
                //     color: AppTheme.primaryGold,
                //   ),
                // ),
                const SizedBox(height: 12),
                // 主添加按钮
                FloatingActionButton.extended(
                      heroTag: 'add_item',
                      onPressed: () => context.push('/home/items/create'),
                      backgroundColor: AppTheme.primaryGold,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(
                        '添加物品',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.02, 1.02),
                      duration: 2000.ms,
                    ),
              ],
            ),
      ),
    );
  }

  Widget _buildBatchActionBar(BuildContext context) {
    final householdState = ref.watch(householdProvider);
    final members = householdState.members;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Text(
                '已选择 ${_selectedItemIds.length} 个物品',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: members.isEmpty
                  ? null
                  : () => _showBatchOwnerDialog(context, members),
              icon: const Icon(Icons.person, size: 18),
              label: const Text('设置归属人'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBatchOwnerDialog(BuildContext context, List members) {
    String? selectedOwnerId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量设置归属人'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('选择归属人：'),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  children: [
                    RadioListTile<String?>(
                      title: const Text('不设置归属人'),
                      value: null,
                      groupValue: selectedOwnerId,
                      onChanged: (value) {
                        setDialogState(() => selectedOwnerId = value);
                      },
                    ),
                    ...members.map(
                      (member) => RadioListTile<String?>(
                        title: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppTheme.primaryGold.withOpacity(
                                0.2,
                              ),
                              child: Text(
                                member.name[0],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primaryGold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(member.name),
                          ],
                        ),
                        value: member.id,
                        groupValue: selectedOwnerId,
                        onChanged: (value) {
                          setDialogState(() => selectedOwnerId = value);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _batchUpdateOwner(selectedOwnerId);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Future<void> _batchUpdateOwner(String? ownerId) async {
    if (_selectedItemIds.isEmpty) return;

    try {
      for (final itemId in _selectedItemIds) {
        await ref.read(offlineItemsProvider.notifier).updateItemOwner(itemId, ownerId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已更新 ${_selectedItemIds.length} 个物品的归属人')),
        );
        setState(() {
          _isMultiSelectMode = false;
          _selectedItemIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  Widget _buildStatsOverview(BuildContext context, ThemeData theme) {
    final overviewAsync = ref.watch(itemOverviewProvider);

    return overviewAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (overview) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              _StatCardsRow(overview: overview, theme: theme),
              const SizedBox(height: 12),
              if (overview.byType.isNotEmpty) ...[
                _buildTypePreview(overview.byType, overview.typeMap, theme),
              ],
              TextButton.icon(
                onPressed: () => context.push('/home/items/stats'),
                icon: const Icon(Icons.bar_chart, size: 18),
                label: const Text('查看详细统计'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _StatCardsRow({
    required ItemOverview overview,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.inventory_2_outlined,
            label: '物品总数',
            value: overview.total.toString(),
            color: AppTheme.primaryGold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.add_circle_outline,
            label: '本月新增',
            value: overview.newThisMonth.toString(),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.warning_amber_outlined,
            label: '需关注',
            value: overview.attentionNeeded.toString(),
            color: overview.attentionNeeded > 0
                ? Colors.orange
                : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTypePreview(
    List<Map<String, dynamic>> byType,
    Map<String, dynamic> typeMap,
    ThemeData theme,
  ) {
    // 只显示前4个类型
    final topTypes = byType.take(4).toList();
    final maxCount = topTypes.isNotEmpty ? (topTypes.first['count'] as int) : 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '类型分布',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...topTypes.map((type) {
            final typeKey = type['type_key'] as String;
            final count = type['count'] as int;
            final config = typeMap[typeKey];
            final label = config?.typeLabel ?? typeKey;
            final icon = config?.icon ?? '📦';
            final percentage = maxCount > 0 ? count / maxCount : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final showProgress = availableWidth > 120;

                  return Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$count',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (showProgress) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 50,
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(
                              _parseColor(config?.color ?? '#6B7280'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryGold;
    }
  }

  Widget _buildSearchBar(
    BuildContext context,
    ThemeData theme,
    ItemsState state,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索物品名称、品牌、型号...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(paginatedItemsProvider.notifier).setSearchQuery('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (value) {
          ref.read(paginatedItemsProvider.notifier).setSearchQuery(value);
        },
      ),
    );
  }

  Widget _buildActiveFilterBar(
    ThemeData theme,
    PaginatedItemsState state,
    AsyncValue typesAsync,
  ) {
    final types = typesAsync.whenOrNull(data: (data) => data as List<ItemTypeConfig>) ?? <ItemTypeConfig>[];
    final typeConfig = state.itemType != null
        ? types.cast<ItemTypeConfig?>().firstWhere(
              (t) => t?.typeKey == state.itemType,
              orElse: () => null,
            )
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 16, color: AppTheme.primaryGold),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (state.itemType != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          '${typeConfig?.icon ?? "📦"} ${typeConfig?.typeLabel ?? state.itemType}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onDeleted: () {
                          ref
                              .read(paginatedItemsProvider.notifier)
                              .setItemTypeFilter(null);
                        },
                        backgroundColor: AppTheme.primaryGold.withOpacity(0.1),
                        deleteIconColor: AppTheme.primaryGold,
                      ),
                    ),
                  if (state.locationId != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: const Text(
                          '📍 已选位置',
                          style: TextStyle(fontSize: 12),
                        ),
                        onDeleted: () {
                          ref
                              .read(paginatedItemsProvider.notifier)
                              .setLocationFilter(null);
                        },
                        backgroundColor: AppTheme.primaryGold.withOpacity(0.1),
                        deleteIconColor: AppTheme.primaryGold,
                      ),
                    ),
                  if (state.tagId != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: const Text(
                          '🏷️ 已选标签',
                          style: TextStyle(fontSize: 12),
                        ),
                        onDeleted: () {
                          ref
                              .read(paginatedItemsProvider.notifier)
                              .setTagFilter(null);
                        },
                        backgroundColor: AppTheme.primaryGold.withOpacity(0.1),
                        deleteIconColor: AppTheme.primaryGold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(paginatedItemsProvider.notifier).resetFilters();
            },
            child: const Text('清除全部'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoHousehold(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home_outlined,
                size: 64,
                color: AppTheme.primaryGold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '请先加入或创建家庭',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '加入家庭后即可使用物品管理功能',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/join-household'),
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('创建/加入家庭'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    final locationsState = ref.watch(locationsProvider);
    final hasNoLocations = locationsState.locations.isEmpty;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.5,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasNoLocations
                      ? Icons.location_off_outlined
                      : Icons.inventory_2_outlined,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                ref.read(paginatedItemsProvider).itemType != null
                    ? '该分类下暂无物品'
                    : (hasNoLocations ? '还没有创建位置' : '暂无物品'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (hasNoLocations) ...[
                Text(
                  '先创建位置，再添加物品',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/home/items/locations/init'),
                  icon: const Icon(Icons.add_home_outlined),
                  label: const Text('创建位置'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  '点击右下角按钮添加第一个物品',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiSelectItemCard extends StatelessWidget {
  final HouseholdItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final ItemTypeConfig? typeConfig;

  const _MultiSelectItemCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.typeConfig,
  });

  Color _parseColor(String colorStr) {
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryGold.withOpacity(0.1)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryGold
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                activeColor: AppTheme.primaryGold,
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _parseColor(
                    typeConfig?.color ?? '#6B7280',
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    typeConfig?.icon ?? '📦',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.brand != null || item.model != null)
                      Text(
                        [item.brand, item.model].whereType<String>().join(' '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Text(
                'x${item.quantity}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final HouseholdItem item;
  final VoidCallback onTap;

  const _ItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  _buildThumbnail(theme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.quantity > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'x${item.quantity}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (item.brand != null) ...[
                              Icon(
                                Icons.business,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item.brand!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // ==================== 位置显示逻辑 ====================
                            // 位置显示优先级：
                            // 1. locationPath - 完整路径（如 "卧室-柜子"，需要格式化为 "卧室 → 柜子"）
                            // 2. locationName - 位置名称（如 "柜子"）
                            //
                            // locationPath 的数据来源：
                            // - ItemLocation.path 字段（从远程数据库同步）
                            // - 格式：用 "-" 分隔的层级路径（如 "卧室-柜子-第三个格子"）
                            // - 显示时通过 LocationPathService.formatArrow() 转换为 " → " 分隔
                            // ====================
                            if (item.locationPath != null || item.locationName != null) ...[
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  // 如果有完整路径，格式化后显示；否则显示位置名称
                                  item.locationPath != null
                                      ? LocationPathService.formatArrow(item.locationPath!)
                                      : item.locationName!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (item.description != null &&
                            item.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(
                                0.7,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // 标签显示
                        if (item.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _buildTags(theme),
                        ],
                        // 保修到期提醒
                        if (item.warrantyExpiry != null) ...[
                          const SizedBox(height: 4),
                          _buildWarrantyWarning(theme),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: SyncStatusBadge(
                  syncStatus: item.syncStatus,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: item.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: VisibilityLazyImage(
                imageUrl: item.imageUrl!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                memCacheWidth: 112,
                memCacheHeight: 112,
              ),
            )
          : _buildPlaceholder(theme),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Text(
        item.itemType == 'other' ? '📦' : _getTypeEmoji(item.itemType),
        style: const TextStyle(fontSize: 24),
      ),
    );
  }

  Widget _buildTags(ThemeData theme) {
    // 最多显示 2 个标签
    final displayTags = item.tags.take(2).toList();
    final remainingCount = item.tags.length - displayTags.length;

    return Row(
      children: [
        ...displayTags.map((tag) {
          final color = _parseColor(tag.color);
          return Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              '${tag.icon ?? "🏷️"} ${tag.name}',
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+$remainingCount',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWarrantyWarning(ThemeData theme) {
    final now = DateTime.now();
    final expiry = item.warrantyExpiry!;
    final daysUntilExpiry = expiry.difference(now).inDays;

    Color warningColor;
    IconData warningIcon;
    String warningText;

    if (daysUntilExpiry < 0) {
      // 已过期
      warningColor = Colors.red;
      warningIcon = Icons.warning_amber_rounded;
      warningText = '保修已过期 ${-daysUntilExpiry} 天';
    } else if (daysUntilExpiry <= 30) {
      // 30天内到期
      warningColor = Colors.orange;
      warningIcon = Icons.schedule;
      warningText = '保修即将到期：$daysUntilExpiry 天后';
    } else {
      // 正常
      warningColor = Colors.green;
      warningIcon = Icons.verified_user_outlined;
      final months = (daysUntilExpiry / 30).floor();
      warningText = '保修剩余 $months 个月';
    }

    return Row(
      children: [
        Icon(
          warningIcon,
          size: 12,
          color: warningColor,
        ),
        const SizedBox(width: 4),
        Text(
          warningText,
          style: TextStyle(
            fontSize: 10,
            color: warningColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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

  String _getTypeEmoji(String type) {
    const emojiMap = {
      'clothing': '👕',
      'appliance': '🔌',
      'furniture': '🛋️',
      'daily': '🧴',
      'tableware': '🍽️',
      'food': '🥫',
      'bedding': '🛏️',
      'electronics': '📱',
      'book': '📚',
      'decoration': '🖼️',
      'tool': '🔧',
      'medicine': '💊',
      'sports': '⚽',
      'toy': '🎮',
      'jewelry': '💍',
      'pet': '🐕',
      'garden': '🌱',
      'automotive': '🚗',
      'stationery': '📎',
      'consumables': '🧻',
    };
    return emojiMap[type] ?? '📦';
  }
}
