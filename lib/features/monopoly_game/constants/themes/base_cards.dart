// 地产大亨 - 卡牌模板
// 
// 本文件包含卡牌模板，使用占位符支持不同主题的地名替换。
// 使用时需要结合具体主题的 BoardTheme 来构建具体卡牌。
// 
// 【占位符说明】
// - {{go}}: 起点名称（如"祖国华诞"或"Go"）
// - {{jail}}: 监狱名称（如"派出所"或"Jail"）
// - {{railroad}}: 第一个火车站名称
// - {{utility}}: 第一个公用事业名称
// - {{station}}: 火车站（同 {{railroad}}）
// - {{parkPlace}}: 深蓝色组最贵地产
// - {{boardwalk}}: 深蓝色组第二贵地产（Boardwalk特供）
// 
// 【使用方式】
// 1. 使用模板构建具体卡牌：
//    final cards = template.buildCards(theme, CardType.chance);
// 2. 然后洗牌使用

import '../../models/models.dart';
import 'board_theme.dart';

/// ============================================================================
/// 命运卡模板（Chance Cards）
/// ============================================================================

/// 命运卡模板列表
/// 共16张命运卡，支持占位符替换
const List<CardTemplate> chanceCardTemplates = [
  // === 位置移动类 ===
  CardTemplate(
    id: 'chance_1',
    type: CardType.chance,
    titleTemplate: '前往{{boardwalk}}',
    descriptionTemplate: '前进至{{boardwalk}}',
    effect: CardEffectTemplate(
      type: CardEffectType.advanceTo,
      targetPlaceholder: '{{boardwalk}}',
    ),
  ),
  CardTemplate(
    id: 'chance_2',
    type: CardType.chance,
    titleTemplate: '{{go}}出发',
    descriptionTemplate: '前进至{{go}}，获得￥200',
    effect: CardEffectTemplate(
      type: CardEffectType.advanceTo,
      targetPlaceholder: '{{go}}',
      passGo: true,
    ),
  ),
  CardTemplate(
    id: 'chance_3',
    type: CardType.chance,
    titleTemplate: '前往{{parkPlace}}',
    descriptionTemplate: '前进至{{parkPlace}}。如果路过{{go}}，获得￥200',
    effect: CardEffectTemplate(
      type: CardEffectType.advanceTo,
      targetPlaceholder: '{{parkPlace}}',
      passGo: true,
    ),
  ),
  CardTemplate(
    id: 'chance_4',
    type: CardType.chance,
    titleTemplate: '前往{{station}}',
    descriptionTemplate: '前进至最近的火车站。如果无人拥有，可向银行购买',
    effect: CardEffectTemplate(
      type: CardEffectType.advanceToNearestRailroad,
    ),
  ),
  CardTemplate(
    id: 'chance_5',
    type: CardType.chance,
    titleTemplate: '前往{{utility}}',
    descriptionTemplate: '前进至最近的公用事业。如果无人拥有，可向银行购买',
    effect: CardEffectTemplate(
      type: CardEffectType.advanceToNearestUtility,
    ),
  ),
  
  // === 资金类 ===
  CardTemplate(
    id: 'chance_6',
    type: CardType.chance,
    titleTemplate: '银行分红',
    descriptionTemplate: '银行向你支付分红￥50',
    effect: CardEffectTemplate(
      type: CardEffectType.collect,
      value: 50,
    ),
  ),
  CardTemplate(
    id: 'chance_7',
    type: CardType.chance,
    titleTemplate: '建筑贷款到期',
    descriptionTemplate: '你的建筑贷款到期，获得￥150',
    effect: CardEffectTemplate(
      type: CardEffectType.collect,
      value: 150,
    ),
  ),
  CardTemplate(
    id: 'chance_8',
    type: CardType.chance,
    titleTemplate: '交通罚款',
    descriptionTemplate: '交通违规罚款￥15',
    effect: CardEffectTemplate(
      type: CardEffectType.pay,
      value: 15,
    ),
  ),
  
  // === 特殊功能类 ===
  CardTemplate(
    id: 'chance_9',
    type: CardType.chance,
    titleTemplate: '免罪金牌',
    descriptionTemplate: '获得一次免进{{jail}}的机会',
    effect: CardEffectTemplate(
      type: CardEffectType.getOutOfJailFree,
    ),
  ),
  CardTemplate(
    id: 'chance_10',
    type: CardType.chance,
    titleTemplate: '进{{jail}}',
    descriptionTemplate: '直接进入{{jail}}。不能路过{{go}}，不能获得￥200',
    effect: CardEffectTemplate(
      type: CardEffectType.goToJail,
    ),
  ),
  
  // === 移动类 ===
  CardTemplate(
    id: 'chance_11',
    type: CardType.chance,
    titleTemplate: '后退3格',
    descriptionTemplate: '向后倒退3格',
    effect: CardEffectTemplate(
      type: CardEffectType.goBack,
      value: 3,
    ),
  ),
  
  // === 费用类 ===
  CardTemplate(
    id: 'chance_12',
    type: CardType.chance,
    titleTemplate: '房屋维修',
    descriptionTemplate: '对所有房产进行维修。每栋房子支付￥25，每家酒店支付￥100',
    effect: CardEffectTemplate(
      type: CardEffectType.payPerHouse,
      value: 25,
    ),
  ),
  CardTemplate(
    id: 'chance_13',
    type: CardType.chance,
    titleTemplate: '董事会主席',
    descriptionTemplate: '你被选为董事会主席，向每位玩家支付￥50',
    effect: CardEffectTemplate(
      type: CardEffectType.electionChairman,
      value: 50,
    ),
  ),
];

/// 公益卡模板列表（Community Chest Cards）
/// 共16张公益卡，支持占位符替换
const List<CardTemplate> communityChestCardTemplates = [
  // === 位置移动类 ===
  CardTemplate(
    id: 'cc_1',
    type: CardType.communityChest,
    titleTemplate: '{{go}}出发',
    descriptionTemplate: '前进至{{go}}，获得￥200',
    effect: CardEffectTemplate(
      type: CardEffectType.advanceTo,
      targetPlaceholder: '{{go}}',
      passGo: true,
    ),
  ),
  
  // === 资金类 ===
  CardTemplate(
    id: 'cc_2',
    type: CardType.communityChest,
    titleTemplate: '银行差错',
    descriptionTemplate: '银行出现差错，对你有利，获得￥200',
    effect: CardEffectTemplate(
      type: CardEffectType.collect,
      value: 200,
    ),
  ),
  CardTemplate(
    id: 'cc_3',
    type: CardType.communityChest,
    titleTemplate: '股票收益',
    descriptionTemplate: '股票收益，获得￥50',
    effect: CardEffectTemplate(
      type: CardEffectType.collect,
      value: 50,
    ),
  ),
  CardTemplate(
    id: 'cc_4',
    type: CardType.communityChest,
    titleTemplate: '节日基金',
    descriptionTemplate: '节日基金到期，获得￥100',
    effect: CardEffectTemplate(
      type: CardEffectType.collect,
      value: 100,
    ),
  ),
  CardTemplate(
    id: 'cc_5',
    type: CardType.communityChest,
    titleTemplate: '所得税退税',
    descriptionTemplate: '所得税退税，获得￥20',
    effect: CardEffectTemplate(
      type: CardEffectType.collect,
      value: 20,
    ),
  ),
  CardTemplate(
    id: 'cc_6',
    type: CardType.communityChest,
    titleTemplate: '人寿保险',
    descriptionTemplate: '人寿保险到期，获得￥100',
    effect: CardEffectTemplate(
      type: CardEffectType.collect,
      value: 100,
    ),
  ),
  CardTemplate(
    id: 'cc_7',
    type: CardType.communityChest,
    titleTemplate: '咨询费',
    descriptionTemplate: '收到咨询费￥25',
    effect: CardEffectTemplate(
      type: CardEffectType.collect,
      value: 25,
    ),
  ),
  CardTemplate(
    id: 'cc_8',
    type: CardType.communityChest,
    titleTemplate: '遗产继承',
    descriptionTemplate: '你继承了￥100的遗产',
    effect: CardEffectTemplate(
      type: CardEffectType.collect,
      value: 100,
    ),
  ),
  CardTemplate(
    id: 'cc_9',
    type: CardType.communityChest,
    titleTemplate: '选美比赛',
    descriptionTemplate: '���在选美比赛中获得二等奖，获得￥10',
    effect: CardEffectTemplate(
      type: CardEffectType.collect,
      value: 10,
    ),
  ),
  
  // === 支付类 ===
  CardTemplate(
    id: 'cc_10',
    type: CardType.communityChest,
    titleTemplate: '医药费',
    descriptionTemplate: '支付医药费￥50',
    effect: CardEffectTemplate(
      type: CardEffectType.pay,
      value: 50,
    ),
  ),
  CardTemplate(
    id: 'cc_11',
    type: CardType.communityChest,
    titleTemplate: '住院费',
    descriptionTemplate: '支付住院费￥100',
    effect: CardEffectTemplate(
      type: CardEffectType.pay,
      value: 100,
    ),
  ),
  CardTemplate(
    id: 'cc_12',
    type: CardType.communityChest,
    titleTemplate: '学费',
    descriptionTemplate: '支付学费￥50',
    effect: CardEffectTemplate(
      type: CardEffectType.pay,
      value: 50,
    ),
  ),
  CardTemplate(
    id: 'cc_13',
    type: CardType.communityChest,
    titleTemplate: '街道维修',
    descriptionTemplate: '街道维修评估，每栋房子支付￥40，每家酒店支付￥115',
    effect: CardEffectTemplate(
      type: CardEffectType.payPerHouse,
      value: 40,
    ),
  ),
  
  // === 特殊功能类 ===
  CardTemplate(
    id: 'cc_14',
    type: CardType.communityChest,
    titleTemplate: '免罪金牌',
    descriptionTemplate: '获得一次免进{{jail}}的机会',
    effect: CardEffectTemplate(
      type: CardEffectType.getOutOfJailFree,
    ),
  ),
  CardTemplate(
    id: 'cc_15',
    type: CardType.communityChest,
    titleTemplate: '进{{jail}}',
    descriptionTemplate: '直接进入{{jail}}。不能路过{{go}}，不能获得￥200',
    effect: CardEffectTemplate(
      type: CardEffectType.goToJail,
    ),
  ),
  
  // === 其他 ===
  CardTemplate(
    id: 'cc_16',
    type: CardType.communityChest,
    titleTemplate: '生日礼物',
    descriptionTemplate: '今天是你的生日，从每位玩家获得￥10',
    effect: CardEffectTemplate(
      type: CardEffectType.birthday,
      value: 10,
    ),
  ),
];

/// ============================================================================
/// 模板集合
/// ============================================================================

/// 卡牌模板集合
const CardTemplates cardTemplates = CardTemplates(
  chanceCards: chanceCardTemplates,
  communityChestCards: communityChestCardTemplates,
);

/// ============================================================================
/// 辅助函数
/// ============================================================================

/// 根据主题构建命运卡
/// [theme]: 当前使用的主题
List<GameCard> buildChanceCards(BoardTheme theme) {
  return cardTemplates.buildCards(theme, CardType.chance);
}

/// 根据主题构建公益卡
/// [theme]: 当前使用的主题
List<GameCard> buildCommunityChestCards(BoardTheme theme) {
  return cardTemplates.buildCards(theme, CardType.communityChest);
}

/// 根据主题构建所有卡牌
/// [theme]: 当前使用的主题
List<GameCard> buildAllCards(BoardTheme theme) {
  return cardTemplates.buildAllCards(theme);
}