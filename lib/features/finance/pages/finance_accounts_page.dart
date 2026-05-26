import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../data/finance/models/finance_account.dart';
import '../../../data/finance/finance_storage.dart';
import '../../household/providers/household_provider.dart';
import '../providers/finance_providers.dart';

class FinanceAccountsPage extends ConsumerStatefulWidget {
  const FinanceAccountsPage({super.key});

  @override
  ConsumerState<FinanceAccountsPage> createState() =>
      _FinanceAccountsPageState();
}

class _FinanceAccountsPageState extends ConsumerState<FinanceAccountsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(financeAccountsProvider);
    final members = ref.watch(memberListProvider);

    final memberMap = {for (final m in members) m.id: m};

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAccountDialog(context, members),
          ),
        ],
      ),
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
                  Text('还没有账户', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '点击右上角 + 添加银行卡、支付宝等账户',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        _showAddAccountDialog(context, members),
                    icon: const Icon(Icons.add),
                    label: const Text('添加账户'),
                  ),
                ],
              ),
            );
          }

          // 按成员分组
          final grouped = <String, List<FinanceAccount>>{};
          for (final account in accounts) {
            grouped.putIfAbsent(account.memberId, () => []).add(account);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              final memberName =
                  memberMap[entry.key]?.name ?? '未知成员';
              final memberAccounts = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 4, bottom: 8, top: 8),
                    child: Text(
                      memberName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  ...memberAccounts.map((account) =>
                      _AccountListTile(
                        account: account,
                        onTap: () => context.push(
                          '/home/finance/account/${account.id}',
                        ),
                        onDelete: () =>
                            _confirmDeleteAccount(context, account),
                      )),
                ],
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  void _showAddAccountDialog(
    BuildContext context,
    List members,
  ) {
    String selectedMemberId = members.isNotEmpty ? members.first.id : '';
    String name = '';
    AccountType type = AccountType.debitCard;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加账户'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedMemberId.isNotEmpty &&
                          members.any((m) => m.id == selectedMemberId)
                      ? selectedMemberId
                      : null,
                  decoration: const InputDecoration(
                    labelText: '成员',
                    border: OutlineInputBorder(),
                  ),
                  items: members.map((m) {
                    return DropdownMenuItem<String>(
                      value: m.id,
                      child: Text(m.name),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedMemberId = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: '账户名称',
                    hintText: '如: 招行工资卡',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountType>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: '账户类型',
                    border: OutlineInputBorder(),
                  ),
                  items: AccountType.values.map((t) {
                    return DropdownMenuItem<AccountType>(
                      value: t,
                      child: Text(t.label),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => type = v);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.trim().isEmpty || selectedMemberId.isEmpty) return;
                if (selectedMemberId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请选择成员')),
                  );
                  return;
                }
                final householdId = ref.read(householdProvider).currentHousehold?.id;
                if (householdId == null) return;

                final account = FinanceAccount(
                  id: const Uuid().v4(),
                  memberId: selectedMemberId,
                  name: name.trim(),
                  type: type,
                  sortOrder: DateTime.now().millisecondsSinceEpoch,
                );

                await FinanceStorage.instance.addAccount(
                    householdId, account);
                ref.invalidate(financeDataProvider);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(
    BuildContext context,
    FinanceAccount account,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定要删除「${account.name}」吗？该账户的所有快照也将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
                  .deleteAccount(householdId, account.id);
              ref.invalidate(financeDataProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _AccountListTile extends StatelessWidget {
  final FinanceAccount account;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AccountListTile({
    required this.account,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconMap = {
      AccountType.debitCard: Icons.credit_card,
      AccountType.creditCard: Icons.credit_score,
      AccountType.alipay: Icons.paypal,
      AccountType.wechat: Icons.chat,
      AccountType.cash: Icons.money,
      AccountType.investment: Icons.trending_up,
      AccountType.loan: Icons.account_balance,
      AccountType.other: Icons.account_balance_wallet,
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor:
              theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            iconMap[account.type] ?? Icons.account_balance_wallet,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(account.name),
        subtitle: Text(
          account.type.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline,
              color: theme.colorScheme.error, size: 20),
          onPressed: onDelete,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
