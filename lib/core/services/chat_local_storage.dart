import 'package:home_manager/core/services/local_storage_service.dart';
import 'package:home_manager/data/ai/ai_models.dart';

/// AI 聊天记录本地存储
/// 使用 JSONL 格式（每行一个 JSON）实现增量写入
class ChatLocalStorage {
  final LocalStorageService _storage = LocalStorageService.instance;

  /// 获取当前月份的聊天文件名称
  String _getCurrentFilename() {
    final now = DateTime.now();
    return 'chats_${now.year}-${now.month.toString().padLeft(2, '0')}.jsonl';
  }

  /// 根据日期获取文件名称
  String _getFilenameForDate(DateTime date) {
    return 'chats_${date.year}-${date.month.toString().padLeft(2, '0')}.jsonl';
  }

  /// 保存单条聊天消息
  Future<void> saveMessage(ChatMessage message) async {
    await _storage.appendJsonLine(
      _getCurrentFilename(),
      _messageToJson(message),
    );
  }

  /// 加载指定月份的所有聊天记录
  Future<List<ChatMessage>> loadMessages({int? year, int? month}) async {
    String filename;
    if (year != null && month != null) {
      filename = 'chats_${year}-${month.toString().padLeft(2, '0')}.jsonl';
    } else {
      filename = _getCurrentFilename();
    }

    final data = await _storage.readJsonLines(filename);
    return data.map((json) => _messageFromJson(json)).toList();
  }

  /// 加载所有月份的聊天记录
  Future<List<ChatMessage>> loadAllMessages() async {
    final files = await _storage.listFiles();
    final chatFiles = files.where((f) => f.startsWith('chats_') && f.endsWith('.jsonl'));
    
    final allMessages = <ChatMessage>[];
    
    for (final file in chatFiles) {
      final data = await _storage.readJsonLines(file);
      allMessages.addAll(data.map((json) => _messageFromJson(json)));
    }
    
    // 按时间排序
    allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return allMessages;
  }

  /// 导出聊天记录到指定路径
  Future<String> exportToFile(String destinationPath) async {
    final messages = await loadAllMessages();
    final data = messages.map((m) => _messageToJson(m)).toList();
    
    // 导出为标准 JSON 数组格式，更易于阅读和导入
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'totalMessages': messages.length,
      'messages': data,
    };
    
    final filename = 'chats_export_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}.json';
    final fullPath = '$destinationPath/$filename';
    
    await _storage.writeJsonFile('exports/$filename', exportData);
    
    return fullPath;
  }

  /// 从文件导入聊天记录
  Future<int> importFromFile(String sourcePath) async {
    final data = await _storage.importJsonLines(sourcePath);
    
    int imported = 0;
    for (final json in data) {
      try {
        final message = _messageFromJson(json);
        await saveMessage(message);
        imported++;
      } catch (e) {
        // 跳过无效记录
      }
    }
    
    return imported;
  }

  /// 获取当前文件大小
  Future<int> getCurrentFileSize() async {
    return await _storage.getFileSize(_getCurrentFilename());
  }

  /// 检查是否有聊天记录
  Future<bool> hasMessages() async {
    return await _storage.fileExists(_getCurrentFilename());
  }

  /// 清空指定月份的聊天记录
  Future<void> clearMessages({int? year, int? month}) async {
    String filename;
    if (year != null && month != null) {
      filename = 'chats_${year}-${month.toString().padLeft(2, '0')}.jsonl';
    } else {
      filename = _getCurrentFilename();
    }
    await _storage.deleteFile(filename);
  }

  Map<String, dynamic> _messageToJson(ChatMessage message) {
    return {
      'id': message.id,
      'content': message.content,
      'isUser': message.isUser,
      'timestamp': message.timestamp.toIso8601String(),
    };
  }

  ChatMessage _messageFromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
