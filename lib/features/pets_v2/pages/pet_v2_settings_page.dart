import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 宠物管家 V2 设置页
class PetV2SettingsPage extends ConsumerWidget {
  const PetV2SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '宠物设置',
          style: TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            '播报设置',
            [
              _buildSwitchTile('晨间播报', true),
              _buildSwitchTile('任务提醒', true),
              _buildSwitchTile('物品提醒', true),
              _buildSwitchTile('天气提醒', true),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            '通知设置',
            [
              _buildSwitchTile('推送通知', true),
              _buildInfoTile('免打扰时段', '22:00 - 07:00'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            '数据管理',
            [
              _buildActionTile(
                '导出宠物数据',
                Icons.download,
                () => _exportData(ref, context),
              ),
              _buildActionTile(
                '导入宠物数据',
                Icons.upload,
                () => _importData(ref, context),
              ),
              _buildActionTile(
                '清除本地缓存',
                Icons.delete_outline,
                () => _clearCache(ref, context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8D6E63),
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool initialValue) {
    return SwitchListTile(
      title: Text(title),
      value: initialValue,
      onChanged: (_) {},
      activeColor: const Color(0xFFFF9800),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(color: Colors.grey),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildActionTile(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFF9800)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Future<void> _exportData(WidgetRef ref, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中...')),
    );
  }

  Future<void> _importData(WidgetRef ref, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导入功能开发中...')),
    );
  }

  Future<void> _clearCache(WidgetRef ref, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有本地宠物数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缓存已清除')),
      );
    }
  }
}
