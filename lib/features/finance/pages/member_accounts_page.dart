import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/finance_providers.dart';

class MemberAccountsPage extends ConsumerWidget {
  final String memberId;

  const MemberAccountsPage({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final member = ref.watch(memberListProvider).where((m) => m.id == memberId).firstOrNull;
    final accountsAsync = ref.watch(memberAccountsProvider(memberId));

    if (member == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('成员账户')),
        body: const Center(child: Text('成员不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${member.name}的账户')),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('${member.name}还没有账户',
                      style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: accounts.map((account) {
              return _MemberAccountCard(
                accountId: account.id,
                accountName: account.name,
                accountType: account.type.label,
                onTap: () => context.push(
                  '/home/finance/account/${account.id}',
                ),
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}

class _MemberAccountCard extends ConsumerWidget {
  final String accountId;
  final String accountName;
  final String accountType;
  final VoidCallback onTap;

  const _MemberAccountCard({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final latestAsync = ref.watch(latestSnapshotProvider(accountId));
    final fmt = NumberFormat('#,###');

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
                radius: 22,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.credit_card,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(accountName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(accountType,
                        style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                  ],
                ),
              ),
              latestAsync.when(
                data: (snapshot) {
                  if (snapshot == null) return const Text('暂无数据');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${fmt.format(snapshot.netWorth)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        '净资产',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Text('—'),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
