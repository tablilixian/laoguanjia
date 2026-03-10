import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../household/providers/household_provider.dart';
import '../../../data/models/member.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authUserProvider);
    final householdState = ref.watch(householdProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: ListView(
        children: [
          // User Info
          authUser.when(
            data: (user) => UserAccountsDrawerHeader(
              accountName: Text(user?.email?.split('@').first ?? '用户'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  (user?.email?.substring(0, 1) ?? 'U').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
            loading: () => const ListTile(
              leading: CircularProgressIndicator(),
              title: Text('加载中...'),
            ),
            error: (_, __) =>
                const ListTile(leading: Icon(Icons.error), title: Text('加载失败')),
          ),
          const Divider(),
          
          // Household Section
          if (householdState.currentHousehold != null) ...[
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(householdState.currentHousehold!.name),
              subtitle: const Text('当前家庭'),
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () => _showEditHouseholdNameDialog(context, ref),
            ),
            
            // Invite Code Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.vpn_key, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '邀请码',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                householdState.currentHousehold!.inviteCode ?? '------',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: householdState.isLoading
                                ? null
                                : () async {
                                    final success = await ref
                                        .read(householdProvider.notifier)
                                        .refreshInviteCode();
                                    if (context.mounted && success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('邀请码已刷新'),
                                        ),
                                      );
                                    }
                                  },
                            icon: householdState.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                          ),
                          IconButton(
                            onPressed: () {
                              final code = householdState.currentHousehold!.inviteCode;
                              if (code != null) {
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('邀请码已复制')),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '分享邀请码，让家人加入家庭',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people_outlined),
              title: const Text('成员管理'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to member management
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.orange),
              title: const Text('退出家庭', style: TextStyle(color: Colors.orange)),
              onTap: () => _showLeaveHouseholdDialog(context, ref),
            ),
            Consumer(
              builder: (context, ref, _) {
                final householdState = ref.watch(householdProvider);
                final authUser = ref.watch(authUserProvider);
                
                if (householdState.currentHousehold == null || authUser.value == null) {
                  return const SizedBox.shrink();
                }
                
                final currentMember = householdState.members.firstWhere(
                  (m) => m.userId == authUser.value!.id,
                  orElse: () => householdState.members.first,
                );
                
                if (currentMember.role != MemberRole.admin) {
                  return const SizedBox.shrink();
                }
                
                return ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('删除家庭', style: TextStyle(color: Colors.red)),
                  onTap: () => _showDeleteHouseholdDialog(context, ref),
                );
              },
            ),
            const Divider(),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('加入或创建家庭'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/join-household');
              },
            ),
            const Divider(),
          ],
          
          // Menu Items
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('数据库测试'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.go('/debug/database');
            },
          ),
          ListTile(
            leading: const Icon(Icons.system_update_tv_outlined),
            title: const Text('Supabase 诊断'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.go('/debug/supabase');
            },
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('直接 Supabase 测试'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.go('/debug/direct');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('AI 设置'),
            subtitle: const Text('配置 AI 模型和 API Key'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/settings/ai');
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('AI 聊天'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/ai-chat');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outlined),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '老管家',
                applicationVersion: '1.0.5',
                applicationLegalese: '© 2026 老管家',
              );
            },
          ),
          const Divider(),
          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认退出'),
                  content: const Text('确定要退出登录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('退出'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await ref.read(authStateProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
          // Version
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本号'),
            subtitle: const Text('1.0.5'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '老管家',
                applicationVersion: '1.0.5',
                applicationLegalese: '© 2026 老管家',
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditHouseholdNameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: ref.read(householdProvider).currentHousehold?.name ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改家庭名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '家庭名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('家庭名称不能为空')),
                  );
                }
                return;
              }

              final success = await ref
                  .read(householdProvider.notifier)
                  .updateHouseholdName(newName);

              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('家庭名称已修改')),
                  );
                } else {
                  final error = ref.read(householdProvider).errorMessage;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? '修改失败'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showLeaveHouseholdDialog(BuildContext context, WidgetRef ref) {
    final householdState = ref.read(householdProvider);
    final authUser = ref.read(authUserProvider);

    if (householdState.currentHousehold == null || authUser.value == null) {
      return;
    }

    final currentMember = householdState.members.firstWhere(
      (m) => m.userId == authUser.value!.id,
      orElse: () => householdState.members.first,
    );

    if (currentMember.role == MemberRole.admin && householdState.members.length > 1) {
      _showTransferAdminDialog(context, ref);
    } else {
      _showConfirmLeaveDialog(context, ref);
    }
  }

  void _showConfirmLeaveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出家庭'),
        content: const Text('确定要退出当前家庭吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final success = await ref.read(householdProvider.notifier).leaveHousehold();

              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  context.go('/join-household');
                } else {
                  final error = ref.read(householdProvider).errorMessage;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? '退出失败'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _showTransferAdminDialog(BuildContext context, WidgetRef ref) {
    final householdState = ref.read(householdProvider);
    final authUser = ref.read(authUserProvider);

    if (authUser.value == null) return;

    final currentMember = householdState.members.firstWhere(
      (m) => m.userId == authUser.value!.id,
      orElse: () => householdState.members.first,
    );

    final otherMembers = householdState.members
        .where((m) => m.id != currentMember.id && m.role != MemberRole.admin)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('转让管理员权限'),
        content: const Text('您是管理员，退出前需要将管理员权限转让给其他成员。'),
        actions: [
          ...otherMembers.map(
            (member) => ListTile(
              title: Text(member.name),
              subtitle: Text(member.role == MemberRole.admin ? '管理员' : '成员'),
              trailing: member.role == MemberRole.admin
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                final transferSuccess = await ref
                    .read(householdProvider.notifier)
                    .transferAdminRole(member.id);

                if (context.mounted) {
                  if (transferSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('管理员权限已转让')),
                    );
                    _showConfirmLeaveDialog(context, ref);
                  } else {
                    final error = ref.read(householdProvider).errorMessage;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error ?? '转让失败'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showDeleteHouseholdDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除家庭'),
        content: const Text(
          '确定要删除家庭吗？此操作将删除所有成员和相关数据，且无法恢复！',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final success = await ref.read(householdProvider.notifier).deleteHousehold();

              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  context.go('/join-household');
                } else {
                  final error = ref.read(householdProvider).errorMessage;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? '删除失败'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
