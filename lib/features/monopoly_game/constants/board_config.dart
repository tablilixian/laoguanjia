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

/// 命运卡数据（使用中国城市主题的卡牌数据）
List<GameCard> get chanceCards {
  // 从 chinaTheme 获取卡牌数据
  // 这里使用兼容方式 - 直接返回硬编码的中国城市卡牌
  // 未来可通过 Provider 动态获取
  return _chanceCards;
}

/// 公益卡数据
List<GameCard> get communityChestCards {
  return _communityChestCards;
}

// 命运卡数据（中国城市版本）
final List<GameCard> _chanceCards = [
  GameCard(
    id: 'chance_1',
    type: CardType.chance,
    title: '前往自贸区',
    description: '前进至自贸区',
    effect: CardEffect(type: CardEffectType.advanceTo, target: '自贸区'),
  ),
  GameCard(
    id: 'chance_2',
    type: CardType.chance,
    title: '祖国华诞',
    description: '前进至祖国华诞，获得￥200',
    effect: CardEffect(type: CardEffectType.advanceTo, target: '祖国华诞', passGo: true),
  ),
  GameCard(
    id: 'chance_3',
    type: CardType.chance,
    title: '前往上海',
    description: '前进至上海。如果路过祖国华诞，获得￥200',
    effect: CardEffect(type: CardEffectType.advanceTo, target: '上海', passGo: true),
  ),
  GameCard(
    id: 'chance_4',
    type: CardType.chance,
    title: '前往成都',
    description: '前进至成都。如果路过祖国华诞，获得￥200',
    effect: CardEffect(type: CardEffectType.advanceTo, target: '成都', passGo: true),
  ),
  GameCard(
    id: 'chance_5',
    type: CardType.chance,
    title: '前往最��的高铁站',
    description: '前进至最近的高铁站。如果无人拥有，可向银行购买',
    effect: CardEffect(type: CardEffectType.advanceToNearestRailroad),
  ),
  GameCard(
    id: 'chance_6',
    type: CardType.chance,
    title: '前往最近的高铁站',
    description: '前进至最近的高铁站。如果无人拥有，可向银行购买',
    effect: CardEffect(type: CardEffectType.advanceToNearestRailroad),
  ),
  GameCard(
    id: 'chance_7',
    type: CardType.chance,
    title: '前往最近的公用事业',
    description: '前进至最近的公用事业。如果无人拥有，可向银行购买',
    effect: CardEffect(type: CardEffectType.advanceToNearestUtility),
  ),
  GameCard(
    id: 'chance_8',
    type: CardType.chance,
    title: '银行分红',
    description: '银行向你支付分红￥50',
    effect: CardEffect(type: CardEffectType.collect, value: 50),
  ),
  GameCard(
    id: 'chance_9',
    type: CardType.chance,
    title: '免罪金牌',
    description: '获得一次免进派出所的机会',
    effect: CardEffect(type: CardEffectType.getOutOfJailFree),
  ),
  GameCard(
    id: 'chance_10',
    type: CardType.chance,
    title: '后退 3 格',
    description: '向后倒退 3 格',
    effect: CardEffect(type: CardEffectType.goBack, value: 3),
  ),
  GameCard(
    id: 'chance_11',
    type: CardType.chance,
    title: '进派出所',
    description: '直接进入派出所。不能路过祖国华诞，不能获得￥200',
    effect: CardEffect(type: CardEffectType.goToJail),
  ),
  GameCard(
    id: 'chance_12',
    type: CardType.chance,
    title: '房屋维修',
    description: '对所有房产进行维修。每栋房子支付￥25，每家酒店支付￥100',
    effect: CardEffect(type: CardEffectType.payPerHouse, value: 25),
  ),
  GameCard(
    id: 'chance_13',
    type: CardType.chance,
    title: '交通罚款',
    description: '交通违规罚款￥15',
    effect: CardEffect(type: CardEffectType.pay, value: 15),
  ),
  GameCard(
    id: 'chance_14',
    type: CardType.chance,
    title: '北京南站之旅',
    description: '前往北京南站。如果路过祖国华诞，获得￥200',
    effect: CardEffect(type: CardEffectType.advanceTo, target: '北京南站', passGo: true),
  ),
  GameCard(
    id: 'chance_15',
    type: CardType.chance,
    title: '董事会主席',
    description: '你被选为董事会主席，向每位玩家支付￥50',
    effect: CardEffect(type: CardEffectType.electionChairman, value: 50),
  ),
  GameCard(
    id: 'chance_16',
    type: CardType.chance,
    title: '建筑贷款到期',
    description: '你的建筑贷款到期，获得￥150',
    effect: CardEffect(type: CardEffectType.collect, value: 150),
  ),
];

// 公益卡数据（中国城市版本）
final List<GameCard> _communityChestCards = [
  GameCard(
    id: 'cc_1',
    type: CardType.communityChest,
    title: '祖国华诞',
    description: '前进至祖国华诞，获得￥200',
    effect: CardEffect(type: CardEffectType.advanceTo, target: '祖国华诞', passGo: true),
  ),
  GameCard(
    id: 'cc_2',
    type: CardType.communityChest,
    title: '银行差错',
    description: '银行出现差错，对你有利，获得￥200',
    effect: CardEffect(type: CardEffectType.collect, value: 200),
  ),
  GameCard(
    id: 'cc_3',
    type: CardType.communityChest,
    title: '医药费',
    description: '支付医药费￥50',
    effect: CardEffect(type: CardEffectType.pay, value: 50),
  ),
  GameCard(
    id: 'cc_4',
    type: CardType.communityChest,
    title: '股票收益',
    description: '股票收益，获得￥50',
    effect: CardEffect(type: CardEffectType.collect, value: 50),
  ),
  GameCard(
    id: 'cc_5',
    type: CardType.communityChest,
    title: '免罪金牌',
    description: '获得一次免进���出所的机会',
    effect: CardEffect(type: CardEffectType.getOutOfJailFree),
  ),
  GameCard(
    id: 'cc_6',
    type: CardType.communityChest,
    title: '进派出所',
    description: '直接进入派出所。不能路过祖国华诞，不能获得￥200',
    effect: CardEffect(type: CardEffectType.goToJail),
  ),
  GameCard(
    id: 'cc_7',
    type: CardType.communityChest,
    title: '节日基金',
    description: '节日基金到期，获得￥100',
    effect: CardEffect(type: CardEffectType.collect, value: 100),
  ),
  GameCard(
    id: 'cc_8',
    type: CardType.communityChest,
    title: '所得税退税',
    description: '所得税退税，获得￥20',
    effect: CardEffect(type: CardEffectType.collect, value: 20),
  ),
  GameCard(
    id: 'cc_9',
    type: CardType.communityChest,
    title: '生日礼物',
    description: '今天是你的生日，从每位玩家获得￥10',
    effect: CardEffect(type: CardEffectType.birthday, value: 10),
  ),
  GameCard(
    id: 'cc_10',
    type: CardType.communityChest,
    title: '人寿保险',
    description: '人寿保险到期，获得￥100',
    effect: CardEffect(type: CardEffectType.collect, value: 100),
  ),
  GameCard(
    id: 'cc_11',
    type: CardType.communityChest,
    title: '住院费',
    description: '支付住院费￥100',
    effect: CardEffect(type: CardEffectType.pay, value: 100),
  ),
  GameCard(
    id: 'cc_12',
    type: CardType.communityChest,
    title: '学费',
    description: '支付学费￥50',
    effect: CardEffect(type: CardEffectType.pay, value: 50),
  ),
  GameCard(
    id: 'cc_13',
    type: CardType.communityChest,
    title: '咨询费',
    description: '收到咨询费￥25',
    effect: CardEffect(type: CardEffectType.collect, value: 25),
  ),
  GameCard(
    id: 'cc_14',
    type: CardType.communityChest,
    title: '街道维修',
    description: '街道维修评估，每栋房子支付￥40，每家酒店支付￥115',
    effect: CardEffect(type: CardEffectType.payPerHouse, value: 40),
  ),
  GameCard(
    id: 'cc_15',
    type: CardType.communityChest,
    title: '选美比赛',
    description: '你在选美比赛中获得二等奖，获得￥10',
    effect: CardEffect(type: CardEffectType.collect, value: 10),
  ),
  GameCard(
    id: 'cc_16',
    type: CardType.communityChest,
    title: '遗产继承',
    description: '你继承了￥100 的遗产',
    effect: CardEffect(type: CardEffectType.collect, value: 100),
  ),
];

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