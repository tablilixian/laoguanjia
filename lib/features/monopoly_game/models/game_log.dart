// 地产大亨 - 游戏日志数据模型
// 游戏日志系统的核心数据结构

/// 游戏日志级别
enum GameLogLevel {
  debug(0, '调试', '🔵'),
  info(1, '信息', '✅'),
  warning(2, '警告', '⚠️'),
  important(3, '重要', '🔶'),
  critical(4, '关键', '🔴');

  final int level;
  final String label;
  final String emoji;

  const GameLogLevel(this.level, this.label, this.emoji);

  bool shouldDisplayThan(GameLogLevel other) => level >= other.level;
}

/// 游戏日志类型
enum GameLogType {
  diceRoll('骰子'),
  playerMove('移动'),
  passGo('经过起点'),
  propertyPurchase('购买地产'),
  propertyAuction('拍卖'),
  propertyBuild('建造房屋'),
  propertyMortgage('抵押'),
  propertyRedeem('赎回'),
  payRent('支付租金'),
  collectRent('收取租金'),
  chanceCard('机会卡'),
  communityChestCard('公益卡'),
  incomeTax('所得税'),
  luxuryTax('奢侈品税'),
  houseRepair('房屋维修'),
  playerBankruptcy('破产'),
  playerEliminated('淘汰'),
  playerJailed('入狱'),
  playerReleased('出狱'),
  payToPlayer('支付给玩家'),
  receiveFromPlayer('收到玩家'),
  gameStart('游戏开始'),
  turnStart('回合开始'),
  turnEnd('回合结束'),
  gameOver('游戏结束'),
  aiDecision('AI决策'),
  systemMessage('系统消息'),
  error('错误');

  final String label;

  const GameLogType(this.label);
}

/// 游戏日志条目
class GameLogEntry {
  final String id;
  final int turnNumber;
  final String? playerId;
  final String? playerName;
  final int? playerColor;
  final GameLogLevel level;
  final GameLogType type;
  final String title;
  final String description;
  final int? amount;
  final String? propertyName;
  final String? targetPlayerId;
  final String? targetPlayerName;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  GameLogEntry({
    required this.id,
    required this.turnNumber,
    this.playerId,
    this.playerName,
    this.playerColor,
    required this.level,
    required this.type,
    required this.title,
    required this.description,
    this.amount,
    this.propertyName,
    this.targetPlayerId,
    this.targetPlayerName,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'turnNumber': turnNumber,
        'playerId': playerId,
        'playerName': playerName,
        'playerColor': playerColor,
        'level': level.index,
        'type': type.index,
        'title': title,
        'description': description,
        'amount': amount,
        'propertyName': propertyName,
        'targetPlayerId': targetPlayerId,
        'targetPlayerName': targetPlayerName,
        'metadata': metadata,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GameLogEntry.fromJson(Map<String, dynamic> json) => GameLogEntry(
        id: json['id'],
        turnNumber: json['turnNumber'] ?? 0,
        playerId: json['playerId'],
        playerName: json['playerName'],
        playerColor: json['playerColor'],
        level: GameLogLevel.values[json['level'] ?? 1],
        type: GameLogType.values[json['type'] ?? 0],
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        amount: json['amount'],
        propertyName: json['propertyName'],
        targetPlayerId: json['targetPlayerId'],
        targetPlayerName: json['targetPlayerName'],
        metadata: json['metadata'],
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );

  @override
  String toString() {
    return '$level $turnNumber $playerName: $title - $description';
  }
}
