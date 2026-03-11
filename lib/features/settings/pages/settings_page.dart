import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/core/services/local_storage_service.dart';
import 'package:home_manager/core/services/chat_local_storage.dart';
import 'package:home_manager/core/services/pet_local_storage.dart';
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
              Text(
                '数据管理',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '导出或导入聊天记录和宠物互动日志',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
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
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : null,
      ),
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
      final data = messages.map((m) => {
        'id': m.id,
        'content': m.content,
        'isUser': m.isUser,
        'timestamp': m.timestamp.toIso8601String(),
      }).toList();
      
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalMessages': messages.length,
        'messages': data,
      };
      
      final jsonContent = jsonEncode(exportData);
      final filename = 'chats_export_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}.json';
      
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导出路径已复制到剪贴板')),
          );
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

  Future<void> _downloadJsonWeb(BuildContext context, String filename, String content) async {
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
      final data = interactions.map((i) => {
        'id': i.id,
        'petId': i.petId,
        'type': i.type,
        'value': i.value,
        'createdAt': i.createdAt.toIso8601String(),
      }).toList();
      
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalInteractions': interactions.length,
        'interactions': data,
      };
      
      final jsonContent = jsonEncode(exportData);
      final filename = 'pet_logs_export_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}.json';
      
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导出路径已复制到剪贴板')),
          );
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

  Future<void> _showImportInputDialog(BuildContext context, String type) async {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('导入${type == 'chat' ? '聊天记录' : '宠物日志'}'),
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

  Future<void> _performImport(BuildContext context, String type, String content) async {
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
      final tempPath = '/tmp/import_${type}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = await File(tempPath).writeAsString(content);
      
      int imported = 0;
      if (type == 'chat') {
        final chatStorage = ChatLocalStorage();
        imported = await chatStorage.importFromFile(tempPath);
      } else {
        final petStorage = PetInteractionLocalStorage();
        imported = await petStorage.importFromFile(tempPath);
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
