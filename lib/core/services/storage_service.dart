import 'package:shared_preferences/shared_preferences.dart';

/// 统一存储服务
/// 使用 SharedPreferences，支持 Web/Android/iOS 平台
class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    _instance ??= StorageService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // 字符串操作
  Future<String?> getString(String key) async {
    return _prefs?.getString(key);
  }

  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  // 布尔操作
  Future<bool?> getBool(String key) async {
    return _prefs?.getBool(key);
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  // 整数操作
  Future<int?> getInt(String key) async {
    return _prefs?.getInt(key);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  // 检查键是否存在
  Future<bool> containsKey(String key) async {
    return _prefs?.containsKey(key) ?? false;
  }
}
