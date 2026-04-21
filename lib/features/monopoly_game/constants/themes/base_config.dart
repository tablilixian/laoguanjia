// 地产大亨 - 基础配置
// 
// 本文件包含游戏的基础配置，与主题无关的内容：
// - 地产颜色组对应的颜色值（ARGB）
// - 颜色组的中文名称
// - 火车站租金表
// - 公用事业租金乘数
// - 玩家棋子颜色
// - 特殊格子索引常量
// 
// 【注意】
// 这些配置是全局统一的，不随主题变化。

import '../../models/models.dart';

/// ============================================================================
/// 地产颜色组配置
/// ============================================================================

/// 颜色组对应的颜色值（ARGB格式）
/// 用于棋盘渲染，颜色组与主题无关
const Map<PropertyColor, int> propertyColorValues = {
  PropertyColor.brown: 0xFF8B4513,      // 棕色 - 小城市
  PropertyColor.lightBlue: 0xFF87CEEB,   // 浅蓝 - 三线城市
  PropertyColor.pink: 0xFFFF69B4,      // 粉色 - 二线城市
  PropertyColor.orange: 0xFFFF8C00,    // 橙色 - 新一线城市
  PropertyColor.red: 0xFFE74C3C,        // 红色 - 发达城市
  PropertyColor.yellow: 0xFFF1C40F,    // 黄色 - 特别行政区
  PropertyColor.green: 0xFF27AE60,     // 绿色 - 特别行政区
  PropertyColor.darkBlue: 0xFF1A5276,  // 深蓝 - 首都
};

/// 颜色组对应的中文名称
/// 用于UI显示，与主题无关
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

/// ============================================================================
/// 租金配置
/// ============================================================================

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

/// ============================================================================
/// 玩家配置
/// ============================================================================

/// 玩家棋子颜色列表
const List<int> playerTokenColors = [
  0xFFE74C3C,  // 红色
  0xFF3498DB,  // 蓝色
  0xFF2ECC71,  // 绿色
  0xFFF39C12, // 黄色
  0xFF9B59B6, // 紫色
  0xFF1ABC9C, // 青色
];

/// ============================================================================
/// 特殊格子索引常量
/// ============================================================================

const int goIndex = 0;
const int jailIndex = 10;
const int freeParkingIndex = 20;
const int goToJailIndex = 30;
const int incomeTaxIndex = 4;
const int luxuryTaxIndex = 38;
const List<int> defaultRailroadIndices = [5, 15, 25, 35];
const List<int> defaultUtilityIndices = [12, 28];
const List<int> chanceIndices = [7, 22, 36];
const List<int> communityChestIndices = [2, 17, 33];

/// ============================================================================
/// 棋子配置
/// ============================================================================

const double tokenSizeRatio = 0.35;
const double tokenSpacingRatio = 0.3;