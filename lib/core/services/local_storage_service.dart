import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 本地文件存储服务
/// 提供基础的 JSON 文件读写功能，支持增量写入
class LocalStorageService {
  static LocalStorageService? _instance;
  late Directory _dataDirectory;
  bool _initialized = false;

  LocalStorageService._();

  static LocalStorageService get instance {
    _instance ??= LocalStorageService._();
    return _instance!;
  }

  /// 初始化存储目录
  Future<void> init() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    _dataDirectory = Directory('${appDir.path}/home_manager_data');
    
    if (!await _dataDirectory.exists()) {
      await _dataDirectory.create(recursive: true);
    }

    // 创建子目录
    final exportsDir = Directory('${_dataDirectory.path}/exports');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    _initialized = true;
  }

  /// 获取数据目录路径
  String get dataPath => _dataDirectory.path;

  /// 获取导出目录路径
  String get exportsPath => '${_dataDirectory.path}/exports';

  /// 读取 JSON 文件
  Future<List<Map<String, dynamic>>> readJsonLines(String filename) async {
    await _ensureInitialized();
    final file = File('${_dataDirectory.path}/$filename');
    
    if (!await file.exists()) {
      return [];
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return [];
    }

    // JSONL 格式：每行一个 JSON 对象
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty);
    return lines.map((line) => jsonDecode(line) as Map<String, dynamic>).toList();
  }

  /// 写入单条 JSON 记录（追加模式）
  Future<void> appendJsonLine(String filename, Map<String, dynamic> data) async {
    await _ensureInitialized();
    final file = File('${_dataDirectory.path}/$filename');
    
    final jsonLine = '${jsonEncode(data)}\n';
    await file.writeAsString(jsonLine, mode: FileMode.append);
  }

  /// 读取整个 JSON 文件
  Future<Map<String, dynamic>?> readJsonFile(String filename) async {
    await _ensureInitialized();
    final file = File('${_dataDirectory.path}/$filename');
    
    if (!await file.exists()) {
      return null;
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return null;
    }

    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// 写入整个 JSON 文件
  Future<void> writeJsonFile(String filename, Map<String, dynamic> data) async {
    await _ensureInitialized();
    final file = File('${_dataDirectory.path}/$filename');
    await file.writeAsString(jsonEncode(data));
  }

  /// 读取 JSON 数组文件
  Future<List<Map<String, dynamic>>> readJsonArray(String filename) async {
    await _ensureInitialized();
    final file = File('${_dataDirectory.path}/$filename');
    
    if (!await file.exists()) {
      return [];
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(content);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 写入 JSON 数组文件
  Future<void> writeJsonArray(String filename, List<Map<String, dynamic>> data) async {
    await _ensureInitialized();
    final file = File('${_dataDirectory.path}/$filename');
    await file.writeAsString(jsonEncode(data));
  }

  /// 导出文件到指定路径
  Future<void> exportFile(String filename, String destinationPath) async {
    await _ensureInitialized();
    final sourceFile = File('${_dataDirectory.path}/$filename');
    final destFile = File(destinationPath);
    
    if (await sourceFile.exists()) {
      await sourceFile.copy(destinationPath);
    }
  }

  /// 从指定路径导入文件
  Future<Map<String, dynamic>?> importJsonFile(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      return null;
    }

    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// 从指定路径导入 JSONL 文件
  Future<List<Map<String, dynamic>>> importJsonLines(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      return [];
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return [];
    }

    final lines = content.split('\n').where((l) => l.trim().isNotEmpty);
    return lines.map((line) => jsonDecode(line) as Map<String, dynamic>).toList();
  }

  /// 获取文件大小（字节）
  Future<int> getFileSize(String filename) async {
    await _ensureInitialized();
    final file = File('${_dataDirectory.path}/$filename');
    
    if (!await file.exists()) {
      return 0;
    }

    return await file.length();
  }

  /// 检查文件是否存在
  Future<bool> fileExists(String filename) async {
    await _ensureInitialized();
    final file = File('${_dataDirectory.path}/$filename');
    return await file.exists();
  }

  /// 删除文件
  Future<void> deleteFile(String filename) async {
    await _ensureInitialized();
    final file = File('${_dataDirectory.path}/$filename');
    
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 列出所有数据文件
  Future<List<String>> listFiles() async {
    await _ensureInitialized();
    final files = await _dataDirectory.list(recursive: true).toList();
    return files
        .whereType<File>()
        .map((f) => f.path.replaceFirst('${_dataDirectory.path}/', ''))
        .toList();
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }
}
