// 地产大亨 - 宋代主题
// 
// 本主题使用宋代州府地图，包含：
// - 28个宋代州府（按州府等级分类）
// - 4个驿站
// - 2个官营事业
// - 10个特殊格子
// 
// 【设计说明】
// 基于宋代州府制度设计，使用当时著名的州府城市。
// 价格和租金与中国版保持相同的相对比例。

import '../../models/models.dart';
import 'board_theme.dart';

/// ============================================================================
/// 主题元信息
/// ============================================================================

/// 宋代主题元信息
const BoardThemeInfo songThemeInfo = BoardThemeInfo(
  id: 'song_dynasty',
  name: '大宋疆域',
  description: '宋代州府地图 - 繁华大宋，锦绣山河',
  type: BoardThemeType.custom, // 使用 custom 类型，预留 europe 可后续添加
);

/// ============================================================================
/// 28个地产配置（按颜色组分类）
/// ============================================================================

/// 棕色组 - 下等州（2格：索引1, 3）
const List<ThemeCellConfig> _brownProperties = [
  ThemeCellConfig(
    index: 1,
    name: '鼎州',
    color: PropertyColor.brown,
    price: 60,
    mortgageValue: 30,
    baseRent: 2,
    rentWithHouse: [10, 30, 90, 160, 250],
    housePrice: 50,
  ),
  ThemeCellConfig(
    index: 3,
    name: '澧州',
    color: PropertyColor.brown,
    price: 60,
    mortgageValue: 30,
    baseRent: 4,
    rentWithHouse: [20, 60, 180, 320, 450],
    housePrice: 50,
  ),
];

/// 浅蓝色组 - 中下州（3格：索引6, 8, 9）
const List<ThemeCellConfig> _lightBlueProperties = [
  ThemeCellConfig(
    index: 6,
    name: '鼎湖',
    color: PropertyColor.lightBlue,
    price: 100,
    mortgageValue: 50,
    baseRent: 6,
    rentWithHouse: [30, 90, 270, 400, 550],
    housePrice: 50,
  ),
  ThemeCellConfig(
    index: 8,
    name: '雷州',
    color: PropertyColor.lightBlue,
    price: 100,
    mortgageValue: 50,
    baseRent: 6,
    rentWithHouse: [30, 90, 270, 400, 550],
    housePrice: 50,
  ),
  ThemeCellConfig(
    index: 9,
    name: '化州',
    color: PropertyColor.lightBlue,
    price: 120,
    mortgageValue: 60,
    baseRent: 8,
    rentWithHouse: [40, 100, 300, 450, 600],
    housePrice: 50,
  ),
];

/// 粉色组 - 中等州（3格：索引11, 13, 14）
const List<ThemeCellConfig> _pinkProperties = [
  ThemeCellConfig(
    index: 11,
    name: '成都府',
    color: PropertyColor.pink,
    price: 140,
    mortgageValue: 70,
    baseRent: 10,
    rentWithHouse: [50, 150, 450, 625, 750],
    housePrice: 100,
  ),
  ThemeCellConfig(
    index: 13,
    name: '江陵府',
    color: PropertyColor.pink,
    price: 140,
    mortgageValue: 70,
    baseRent: 10,
    rentWithHouse: [50, 150, 450, 625, 750],
    housePrice: 100,
  ),
  ThemeCellConfig(
    index: 14,
    name: '扬州',
    color: PropertyColor.pink,
    price: 160,
    mortgageValue: 80,
    baseRent: 12,
    rentWithHouse: [60, 180, 500, 700, 900],
    housePrice: 100,
  ),
];

/// 橙色组 - 中上州（3格：索引16, 18, 19）
const List<ThemeCellConfig> _orangeProperties = [
  ThemeCellConfig(
    index: 16,
    name: '苏州',
    color: PropertyColor.orange,
    price: 180,
    mortgageValue: 90,
    baseRent: 14,
    rentWithHouse: [70, 200, 550, 750, 950],
    housePrice: 100,
  ),
  ThemeCellConfig(
    index: 18,
    name: '杭州',
    color: PropertyColor.orange,
    price: 180,
    mortgageValue: 90,
    baseRent: 14,
    rentWithHouse: [70, 200, 550, 750, 950],
    housePrice: 100,
  ),
  ThemeCellConfig(
    index: 19,
    name: '福州',
    color: PropertyColor.orange,
    price: 200,
    mortgageValue: 100,
    baseRent: 16,
    rentWithHouse: [80, 220, 600, 800, 1000],
    housePrice: 100,
  ),
];

/// 红色组 - 上州（3格：索引21, 23, 24）
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
    name: '泉州',
    color: PropertyColor.red,
    price: 220,
    mortgageValue: 110,
    baseRent: 18,
    rentWithHouse: [90, 250, 700, 875, 1050],
    housePrice: 150,
  ),
  ThemeCellConfig(
    index: 24,
    name: '明州',
    color: PropertyColor.red,
    price: 240,
    mortgageValue: 120,
    baseRent: 20,
    rentWithHouse: [100, 300, 750, 925, 1100],
    housePrice: 150,
  ),
];

/// 黄色组 - 紧要州（3格：索引26, 27, 29）
const List<ThemeCellConfig> _yellowProperties = [
  ThemeCellConfig(
    index: 26,
    name: '长安',
    color: PropertyColor.yellow,
    price: 260,
    mortgageValue: 130,
    baseRent: 22,
    rentWithHouse: [110, 330, 800, 975, 1150],
    housePrice: 150,
  ),
  ThemeCellConfig(
    index: 27,
    name: '洛阳',
    color: PropertyColor.yellow,
    price: 260,
    mortgageValue: 130,
    baseRent: 22,
    rentWithHouse: [110, 330, 800, 975, 1150],
    housePrice: 150,
  ),
  ThemeCellConfig(
    index: 29,
    name: '开封府',
    color: PropertyColor.yellow,
    price: 280,
    mortgageValue: 140,
    baseRent: 24,
    rentWithHouse: [120, 360, 850, 1025, 1200],
    housePrice: 150,
  ),
];

/// 绿色组 - 次繁庶州（3格：索引31, 32, 34）
const List<ThemeCellConfig> _greenProperties = [
  ThemeCellConfig(
    index: 31,
    name: '郓州',
    color: PropertyColor.green,
    price: 300,
    mortgageValue: 150,
    baseRent: 26,
    rentWithHouse: [130, 390, 900, 1100, 1275],
    housePrice: 200,
  ),
  ThemeCellConfig(
    index: 32,
    name: '济州',
    color: PropertyColor.green,
    price: 300,
    mortgageValue: 150,
    baseRent: 26,
    rentWithHouse: [130, 390, 900, 1100, 1275],
    housePrice: 200,
  ),
  ThemeCellConfig(
    index: 34,
    name: '大名府',
    color: PropertyColor.green,
    price: 320,
    mortgageValue: 160,
    baseRent: 28,
    rentWithHouse: [150, 450, 1000, 1200, 1400],
    housePrice: 200,
  ),
];

/// 深蓝色组 - 首府（2格：索引37, 39）
const List<ThemeCellConfig> _darkBlueProperties = [
  ThemeCellConfig(
    index: 37,
    name: '临安府',
    color: PropertyColor.darkBlue,
    price: 350,
    mortgageValue: 175,
    baseRent: 35,
    rentWithHouse: [175, 500, 1100, 1300, 1500],
    housePrice: 200,
  ),
  ThemeCellConfig(
    index: 39,
    name: '汴京府',
    color: PropertyColor.darkBlue,
    price: 400,
    mortgageValue: 200,
    baseRent: 50,
    rentWithHouse: [200, 600, 1400, 1700, 2000],
    housePrice: 200,
  ),
];

/// ============================================================================
/// 10个特殊格子配置
/// ============================================================================

const List<ThemeSpecialCellConfig> songSpecialCells = [
  // 索引0: 起点
  ThemeSpecialCellConfig(index: 0, name: '开元', type: CellType.go),
  // 索引2: 公益
  ThemeSpecialCellConfig(index: 2, name: '德音', type: CellType.communityChest),
  // 索引4: 税课
  ThemeSpecialCellConfig(index: 4, name: '市税司', type: CellType.incomeTax),
  // 索引7: 占卜
  ThemeSpecialCellConfig(index: 7, name: '钦天监', type: CellType.chance),
  // 索引10: 监狱（仅路过）
  ThemeSpecialCellConfig(index: 10, name: '大理寺', type: CellType.jail),
  // 索引17: 公益
  ThemeSpecialCellConfig(index: 17, name: '德音', type: CellType.communityChest),
  // 索引20: 免费停车
  ThemeSpecialCellConfig(index: 20, name: '御街', type: CellType.freeParking),
  // 索引22: 占卜
  ThemeSpecialCellConfig(index: 22, name: '钦天监', type: CellType.chance),
  // 索引30: 前往监狱
  ThemeSpecialCellConfig(index: 30, name: '入狱', type: CellType.goToJail),
  // 索引33: 公益
  ThemeSpecialCellConfig(index: 33, name: '德音', type: CellType.communityChest),
  // 索引36: 占卜
  ThemeSpecialCellConfig(index: 36, name: '钦天监', type: CellType.chance),
  // 索引38: 消渴税
  ThemeSpecialCellConfig(index: 38, name: '茶税司', type: CellType.luxuryTax),
];

/// ============================================================================
/// 6个站点配置（4驿站 + 2官营事业）
/// ============================================================================

const List<ThemeStationCellConfig> songStations = [
  // 驿站
  ThemeStationCellConfig(
    index: 5,
    name: '京兆驿',
    type: CellType.railroad,
    price: 200,
    mortgageValue: 100,
    stationIndex: 0,
  ),
  ThemeStationCellConfig(
    index: 15,
    name: '泰山驿',
    type: CellType.railroad,
    price: 200,
    mortgageValue: 100,
    stationIndex: 1,
  ),
  ThemeStationCellConfig(
    index: 25,
    name: '荆南驿',
    type: CellType.railroad,
    price: 200,
    mortgageValue: 100,
    stationIndex: 2,
  ),
  ThemeStationCellConfig(
    index: 35,
    name: '岭南驿',
    type: CellType.railroad,
    price: 200,
    mortgageValue: 100,
    stationIndex: 3,
  ),
  // 官营事业
  ThemeStationCellConfig(
    index: 12,
    name: '官窑',
    type: CellType.utility,
    price: 150,
    mortgageValue: 75,
  ),
  ThemeStationCellConfig(
    index: 28,
    name: '榷场',
    type: CellType.utility,
    price: 150,
    mortgageValue: 75,
  ),
];

/// ============================================================================
/// 颜色组映射
/// ============================================================================

const Map<PropertyColor, List<int>> songColorGroupMap = {
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
final List<ThemeCellConfig> _allSongProperties = [
  ..._brownProperties,
  ..._lightBlueProperties,
  ..._pinkProperties,
  ..._orangeProperties,
  ..._redProperties,
  ..._yellowProperties,
  ..._greenProperties,
  ..._darkBlueProperties,
];

/// 宋代主题
final BoardTheme songTheme = BoardTheme(
  info: songThemeInfo,
  properties: _allSongProperties,
  specialCells: songSpecialCells,
  stations: songStations,
  colorGroupMap: songColorGroupMap,
);

/// ============================================================================
/// 便捷函数
/// ============================================================================

/// 获取宋代州府的Cell列表
List<Cell> buildSongCells() => songTheme.buildCells();

/// 获取颜色组对应的州府索引
Map<PropertyColor, List<int>> getSongColorGroupMap() => songColorGroupMap;