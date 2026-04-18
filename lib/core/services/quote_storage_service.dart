import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 每日一言存储服务
/// 
/// 功能：
/// - 保存历史记录（最多 500 条，超过自动删除旧的）
/// - 保存用户偏好的分类设置（使用 SharedPreferences）
/// - 支持分类轮换获取
/// 
/// 存储方式：
/// - Android/iOS：本地 JSON 文件
/// - Web：内存存储（不持久化）
/// 
/// Hitokoto API 分类参考：
/// - a: 动画, b: 漫画, c: 游戏, d: 文学, e: 原创
/// - f: 来自网络, g: 其他, h: 影视, i: 诗词, j: 网易云
/// - k: 哲学, l: 抖机灵
class QuoteStorageService {
  static QuoteStorageService? _instance;
  
  // 文件名和限制
  static const String _fileName = 'quote_history.json';
  static const int maxHistory = 500;      // 最多保存 500 条
  static const int displayLimit = 100;     // 列表显示 100 条
  static const String _prefKeyCategories = 'quote_categories';  // SharedPreferences key

  // 内部状态
  List<Map<String, dynamic>> _quotes = [];   // 历史记录列表
  bool _initialized = false;
  String _filePath = '';              // 文件路径
  SharedPreferences? _prefs;        // SharedPreferences 实例
  bool get _isWeb => kIsWeb;        // 是否 Web 平台

  QuoteStorageService._();

  static QuoteStorageService get instance {
    _instance ??= QuoteStorageService._();
    return _instance!;
  }

  /// 初始化
  Future<void> init() async {
    if (_initialized) return;

    // 加载用户偏好
    _prefs = await SharedPreferences.getInstance();
    _preferredCategories = _prefs?.getStringList(_prefKeyCategories) ?? [];

    if (_isWeb) {
      _quotes = [];
    } else {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        _filePath = '${appDir.path}/home_manager_data/$_fileName';
        await _loadFromFile();
      } catch (_) {}
    }
    _initialized = true;
  }

  /// 从文件加载历史
  Future<void> _loadFromFile() async {
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = json.decode(content) as List;
        _quotes = list.cast<Map<String, dynamic>>();
      }
    } catch (_) {
      _quotes = [];
    }
  }

  /// 保存到文件
  Future<void> _saveToFile() async {
    if (_isWeb) return;
    try {
      final file = File(_filePath);
      await file.writeAsString(json.encode(_quotes));
    } catch (_) {}
  }

  /// 保存新句子
  Future<void> addQuote({
    required String quote,
    required String category,
  }) async {
    final now = DateTime.now();
    final record = {
      'quote': quote,
      'category': category,
      'createdAt': now.toIso8601String(),
      'timestamp': now.millisecondsSinceEpoch,
    };

    _quotes.insert(0, record);
    if (_quotes.length > maxHistory) {
      _quotes = _quotes.sublist(0, maxHistory);
    }

    await _saveToFile();
  }

  /// 获取显示的历史 (最近 100 条)
  List<Map<String, dynamic>> get displayHistory {
    if (_quotes.length <= displayLimit) return List.from(_quotes);
    return _quotes.sublist(0, displayLimit);
  }

  /// 所有分类
  static const Map<String, String> allCategories = {
    'a': '动画',
    'b': '漫画',
    'c': '游戏',
    'd': '文学',
    'e': '原创',
    'f': '来自网络',
    'g': '其他',
    'h': '影视',
    'i': '诗词',
    'j': '网易云',
    'k': '哲学',
    'l': '抖机灵',
  };

  /// 获取分类名称
  String getCategoryName(String category) {
    return allCategories[category] ?? category;
  }

  /// 用户偏好的分类列表
  List<String> _preferredCategories = [];

  List<String> get preferredCategories =>
      _preferredCategories.isEmpty ? defaultCategories : _preferredCategories;

  static const List<String> defaultCategories = ['k', 'i', 'f'];

  /// 设置用户偏好的分类
  Future<void> setPreferredCategories(List<String> categories) async {
    _preferredCategories = categories;
    _categoryIndex = 0;
    await _prefs?.setStringList(_prefKeyCategories, categories);
  }

  int _categoryIndex = -1;

  /// 获取下一个分类 - 基于用户偏好轮换
  String getNextCategory() {
    final list = preferredCategories;
    if (list.isEmpty) {
      _categoryIndex = (_categoryIndex + 1) % defaultCategories.length;
      return defaultCategories[_categoryIndex];
    }
    _categoryIndex = (_categoryIndex + 1) % list.length;
    return list[_categoryIndex];
  }

  int get totalCount => _quotes.length;
}