// 地产大亨 - 存档服务
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// 存档服务 - 负责游戏存档和读档
class SaveService {
  static const String _saveKey = 'monopoly_game_save';
  static const String _settingsKey = 'monopoly_game_settings';

  /// 保存游戏
  static Future<bool> saveGame(GameState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.toJson());
      return await prefs.setString(_saveKey, json);
    } catch (e) {
      print('保存游戏失败: $e');
      return false;
    }
  }

  /// 加载游戏
  static Future<GameState?> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_saveKey);
      if (json == null) return null;
      
      final data = jsonDecode(json) as Map<String, dynamic>;
      return GameState.fromJson(data);
    } catch (e) {
      print('加载游戏失败: $e');
      return null;
    }
  }

  /// 删除存档
  static Future<bool> deleteSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_saveKey);
    } catch (e) {
      print('删除存档失败: $e');
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
