// 地产大亨 - 存档服务
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/logger.dart';
import '../models/models.dart';

/// 存档服务 - 负责游戏存档和读档
class SaveService {
  static const String _saveKey = 'monopoly_game_save';
  static const String _settingsKey = 'monopoly_game_settings';
  static const String _logsKey = 'monopoly_game_logs';
  static const String _gameLogsKey = 'monopoly_game_game_logs';

  /// 保存游戏
  static Future<bool> saveGame(GameState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameData = state.toJson();
      
      final json = jsonEncode(gameData);
      final result = await prefs.setString(_saveKey, json);
      
      // 保存日志记录
      final logs = AppLogger.getLogRecords();
      final logsJson = jsonEncode(logs.map((log) => {
        'timestamp': log.timestamp.toIso8601String(),
        'tag': log.tag,
        'level': log.level.index,
        'message': log.message,
      }).toList());
      await prefs.setString(_logsKey, logsJson);
      
      // 保存 GameLogger 日志
      final gameLogs = GameLogger.exportToJson();
      final gameLogsJson = jsonEncode(gameLogs);
      await prefs.setString(_gameLogsKey, gameLogsJson);
      
      // 添加到游戏操作列表
      AppLogger.info('游戏已保存 - 第 ${gameData['turnNumber']} 回合');
      
      return result;
    } catch (e) {
      AppLogger.error('保存游戏失败: $e');
      return false;
    }
  }

  /// 加载游戏
  static Future<GameState?> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final json = prefs.getString(_saveKey);
      if (json == null) {
        return null;
      }
      
      final data = jsonDecode(json) as Map<String, dynamic>;
      final gameState = GameState.fromJson(data);
      
      // 加载日志记录
      final logsJson = prefs.getString(_logsKey);
      if (logsJson != null) {
        final logsData = jsonDecode(logsJson) as List;
        // 清空现有日志
        AppLogger.clearLogRecords();
        // 恢复日志记录
        for (var logData in logsData) {
          // 根据日志级别使用对应的公共方法
          final level = LogLevel.values[logData['level']];
          switch (level) {
            case LogLevel.debug:
              AppLogger.debug(logData['message'], tag: logData['tag']);
              break;
            case LogLevel.info:
              AppLogger.info(logData['message'], tag: logData['tag']);
              break;
            case LogLevel.warning:
              AppLogger.warning(logData['message'], tag: logData['tag']);
              break;
            case LogLevel.error:
              AppLogger.error(logData['message'], tag: logData['tag']);
              break;
          }
        }
      }
      
      // 加载 GameLogger 日志
      final gameLogsJson = prefs.getString(_gameLogsKey);
      if (gameLogsJson != null) {
        final gameLogsData = jsonDecode(gameLogsJson) as List;
        GameLogger.clear();
        GameLogger.importFromJson(gameLogsData.cast<Map<String, dynamic>>());
      }
      
      // 添加到游戏操作列表
      AppLogger.info('游戏已加载 - 第 ${data['turnNumber']} 回合');
      
      return gameState;
    } catch (e) {
      AppLogger.error('加载游戏失败: $e');
      return null;
    }
  }

  /// 删除存档
  static Future<bool> deleteSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_saveKey);
      await prefs.remove(_logsKey);
      await prefs.remove(_gameLogsKey);
      // 清空日志记录
      AppLogger.clearLogRecords();
      GameLogger.clear();
      return true;
    } catch (e) {
      AppLogger.error('删除存档失败: $e');
      return false;
    }
  }

  /// 检查是否有存档
  static Future<bool> hasSave() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_saveKey);
  }

  /// 保存游戏设置
  static Future<bool> saveSettings(GameSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(settings.toJson());
      return await prefs.setString(_settingsKey, json);
    } catch (e) {
      print('保存设置失败: $e');
      return false;
    }
  }

  /// 加载游戏设置
  static Future<GameSettings?> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_settingsKey);
      if (json == null) return null;
      
      final data = jsonDecode(json) as Map<String, dynamic>;
      return GameSettings.fromJson(data);
    } catch (e) {
      print('加载设置失败: $e');
      return null;
    }
  }
}
