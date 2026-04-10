import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/core/constants/app_constants.dart';
import 'package:home_manager/core/services/local_storage_service.dart';
import 'package:home_manager/core/services/chat_local_storage.dart';
import 'package:home_manager/core/services/pet_local_storage.dart';
import 'package:home_manager/core/services/session_manager.dart';
import 'package:home_manager/core/sync/sync_status.dart';
import 'package:home_manager/core/sync/sync_status_provider.dart';
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
            title: const Text('数据管理'),
            subtitle: const Text('导出/导入聊天记录和宠物日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDataManagementDialog(context),
          ),
          const Divider(),
          _buildSyncStatusCard(context, ref),
          const Divider(),
          _buildAdvancedSyncOptions(context, ref),
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

  void _showDataManagementDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const DataManagementSheet(),
    );
  }
}

class DataManagementSheet extends StatefulWidget {
  const DataManagementSheet({super.key});

  @override
  State<DataManagementSheet> createState() => _DataManagementSheetState();
}

class _DataManagementSheetState extends State<DataManagementSheet> {
  bool _isLoading = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('数据管理', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '导出或导入聊天记录和宠物互动日志',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Status Message
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _statusMessage!.contains('成功')
                        ? Colors.green[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage!.contains('成功')
                            ? Icons.check_circle
                            : Icons.info_outlined,
                        color: _statusMessage!.contains('成功')
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_statusMessage!)),
                    ],
                  ),
                ),
              ],

              // Chat Export
              _buildActionTile(
                context,
                icon: Icons.chat_outlined,
                title: '导出聊天记录',
                subtitle: '导出 AI 聊天记录到文件',
                isLoading: _isLoading,
                onTap: () => _exportChatData(context),
              ),

              // Pet Logs Export
              _buildActionTile(
                context,
                icon: Icons.pets_outlined,
                title: '导出宠物日志',
                subtitle: '导出宠物互动日志到文件',
                isLoading: _isLoading,
                onTap: () => _exportPetLogs(context),
              ),

              // Pet Memories Export
              _buildActionTile(
                context,
                icon: Icons.memory,
                title: '导出宠物记忆',
                subtitle: '导出所有宠物的记忆数据',
                isLoading: _isLoading,
                onTap: () => _exportPetMemories(context),
              ),

              const Divider(height: 32),

              // Chat Import
              _buildActionTile(
                context,
                icon: Icons.upload_file_outlined,
                title: '导入聊天记录',
                subtitle: '从 JSON 文件导入聊天记录',
                isLoading: _isLoading,
                onTap: () => _importChatData(context),
              ),

              // Pet Logs Import
              _buildActionTile(
                context,
                icon: Icons.pets,
                title: '导入宠物日志',
                subtitle: '从 JSON 文件导入宠物日志',
                isLoading: _isLoading,
                onTap: () => _importPetLogs(context),
              ),

              // Pet Memories Import
              _buildActionTile(
                context,
                icon: Icons.memory,
                title: '导入宠物记忆',
                subtitle: '从 JSON 文件导入宠物记忆',
                isLoading: _isLoading,
                onTap: () => _importPetMemories(context),
              ),

              const Divider(height: 32),

              // Clear Data
              _buildActionTile(
                context,
                icon: Icons.delete_outline,
                title: '清空本地数据',
                subtitle: '删除所有本地存储的聊天记录和宠物日志',
                isLoading: _isLoading,
                isDestructive: true,
                onTap: () => _showClearDataDialog(context),
              ),

              const SizedBox(height: 16),

              // Storage Info
              FutureBuilder<Map<String, int>>(
                future: _getStorageInfo(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  final info = snapshot.data!;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '存储信息',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text('聊天记录: ${_formatBytes(info['chats'] ?? 0)}'),
                        Text('宠物日志: ${_formatBytes(info['pets'] ?? 0)}'),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : null),
      title: Text(
        title,
        style: isDestructive ? const TextStyle(color: Colors.red) : null,
      ),
      subtitle: Text(subtitle),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: isLoading ? null : onTap,
    );
  }

  Future<Map<String, int>> _getStorageInfo() async {
    final storage = LocalStorageService.instance;
    await storage.init();

    int chatSize = 0;
    int petSize = 0;

    final files = await storage.listFiles();
    for (final file in files) {
      if (file.startsWith('chats_')) {
        chatSize += await storage.getFileSize(file);
      } else if (file.startsWith('pet_interactions_')) {
        petSize += await storage.getFileSize(file);
      }
    }

    return {'chats': chatSize, 'pets': petSize};
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _exportChatData(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final chatStorage = ChatLocalStorage();
      final storage = LocalStorageService.instance;
      await storage.init();

      final messages = await chatStorage.loadAllMessages();
      final data = messages
          .map(
            (m) => {
              'id': m.id,
              'content': m.content,
              'isUser': m.isUser,
              'timestamp': m.timestamp.toIso8601String(),
            },
          )
          .toList();

      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalMessages': messages.length,
        'messages': data,
      };

      final jsonContent = jsonEncode(exportData);
      final filename =
          'chats_export_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}.json';

      if (storage.isWeb) {
        // Web 平台：使用 webkitRelativePath 或创建下载链接
        await _downloadJsonWeb(context, filename, jsonContent);
        setState(() {
          _statusMessage = '聊天记录已触发下载: $filename';
        });
      } else {
        // 非 Web 平台：保存到文件
        final exportPath = await chatStorage.exportToFile(storage.exportsPath);
        setState(() {
          _statusMessage = '聊天记录已导出到: $exportPath';
        });
        await Clipboard.setData(ClipboardData(text: exportPath));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('导出路径已复制到剪贴板')));
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = '导出失败: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadJsonWeb(
    BuildContext context,
    String filename,
    String content,
  ) async {
    // 创建 Blob 并触发下载
    final encoded = Uri.encodeComponent(content);
    final blobUrl = 'data:application/json;charset=utf-8,$encoded';

    // 使用 HTML 模板创建下载
    await Future.delayed(const Duration(milliseconds: 100));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请右键点击页面另存为: $filename\n\n或复制以下内容保存为 JSON 文件'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: '复制',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
            },
          ),
        ),
      );
    }
  }

  Future<void> _exportPetLogs(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final petStorage = PetInteractionLocalStorage();
      final storage = LocalStorageService.instance;
      await storage.init();

      final interactions = await petStorage.loadAllInteractions();
      final data = interactions
          .map(
            (i) => {
              'id': i.id,
              'petId': i.petId,
              'type': i.type,
              'value': i.value,
              'createdAt': i.createdAt.toIso8601String(),
            },
          )
          .toList();

      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalInteractions': interactions.length,
        'interactions': data,
      };

      final jsonContent = jsonEncode(exportData);
      final filename =
          'pet_logs_export_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}.json';

      if (storage.isWeb) {
        await _downloadJsonWeb(context, filename, jsonContent);
        setState(() {
          _statusMessage = '宠物日志已触发下载: $filename';
        });
      } else {
        final exportPath = await petStorage.exportToFile(storage.exportsPath);
        setState(() {
          _statusMessage = '宠物日志已导出到: $exportPath';
        });
        await Clipboard.setData(ClipboardData(text: exportPath));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('导出路径已复制到剪贴板')));
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = '导出失败: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 导出所有宠物的记忆数据
  Future<void> _exportPetMemories(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final storage = LocalStorageService.instance;
      await storage.init();

      // 获取所有宠物记忆文件
      final files = await storage.listFiles();
      final memoryFiles = files
          .where((f) => f.startsWith('pet_memories_') && f.endsWith('.json'))
          .toList();

      // 收集所有宠物的记忆数据
      final allMemories = <String, dynamic>{};
      int totalMemories = 0;

      for (final file in memoryFiles) {
        try {
          final data = await storage.readJsonFile(file);
          if (data != null) {
            final petId = data['pet_id'] as String?;
            final memories = data['memories'] as List?;
            if (petId != null && memories != null) {
              // 精简记忆数据，只保留核心字段
              final simplifiedMemories = memories.map((m) {
                final memory = m as Map<String, dynamic>;
                return {
                  'memory_type': memory['memory_type'],
                  'title': memory['title'],
                  'description': memory['description'],
                  'emotion': memory['emotion'],
                  'importance': memory['importance'],
                  'occurred_at': memory['occurred_at'],
                };
              }).toList();

              allMemories[petId] = {
                'memories': simplifiedMemories,
                'statistics': data['statistics'],
              };
              totalMemories += memories.length;
            }
          }
        } catch (e) {
          // 跳过读取失败的文件
        }
      }

      // 构建导出数据
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'totalPets': allMemories.length,
        'totalMemories': totalMemories,
        'pets': allMemories,
      };

      final jsonContent = jsonEncode(exportData);
      final filename =
          'pet_memories_export_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}.json';

      if (storage.isWeb) {
        await _downloadJsonWeb(context, filename, jsonContent);
        setState(() {
          _statusMessage = '宠物记忆已触发下载: $filename';
        });
      } else {
        // 保存到导出目录
        final exportFile = File('${storage.exportsPath}/$filename');
        await exportFile.writeAsString(jsonContent);
        
        setState(() {
          _statusMessage = '宠物记忆已导出到: ${exportFile.path}\n共 $totalMemories 条记忆';
        });
        
        await Clipboard.setData(ClipboardData(text: exportFile.path));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('导出路径已复制到剪贴板')));
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = '导出失败: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importChatData(BuildContext context) async {
    // 显示提示信息，让用户手动复制 JSON 内容
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入聊天记录'),
        content: const Text(
          '请在弹出的输入框中粘贴导出的 JSON 内容。\n\n如果是文件导入，请先读取文件内容，然后粘贴到输入框中。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _showImportInputDialog(context, 'chat');
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  Future<void> _importPetLogs(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入宠物日志'),
        content: const Text(
          '请在弹出的输入框中粘贴导出的 JSON 内容。\n\n如果是文件导入，请先读取文件内容，然后粘贴到输入框中。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _showImportInputDialog(context, 'pet');
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  /// 导入宠物记忆数据
  Future<void> _importPetMemories(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入宠物记忆'),
        content: const Text(
          '请在弹出的输入框中粘贴导出的 JSON 内容。\n\n如果是文件导入，请先读取文件内容，然后粘贴到输入框中。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _showImportInputDialog(context, 'pet_memories');
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportInputDialog(BuildContext context, String type) async {
    final controller = TextEditingController();

    String title;
    switch (type) {
      case 'chat':
        title = '导入聊天记录';
        break;
      case 'pet':
        title = '导入宠物日志';
        break;
      case 'pet_memories':
        title = '导入宠物记忆';
        break;
      default:
        title = '导入数据';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: '粘贴 JSON 内容到这里...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performImport(context, type, controller.text);
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<void> _performImport(
    BuildContext context,
    String type,
    String content,
  ) async {
    if (content.trim().isEmpty) {
      setState(() => _statusMessage = '请输入 JSON 内容');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      // 创建一个临时文件用于导入
      final tempPath =
          '/tmp/import_${type}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = await File(tempPath).writeAsString(content);

      int imported = 0;
      if (type == 'chat') {
        final chatStorage = ChatLocalStorage();
        imported = await chatStorage.importFromFile(tempPath);
      } else if (type == 'pet') {
        final petStorage = PetInteractionLocalStorage();
        imported = await petStorage.importFromFile(tempPath);
      } else if (type == 'pet_memories') {
        // 导入宠物记忆
        imported = await _importPetMemoriesFromJson(content);
      }

      // 删除临时文件
      await file.delete();

      setState(() {
        _statusMessage = '成功导入 $imported 条记录';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '导入失败: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 从 JSON 内容导入宠物记忆
  Future<int> _importPetMemoriesFromJson(String jsonContent) async {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final pets = data['pets'] as Map<String, dynamic>?;
      
      if (pets == null) return 0;

      int totalImported = 0;

      for (final entry in pets.entries) {
        final petId = entry.key;
        final petData = entry.value as Map<String, dynamic>;
        final memories = petData['memories'] as List?;

        if (memories != null && memories.isNotEmpty) {
          // 将精简格式转换为完整格式
          final fullMemories = memories.map((m) {
            final memory = m as Map<String, dynamic>;
            
            // 检查是否是精简格式（没有 id 字段）
            if (!memory.containsKey('id')) {
              // 精简格式，补充默认值
              return {
                'id': '',
                'pet_id': petId,
                'memory_type': memory['memory_type'],
                'title': memory['title'],
                'description': memory['description'],
                'emotion': memory['emotion'],
                'participants': ['主人', '我'],
                'importance': memory['importance'],
                'is_summarized': false,
                'interaction_id': null,
                'occurred_at': memory['occurred_at'],
                'created_at': memory['occurred_at'],
              };
            } else {
              // 旧格式，直接使用
              return memory;
            }
          }).toList();

          // 保存到本地文件
          final fileName = 'pet_memories_$petId.json';
          final storage = LocalStorageService.instance;
          await storage.init();

          await storage.writeJsonFile(fileName, {
            'pet_id': petId,
            'version': '1.0',
            'last_updated': DateTime.now().toIso8601String(),
            'memories': fullMemories,
            'statistics': petData['statistics'],
          });

          totalImported += memories.length;
        }
      }

      return totalImported;
    } catch (e) {
      throw Exception('解析宠物记忆数据失败: $e');
    }
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空本地数据'),
        content: const Text(
          '确定要清空所有本地存储的数据吗？\n\n此操作将删除：\n- 所有聊天记录\n- 所有宠物互动日志\n\n注意：此操作不可恢复！',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllData(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final storage = LocalStorageService.instance;
      await storage.init();

      final files = await storage.listFiles();
      for (final file in files) {
        if (file.startsWith('chats_') || file.startsWith('pet_interactions_')) {
          await storage.deleteFile(file);
        }
      }

      setState(() {
        _statusMessage = '本地数据已清空';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '清空失败: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
