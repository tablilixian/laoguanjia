// 地产大亨 - 棋盘配置常量
// 包含完整的40格棋盘数据、租金表、卡牌数据

import '../models/models.dart';

/// 完整的棋盘格子配置 (40 格) - 中国版本
const List<Cell> boardCells = [
  // ===== 第一圈 (下边缘，从左至右) =====
  // 0: 起点 - 祖国华诞
  Cell(index: 0, name: '祖国华诞', type: CellType.go),
  // 1: 棕色组 - 小城市
  Cell(index: 1, name: '拉萨', type: CellType.property, color: PropertyColor.brown, price: 60, mortgageValue: 30, baseRent: 2, rentWithHouse: [10, 30, 90, 160, 250], housePrice: 50),
  // 2: 公益卡
  Cell(index: 2, name: '公益', type: CellType.communityChest),
  // 3: 棕色组 - 小城市
  Cell(index: 3, name: '西宁', type: CellType.property, color: PropertyColor.brown, price: 60, mortgageValue: 30, baseRent: 4, rentWithHouse: [20, 60, 180, 320, 450], housePrice: 50),
  // 4: 个人所得税
  Cell(index: 4, name: '所得税', type: CellType.incomeTax),
  // 5: 高铁站 1 - 北京南站
  Cell(index: 5, name: '北京南站', type: CellType.railroad, price: 200, mortgageValue: 100, railroadIndex: 0),
  
  // ===== 第二圈 (右边缘，从下至上) =====
  // 6: 浅蓝组 - 三线城市
  Cell(index: 6, name: '桂林', type: CellType.property, color: PropertyColor.lightBlue, price: 100, mortgageValue: 50, baseRent: 6, rentWithHouse: [30, 90, 270, 400, 550], housePrice: 50),
  // 7: 命运卡
  Cell(index: 7, name: '命运', type: CellType.chance),
  // 8: 浅蓝组 - 三线城市
  Cell(index: 8, name: '三亚', type: CellType.property, color: PropertyColor.lightBlue, price: 100, mortgageValue: 50, baseRent: 6, rentWithHouse: [30, 90, 270, 400, 550], housePrice: 50),
  // 9: 浅蓝组 - 三线城市
  Cell(index: 9, name: '丽江', type: CellType.property, color: PropertyColor.lightBlue, price: 120, mortgageValue: 60, baseRent: 8, rentWithHouse: [40, 100, 300, 450, 600], housePrice: 50),
  // 10: 派出所
  Cell(index: 10, name: '派出所', type: CellType.jail),
  
  // 11: 粉色组 - 二线城市
  Cell(index: 11, name: '成都', type: CellType.property, color: PropertyColor.pink, price: 140, mortgageValue: 70, baseRent: 10, rentWithHouse: [50, 150, 450, 625, 750], housePrice: 100),
  // 12: 公用事业 1 - 国家电网
  Cell(index: 12, name: '国家电网', type: CellType.utility, price: 150, mortgageValue: 75, isUtility: true),
  // 13: 粉色组 - 二线城市
  Cell(index: 13, name: '杭州', type: CellType.property, color: PropertyColor.pink, price: 140, mortgageValue: 70, baseRent: 10, rentWithHouse: [50, 150, 450, 625, 750], housePrice: 100),
  // 14: 粉色组 - 二线城市
  Cell(index: 14, name: '南京', type: CellType.property, color: PropertyColor.pink, price: 160, mortgageValue: 80, baseRent: 12, rentWithHouse: [60, 180, 500, 700, 900], housePrice: 100),
  // 15: 高铁站 2 - 上海虹桥站
  Cell(index: 15, name: '虹桥站', type: CellType.railroad, price: 200, mortgageValue: 100, railroadIndex: 1),
  
  // ===== 第三圈 (上边缘，从右至左) =====
  // 16: 橙色组 - 新一线城市
  Cell(index: 16, name: '武汉', type: CellType.property, color: PropertyColor.orange, price: 180, mortgageValue: 90, baseRent: 14, rentWithHouse: [70, 200, 550, 750, 950], housePrice: 100),
  // 17: 公益卡
  Cell(index: 17, name: '公益', type: CellType.communityChest),
  // 18: 橙色组 - 新一线城市
  Cell(index: 18, name: '西安', type: CellType.property, color: PropertyColor.orange, price: 180, mortgageValue: 90, baseRent: 14, rentWithHouse: [70, 200, 550, 750, 950], housePrice: 100),
  // 19: 橙色组 - 新一线城市
  Cell(index: 19, name: '重庆', type: CellType.property, color: PropertyColor.orange, price: 200, mortgageValue: 100, baseRent: 16, rentWithHouse: [80, 220, 600, 800, 1000], housePrice: 100),
  // 20: 人民广场
  Cell(index: 20, name: '人民广场', type: CellType.freeParking),
  
  // 21: 红色组 - 发达城市
  Cell(index: 21, name: '广州', type: CellType.property, color: PropertyColor.red, price: 220, mortgageValue: 110, baseRent: 18, rentWithHouse: [90, 250, 700, 875, 1050], housePrice: 150),
  // 22: 命运卡
  Cell(index: 22, name: '命运', type: CellType.chance),
  // 23: 红色组 - 发达城市
  Cell(index: 23, name: '深圳', type: CellType.property, color: PropertyColor.red, price: 220, mortgageValue: 110, baseRent: 18, rentWithHouse: [90, 250, 700, 875, 1050], housePrice: 150),
  // 24: 红色组 - 发达城市
  Cell(index: 24, name: '上海', type: CellType.property, color: PropertyColor.red, price: 240, mortgageValue: 120, baseRent: 20, rentWithHouse: [100, 300, 750, 925, 1100], housePrice: 150),
  // 25: 高铁站 3 - 广州南站
  Cell(index: 25, name: '广州南站', type: CellType.railroad, price: 200, mortgageValue: 100, railroadIndex: 2),
  
  // 26: 黄色组 - 特别行政区
  Cell(index: 26, name: '苏州', type: CellType.property, color: PropertyColor.yellow, price: 260, mortgageValue: 130, baseRent: 22, rentWithHouse: [110, 330, 800, 975, 1150], housePrice: 150),
  // 27: 黄色组 - 特别行政区
  Cell(index: 27, name: '天津', type: CellType.property, color: PropertyColor.yellow, price: 260, mortgageValue: 130, baseRent: 22, rentWithHouse: [110, 330, 800, 975, 1150], housePrice: 150),
  // 28: 公用事业 2 - 中国石化
  Cell(index: 28, name: '中国石化', type: CellType.utility, price: 150, mortgageValue: 75, isUtility: true),
  // 29: 黄色组 - 特别行政区
  Cell(index: 29, name: '青岛', type: CellType.property, color: PropertyColor.yellow, price: 280, mortgageValue: 140, baseRent: 24, rentWithHouse: [120, 360, 850, 1025, 1200], housePrice: 150),
  // 30: 前往派出所
  Cell(index: 30, name: '前往监狱', type: CellType.goToJail),
  
  // ===== 第四圈 (左边缘，从上至下) =====
  // 31: 绿色组 - 特别行政区
  Cell(index: 31, name: '香港', type: CellType.property, color: PropertyColor.green, price: 300, mortgageValue: 150, baseRent: 26, rentWithHouse: [130, 390, 900, 1100, 1275], housePrice: 200),
  // 32: 绿色组 - 特别行政区
  Cell(index: 32, name: '澳门', type: CellType.property, color: PropertyColor.green, price: 300, mortgageValue: 150, baseRent: 26, rentWithHouse: [130, 390, 900, 1100, 1275], housePrice: 200),
  // 33: 公益卡
  Cell(index: 33, name: '公益', type: CellType.communityChest),
  // 34: 绿色组 - 特别行政区
  Cell(index: 34, name: '台北', type: CellType.property, color: PropertyColor.green, price: 320, mortgageValue: 160, baseRent: 28, rentWithHouse: [150, 450, 1000, 1200, 1400], housePrice: 200),
  // 35: 高铁站 4 - 成都东站
  Cell(index: 35, name: '成都东站', type: CellType.railroad, price: 200, mortgageValue: 100, railroadIndex: 3),
  // 36: 命运卡
  Cell(index: 36, name: '命运', type: CellType.chance),
  // 37: 深蓝色组 - 首都
  Cell(index: 37, name: '北京', type: CellType.property, color: PropertyColor.darkBlue, price: 350, mortgageValue: 175, baseRent: 35, rentWithHouse: [175, 500, 1100, 1300, 1500], housePrice: 200),
  // 38: 消费税
  Cell(index: 38, name: '消费税', type: CellType.luxuryTax),
  // 39: 深蓝色组 - 首都
  Cell(index: 39, name: '自贸区', type: CellType.property, color: PropertyColor.darkBlue, price: 400, mortgageValue: 200, baseRent: 50, rentWithHouse: [200, 600, 1400, 1700, 2000], housePrice: 200),
];

/// 获取色组的所有地产索引
const Map<PropertyColor, List<int>> colorGroupProperties = {
  PropertyColor.brown: [1, 3],
  PropertyColor.lightBlue: [6, 8, 9],
  PropertyColor.pink: [11, 13, 14],
  PropertyColor.orange: [16, 18, 19],
  PropertyColor.red: [21, 23, 24],
  PropertyColor.yellow: [26, 27, 29],
  PropertyColor.green: [31, 32, 34],
  PropertyColor.darkBlue: [37, 39],
};

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
  0xFF9B59B6,  // 紫色
  0xFF1ABC9C,  // 青色
];

/// 命运卡数据
const List<GameCard> chanceCards = [
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
    title: '前往最近的高铁站',
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

/// 公益卡数据
const List<GameCard> communityChestCards = [
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
    description: '获得一次免进派出所的机会',
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
