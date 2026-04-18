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

  static Future<void> saveLastSyncTime(DateTime time) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setInt('last_sync_time', time.millisecondsSinceEpoch);
  }

  static Future<DateTime?> getLastSyncTime() async {
    _prefs ??= await SharedPreferences.getInstance();
    final timestamp = _prefs?.getInt('last_sync_time');
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// 自动同步开关 (默认开启)
  static const String _kAutoSyncEnabled = 'auto_sync_enabled';

  static Future<void> setAutoSyncEnabled(bool enabled) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(_kAutoSyncEnabled, enabled);
  }

  static Future<bool> isAutoSyncEnabled() async {
    _prefs ??= await SharedPreferences.getInstance();
    // 默认返回 true (开启自动同步)
    return _prefs?.getBool(_kAutoSyncEnabled) ?? true;
  }
}
