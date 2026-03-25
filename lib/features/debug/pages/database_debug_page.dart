import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'package:drift/drift.dart' as drift;

import '../../../data/local_db/app_database.dart';
import '../providers/database_debug_provider.dart';

class DatabaseDebugPage extends ConsumerStatefulWidget {
  const DatabaseDebugPage({super.key});

  @override
  ConsumerState<DatabaseDebugPage> createState() => _DatabaseDebugPageState();
}

class _DatabaseDebugPageState extends ConsumerState<DatabaseDebugPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据库调试工具'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(databaseDebugProvider.notifier).loadTableCounts();
            },
            tooltip: '刷新统计',
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final state = ref.watch(databaseDebugProvider);

          if (state.isLoading && state.tableCounts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildTableList(state),
              if (state.selectedTable != null) _buildTableData(state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTableList(DatabaseDebugState state) {
    final tables = [
      {'name': 'household_items', 'label': '物品', 'icon': '📦'},
      {'name': 'item_locations', 'label': '位置', 'icon': '📍'},
      {'name': 'item_tags', 'label': '标签', 'icon': '🏷️'},
      {'name': 'item_tag_relations', 'label': '标签关联', 'icon': '🔗'},
      {'name': 'item_type_configs', 'label': '类型配置', 'icon': '⚙️'},
      {'name': 'tasks', 'label': '任务', 'icon': '📋'},
    ];

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        itemCount: tables.length,
        itemBuilder: (context, index) {
          final table = tables[index];
          final tableName = table['name'] ?? '';
          final count = state.tableCounts[tableName] ?? 0;
          final isSelected = state.selectedTable == tableName;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: Text(
                table['icon'] ?? '',
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(table['label'] ?? ''),
              subtitle: Text('$count 条数据'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Colors.green)
                  else
                    Icon(Icons.chevron_right, color: Colors.grey),
                  const SizedBox(width: 8),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              onTap: () {
                final tableName = table['name'] ?? '';
                if (tableName.isNotEmpty) {
                  ref.read(databaseDebugProvider.notifier).loadTableData(tableName);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableData(DatabaseDebugState state) {
    final tableName = state.selectedTable ?? '';
    final data = state.selectedTableData;

    return Expanded(
      child: Column(
        children: [
          _buildTableHeader(tableName, state),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? const Center(child: Text('暂无数据'))
                    : _buildDataList(data),
          ),
          _buildActionButtons(tableName),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String tableName, DatabaseDebugState state) {
    final tableLabels = {
      'household_items': '物品数据',
      'item_locations': '位置数据',
      'item_tags': '标签数据',
      'item_tag_relations': '标签关联数据',
      'item_type_configs': '类型配置数据',
      'tasks': '任务数据',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Text(
            tableLabels[tableName] ?? tableName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '${state.selectedTableData.length} 条',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataList(List<Map<String, dynamic>> data) {
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ExpansionTile(
            title: Text('记录 #${index + 1}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(item),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(String tableName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
            onPressed: () {
              ref.read(databaseDebugProvider.notifier).loadTableData(tableName);
            },
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('复制JSON'),
            onPressed: () async {
              final jsonString = await ref.read(databaseDebugProvider.notifier).exportTableAsJson(tableName);
              if (jsonString.isNotEmpty) {
                await Clipboard.setData(ClipboardData(text: jsonString));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('导出JSON'),
            onPressed: () async {
              final jsonString = await ref.read(databaseDebugProvider.notifier).exportTableAsJson(tableName);
              if (jsonString.isNotEmpty) {
                _downloadJson(jsonString, tableName);
              }
            },
          ),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('清空表格'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _showClearConfirmDialog(tableName);
            },
          ),
        ],
      ),
    );
  }

  void _showClearConfirmDialog(String tableName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: Text('确定要清空 $tableName 表格的所有数据吗？此操作不可恢复！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(databaseDebugProvider.notifier).clearTable(tableName);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
  }

  void _downloadJson(String jsonString, String tableName) {
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '$tableName.json')
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}