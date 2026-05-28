import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/core/constants/app_constants.dart';
import 'package:home_manager/core/services/session_manager.dart';
import 'package:home_manager/core/sync/sync_status.dart';
import 'package:home_manager/core/sync/sync_status_provider.dart';
import 'package:home_manager/core/sync/sync_scheduler.dart';
import 'package:home_manager/core/services/quote_storage_service.dart';
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
          Consumer(
            builder: (context, ref, _) {
              final authUser = ref.watch(authUserProvider);
              final householdState = ref.watch(householdProvider);

              return authUser.when(
                data: (user) {
                  // 尝试从家庭成员中获取昵称
                  String displayName = '用户';
                  String? avatarUrl;
                  if (user != null && householdState.members.isNotEmpty) {
                    try {
                      final member = householdState.members.firstWhere(
                        (m) => m.userId == user.id,
                      );
                      displayName = member.name;
                      avatarUrl = member.avatarUrl;
                    } catch (_) {
                      displayName = user.email?.split('@').first ?? '用户';
                    }
                  } else if (user != null) {
                    displayName = user.email?.split('@').first ?? '用户';
                  }

                  final initial = displayName.isNotEmpty ? displayName[0] : 'U';

                  return UserAccountsDrawerHeader(
                    accountName: Text(displayName),
                    accountEmail: Text(user?.email ?? ''),
                    currentAccountPicture:
                        avatarUrl != null && avatarUrl.isNotEmpty
                        ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
                        : CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              initial.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                          ),
                  );
                },
                loading: () => const ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('加载中...'),
                ),
                error: (_, __) => const ListTile(
                  leading: Icon(Icons.error),
                  title: Text('加载失败'),
                ),
              );
            },
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
                          Text('邀请码', style: theme.textTheme.titleMedium),
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
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                householdState.currentHousehold!.inviteCode ??
                                    '------',
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(content: Text('邀请码已刷新')),
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
                              final code =
                                  householdState.currentHousehold!.inviteCode;
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
                context.push('/settings/members');
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

                if (householdState.currentHousehold == null ||
                    authUser.value == null) {
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
                  title: const Text(
                    '删除家庭',
                    style: TextStyle(color: Colors.red),
                  ),
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
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('AI 设置'),
            subtitle: const Text('配置 AI 模型和 API Key'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/settings/ai');
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('天气设置'),
            subtitle: const Text('配置默认城市和 API'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/settings/weather');
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
          // Data Management Section
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('数据导入/导出'),
            subtitle: const Text('统一导入导出财务、聊天、宠物等数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/data-export'),
          ),
          const Divider(),
          _buildSyncStatusCard(context, ref),
          const Divider(),
          _buildAdvancedSyncOptions(context, ref),
          const Divider(),
          // 每日一言设置
          ListTile(
            leading: const Icon(Icons.format_quote),
            title: const Text('每日一言'),
            subtitle: const Text('设置喜欢的句子类型'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showQuoteCategoryDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('调试工具'),
            subtitle: const Text('测试功能和系统信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/debug');
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
                applicationVersion: AppConstants.appVersion,
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
                // 使用 SessionManager 执行完整退出流程，清除所有用户状态
                await ref.read(sessionManagerProvider).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('家庭名称不能为空')));
                }
                return;
              }

              final success = await ref
                  .read(householdProvider.notifier)
                  .updateHouseholdName(newName);

              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('家庭名称已修改')));
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

    if (currentMember.role == MemberRole.admin &&
        householdState.members.length > 1) {
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
              final success = await ref
                  .read(householdProvider.notifier)
                  .leaveHousehold();

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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('管理员权限已转让')));
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
        content: const Text('确定要删除家庭吗？此操作将删除所有成员和相关数据，且无法恢复！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final success = await ref
                  .read(householdProvider.notifier)
                  .deleteHousehold();

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

  Widget _buildSyncStatusCard(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;

    switch (syncStatus.state) {
      case SyncState.idle:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case SyncState.syncing:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        break;
      case SyncState.success:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case SyncState.error:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
      case SyncState.offline:
        statusColor = Colors.grey;
        statusIcon = Icons.wifi_off;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_sync_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '同步状态',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    syncStatus.statusText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (syncStatus.lastSyncTime != null) ...[
              const SizedBox(height: 8),
              Text(
                '上次同步: ${_formatDateTime(syncStatus.lastSyncTime!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
if (syncStatus.state == SyncState.syncing &&
                syncStatus.totalItems != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value:
                    syncStatus.syncedItems != null &&
                        syncStatus.totalItems != null &&
                        syncStatus.totalItems! > 0
                        ? syncStatus.syncedItems! / syncStatus.totalItems!
                        : null,
              ),
              const SizedBox(height: 8),
              Text(
                '已同步: ${syncStatus.syncedItems ?? 0}/${syncStatus.totalItems ?? 0}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // 自动同步开关
            SwitchListTile(
              title: const Text('自动同步'),
              subtitle: const Text('App 打开时自动同步数据'),
              secondary: const Icon(Icons.autorenew),
              value: syncStatus.autoSyncEnabled,
              onChanged: (value) async {
                await ref.read(syncStatusProvider.notifier).updateAutoSyncEnabled(value);
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: syncStatus.state == SyncState.syncing
                    ? null
                    : () => ref.read(syncStatusProvider.notifier).sync(),
                icon: syncStatus.state == SyncState.syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(
                  syncStatus.state == SyncState.syncing ? '同步中...' : '手动同步',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSyncOptions(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  '高级同步选项',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('强制全量同步'),
              subtitle: const Text('从云端拉取所有数据，覆盖本地'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showForceSyncDialog(context, ref),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.red,
              ),
              title: const Text('重置本地数据', style: TextStyle(color: Colors.red)),
              subtitle: const Text('删除所有本地数据，重新同步'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showResetDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showForceSyncDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('强制全量同步'),
        content: const Text('这将从云端拉取所有数据，覆盖本地数据。\n\n确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performForceSync(context, ref);
            },
            child: const Text('确认同步'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置本地数据'),
        content: const Text('这将删除所有本地数据，然后从云端重新同步。\n\n确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performReset(context, ref);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
  }

  Future<void> _performForceSync(BuildContext context, WidgetRef ref) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正在执行全量同步...')));

      await ref.read(syncStatusProvider.notifier).forceFullSync();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('全量同步完成'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同步失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performReset(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(syncStatusProvider.notifier).resetAndSync();
      if (context.mounted) {
        context.go('/welcome');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重置失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 显示每日一言分类设置弹窗
  void _showQuoteCategoryDialog(BuildContext context) async {
    final storage = QuoteStorageService.instance;
    await storage.init();
    final selected = List<String>.from(storage.preferredCategories);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _QuoteCategorySheet(initialSelected: selected),
    );

    if (result != null) {
      await storage.setPreferredCategories(result);
    }
  }
}

/// 每日一言分类选择弹窗
class _QuoteCategorySheet extends StatefulWidget {
  final List<String> initialSelected;

  const _QuoteCategorySheet({required this.initialSelected});

  @override
  State<_QuoteCategorySheet> createState() => _QuoteCategorySheetState();
}

class _QuoteCategorySheetState extends State<_QuoteCategorySheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = QuoteStorageService.allCategories;

    return AlertDialog(
      title: const Text('每日一言类型'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择你喜欢的类型，进入首页时会轮换显示',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.entries.map((e) {
                final isSelected = _selected.contains(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selected.add(e.key);
                      } else {
                        _selected.remove(e.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('保存'),
        ),
      ],
    );
  }
}


