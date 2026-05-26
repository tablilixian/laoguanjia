import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/finance/finance_storage.dart';
import '../../../data/finance/models/finance_snapshot.dart';
import '../../../data/finance/models/finance_account.dart';
import '../../household/providers/household_provider.dart';
import '../providers/finance_providers.dart';

class AccountDetailPage extends ConsumerWidget {
  final String accountId;

  const AccountDetailPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(financeAccountsProvider);
    final snapshotsAsync = ref.watch(accountSnapshotsProvider(accountId));
    final fmt = NumberFormat('#,###');

    return accountsAsync.when(
      data: (accounts) {
        final account = accounts.where((a) => a.id == accountId).firstOrNull;
        if (account == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('账户详情')),
            body: const Center(child: Text('账户不存在')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(account.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => context.push(
                  '/home/finance/snapshot/add',
                  extra: {'accountId': accountId},
                ),
                tooltip: '录快照',
              ),
            ],
          ),
          body: snapshotsAsync.when(
            data: (snapshots) {
              final latest = snapshots.isNotEmpty ? snapshots.first : null;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 当前余额
                  if (latest != null)
                    _BalanceCard(
                      account: account,
                      snapshot: latest,
                      fmt: fmt,
                      theme: theme,
                    )
                  else
                    _EmptyBalanceCard(theme: theme),

                  const SizedBox(height: 16),

                  // 快照历史
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '快照记录',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push(
                          '/home/finance/snapshot/add',
                          extra: {'accountId': accountId},
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('录新快照'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (snapshots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.history,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text(
                            '暂无快照记录',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...snapshots.map((snapshot) {
                      final previousIndex =
                          snapshots.indexOf(snapshot) + 1;
                      final previous = previousIndex < snapshots.length
                          ? snapshots[previousIndex]
                          : null;
                      final delta = previous != null
                          ? snapshot.netWorth - previous.netWorth
                          : 0.0;

                      return _SnapshotTile(
                        snapshot: snapshot,
                        delta: delta,
                        fmt: fmt,
                        theme: theme,
                        onDelete: () =>
                            _confirmDeleteSnapshot(context, ref, snapshot),
                      );
                    }),
                  const SizedBox(height: 80),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('加载失败: $e')),
      ),
    );
  }

  void _confirmDeleteSnapshot(
    BuildContext context,
    WidgetRef ref,
    FinanceSnapshot snapshot,
  ) {
    final dateStr = DateFormat('M月d日').format(snapshot.recordDate);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除快照'),
        content: Text('确定要删除 $dateStr 的快照记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final householdId = ref
                  .read(householdProvider)
                  .currentHousehold
                  ?.id;
              if (householdId == null) return;
              await FinanceStorage.instance
                  .deleteSnapshot(householdId, snapshot.id);
              ref.invalidate(financeDataProvider);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final FinanceAccount account;
  final FinanceSnapshot snapshot;
  final NumberFormat fmt;
  final ThemeData theme;

  const _BalanceCard({
    required this.account,
    required this.snapshot,
    required this.fmt,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.05),
              theme.colorScheme.primary.withValues(alpha: 0.01),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(account.type.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '¥${fmt.format(snapshot.assetAmount)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '资产',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (snapshot.liabilityAmount > 0) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '¥${fmt.format(snapshot.liabilityAmount)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '负债',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '净资产 ¥${fmt.format(snapshot.netWorth)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '更新于 ${DateFormat('M月d日 HH:mm').format(snapshot.recordDate)}',
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

class _EmptyBalanceCard extends StatelessWidget {
  final ThemeData theme;

  const _EmptyBalanceCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('暂无快照', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('点击右上角 + 录入第一条快照',
                style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
          ],
        ),
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final FinanceSnapshot snapshot;
  final double delta;
  final NumberFormat fmt;
  final ThemeData theme;
  final VoidCallback onDelete;

  const _SnapshotTile({
    required this.snapshot,
    required this.delta,
    required this.fmt,
    required this.theme,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('M月d日 HH:mm').format(snapshot.recordDate);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '资 ¥${fmt.format(snapshot.assetAmount)}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      if (snapshot.liabilityAmount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '负 ¥${fmt.format(snapshot.liabilityAmount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 净资产变化
            if (delta != 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: delta > 0
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${delta > 0 ? '+' : ''}¥${fmt.format(delta)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: delta > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (snapshot.activeIncome > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '收入 ¥${fmt.format(snapshot.activeIncome)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
