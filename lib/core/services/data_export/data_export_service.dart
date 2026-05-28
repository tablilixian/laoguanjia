import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'data_export_source.dart';
import '../../../core/services/local_storage_service.dart';

class DataExportService {
  DataExportService._();

  static const String exportVersion = '1.0';

  /// 构建统一导出 JSON
  static Future<String> buildExportJson(
    List<DataExportSource> sources,
  ) async {
    final data = <String, dynamic>{};
    for (final source in sources) {
      final result = await source.exportData();
      data.addAll(result);
    }

    return const JsonEncoder.withIndent('  ').convert({
      'exportVersion': exportVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'appName': '老管家',
      'sources': sources.map((s) => s.id).toList(),
      'data': data,
    });
  }

  /// 解析导入 JSON，返回各数据源的数据片段
  static ParsedImport? parseImportJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      final exportVersion = decoded['exportVersion'] as String?;
      final exportDate = decoded['exportDate'] as String?;
      final sources = (decoded['sources'] as List?)?.cast<String>() ?? [];
      final data = decoded['data'] as Map<String, dynamic>? ?? {};

      return ParsedImport(
        exportVersion: exportVersion ?? 'unknown',
        exportDate: exportDate,
        sourceIds: sources,
        data: data,
      );
    } catch (e) {
      return null;
    }
  }

  /// 方式一：通过系统分享导出
  static Future<void> shareExport(String jsonContent, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(jsonContent, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '老管家数据导出',
      text: '老管家数据导出 - ${DateTime.now().toLocal()}',
    );
  }

  /// 方式二：保存到本地导出目录，复制路径到剪贴板
  static Future<String> saveToLocal(String jsonContent, String filename) async {
    final storage = LocalStorageService.instance;
    await storage.init();
    final file = File('${storage.exportsPath}/$filename');
    await file.writeAsString(jsonContent);

    await Clipboard.setData(ClipboardData(text: file.path));
    return file.path;
  }

  /// Web 平台触发下载
  static Future<void> downloadForWeb(
    String jsonContent,
    String filename,
  ) async {
    final storage = LocalStorageService.instance;
    await storage.init();
    await storage.writeJsonFile('exports/$filename', {
      'content': jsonContent,
    });
  }

  /// 生成带时间戳的文件名
  static String generateFilename() {
    final now = DateTime.now();
    return 'home_manager_export_${DateFormat('yyyyMMdd_HHmmss').format(now)}.json';
  }
}

class ParsedImport {
  final String exportVersion;
  final String? exportDate;
  final List<String> sourceIds;
  final Map<String, dynamic> data;

  ParsedImport({
    required this.exportVersion,
    this.exportDate,
    required this.sourceIds,
    required this.data,
  });
}
