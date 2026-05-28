import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:home_manager/core/services/data_export/data_export_source.dart';
import 'package:home_manager/core/services/data_export/data_export_registry.dart';
import 'package:home_manager/core/services/data_export/data_export_service.dart';
import 'package:home_manager/features/finance/providers/finance_providers.dart';

class DataExportPage extends ConsumerStatefulWidget {
  const DataExportPage({super.key});

  @override
  ConsumerState<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends ConsumerState<DataExportPage> {
  List<DataExportSource> _sources = [];
  Set<String> _exportSelected = {};
  bool _isExporting = false;
  String? _exportMessage;

  Map<String, dynamic>? _importParsedData;
  Set<String> _importSelected = {};
  bool _isImporting = false;
  String? _importMessage;

  @override
  void initState() {
    super.initState();
    _initSources();
  }

  Future<void> _initSources() async {
    final householdId = ref.read(currentHouseholdIdProvider);
    final sources = DataExportRegistry.createSources(householdId: householdId);
    setState(() {
      _sources = sources;
      _exportSelected = sources.map((s) => s.id).toSet();
    });
  }

  // ========== Export ==========

  Future<void> _onExport() async {
    if (_exportSelected.isEmpty) {
      _showSnackBar('请选择至少一个数据源');
      return;
    }

    setState(() {
      _isExporting = true;
      _exportMessage = null;
    });

    try {
      final selectedSources =
          _sources.where((s) => _exportSelected.contains(s.id)).toList();
      final jsonContent = await DataExportService.buildExportJson(selectedSources);
      final filename = DataExportService.generateFilename();

      if (!mounted) return;

      final method = await _showExportMethodDialog();
      if (method == null) return;

      switch (method) {
        case 'share':
          await DataExportService.shareExport(jsonContent, filename);
          setState(() => _exportMessage = '数据已通过系统分享导出');
        case 'local':
          final path = await DataExportService.saveToLocal(jsonContent, filename);
          setState(() => _exportMessage = '数据已保存到: $path\n路径已复制到剪贴板');
        case 'web':
          await DataExportService.downloadForWeb(jsonContent, filename);
          setState(() => _exportMessage = '数据已准备下载\n请查看浏览器下载提示');
      }

      _showSnackBar('导出成功');
    } catch (e) {
      setState(() => _exportMessage = '导出失败: $e');
      _showSnackBar('导出失败: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<String?> _showExportMethodDialog() async {
    final isWeb = false; // TODO: detect web
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择导出方式'),
        content: const Text('请选择导出数据的方式：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'share'),
            child: const Text('系统分享'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'local'),
            child: const Text('保存到本地'),
          ),
          if (isWeb)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'web'),
              child: const Text('Web 下载'),
            ),
        ],
      ),
    );
  }

  // ========== Import ==========

  Future<void> _onPickFile() async {
    setState(() {
      _importParsedData = null;
      _importSelected = {};
      _importMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final jsonStr = await file.readAsString();
      final parsed = DataExportService.parseImportJson(jsonStr);

      if (parsed == null) {
        _showSnackBar('无效的导出文件格式');
        return;
      }

      final available = parsed.sourceIds.toSet();
      final knownIds = _sources.map((s) => s.id).toSet();
      final matched = available.intersection(knownIds);

      if (matched.isEmpty) {
        _showSnackBar('文件中不包含可识别的数据源');
        return;
      }

      setState(() {
        _importParsedData = parsed.data;
        _importSelected = matched;
      });
    } catch (e) {
      _showSnackBar('读取文件失败: $e');
    }
  }

  Future<void> _onImport() async {
    if (_importParsedData == null || _importSelected.isEmpty) {
      _showSnackBar('请先选择文件并勾选要导入的数据源');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认导入'),
        content: Text('将导入以下数据：\n${_importSelected.map((id) {
          final source = _sources.firstWhere((s) => s.id == id);
          return '  • ${source.name}';
        }).join('\n')}\n\n⚠️ 财务数据将被覆盖，其他数据为追加导入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认导入'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isImporting = true;
      _importMessage = null;
    });

    try {
      final results = <String>[];
      for (final id in _importSelected) {
        final source = _sources.firstWhere((s) => s.id == id);
        final sourceData = _importParsedData![id] as Map<String, dynamic>;
        final summary = await source.importData(sourceData);
        results.add('${source.name}: ${summary.message ?? "${summary.itemCount} 条"}');
      }

      ref.invalidate(financeDataProvider);

      setState(() {
        _importMessage = results.join('\n');
      });
      _showSnackBar('导入完成');
    } catch (e) {
      setState(() => _importMessage = '导入失败: $e');
      _showSnackBar('导入失败: $e');
    } finally {
      setState(() => _isImporting = false);
    }
  }

  // ========== UI ==========

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('数据导入/导出')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            title: '导出数据',
            icon: Icons.file_upload_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._sources.map((s) => _buildSourceTile(
                      source: s,
                      selected: _exportSelected.contains(s.id),
                      onToggle: (v) {
                        setState(() {
                          if (v == true) {
                            _exportSelected.add(s.id);
                          } else {
                            _exportSelected.remove(s.id);
                          }
                        });
                      },
                    )),
                if (_sources.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('暂无数据源'),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isExporting ? null : _onExport,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_upload_outlined),
                    label:
                        Text(_isExporting ? '正在导出...' : '导出选中数据'),
                  ),
                ),
                if (_exportMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildMessageBanner(_exportMessage!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: '导入数据',
            icon: Icons.file_download_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isImporting ? null : _onPickFile,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('选择 JSON 文件'),
                  ),
                ),
                if (_importParsedData != null && _importSelected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '文件中包含以下数据源，请选择要导入的项：',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        ..._sources
                            .where((s) => _importParsedData!.containsKey(s.id))
                            .map((s) => _buildSourceTile(
                                  source: s,
                                  selected: _importSelected.contains(s.id),
                                  onToggle: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _importSelected.add(s.id);
                                      } else {
                                        _importSelected.remove(s.id);
                                      }
                                    });
                                  },
                                )),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isImporting ? null : _onImport,
                            icon: _isImporting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.file_download_outlined),
                            label: Text(
                                _isImporting ? '正在导入...' : '导入选中数据'),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_importMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildMessageBanner(_importMessage!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile({
    required DataExportSource source,
    required bool selected,
    required void Function(bool?) onToggle,
  }) {
    return CheckboxListTile(
      value: selected,
      onChanged: onToggle,
      secondary: Icon(source.icon),
      title: Text(source.name),
      subtitle: Text(source.description,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildMessageBanner(String message) {
    final isError = message.contains('失败');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? Colors.red[700] : Colors.green[700],
          fontSize: 13,
        ),
      ),
    );
  }
}
