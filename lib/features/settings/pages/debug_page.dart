import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/core/constants/app_constants.dart';

class DebugPage extends ConsumerWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('调试工具'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // Version Info Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '版本信息',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('应用名称', AppConstants.appName),
                    _buildInfoRow('版本号', AppConstants.appVersion),
                    _buildInfoRow('构建版本', AppConstants.appVersion),
                    _buildInfoRow('发布日期', '2026-03-11'),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),

          // Database Debug Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '数据库调试',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('数据库测试'),
            subtitle: const Text('测试数据库连接和基本操作'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.go('/debug/database');
            },
          ),
          ListTile(
            leading: const Icon(Icons.system_update_tv_outlined),
            title: const Text('Supabase 诊断'),
            subtitle: const Text('诊断 Supabase 连接状态'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.go('/debug/supabase');
            },
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('直接 Supabase 测试'),
            subtitle: const Text('直接测试 Supabase API'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.go('/debug/direct');
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('物品功能调试'),
            subtitle: const Text('初始化预设数据、生成/清空测试数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.go('/debug/items');
            },
          ),
          ListTile(
            leading: const Icon(Icons.home_work_outlined),
            title: const Text('位置初始化向导'),
            subtitle: const Text('快速创建家庭空间位置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/home/items/locations/init');
            },
          ),
          const Divider(),

          // System Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '系统信息',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('设备信息'),
            subtitle: const Text('查看设备详细信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showDeviceInfo(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('存储信息'),
            subtitle: const Text('查看应用存储使用情况'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showStorageInfo(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showDeviceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设备信息'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('平台: Web'),
              Text('浏览器: Chrome'),
              Text('屏幕尺寸: Responsive'),
              Text('语言: zh-CN'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showStorageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('存储信息'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('本地存储: 未使用'),
              Text('缓存大小: 0 KB'),
              Text('数据库: Supabase Cloud'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
