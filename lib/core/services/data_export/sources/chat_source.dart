import 'package:flutter/material.dart';
import 'package:home_manager/core/services/chat_local_storage.dart';
import 'package:home_manager/data/ai/ai_models.dart';
import '../data_export_source.dart';

class ChatSource implements DataExportSource {
  final ChatLocalStorage _storage = ChatLocalStorage();

  @override
  String get id => 'chat';

  @override
  String get name => '聊天记录';

  @override
  String get description => 'AI 聊天消息历史';

  @override
  IconData get icon => Icons.chat_outlined;

  @override
  Future<bool> hasData() async {
    return _storage.hasMessages();
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    final messages = await _storage.loadAllMessages();
    return {
      'chat': {
        'messages': messages.map((m) => _messageToJson(m)).toList(),
        '_meta': {'totalMessages': messages.length},
      },
    };
  }

  @override
  Future<ImportSummary> importData(Map<String, dynamic> data) async {
    try {
      final messages = data['messages'] as List;
      int imported = 0;
      for (final json in messages) {
        final map = json as Map<String, dynamic>;
        await _storage.saveMessage(_messageFromJson(map));
        imported++;
      }
      return ImportSummary(
        success: true,
        itemCount: imported,
        message: '已导入 $imported 条聊天记录',
      );
    } catch (e) {
      return ImportSummary(success: false, itemCount: 0, message: '导入聊天记录失败: $e');
    }
  }

  Map<String, dynamic> _messageToJson(ChatMessage m) => {
        'id': m.id,
        'content': m.content,
        'isUser': m.isUser,
        'timestamp': m.timestamp.toIso8601String(),
      };

  ChatMessage _messageFromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        content: json['content'] as String,
        isUser: json['isUser'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
