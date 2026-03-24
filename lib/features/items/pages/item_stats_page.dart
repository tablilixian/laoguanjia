import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../household/providers/household_provider.dart';
import '../providers/offline_item_stats_provider.dart';
import '../providers/item_types_provider.dart';

class ItemStatsPage extends ConsumerStatefulWidget {
  const ItemStatsPage({super.key});

  @override
  ConsumerState<ItemStatsPage> createState() => _ItemStatsPageState();
}

class _ItemStatsPageState extends ConsumerState<ItemStatsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final householdState = ref.watch(householdProvider);

    if (householdState.currentHousehold == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('物品统计')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('请先加入或创建家庭'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/join-household'),
                child: const Text('创建/加入家庭'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('物品统计'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '📊 概览'),
            Tab(text: '📦 按类型'),
            Tab(text: '📍 按位置'),
            Tab(text: '👤 按成员'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _ByTypeTab(),
          _ByLocationTab(),
          _ByOwnerTab(),
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(itemOverviewProvider);
    final typesAsync = ref.watch(itemTypesProvider);

    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (overview) {
        final typeMap =
            typesAsync.whenOrNull(
              data: (types) => {for (var t in types) t.typeKey: t},
            ) ??
            {};

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(itemOverviewProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 统计卡片行
              Row(
                children: [
                  _StatCard(
                    icon: Icons.inventory_2_outlined,
                    label: '物品总数',
                    value: overview.total.toString(),
                    color: AppTheme.primaryGold,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.add_circle_outline,
                    label: '本月新增',
                    value: overview.newThisMonth.toString(),
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.warning_amber_outlined,
                    label: '需关注',
                    value: overview.attentionNeeded.toString(),
                    color: overview.attentionNeeded > 0
                        ? Colors.orange
                        : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 类型分布
              Text(
                '类型分布',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...overview.byType.map((type) {
                final typeKey = type['type_key'] as String;
                final count = type['count'] as int;
                final config = typeMap[typeKey];
                final label = config?.typeLabel ?? typeKey;
                final icon = config?.icon ?? '📦';
                final percentage = overview.total > 0
                    ? count / overview.total
                    : 0.0;

                return _StatListTile(
                  icon: icon,
                  label: label,
                  count: count,
                  percentage: percentage,
                  color: _parseColor(config?.color ?? '#6B7280'),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _ByTypeTab extends ConsumerWidget {
  const _ByTypeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(itemStatsByTypeProvider);
    final typesAsync = ref.watch(itemTypesProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (stats) {
        if (stats.isEmpty) {
          return const Center(child: Text('暂无数据'));
        }

        final total = stats.fold<int>(0, (sum, s) => sum + (s['count'] as int));
        final typeMap =
            typesAsync.whenOrNull(
              data: (types) => {for (var t in types) t.typeKey: t},
            ) ??
            {};

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final type = stats[index];
            final typeKey = type['type_key'] as String;
            final count = type['count'] as int;
            final config = typeMap[typeKey];
            final label = config?.typeLabel ?? typeKey;
            final icon = config?.icon ?? '📦';
            final percentage = total > 0 ? count / total : 0.0;

            return _StatListTile(
              icon: icon,
              label: label,
              count: count,
              percentage: percentage,
              color: _parseColor(config?.color ?? '#6B7280'),
            );
          },
        );
      },
    );
  }
}

class _ByLocationTab extends ConsumerWidget {
  const _ByLocationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(itemStatsByLocationProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (stats) {
        if (stats.isEmpty) {
          return const Center(child: Text('暂无数据'));
        }

        final total = stats.fold<int>(0, (sum, s) => sum + (s['count'] as int));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final location = stats[index];
            final name = location['name'] as String? ?? '未知';
            final icon = location['icon'] as String? ?? '📍';
            final count = location['count'] as int;
            final percentage = total > 0 ? count / total : 0.0;

            return _StatListTile(
              icon: icon,
              label: name,
              count: count,
              percentage: percentage,
              color: AppTheme.primaryGold,
            );
          },
        );
      },
    );
  }
}

class _ByOwnerTab extends ConsumerWidget {
  const _ByOwnerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(itemStatsByOwnerProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (stats) {
        if (stats.isEmpty) {
          return const Center(child: Text('暂无数据'));
        }

        final total = stats.fold<int>(0, (sum, s) => sum + (s['count'] as int));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final owner = stats[index];
            final name = owner['name'] as String? ?? '未知';
            final avatarUrl = owner['avatar_url'] as String?;
            final count = owner['count'] as int;
            final percentage = total > 0 ? count / total : 0.0;

            return _OwnerStatListTile(
              name: name,
              avatarUrl: avatarUrl,
              count: count,
              percentage: percentage,
            );
          },
        );
      },
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatListTile extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final double percentage;
  final Color color;

  const _StatListTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                count.toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerStatListTile extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int count;
  final double percentage;

  const _OwnerStatListTile({
    required this.name,
    this.avatarUrl,
    required this.count,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(AppTheme.primaryGold),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                count.toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _parseColor(String colorStr) {
  try {
    return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
  } catch (_) {
    return AppTheme.primaryGold;
  }
}
