// 地产大亨 - 游戏日志入口
// 游戏中唯一的日志调用入口
// 所有细分功能都封装在此类内部

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../constants/board_config.dart';
import 'game_log.dart';
import 'game_log_manager.dart';

/// 游戏日志入口
/// 游戏中只调用此类记录日志
/// 所有便捷方法和细分功能都封装在此类内部
class GameLogger {
  static final GameLogManager _manager = GameLogManager.instance;
  static final Uuid _uuid = const Uuid();

  static void _log({
    required GameLogLevel level,
    required GameLogType type,
    required String title,
    required String description,
    int? amount,
    String? propertyName,
    String? targetPlayerId,
    String? targetPlayerName,
    Map<String, dynamic>? metadata,
    String? playerId,
    String? playerName,
    int? playerColor,
  }) {
    final entry = GameLogEntry(
      id: _uuid.v4(),
      turnNumber: _manager.currentTurnNumber,
      playerId: playerId ?? _manager.currentPlayerId,
      playerName: playerName ?? _manager.currentPlayerName,
      playerColor: playerColor ?? _manager.currentPlayerColor,
      level: level,
      type: type,
      title: title,
      description: description,
      amount: amount,
      propertyName: propertyName,
      targetPlayerId: targetPlayerId,
      targetPlayerName: targetPlayerName,
      metadata: metadata,
      timestamp: DateTime.now(),
    );

    _manager.logEntry(entry);
  }

  // ==================== 基础日志方法 ====================

  static void debug(String message, {String? playerId, String? playerName, int? playerColor}) {
    _log(
      level: GameLogLevel.debug,
      type: GameLogType.systemMessage,
      title: '调试',
      description: message,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void info(String message, {
    GameLogType? type,
    String? playerId,
    String? playerName,
    int? playerColor,
  }) {
    _log(
      level: GameLogLevel.info,
      type: type ?? GameLogType.systemMessage,
      title: '信息',
      description: message,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void warning(String message, {
    String? playerId,
    String? playerName,
    int? playerColor,
  }) {
    _log(
      level: GameLogLevel.warning,
      type: GameLogType.systemMessage,
      title: '警告',
      description: message,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void important(String message, {
    GameLogType? type,
    String? playerId,
    String? playerName,
    int? playerColor,
  }) {
    _log(
      level: GameLogLevel.important,
      type: type ?? GameLogType.systemMessage,
      title: '重要',
      description: message,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void critical(String message, {
    GameLogType? type,
    String? playerId,
    String? playerName,
    int? playerColor,
  }) {
    _log(
      level: GameLogLevel.critical,
      type: type ?? GameLogType.systemMessage,
      title: '关键',
      description: message,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  // ==================== 便捷工厂方法 ====================

  static void diceRoll({
    required int dice1,
    required int dice2,
    required bool isDoubles,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    final total = dice1 + dice2;
    final title = isDoubles
        ? '掷出对子: $dice1 + $dice2 = $total (对子!)'
        : '掷骰子: $dice1 + $dice2 = $total';

    _log(
      level: GameLogLevel.debug,
      type: GameLogType.diceRoll,
      title: title,
      description: title,
      metadata: {'dice1': dice1, 'dice2': dice2, 'isDoubles': isDoubles},
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void jailDiceRoll({
    required int dice1,
    required int dice2,
    required bool isDoubles,
    required bool isReleased,
    int? remainingTurns,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    final total = dice1 + dice2;
    String message;
    if (isReleased) {
      message = '在监狱中掷出对子 ($dice1+$dice2=$total)，离开监狱';
    } else {
      message = remainingTurns != null && remainingTurns > 0
          ? '在监狱中掷出非对子 ($dice1+$dice2=$total)，还需等待 $remainingTurns 回合'
          : '在监狱中掷出非对子 ($dice1+$dice2=$total)，继续待在监狱';
    }

    _log(
      level: GameLogLevel.debug,
      type: GameLogType.diceRoll,
      title: '监狱掷骰',
      description: message,
      metadata: {'dice1': dice1, 'dice2': dice2, 'isDoubles': isDoubles, 'isReleased': isReleased},
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void playerMove({
    required int fromPosition,
    required int toPosition,
    required int steps,
    required bool passedGo,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    final fromCell = boardCells[fromPosition];
    final toCell = boardCells[toPosition];
    final title = '从位置 $fromPosition(${fromCell.name}) 移动 ${steps} 步到位置 $toPosition(${toCell.name})';

    _log(
      level: GameLogLevel.debug,
      type: GameLogType.playerMove,
      title: title,
      description: passedGo ? '$title，经过起点' : title,
      metadata: {'from': fromPosition, 'to': toPosition, 'steps': steps, 'passedGo': passedGo},
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void passGo({
    required int reward,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.info,
      type: GameLogType.passGo,
      title: '经过起点',
      description: '经过起点，获得 \$$reward',
      amount: reward,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void propertyPurchase({
    required String propertyName,
    required int price,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.important,
      type: GameLogType.propertyPurchase,
      title: '购买地产',
      description: '购买了 $propertyName，花费 \$$price',
      amount: -price,
      propertyName: propertyName,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void rejectPurchase({
    required String propertyName,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.info,
      type: GameLogType.propertyAuction,
      title: '放弃购买',
      description: '放弃购买 $propertyName',
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void payRent({
    required String propertyName,
    required int amount,
    required String payerId,
    required String payerName,
    required int payerColor,
    required String receiverId,
    required String receiverName,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.important,
      type: GameLogType.payRent,
      title: '支付租金',
      description: '向 $receiverName 支付租金 \$$amount（$propertyName）',
      amount: -amount,
      propertyName: propertyName,
      targetPlayerId: receiverId,
      targetPlayerName: receiverName,
      playerId: payerId,
      playerName: payerName,
      playerColor: payerColor,
    );
  }

  static void collectRent({
    required String propertyName,
    required int amount,
    required String collectorId,
    required String collectorName,
    required int collectorColor,
    required String payerName,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.info,
      type: GameLogType.collectRent,
      title: '收取租金',
      description: '从 $payerName 收取租金 \$$amount（$propertyName）',
      amount: amount,
      propertyName: propertyName,
      playerId: collectorId,
      playerName: collectorName,
      playerColor: collectorColor,
    );
  }

  static void buildHouse({
    required String propertyName,
    required int housesBefore,
    required int housesAfter,
    required int cost,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    final houseDesc = housesAfter >= 5 ? '酒店' : '第$housesAfter栋房屋';
    _log(
      level: GameLogLevel.important,
      type: GameLogType.propertyBuild,
      title: housesAfter >= 5 ? '建造酒店' : '建造房屋',
      description: '在 $propertyName 建造了 $houseDesc，花费 \$$cost',
      amount: -cost,
      propertyName: propertyName,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void mortgage({
    required String propertyName,
    required int amount,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.info,
      type: GameLogType.propertyMortgage,
      title: '抵押地产',
      description: '抵押 $propertyName，获得 \$$amount',
      amount: amount,
      propertyName: propertyName,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void redeem({
    required String propertyName,
    required int amount,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.info,
      type: GameLogType.propertyRedeem,
      title: '赎回抵押',
      description: '赎回 $propertyName，支付 \$$amount',
      amount: -amount,
      propertyName: propertyName,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void drawCard({
    required bool isChance,
    required String cardTitle,
    required String cardDescription,
    int? amount,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    final cardType = isChance ? '机会卡' : '公益卡';
    String title = '$cardType: $cardTitle';
    String description = cardDescription;

    _log(
      level: GameLogLevel.important,
      type: isChance ? GameLogType.chanceCard : GameLogType.communityChestCard,
      title: title,
      description: description,
      amount: amount,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void goToJail({
    required String reason,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.critical,
      type: GameLogType.playerJailed,
      title: '进入监狱',
      description: '被送进派出所：$reason',
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void releaseFromJail({
    required String reason,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.important,
      type: GameLogType.playerReleased,
      title: '离开监狱',
      description: reason != null ? '离开监狱：$reason' : '离开监狱',
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void payTax({
    required bool isIncomeTax,
    required int amount,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    final taxType = isIncomeTax ? '所得税' : '奢侈品税';
    _log(
      level: GameLogLevel.warning,
      type: isIncomeTax ? GameLogType.incomeTax : GameLogType.luxuryTax,
      title: '支付税款',
      description: '支付 $taxType \$$amount',
      amount: -amount,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void bankruptcy({
    required String playerId,
    required String playerName,
    required int playerColor,
    required String? creditorName,
    required int turnNumber,
  }) {
    final description = creditorName != null
        ? '破产，资产转移给 $creditorName'
        : '破产，退出游戏';

    _log(
      level: GameLogLevel.critical,
      type: GameLogType.playerBankruptcy,
      title: '玩家破产',
      description: description,
      targetPlayerName: creditorName,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void gameStart({
    required List<String> playerNames,
    required int turnNumber,
  }) {
    final players = playerNames.join('、');
    _log(
      level: GameLogLevel.important,
      type: GameLogType.gameStart,
      title: '游戏开始',
      description: '游戏开始！玩家: $players',
      metadata: {'players': playerNames},
    );
  }

  static void turnStart({
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.info,
      type: GameLogType.turnStart,
      title: '回合开始',
      description: '第 $turnNumber 回合开始',
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void turnEnd({
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.debug,
      type: GameLogType.turnEnd,
      title: '回合结束',
      description: '$playerName 回合结束',
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void gameOver({
    required String winnerId,
    required String winnerName,
    required int winnerColor,
    required int turnNumber,
    required List<Map<String, dynamic>> finalResults,
  }) {
    _log(
      level: GameLogLevel.critical,
      type: GameLogType.gameOver,
      title: '游戏结束',
      description: '$winnerName 赢得游戏！',
      playerId: winnerId,
      playerName: winnerName,
      playerColor: winnerColor,
      metadata: {'results': finalResults},
    );
  }

  static void cashInsufficient({
    required String reason,
    required int needed,
    required int available,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.warning,
      type: GameLogType.systemMessage,
      title: '现金不足',
      description: '$reason（需要 $needed，只有 $available）',
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void consecutiveDoublesWarning({
    required int count,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.warning,
      type: GameLogType.diceRoll,
      title: '连续对子警告',
      description: '连续 $count 次对子，再来一次将被送进派出所',
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void doublesBonus({
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.info,
      type: GameLogType.diceRoll,
      title: '对子奖励',
      description: '掷出对子，可以再掷一次！',
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void houseRepair({
    required int amount,
    required int houseCount,
    required int hotelCount,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.warning,
      type: GameLogType.houseRepair,
      title: '房屋维修',
      description: '支付房屋维修费用（房屋:$houseCount, 酒店:$hotelCount），共计 \$$amount',
      amount: -amount,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void payEachPlayer({
    required int amountPerPlayer,
    required int playerCount,
    required int totalAmount,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.warning,
      type: GameLogType.payToPlayer,
      title: '支付给所有玩家',
      description: '向每位玩家支付 \$$amountPerPlayer（共$playerCount位玩家），共计 \$$totalAmount',
      amount: -totalAmount,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  static void collectFromEachPlayer({
    required int amountPerPlayer,
    required int playerCount,
    required int totalAmount,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    _log(
      level: GameLogLevel.important,
      type: GameLogType.receiveFromPlayer,
      title: '从所有玩家获得',
      description: '从每位玩家获得 \$$amountPerPlayer（共$playerCount位玩家），共计 \$$totalAmount',
      amount: totalAmount,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
    );
  }

  // ==================== 访问器 ====================

  static List<GameLogEntry> get entries => _manager.entries;

  static int get currentTurnNumber => _manager.currentTurnNumber;

  static void clear() => _manager.clear();

  static void setCurrentTurn(int turnNumber, {String? playerId, String? playerName, int? playerColor}) {
    _manager.setCurrentTurn(turnNumber, playerId: playerId, playerName: playerName, playerColor: playerColor);
  }

  static List<GameLogEntry> getFiltered({
    GameLogLevel? minLevel,
    GameLogType? type,
    String? playerId,
    int? turnNumber,
    String? searchQuery,
  }) {
    return _manager.getFiltered(
      minLevel: minLevel,
      type: type,
      playerId: playerId,
      turnNumber: turnNumber,
      searchQuery: searchQuery,
    );
  }

  static Map<int, List<GameLogEntry>> getGroupedByTurn() {
    return _manager.getGroupedByTurn();
  }

  static List<Map<String, dynamic>> exportToJson() {
    return _manager.exportToJson();
  }

  static void importFromJson(List<Map<String, dynamic>> jsonList) {
    _manager.importFromJson(jsonList);
  }
}
