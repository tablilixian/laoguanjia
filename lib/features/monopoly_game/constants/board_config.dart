// 地产大亨 - 棋盘配置常量
// 包含完整的40格棋盘数据、租金表、卡牌数据
// 
// 【重要】本文件已重构为兼容模式
// - boardCells 数据现在来自 themes/china_theme.dart
// - 如需使用其他主题，使用 themes/theme_provider.dart 中的 Provider
// 
// 【向后兼容】
// - 现有代码无需修改即可工作
// - 新功能请使用 themes/ 下的 Provider

import '../models/models.dart';

// 从主题系统导入确保兼容
// 导出主题系统中的所有可用内容
export 'themes/board_theme.dart';
export 'themes/china_theme.dart' show chinaTheme;
export 'themes/base_config.dart';

// 使用主题缓存获取动态主题数据
import 'themes/theme_provider.dart';

/// 完整的棋盘格子配置 (40格)
List<Cell> get boardCells => cachedCells;

/// 颜色组对应的地产索引（来自当前主题）
Map<PropertyColor, List<int>> get colorGroupProperties => cachedColorGroupMap;

/// 火车站租金表
const Map<int, int> railroadRentTable = {
  1: 25,
  2: 50,
  3: 100,
  4: 200,
};

/// 公用事业租金乘数
const Map<int, int> utilityRentMultiplier = {
  1: 4,
  2: 10,
};

/// 色组对应的颜色值
const Map<PropertyColor, int> propertyColorValues = {
  PropertyColor.brown: 0xFF8B4513,      // 棕色
  PropertyColor.lightBlue: 0xFF87CEEB, // 浅蓝
  PropertyColor.pink: 0xFFFF69B4,       // 粉色
  PropertyColor.orange: 0xFFFF8C00,     // 橙色
  PropertyColor.red: 0xFFE74C3C,         // 红色
  PropertyColor.yellow: 0xFFF1C40F,     // 黄色
  PropertyColor.green: 0xFF27AE60,       // 绿色
  PropertyColor.darkBlue: 0xFF1A5276,   // 深蓝
};

/// 玩家棋子颜色
const List<int> playerTokenColors = [
  0xFFE74C3C,  // 红色
  0xFF3498DB,  // 蓝色
  0xFF2ECC71,  // 绿色
  0xFFF39C12,  // 黄色
  0xFF9B59B6, // 紫色
  0xFF1ABC9C, // 青色
];

/// ============================================================================
/// 卡牌模板系统
/// 
/// 卡牌现在通过模板系统动态生成，自动适配当前选择的主题。
/// 
/// 【使用方式】
///   import '../constants/themes/base_cards.dart';
///   import '../constants/themes/theme_provider.dart';
///   
///   // 获取当前主题的卡牌
///   final theme = currentCachedTheme;
///   final chanceCards = buildChanceCards(theme);
///   final communityChestCards = buildCommunityChestCards(theme);
/// ============================================================================

/// 颜色组中文名称映射
const Map<PropertyColor, String> propertyColorNames = {
  PropertyColor.brown: '小城市',
  PropertyColor.lightBlue: '三线城市',
  PropertyColor.pink: '二线城市',
  PropertyColor.orange: '新一线城市',
  PropertyColor.red: '发达城市',
  PropertyColor.yellow: '特别行政区',
  PropertyColor.green: '特别行政区',
  PropertyColor.darkBlue: '首都',
};

/// 特殊格子索引常量
const int goIndex = 0;
const int jailIndex = 10;
const int freeParkingIndex = 20;
const int goToJailIndex = 30;

/// 火车站索引列表
const List<int> railroadIndices = [5, 15, 25, 35];

/// 公用事业索引列表
const List<int> utilityIndices = [12, 28];

/// 机会卡格子索引列表
const List<int> chanceIndices = [7, 22, 36];

/// 社区福利卡格子索引列表
const List<int> communityChestIndices = [2, 17, 33];

/// 税务格索引
const int incomeTaxIndex = 4;
const int luxuryTaxIndex = 38;