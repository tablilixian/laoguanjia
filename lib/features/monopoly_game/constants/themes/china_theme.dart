// 地产大亨 - 中国城市主题
// 
// 本主题使用中国城市地图，包含：
// - 28个中国城市（按城市等级分类）
// - 4个高铁站
// - 2个公用事业
// - 10个特殊格子
// 
// 【数据来源】
// 从原 board_config.dart 迁移，保持原有数值和名称不变。

import '../../models/models.dart';
import 'board_theme.dart';

/// ============================================================================
/// 主题元信息
/// ============================================================================

/// 中国城市主题元信息
const BoardThemeInfo chinaThemeInfo = BoardThemeInfo(
  id: 'china_cities',
  name: '中国城市',
  description: '经典的中国城市地图，包含各省省会城市',
  type: BoardThemeType.chinaCities,
);

/// ============================================================================
/// 28个地产配置（按颜色组分类）
/// ============================================================================

/// 棕色组 - 小城市（2格：索引1, 3）
const List<ThemeCellConfig> _brownProperties = [
  ThemeCellConfig(
    index: 1,
    name: '拉萨',
    color: PropertyColor.brown,
    price: 60,
    mortgageValue: 30,
    baseRent: 2,
    rentWithHouse: [10, 30, 90, 160, 250],
    housePrice: 50,
  ),
  ThemeCellConfig(
    index: 3,
    name: '西宁',
    color: PropertyColor.brown,
    price: 60,
    mortgageValue: 30,
    baseRent: 4,
    rentWithHouse: [20, 60, 180, 320, 450],
    housePrice: 50,
  ),
];

/// 浅蓝色组 - 三线城市（3格：索引6, 8, 9）
const List<ThemeCellConfig> _lightBlueProperties = [
  ThemeCellConfig(
    index: 6,
    name: '桂林',
    color: PropertyColor.lightBlue,
    price: 100,
    mortgageValue: 50,
    baseRent: 6,
    rentWithHouse: [30, 90, 270, 400, 550],
    housePrice: 50,
  ),
  ThemeCellConfig(
    index: 8,
    name: '三亚',
    color: PropertyColor.lightBlue,
    price: 100,
    mortgageValue: 50,
    baseRent: 6,
    rentWithHouse: [30, 90, 270, 400, 550],
    housePrice: 50,
  ),
  ThemeCellConfig(
    index: 9,
    name: '丽江',
    color: PropertyColor.lightBlue,
    price: 120,
    mortgageValue: 60,
    baseRent: 8,
    rentWithHouse: [40, 100, 300, 450, 600],
    housePrice: 50,
  ),
];

/// 粉色组 - 二线城市（3格：索引11, 13, 14）
const List<ThemeCellConfig> _pinkProperties = [
  ThemeCellConfig(
    index: 11,
    name: '成都',
    color: PropertyColor.pink,
    price: 140,
    mortgageValue: 70,
    baseRent: 10,
    rentWithHouse: [50, 150, 450, 625, 750],
    housePrice: 100,
  ),
  ThemeCellConfig(
    index: 13,
    name: '杭州',
    color: PropertyColor.pink,
    price: 140,
    mortgageValue: 70,
    baseRent: 10,
    rentWithHouse: [50, 150, 450, 625, 750],
    housePrice: 100,
  ),
  ThemeCellConfig(
    index: 14,
    name: '南京',
    color: PropertyColor.pink,
    price: 160,
    mortgageValue: 80,
    baseRent: 12,
    rentWithHouse: [60, 180, 500, 700, 900],
    housePrice: 100,
  ),
];

/// 橙色组 - 新一线城市（3格：索引16, 18, 19）
const List<ThemeCellConfig> _orangeProperties = [
  ThemeCellConfig(
    index: 16,
    name: '武汉',
    color: PropertyColor.orange,
    price: 180,
    mortgageValue: 90,
    baseRent: 14,
    rentWithHouse: [70, 200, 550, 750, 950],
    housePrice: 100,
  ),
  ThemeCellConfig(
    index: 18,
    name: '西安',
    color: PropertyColor.orange,
    price: 180,
    mortgageValue: 90,
    baseRent: 14,
    rentWithHouse: [70, 200, 550, 750, 950],
    housePrice: 100,
  ),
  ThemeCellConfig(
    index: 19,
    name: '重庆',
    color: PropertyColor.orange,
    price: 200,
    mortgageValue: 100,
    baseRent: 16,
    rentWithHouse: [80, 220, 600, 800, 1000],
    housePrice: 100,
  ),
];

/// 红色组 - 发达城市（3格：索引21, 23, 24）
const List<ThemeCellConfig> _redProperties = [
  ThemeCellConfig(
    index: 21,
    name: '广州',
    color: PropertyColor.red,
    price: 220,
    mortgageValue: 110,
    baseRent: 18,
    rentWithHouse: [90, 250, 700, 875, 1050],
    housePrice: 150,
  ),
  ThemeCellConfig(
    index: 23,
    name: '深圳',
    color: PropertyColor.red,
    price: 220,
    mortgageValue: 110,
    baseRent: 18,
    rentWithHouse: [90, 250, 700, 875, 1050],
    housePrice: 150,
  ),
  ThemeCellConfig(
    index: 24,
    name: '上海',
    color: PropertyColor.red,
    price: 240,
    mortgageValue: 120,
    baseRent: 20,
    rentWithHouse: [100, 300, 750, 925, 1100],
    housePrice: 150,
  ),
];

/// 黄色组 - 特别行政区（3格：索引26, 27, 29）
const List<ThemeCellConfig> _yellowProperties = [
  ThemeCellConfig(
    index: 26,
    name: '苏州',
    color: PropertyColor.yellow,
    price: 260,
    mortgageValue: 130,
    baseRent: 22,
    rentWithHouse: [110, 330, 800, 975, 1150],
    housePrice: 150,
  ),
  ThemeCellConfig(
    index: 27,
    name: '天津',
    color: PropertyColor.yellow,
    price: 260,
    mortgageValue: 130,
    baseRent: 22,
    rentWithHouse: [110, 330, 800, 975, 1150],
    housePrice: 150,
  ),
  ThemeCellConfig(
    index: 29,
    name: '青岛',
    color: PropertyColor.yellow,
    price: 280,
    mortgageValue: 140,
    baseRent: 24,
    rentWithHouse: [120, 360, 850, 1025, 1200],
    housePrice: 150,
  ),
];

/// 绿色组 - 特别行政区（3格：索引31, 32, 34）
const List<ThemeCellConfig> _greenProperties = [
  ThemeCellConfig(
    index: 31,
    name: '香港',
    color: PropertyColor.green,
    price: 300,
    mortgageValue: 150,
    baseRent: 26,
    rentWithHouse: [130, 390, 900, 1100, 1275],
    housePrice: 200,
  ),
  ThemeCellConfig(
    index: 32,
    name: '澳门',
    color: PropertyColor.green,
    price: 300,
    mortgageValue: 150,
    baseRent: 26,
    rentWithHouse: [130, 390, 900, 1100, 1275],
    housePrice: 200,
  ),
  ThemeCellConfig(
    index: 34,
    name: '台北',
    color: PropertyColor.green,
    price: 320,
    mortgageValue: 160,
    baseRent: 28,
    rentWithHouse: [150, 450, 1000, 1200, 1400],
    housePrice: 200,
  ),
];

/// 深蓝色组 - 首都（2格：索引37, 39）
const List<ThemeCellConfig> _darkBlueProperties = [
  ThemeCellConfig(
    index: 37,
    name: '北京',
    color: PropertyColor.darkBlue,
    price: 350,
    mortgageValue: 175,
    baseRent: 35,
    rentWithHouse: [175, 500, 1100, 1300, 1500],
    housePrice: 200,
  ),
  ThemeCellConfig(
    index: 39,
    name: '自贸区',
    color: PropertyColor.darkBlue,
    price: 400,
    mortgageValue: 200,
    baseRent: 50,
    rentWithHouse: [200, 600, 1400, 1700, 2000],
    housePrice: 200,
  ),
];

/// 所有地产配置（合并8个颜色组，共28格）
List<ThemeCellConfig> get chinaProperties => [
  ..._brownProperties,
  ..._lightBlueProperties,
  ..._pinkProperties,
  ..._orangeProperties,
  ..._redProperties,
  ..._yellowProperties,
  ..._greenProperties,
  ..._darkBlueProperties,
];

/// ============================================================================
/// 10个特殊格子配置
/// ============================================================================

/// 特殊格子配置列表
const List<ThemeSpecialCellConfig> chinaSpecialCells = [
  // 索引0: 起点
  ThemeSpecialCellConfig(index: 0, name: '祖国华诞', type: CellType.go),
  // 索引2: 公益卡
  ThemeSpecialCellConfig(index: 2, name: '公益', type: CellType.communityChest),
  // 索引4: 所得税
  ThemeSpecialCellConfig(index: 4, name: '所得税', type: CellType.incomeTax),
  // 索引7: 命运卡
  ThemeSpecialCellConfig(index: 7, name: '命运', type: CellType.chance),
  // 索引10: 监狱（仅路过）
  ThemeSpecialCellConfig(index: 10, name: '派出所', type: CellType.jail),
  // 索引17: 公益卡
  ThemeSpecialCellConfig(index: 17, name: '公益', type: CellType.communityChest),
  // 索引20: 免费停车
  ThemeSpecialCellConfig(index: 20, name: '人民广场', type: CellType.freeParking),
  // 索引22: 命运卡
  ThemeSpecialCellConfig(index: 22, name: '命运', type: CellType.chance),
  // 索引30: 前往监狱
  ThemeSpecialCellConfig(index: 30, name: '前往监狱', type: CellType.goToJail),
  // 索引33: 公益卡
  ThemeSpecialCellConfig(index: 33, name: '公益', type: CellType.communityChest),
  // 索引36: 命运卡
  ThemeSpecialCellConfig(index: 36, name: '命运', type: CellType.chance),
  // 索引38: 消费税
  ThemeSpecialCellConfig(index: 38, name: '消费税', type: CellType.luxuryTax),
];

/// ============================================================================
/// 6个站点配置（4火车站 + 2公用事业）
/// ============================================================================

/// 站点配置列表
const List<ThemeStationCellConfig> chinaStations = [
  // 火车站
  ThemeStationCellConfig(
    index: 5,
    name: '北京南站',
    type: CellType.railroad,
    price: 200,
    mortgageValue: 100,
    stationIndex: 0,
  ),
  ThemeStationCellConfig(
    index: 15,
    name: '虹桥站',
    type: CellType.railroad,
    price: 200,
    mortgageValue: 100,
    stationIndex: 1,
  ),
  ThemeStationCellConfig(
    index: 25,
    name: '广州南站',
    type: CellType.railroad,
    price: 200,
    mortgageValue: 100,
    stationIndex: 2,
  ),
  ThemeStationCellConfig(
    index: 35,
    name: '成都东站',
    type: CellType.railroad,
    price: 200,
    mortgageValue: 100,
    stationIndex: 3,
  ),
  // 公用事业
  ThemeStationCellConfig(
    index: 12,
    name: '国家电网',
    type: CellType.utility,
    price: 150,
    mortgageValue: 75,
  ),
  ThemeStationCellConfig(
    index: 28,
    name: '中国石化',
    type: CellType.utility,
    price: 150,
    mortgageValue: 75,
  ),
];

/// ============================================================================
/// 颜色组映射
/// ============================================================================

/// 颜色组对应的格子索引
const Map<PropertyColor, List<int>> chinaColorGroupMap = {
  PropertyColor.brown: [1, 3],
  PropertyColor.lightBlue: [6, 8, 9],
  PropertyColor.pink: [11, 13, 14],
  PropertyColor.orange: [16, 18, 19],
  PropertyColor.red: [21, 23, 24],
  PropertyColor.yellow: [26, 27, 29],
  PropertyColor.green: [31, 32, 34],
  PropertyColor.darkBlue: [37, 39],
};

/// ============================================================================
/// 完整主题配置
/// ============================================================================

/// 合并所有地产配置
final List<ThemeCellConfig> _allChinaProperties = [
  ..._brownProperties,
  ..._lightBlueProperties,
  ..._pinkProperties,
  ..._orangeProperties,
  ..._redProperties,
  ..._yellowProperties,
  ..._greenProperties,
  ..._darkBlueProperties,
];

/// 中国城市主题
/// 用于游戏初始化和卡牌构建
final BoardTheme chinaTheme = BoardTheme(
  info: chinaThemeInfo,
  properties: _allChinaProperties,
  specialCells: chinaSpecialCells,
  stations: chinaStations,
  colorGroupMap: chinaColorGroupMap,
);

/// ============================================================================
/// 便捷函数
/// ============================================================================

/// 获取中国城市的Cell列表
/// 用于游戏初始化
List<Cell> buildChinaCells() => chinaTheme.buildCells();

/// 获取颜色组对应的地产索引
Map<PropertyColor, List<int>> getChinaColorGroupMap() => chinaColorGroupMap;