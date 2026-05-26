import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/models/member.dart';
import '../providers/finance_providers.dart';

class FinanceHomePage extends ConsumerWidget {
  const FinanceHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final totalNetWorthAsync = ref.watch(totalNetWorthProvider);
    final currentMetricsAsync = ref.watch(currentMonthMetricsProvider);
    final accountsAsync = ref.watch(financeAccountsProvider);
    final membersAsync = ref.watch(memberListProvider);

    final now = DateTime.now();
    final monthLabel = DateFormat('yyyy年M月').format(now);
    return Scaffold(
      appBar: AppBar(
        title: const Text('财务概览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(financeDataProvider);
            },
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/home/finance/snapshot/add'),
            tooltip: '录快照',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financeDataProvider);
          await ref.read(financeDataProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 总净资产
            totalNetWorthAsync.when(
              data: (netWorth) => _NetWorthCard(netWorth: netWorth),
              loading: () => const Card(
                child: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => const Card(
                child: SizedBox(
                  height: 100,
                  child: Center(child: Text('暂无数据')),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 月度概览
            Text(
              monthLabel,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            currentMetricsAsync.when(
              data: (metrics) => metrics != null
                  ? _MonthOverviewCard(
                      metrics: metrics,
                      accounts: accountsAsync.asData?.value ?? [],
                    )
                  : _EmptyFinanceHint(),
              loading: () => const Card(
                child: SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => _EmptyFinanceHint(),
            ),
            const SizedBox(height: 24),

            // 按成员分组
            Text(
              '成员资产',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            () {
              final members = membersAsync;
              if (members.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('暂无家庭成员'),
                  ),
                );
              }
              return Column(
                children: members.map((member) {
                  return _MemberSection(
                    member: member,
                    onTap: () => context.push(
                      '/home/finance/member/${member.id}',
                    ),
                  );
                }).toList(),
              );
            }(),
            const SizedBox(height: 24),

            // 快捷操作
            Text(
              '管理',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _QuickActionButton(
              icon: Icons.manage_accounts,
              label: '管理账户',
              onTap: () => context.push('/home/finance/accounts'),
            ),
            const SizedBox(height: 8),
            _QuickActionButton(
              icon: Icons.add,
              label: '录快照',
              onTap: () => context.push('/home/finance/snapshot/add'),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  final double netWorth;
  const _NetWorthCard({required this.netWorth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.colorScheme.primary.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '家庭净资产',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '¥${fmt.format(netWorth)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthOverviewCard extends StatelessWidget {
  final dynamic metrics;
  final List accounts;

  const _MonthOverviewCard({
    required this.metrics,
    required this.accounts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatRow(
              label: '收入',
              amount: metrics.totalIncome,
              color: Colors.green,
              prefix: '',
            ),
            const Divider(height: 20),
            _StatRow(
              label: '支出',
              amount: metrics.totalExpense,
              color: Colors.red,
              prefix: '',
            ),
            const Divider(height: 20),
            _StatRow(
              label: '净资产变化',
              amount: metrics.netWorthChange,
              color: metrics.netWorthChange >= 0
                  ? Colors.green
                  : Colors.red,
              prefix: metrics.netWorthChange >= 0 ? '+' : '',
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    '被动收入覆盖率',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    metrics.coverageRatioPercent,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '储蓄率 ${metrics.savingsRatePercent}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String prefix;

  const _StatRow({
    required this.label,
    required this.amount,
    required this.color,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(
          '$prefix¥${fmt.format(amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _EmptyFinanceHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              '还没有财务数据',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '先为家庭成员添加账户，再录入快照\n系统会自动分析你的收支情况',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/home/finance/accounts'),
              icon: const Icon(Icons.add),
              label: const Text('添加账户'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberSection extends ConsumerWidget {
  final Member member;
  final VoidCallback onTap;

  const _MemberSection({
    required this.member,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(memberAccountsProvider(member.id));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  member.name.isNotEmpty ? member.name[0] : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    accountsAsync.when(
                      data: (accts) => Text(
                        '${accts.length} 个账户',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(label),
        trailing: Icon(Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
