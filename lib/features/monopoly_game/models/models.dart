// 地产大亨游戏 - 数据模型
// 包含玩家、格子、地产、卡牌、游戏状态等核心模型

import 'package:flutter/material.dart';

/// 格子类型枚举
enum CellType {
  go,                        // 起点 - 祖国华诞
  property,                  // 地产 - 城市
  railroad,                  // 高铁站
  utility,                   // 公用事业
  chance,                    // 命运卡
  communityChest,            // 公益卡
  incomeTax,                 // 个人所得税
  luxuryTax,                 // 消费税
  jail,                      // 派出所（仅路过）
  freeParking,               // 人民广场
  goToJail,                  // 前往派出所
}

/// 地产颜色组
enum PropertyColor {
  brown,      // 棕色 - 2格
  lightBlue,  // 浅蓝 - 3格
  pink,       // 粉色 - 3格
  orange,     // 橙色 - 3格
  red,        // 红色 - 3格
  yellow,     // 黄色 - 3格
  green,      // 绿色 - 3格
  darkBlue,   // 深蓝 - 2格
}

/// 玩家状态
enum PlayerStatus {
  active,    // 活跃
  inJail,    // 在监狱中
  bankrupt,  // 破产
}

/// 格子模型
class Cell {
  final int index;
  final String name;
  final CellType type;
  final PropertyColor? color;  // 仅property类型使用
  final int? price;             // 购买价格
  final int? mortgageValue;     // 抵押价值
  final int? baseRent;         // 基础租金
  final List<int>? rentWithHouse; // 有房屋时的租金 [1房,2房,3房,4房,酒店]
  final int? housePrice;       // 房屋建造成本
  final int? railroadIndex;    // 火车站编号
  final bool isUtility;        // 是否是公用事业

  const Cell({
    required this.index,
    required this.name,
    required this.type,
    this.color,
    this.price,
    this.mortgageValue,
    this.baseRent,
    this.rentWithHouse,
    this.housePrice,
    this.railroadIndex,
    this.isUtility = false,
  });

  /// 是否可以购买
  bool get isPurchasable =>
      type == CellType.property || type == CellType.railroad || type == CellType.utility;

  /// 是否可以建造房屋
  bool get isBuildable => type == CellType.property && color != null;
}

/// 地产状态模型
class PropertyState {
  final int cellIndex;
  final String? ownerId;
  final int houses;         // 0-4 房屋数量, 5表示酒店
  final bool isMortgaged;   // 是否已抵押

  const PropertyState({
    required this.cellIndex,
    this.ownerId,
    this.houses = 0,
    this.isMortgaged = false,
  });

  bool get hasHotel => houses >= 5;
  bool get hasCompleteSet => ownerId != null;

  PropertyState copyWith({
    int? cellIndex,
    String? ownerId,
    int? houses,
    bool? isMortgaged,
  }) {
    return PropertyState(
      cellIndex: cellIndex ?? this.cellIndex,
      ownerId: ownerId ?? this.ownerId,
      houses: houses ?? this.houses,
      isMortgaged: isMortgaged ?? this.isMortgaged,
    );
  }

  Map<String, dynamic> toJson() => {
    'cellIndex': cellIndex,
    'ownerId': ownerId,
    'houses': houses,
    'isMortgaged': isMortgaged,
  };

  factory PropertyState.fromJson(Map<String, dynamic> json) => PropertyState(
    cellIndex: json['cellIndex'],
    ownerId: json['ownerId'],
    houses: json['houses'] ?? 0,
    isMortgaged: json['isMortgaged'] ?? false,
  );
}

/// 玩家模型
class Player {
  final String id;
  final String name;
  final Color tokenColor;
  final int position;         // 当前在棋盘上的位置
  final int cash;              // 现金
  final int cashAtStart;      // 初始现金
  final PlayerStatus status;
  final int jailTurns;        // 在监狱的剩余回合数
  final bool hasGetOutOfJailFree; // 是否持有出狱卡
  final List<int> ownedProperties; // 拥有的地产索引列表
  final bool isHuman;          // 是否为人类玩家

  const Player({
    required this.id,
    required this.name,
    required this.tokenColor,
    this.position = 0,
    this.cash = 1500,
    this.cashAtStart = 1500,
    this.status = PlayerStatus.active,
    this.jailTurns = 0,
    this.hasGetOutOfJailFree = false,
    this.ownedProperties = const [],
    this.isHuman = false,
  });

  bool get isBankrupt => status == PlayerStatus.bankrupt;
  bool get isInJail => status == PlayerStatus.inJail;

  /// 计算玩家总资产
  int totalAssets(int propertyValues, int housesValue) {
    return cash + propertyValues + housesValue;
  }

  Player copyWith({
    String? id,
    String? name,
    Color? tokenColor,
    int? position,
    int? cash,
    int? cashAtStart,
    PlayerStatus? status,
    int? jailTurns,
    bool? hasGetOutOfJailFree,
    List<int>? ownedProperties,
    bool? isHuman,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      tokenColor: tokenColor ?? this.tokenColor,
      position: position ?? this.position,
      cash: cash ?? this.cash,
      cashAtStart: cashAtStart ?? this.cashAtStart,
      status: status ?? this.status,
      jailTurns: jailTurns ?? this.jailTurns,
      hasGetOutOfJailFree: hasGetOutOfJailFree ?? this.hasGetOutOfJailFree,
      ownedProperties: ownedProperties ?? this.ownedProperties,
      isHuman: isHuman ?? this.isHuman,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tokenColor': tokenColor.toARGB32(),
    'position': position,
    'cash': cash,
    'cashAtStart': cashAtStart,
    'status': status.index,
    'jailTurns': jailTurns,
    'hasGetOutOfJailFree': hasGetOutOfJailFree,
    'ownedProperties': ownedProperties,
    'isHuman': isHuman,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'],
    name: json['name'],
    tokenColor: Color(json['tokenColor']),
    position: json['position'] ?? 0,
    cash: json['cash'] ?? 1500,
    cashAtStart: json['cashAtStart'] ?? 1500,
    status: PlayerStatus.values[json['status'] ?? 0],
    jailTurns: json['jailTurns'] ?? 0,
    hasGetOutOfJailFree: json['hasGetOutOfJailFree'] ?? false,
    ownedProperties: List<int>.from(json['ownedProperties'] ?? []),
    isHuman: json['isHuman'] ?? false,
  );
}

/// 卡牌类型
enum CardType {
  chance,         // 机会卡
  communityChest, // 社区福利卡
}

/// 卡牌效果类型
enum CardEffectType {
  advanceTo,              // 前进至指定位置
  advanceToNearestRailroad, // 前进至最近火车站
  advanceToNearestUtility, // 前进至最近公用事业
  goToJail,               // 前往监狱
  collect,                // 获得资金
  pay,                    // 支付费用
  payPerHouse,             // 按房屋支付
  goBack,                 // 后退
  getOutOfJailFree,       // 出狱卡
  electionChairman,       // 支付每位玩家
}

/// 卡牌效果
class CardEffect {
  final CardEffectType type;
  final int? value;           // 数值参数
  final String? target;       // 目标位置名称
  final bool passGo;          // 是否经过起点

  const CardEffect({
    required this.type,
    this.value,
    this.target,
    this.passGo = false,
  });
}

/// 卡牌模型
class GameCard {
  final String id;
  final CardType type;
  final String title;
  final String description;
  final CardEffect effect;

  const GameCard({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.effect,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'title': title,
    'description': description,
    'effect': {
      'type': effect.type.index,
      'value': effect.value,
      'target': effect.target,
      'passGo': effect.passGo,
    },
  };

  factory GameCard.fromJson(Map<String, dynamic> json) {
    final effectJson = json['effect'];
    return GameCard(
      id: json['id'],
      type: CardType.values[json['type']],
      title: json['title'],
      description: json['description'],
      effect: CardEffect(
        type: CardEffectType.values[effectJson['type']],
        value: effectJson['value'],
        target: effectJson['target'],
        passGo: effectJson['passGo'] ?? false,
      ),
    );
  }
}

/// 游戏流程状态
enum GamePhase {
  init,               // 初始化
  playerTurnStart,    // 玩家回合开始
  diceRolling,        // 掷骰子
  playerMoving,       // 玩家移动
  eventProcessing,   // 事件处理
  playerAction,       // 玩家行动选择
  turnEnd,            // 回合结束
  gameOver,           // 游戏结束
}

/// AI难度
enum AIDifficulty {
  easy,   // 简单
  hard,   // 困难
}

/// AI性格
enum AIPersonality {
  aggressive, // 激进型 - 积极购买和建造
  conservative, // 保守型 - 现金为王
  random,    // 随机型
}

/// 游戏设置
class GameSettings {
  final int playerCount;
  final AIDifficulty difficulty;
  final List<AIPersonality> aiPersonas;
  final bool soundEnabled;
  final bool musicEnabled;
  final bool autoSaveEnabled;

  const GameSettings({
    this.playerCount = 2,
    this.difficulty = AIDifficulty.easy,
    this.aiPersonas = const [AIPersonality.conservative],
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.autoSaveEnabled = true,
  });

  GameSettings copyWith({
    int? playerCount,
    AIDifficulty? difficulty,
    List<AIPersonality>? aiPersonas,
    bool? soundEnabled,
    bool? musicEnabled,
    bool? autoSaveEnabled,
  }) {
    return GameSettings(
      playerCount: playerCount ?? this.playerCount,
      difficulty: difficulty ?? this.difficulty,
      aiPersonas: aiPersonas ?? this.aiPersonas,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'playerCount': playerCount,
    'difficulty': difficulty.index,
    'aiPersonas': aiPersonas.map((e) => e.index).toList(),
    'soundEnabled': soundEnabled,
    'musicEnabled': musicEnabled,
    'autoSaveEnabled': autoSaveEnabled,
  };

  factory GameSettings.fromJson(Map<String, dynamic> json) => GameSettings(
    playerCount: json['playerCount'] ?? 2,
    difficulty: AIDifficulty.values[json['difficulty'] ?? 0],
    aiPersonas: (json['aiPersonas'] as List?)?.map((e) => AIPersonality.values[e]).toList() ?? [AIPersonality.conservative],
    soundEnabled: json['soundEnabled'] ?? true,
    musicEnabled: json['musicEnabled'] ?? true,
    autoSaveEnabled: json['autoSaveEnabled'] ?? true,
  );
}

/// 游戏状态模型
class GameState {
  final List<Player> players;
  final int currentPlayerIndex;
  final int turnNumber;
  final GamePhase phase;
  final List<PropertyState> properties;
  final List<GameCard> chanceCards;
  final List<GameCard> communityChestCards;
  final int chanceCardIndex;
  final int communityChestCardIndex;
  final int? lastDice1;
  final int? lastDice2;
  final bool isDoubles;          // 是否掷出双三
  final int consecutiveDoubles;  // 连续双三次数
  final String? winnerId;
  final GameSettings settings;

  const GameState({
    required this.players,
    this.currentPlayerIndex = 0,
    this.turnNumber = 1,
    this.phase = GamePhase.init,
    this.properties = const [],
    this.chanceCards = const [],
    this.communityChestCards = const [],
    this.chanceCardIndex = 0,
    this.communityChestCardIndex = 0,
    this.lastDice1,
    this.lastDice2,
    this.isDoubles = false,
    this.consecutiveDoubles = 0,
    this.winnerId,
    this.settings = const GameSettings(),
  });

  Player get currentPlayer => players[currentPlayerIndex];

  bool get isGameOver => winnerId != null;

  GameState copyWith({
    List<Player>? players,
    int? currentPlayerIndex,
    int? turnNumber,
    GamePhase? phase,
    List<PropertyState>? properties,
    List<GameCard>? chanceCards,
    List<GameCard>? communityChestCards,
    int? chanceCardIndex,
    int? communityChestCardIndex,
    int? lastDice1,
    int? lastDice2,
    bool? isDoubles,
    int? consecutiveDoubles,
    String? winnerId,
    GameSettings? settings,
  }) {
    return GameState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      turnNumber: turnNumber ?? this.turnNumber,
      phase: phase ?? this.phase,
      properties: properties ?? this.properties,
      chanceCards: chanceCards ?? this.chanceCards,
      communityChestCards: communityChestCards ?? this.communityChestCards,
      chanceCardIndex: chanceCardIndex ?? this.chanceCardIndex,
      communityChestCardIndex: communityChestCardIndex ?? this.communityChestCardIndex,
      lastDice1: lastDice1 ?? this.lastDice1,
      lastDice2: lastDice2 ?? this.lastDice2,
      isDoubles: isDoubles ?? this.isDoubles,
      consecutiveDoubles: consecutiveDoubles ?? this.consecutiveDoubles,
      winnerId: winnerId ?? this.winnerId,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
    'currentPlayerIndex': currentPlayerIndex,
    'turnNumber': turnNumber,
    'phase': phase.index,
    'properties': properties.map((p) => p.toJson()).toList(),
    'chanceCardIndex': chanceCardIndex,
    'communityChestCardIndex': communityChestCardIndex,
    'lastDice1': lastDice1,
    'lastDice2': lastDice2,
    'isDoubles': isDoubles,
    'consecutiveDoubles': consecutiveDoubles,
    'winnerId': winnerId,
    'settings': settings.toJson(),
  };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
    players: (json['players'] as List).map((p) => Player.fromJson(p)).toList(),
    currentPlayerIndex: json['currentPlayerIndex'] ?? 0,
    turnNumber: json['turnNumber'] ?? 1,
    phase: GamePhase.values[json['phase'] ?? 0],
    properties: (json['properties'] as List?)?.map((p) => PropertyState.fromJson(p)).toList() ?? [],
    chanceCards: [],
    communityChestCards: [],
    chanceCardIndex: json['chanceCardIndex'] ?? 0,
    communityChestCardIndex: json['communityChestCardIndex'] ?? 0,
    lastDice1: json['lastDice1'],
    lastDice2: json['lastDice2'],
    isDoubles: json['isDoubles'] ?? false,
    consecutiveDoubles: json['consecutiveDoubles'] ?? 0,
    winnerId: json['winnerId'],
    settings: json['settings'] != null ? GameSettings.fromJson(json['settings']) : const GameSettings(),
  );
}
