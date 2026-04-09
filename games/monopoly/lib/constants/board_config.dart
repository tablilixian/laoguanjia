// 地产大亨 - 棋盘配置常量
// 包含完整的40格棋盘数据、租金表、卡牌数据

import '../models/models.dart';

/// 完整的棋盘格子配置 (40格)
const List<Cell> boardCells = [
  // ===== 第一圈 (下边缘，从左至右) =====
  // 0: 起点 Go
  Cell(index: 0, name: 'Go', type: CellType.go),
  // 1: Mediterranean Avenue - 棕色组
  Cell(index: 1, name: 'Mediterranean Ave', type: CellType.property, color: PropertyColor.brown, price: 60, mortgageValue: 30, baseRent: 2, rentWithHouse: [10, 30, 90, 160, 250], housePrice: 50),
  // 2: Community Chest
  Cell(index: 2, name: 'Community Chest', type: CellType.communityChest),
  // 3: Baltic Avenue - 棕色组
  Cell(index: 3, name: 'Baltic Ave', type: CellType.property, color: PropertyColor.brown, price: 60, mortgageValue: 30, baseRent: 4, rentWithHouse: [20, 60, 180, 320, 450], housePrice: 50),
  // 4: Income Tax
  Cell(index: 4, name: 'Income Tax', type: CellType.incomeTax),
  // 5: Reading Railroad - 火车站1
  Cell(index: 5, name: 'Reading Railroad', type: CellType.railroad, price: 200, mortgageValue: 100, railroadIndex: 0),
  
  // ===== 第二圈 (右边缘，从下至上) =====
  // 6: Oriental Avenue - 浅蓝组
  Cell(index: 6, name: 'Oriental Ave', type: CellType.property, color: PropertyColor.lightBlue, price: 100, mortgageValue: 50, baseRent: 6, rentWithHouse: [30, 90, 270, 400, 550], housePrice: 50),
  // 7: Chance
  Cell(index: 7, name: 'Chance', type: CellType.chance),
  // 8: Vermont Avenue - 浅蓝组
  Cell(index: 8, name: 'Vermont Ave', type: CellType.property, color: PropertyColor.lightBlue, price: 100, mortgageValue: 50, baseRent: 6, rentWithHouse: [30, 90, 270, 400, 550], housePrice: 50),
  // 9: Connecticut Avenue - 浅蓝组
  Cell(index: 9, name: 'Connecticut Ave', type: CellType.property, color: PropertyColor.lightBlue, price: 120, mortgageValue: 60, baseRent: 8, rentWithHouse: [40, 100, 300, 450, 600], housePrice: 50),
  // 10: Jail / Just Visiting
  Cell(index: 10, name: 'Jail', type: CellType.jail),
  
  // 11: St. Charles Place - 粉色组
  Cell(index: 11, name: 'St. Charles Place', type: CellType.property, color: PropertyColor.pink, price: 140, mortgageValue: 70, baseRent: 10, rentWithHouse: [50, 150, 450, 625, 750], housePrice: 100),
  // 12: Electric Company - 公用事业1
  Cell(index: 12, name: 'Electric Company', type: CellType.utility, price: 150, mortgageValue: 75, isUtility: true),
  // 13: States Avenue - 粉色组
  Cell(index: 13, name: 'States Ave', type: CellType.property, color: PropertyColor.pink, price: 140, mortgageValue: 70, baseRent: 10, rentWithHouse: [50, 150, 450, 625, 750], housePrice: 100),
  // 14: Virginia Avenue - 粉色组
  Cell(index: 14, name: 'Virginia Ave', type: CellType.property, color: PropertyColor.pink, price: 160, mortgageValue: 80, baseRent: 12, rentWithHouse: [60, 180, 500, 700, 900], housePrice: 100),
  // 15: Pennsylvania Railroad - 火车站2
  Cell(index: 15, name: 'Pennsylvania R.R.', type: CellType.railroad, price: 200, mortgageValue: 100, railroadIndex: 1),
  
  // ===== 第三圈 (上边缘，从右至左) =====
  // 16: St. James Place - 橙色组
  Cell(index: 16, name: 'St. James Place', type: CellType.property, color: PropertyColor.orange, price: 180, mortgageValue: 90, baseRent: 14, rentWithHouse: [70, 200, 550, 750, 950], housePrice: 100),
  // 17: Community Chest
  Cell(index: 17, name: 'Community Chest', type: CellType.communityChest),
  // 18: Tennessee Avenue - 橙色组
  Cell(index: 18, name: 'Tennessee Ave', type: CellType.property, color: PropertyColor.orange, price: 180, mortgageValue: 90, baseRent: 14, rentWithHouse: [70, 200, 550, 750, 950], housePrice: 100),
  // 19: New York Avenue - 橙色组
  Cell(index: 19, name: 'New York Ave', type: CellType.property, color: PropertyColor.orange, price: 200, mortgageValue: 100, baseRent: 16, rentWithHouse: [80, 220, 600, 800, 1000], housePrice: 100),
  // 20: Free Parking
  Cell(index: 20, name: 'Free Parking', type: CellType.freeParking),
  
  // 21: Kentucky Avenue - 红色组
  Cell(index: 21, name: 'Kentucky Ave', type: CellType.property, color: PropertyColor.red, price: 220, mortgageValue: 110, baseRent: 18, rentWithHouse: [90, 250, 700, 875, 1050], housePrice: 150),
  // 22: Chance
  Cell(index: 22, name: 'Chance', type: CellType.chance),
  // 23: Indiana Avenue - 红色组
  Cell(index: 23, name: 'Indiana Ave', type: CellType.property, color: PropertyColor.red, price: 220, mortgageValue: 110, baseRent: 18, rentWithHouse: [90, 250, 700, 875, 1050], housePrice: 150),
  // 24: Illinois Avenue - 红色组
  Cell(index: 24, name: 'Illinois Ave', type: CellType.property, color: PropertyColor.red, price: 240, mortgageValue: 120, baseRent: 20, rentWithHouse: [100, 300, 750, 925, 1100], housePrice: 150),
  // 25: B&O Railroad - 火车站3
  Cell(index: 25, name: 'B&O Railroad', type: CellType.railroad, price: 200, mortgageValue: 100, railroadIndex: 2),
  
  // 26: Atlantic Avenue - 黄色组
  Cell(index: 26, name: 'Atlantic Ave', type: CellType.property, color: PropertyColor.yellow, price: 260, mortgageValue: 130, baseRent: 22, rentWithHouse: [110, 330, 800, 975, 1150], housePrice: 150),
  // 27: Ventnor Avenue - 黄色组
  Cell(index: 27, name: 'Ventnor Ave', type: CellType.property, color: PropertyColor.yellow, price: 260, mortgageValue: 130, baseRent: 22, rentWithHouse: [110, 330, 800, 975, 1150], housePrice: 150),
  // 28: Water Works - 公用事业2
  Cell(index: 28, name: 'Water Works', type: CellType.utility, price: 150, mortgageValue: 75, isUtility: true),
  // 29: Marvin Gardens - 黄色组
  Cell(index: 29, name: 'Marvin Gardens', type: CellType.property, color: PropertyColor.yellow, price: 280, mortgageValue: 140, baseRent: 24, rentWithHouse: [120, 360, 850, 1025, 1200], housePrice: 150),
  // 30: Go To Jail
  Cell(index: 30, name: 'Go To Jail', type: CellType.goToJail),
  
  // ===== 第四圈 (左边缘，从上至下) =====
  // 31: Pacific Avenue - 绿色组
  Cell(index: 31, name: 'Pacific Ave', type: CellType.property, color: PropertyColor.green, price: 300, mortgageValue: 150, baseRent: 26, rentWithHouse: [130, 390, 900, 1100, 1275], housePrice: 200),
  // 32: North Carolina Avenue - 绿色组
  Cell(index: 32, name: 'North Carolina Ave', type: CellType.property, color: PropertyColor.green, price: 300, mortgageValue: 150, baseRent: 26, rentWithHouse: [130, 390, 900, 1100, 1275], housePrice: 200),
  // 33: Community Chest
  Cell(index: 33, name: 'Community Chest', type: CellType.communityChest),
  // 34: Pennsylvania Avenue - 绿色组
  Cell(index: 34, name: 'Pennsylvania Ave', type: CellType.property, color: PropertyColor.green, price: 320, mortgageValue: 160, baseRent: 28, rentWithHouse: [150, 450, 1000, 1200, 1400], housePrice: 200),
  // 35: Short Line - 火车站4
  Cell(index: 35, name: 'Short Line', type: CellType.railroad, price: 200, mortgageValue: 100, railroadIndex: 3),
  // 36: Chance
  Cell(index: 36, name: 'Chance', type: CellType.chance),
  // 37: Park Place - 深蓝组
  Cell(index: 37, name: 'Park Place', type: CellType.property, color: PropertyColor.darkBlue, price: 350, mortgageValue: 175, baseRent: 35, rentWithHouse: [175, 500, 1100, 1300, 1500], housePrice: 200),
  // 38: Luxury Tax
  Cell(index: 38, name: 'Luxury Tax', type: CellType.luxuryTax),
  // 39: Boardwalk - 深蓝组
  Cell(index: 39, name: 'Boardwalk', type: CellType.property, color: PropertyColor.darkBlue, price: 400, mortgageValue: 200, baseRent: 50, rentWithHouse: [200, 600, 1400, 1700, 2000], housePrice: 200),
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

/// 机会卡数据
const List<GameCard> chanceCards = [
  GameCard(
    id: 'chance_1',
    type: CardType.chance,
    title: 'Advance to Boardwalk',
    description: 'Advance token to Boardwalk',
    effect: CardEffect(type: CardEffectType.advanceTo, target: 'Boardwalk'),
  ),
  GameCard(
    id: 'chance_2',
    type: CardType.chance,
    title: 'Advance to Go',
    description: 'Advance to Go. Collect \$200',
    effect: CardEffect(type: CardEffectType.advanceTo, target: 'Go', passGo: true),
  ),
  GameCard(
    id: 'chance_3',
    type: CardType.chance,
    title: 'Advance to Illinois Ave',
    description: 'Advance to Illinois Avenue. If you pass Go, collect \$200',
    effect: CardEffect(type: CardEffectType.advanceTo, target: 'Illinois Ave', passGo: true),
  ),
  GameCard(
    id: 'chance_4',
    type: CardType.chance,
    title: 'Advance to St. Charles',
    description: 'Advance to St. Charles Place. If you pass Go, collect \$200',
    effect: CardEffect(type: CardEffectType.advanceTo, target: 'St. Charles Place', passGo: true),
  ),
  GameCard(
    id: 'chance_5',
    type: CardType.chance,
    title: 'Advance to nearest Railroad',
    description: 'Advance to the nearest Railroad. If unowned, you may buy it from the Bank.',
    effect: CardEffect(type: CardEffectType.advanceToNearestRailroad),
  ),
  GameCard(
    id: 'chance_6',
    type: CardType.chance,
    title: 'Advance to nearest Railroad',
    description: 'Advance to the nearest Railroad. If unowned, you may buy it from the Bank.',
    effect: CardEffect(type: CardEffectType.advanceToNearestRailroad),
  ),
  GameCard(
    id: 'chance_7',
    type: CardType.chance,
    title: 'Advance to nearest Utility',
    description: 'Advance token to nearest Utility. If unowned, you may buy it from the Bank.',
    effect: CardEffect(type: CardEffectType.advanceToNearestUtility),
  ),
  GameCard(
    id: 'chance_8',
    type: CardType.chance,
    title: 'Bank Dividend',
    description: 'Bank pays you dividend of \$50',
    effect: CardEffect(type: CardEffectType.collect, value: 50),
  ),
  GameCard(
    id: 'chance_9',
    type: CardType.chance,
    title: 'Get Out of Jail Free',
    description: 'Get Out of Jail Free',
    effect: CardEffect(type: CardEffectType.getOutOfJailFree),
  ),
  GameCard(
    id: 'chance_10',
    type: CardType.chance,
    title: 'Go Back 3 Spaces',
    description: 'Go back 3 Spaces',
    effect: CardEffect(type: CardEffectType.goBack, value: 3),
  ),
  GameCard(
    id: 'chance_11',
    type: CardType.chance,
    title: 'Go to Jail',
    description: 'Go directly to Jail. Do not pass Go. Do not collect \$200',
    effect: CardEffect(type: CardEffectType.goToJail),
  ),
  GameCard(
    id: 'chance_12',
    type: CardType.chance,
    title: 'General Repairs',
    description: 'Make general repairs on all your property. For each house pay \$25. For each hotel pay \$100',
    effect: CardEffect(type: CardEffectType.payPerHouse, value: 25),
  ),
  GameCard(
    id: 'chance_13',
    type: CardType.chance,
    title: 'Speeding Fine',
    description: 'Speeding fine \$15',
    effect: CardEffect(type: CardEffectType.pay, value: 15),
  ),
  GameCard(
    id: 'chance_14',
    type: CardType.chance,
    title: 'Take a Trip',
    description: 'Take a trip to Reading Railroad. If you pass Go, collect \$200',
    effect: CardEffect(type: CardEffectType.advanceTo, target: 'Reading Railroad', passGo: true),
  ),
  GameCard(
    id: 'chance_15',
    type: CardType.chance,
    title: 'Chairman',
    description: 'You have been elected Chairman of the Board. Pay each player \$50',
    effect: CardEffect(type: CardEffectType.electionChairman, value: 50),
  ),
  GameCard(
    id: 'chance_16',
    type: CardType.chance,
    title: 'Building Loan',
    description: 'Your building loan matures. Collect \$150',
    effect: CardEffect(type: CardEffectType.collect, value: 150),
  ),
];

/// 社区福利卡数据
const List<GameCard> communityChestCards = [
  GameCard(
    id: 'cc_1',
    type: CardType.communityChest,
    title: 'Advance to Go',
    description: 'Advance to Go. Collect \$200',
    effect: CardEffect(type: CardEffectType.advanceTo, target: 'Go', passGo: true),
  ),
  GameCard(
    id: 'cc_2',
    type: CardType.communityChest,
    title: 'Bank Error',
    description: 'Bank error in your favor. Collect \$200',
    effect: CardEffect(type: CardEffectType.collect, value: 200),
  ),
  GameCard(
    id: 'cc_3',
    type: CardType.communityChest,
    title: "Doctor's Fee",
    description: "Doctor's fee. Pay \$50",
    effect: CardEffect(type: CardEffectType.pay, value: 50),
  ),
  GameCard(
    id: 'cc_4',
    type: CardType.communityChest,
    title: 'Stock Sale',
    description: 'From sale of stock you get \$50',
    effect: CardEffect(type: CardEffectType.collect, value: 50),
  ),
  GameCard(
    id: 'cc_5',
    type: CardType.communityChest,
    title: 'Get Out of Jail Free',
    description: 'Get Out of Jail Free',
    effect: CardEffect(type: CardEffectType.getOutOfJailFree),
  ),
  GameCard(
    id: 'cc_6',
    type: CardType.communityChest,
    title: 'Go to Jail',
    description: 'Go directly to jail. Do not pass Go. Do not collect \$200',
    effect: CardEffect(type: CardEffectType.goToJail),
  ),
  GameCard(
    id: 'cc_7',
    type: CardType.communityChest,
    title: 'Holiday Fund',
    description: 'Holiday fund matures. Receive \$100',
    effect: CardEffect(type: CardEffectType.collect, value: 100),
  ),
  GameCard(
    id: 'cc_8',
    type: CardType.communityChest,
    title: 'Income Tax Refund',
    description: 'Income tax refund. Collect \$20',
    effect: CardEffect(type: CardEffectType.collect, value: 20),
  ),
  GameCard(
    id: 'cc_9',
    type: CardType.communityChest,
    title: 'Birthday',
    description: 'It is your birthday. Collect \$10 from every player',
    effect: CardEffect(type: CardEffectType.electionChairman, value: 10),
  ),
  GameCard(
    id: 'cc_10',
    type: CardType.communityChest,
    title: 'Life Insurance',
    description: 'Life insurance matures. Collect \$100',
    effect: CardEffect(type: CardEffectType.collect, value: 100),
  ),
  GameCard(
    id: 'cc_11',
    type: CardType.communityChest,
    title: 'Hospital Fees',
    description: 'Pay hospital fees of \$100',
    effect: CardEffect(type: CardEffectType.pay, value: 100),
  ),
  GameCard(
    id: 'cc_12',
    type: CardType.communityChest,
    title: 'School Fees',
    description: 'Pay school fees of \$50',
    effect: CardEffect(type: CardEffectType.pay, value: 50),
  ),
  GameCard(
    id: 'cc_13',
    type: CardType.communityChest,
    title: 'Consultancy Fee',
    description: 'Receive \$25 consultancy fee',
    effect: CardEffect(type: CardEffectType.collect, value: 25),
  ),
  GameCard(
    id: 'cc_14',
    type: CardType.communityChest,
    title: 'Street Repairs',
    description: 'You are assessed for street repair. \$40 per house. \$115 per hotel',
    effect: CardEffect(type: CardEffectType.payPerHouse, value: 40),
  ),
  GameCard(
    id: 'cc_15',
    type: CardType.communityChest,
    title: 'Beauty Contest',
    description: 'You have won second prize in a beauty contest. Collect \$10',
    effect: CardEffect(type: CardEffectType.collect, value: 10),
  ),
  GameCard(
    id: 'cc_16',
    type: CardType.communityChest,
    title: 'Inherit',
    description: 'You inherit \$100',
    effect: CardEffect(type: CardEffectType.collect, value: 100),
  ),
];

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
