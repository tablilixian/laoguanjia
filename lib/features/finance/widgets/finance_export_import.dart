import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../../data/finance/models/finance_data.dart';
import '../providers/finance_providers.dart';

Future<void> exportFinanceData(BuildContext context, WidgetRef ref) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  try {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('未选择家庭')),
      );
      return;
    }

    final storage = ref.read(financeStorageProvider);
    final data = await storage.load(householdId);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());

    final dir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/finance_data_$timestamp.json');
    await file.writeAsString(jsonStr, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '家庭财务数据导出',
      text: '家庭财务数据 - ${data.updatedAt.toLocal()}',
    );
  } catch (e) {
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('导出失败: $e')),
    );
  }
}

Future<void> importFinanceData(BuildContext context, WidgetRef ref) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final jsonStr = await file.readAsString();
    final json = jsonDecode(jsonStr);

    if (json is! Map<String, dynamic>) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('无效的 JSON 格式')),
      );
      return;
    }

    final importedData = FinanceData.fromJson(json);
    final accountCount = importedData.accounts.length;
    final snapshotCount = importedData.snapshots.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入数据'),
        content: Text(
          '将导入 $accountCount 个账户, $snapshotCount 条快照。\n'
          '⚠️ 当前数据将被覆盖，是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认导入'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return;

    final storage = ref.read(financeStorageProvider);
    await storage.save(householdId, importedData);
    ref.invalidate(financeDataProvider);

    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('导入成功: $accountCount 个账户, $snapshotCount 条快照')),
    );
  } catch (e) {
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('导入失败: $e')),
    );
  }
}
