// 地产大亨 - 主题状态管理
// 
// 本文件提供主题相关的 Riverpod Provider，用于：
// - 管理当前选中的主题
// - 提供可用主题列表
// - 主题偏好持久化
// 
// 【使用方式】
// 1. 在 App 入口获取/设置主题：
//    final selectedTheme = ref.read(selectedThemeProvider);
// 2. 在游戏初始化时获取主题：
//    final theme = ref.read(currentThemeProvider);
// 3. 在UI中显示主题选择：
//    final themes = ref.watch(availableThemesProvider);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import 'board_theme.dart';
import 'china_theme.dart';
import 'international_theme.dart';
import 'song_theme.dart';

/// ============================================================================
/// 常量定义
/// ============================================================================

/// 存储键名
const String _themeIdKey = 'selected_board_theme';

/// 默认主题ID
const String _defaultThemeId = 'china_cities';

/// ============================================================================
/// 全局缓存（供非Riverpod代码使用）
/// ============================================================================

/// 当前选中的主题ID（全局缓存，用于非Provider上下文）
String _cachedThemeId = _defaultThemeId;

/// 当前主题的Cell列表（全局缓存）
List<Cell> _cachedCells = chinaTheme.buildCells();

/// 当前主题的颜色组映射（全局缓存）
Map<PropertyColor, List<int>> _cachedColorGroupMap = chinaTheme.colorGroupMap;

/// 设置缓存的主题（当用户选择主题时调用）
void _setCachedTheme(BoardTheme theme) {
  _cachedThemeId = theme.info.id;
  _cachedCells = theme.buildCells();
  _cachedColorGroupMap = theme.colorGroupMap;
}

/// 获取当前主题的Cell列表（供board_config.dart使用）
List<Cell> get cachedCells => _cachedCells;

/// 获取当前主题的颜色组映射（供board_config.dart使用）
Map<PropertyColor, List<int>> get cachedColorGroupMap => _cachedColorGroupMap;

/// ============================================================================
/// Provider 定义
/// ============================================================================

/// 可用主题列表 Provider
/// 提供所有可用的主题，供UI选择使用
final availableThemesProvider = Provider<List<BoardTheme>>((ref) {
  return [
    chinaTheme,       // 中国城市（默认）
    internationalTheme, // 美国版
    songTheme,       // 宋代主题
    // 未来可添加更多主题...
  ];
});

/// 当前选中的主题ID Provider
/// 用于持久化存储和切换
final selectedThemeIdProvider = StateNotifierProvider<SelectedThemeNotifier, String>((ref) {
  return SelectedThemeNotifier();
});

/// 当前主题 Provider
/// 根据 selectedThemeIdProvider 获取当前选中的主题
final currentThemeProvider = Provider<BoardTheme>((ref) {
  final themeId = ref.watch(selectedThemeIdProvider);
  final themes = ref.watch(availableThemesProvider);
  
  return themes.firstWhere(
    (t) => t.info.id == themeId,
    orElse: () => themes.first,
  );
});

/// 当前主题的Cell列表 Provider
/// 用于游戏初始化
final currentCellsProvider = Provider<List<Cell>>((ref) {
  final theme = ref.watch(currentThemeProvider);
  return theme.buildCells();
});

/// 当前主题的颜色组映射 Provider
final currentColorGroupMapProvider = Provider<Map<PropertyColor, List<int>>>((ref) {
  final theme = ref.watch(currentThemeProvider);
  return theme.colorGroupMap;
});

/// ============================================================================
/// 主题选择状态管理
/// ============================================================================

/// 主题选择状态管理类
/// 支持持久化存储
class SelectedThemeNotifier extends StateNotifier<String> {
  /// SharedPreferences 实例
  SharedPreferences? _prefs;
  
  SelectedThemeNotifier() : super(_defaultThemeId) {
    _init();
  }
  
  /// 异步初始化
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedThemeId = _prefs?.getString(_themeIdKey);
    if (savedThemeId != null && savedThemeId.isNotEmpty) {
      state = savedThemeId;
    }
    // 初始化全局缓存
    _initializeCache();
  }
  
  /// 初始化全局缓存
  void _initializeCache() {
    final themes = [
      chinaTheme,
      internationalTheme,
      songTheme,
    ];
    final theme = themes.firstWhere(
      (t) => t.info.id == state,
      orElse: () => chinaTheme,
    );
    _setCachedTheme(theme);
  }
  
  /// 设置主题
  /// [themeId]: 主题ID
  Future<void> setTheme(String themeId) async {
    state = themeId;
    await _prefs?.setString(_themeIdKey, themeId);
    // 更新全局缓存
    final themes = [
      chinaTheme,
      internationalTheme,
      songTheme,
    ];
    final theme = themes.firstWhere(
      (t) => t.info.id == themeId,
      orElse: () => chinaTheme,
    );
    _setCachedTheme(theme);
  }
  
  /// 重置为默认主题
  Future<void> resetToDefault() async {
    await setTheme(_defaultThemeId);
  }
}

/// ============================================================================
/// 便捷函数
/// ============================================================================

/// 获取当前主题（全局缓存版本）
/// 供非Riverpod上下文的代码使用（如静态方法、Service类等）
/// 注意：此方法返回的是缓存的主题，切换主题后需手动刷新
BoardTheme get currentCachedTheme {
  final themes = [
    chinaTheme,
    internationalTheme,
    songTheme,
  ];
  return themes.firstWhere(
    (t) => t.info.id == _cachedThemeId,
    orElse: () => chinaTheme,
  );
}

/// 根据主题ID获取主题
/// [themeId]: 主题ID
BoardTheme? getThemeById(String themeId, List<BoardTheme> themes) {
  return themes.firstWhere(
    (t) => t.info.id == themeId,
    orElse: () => themes.first,
  );
}

/// 获取主题的显示名称
/// [themeId]: 主题ID
String getThemeDisplayName(String themeId) {
  switch (themeId) {
    case 'china_cities':
      return '中国城市';
    case 'international':
      return '美国版';
    case 'song_dynasty':
      return '大宋疆域';
    default:
      return themeId;
  }
}