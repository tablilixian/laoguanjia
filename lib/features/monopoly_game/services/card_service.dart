// 地产大亨 - 卡牌服务
import 'dart:math';
import '../models/models.dart';
import '../constants/board_config.dart';

/// 卡牌服务 - 负责抽卡和卡牌效果执行
class CardService {
  static final Random _random = Random();

  /// 初始化卡牌（洗牌）
  static List<GameCard> shuffleCards(List<GameCard> cards) {
    final shuffled = List<GameCard>.from(cards);
    shuffled.shuffle(_random);
    return shuffled;
  }

  /// 从牌堆顶部抽一张卡
  static (GameCard, int, List<GameCard>) drawCard(List<GameCard> cards, int currentIndex) {
    // 确保索引在有效范围内
    if (cards.isEmpty) {
      throw StateError('卡牌列表为空，无法抽卡');
    }
    final safeIndex = currentIndex % cards.length;
    final card = cards[safeIndex];
    final nextIndex = (safeIndex + 1) % cards.length;
    return (card, nextIndex, cards);
  }

  /// 执行卡牌效果
  /// 返回 (newPosition, amount, passGo, goToJail, getOutOfJailFree)
  static CardEffectResult executeCardEffect(
    GameCard card,
    int currentPosition,
  ) {
    final effect = card.effect;
    
    switch (effect.type) {
      case CardEffectType.advanceTo:
        return _executeAdvanceTo(effect, currentPosition);
      case CardEffectType.advanceToNearestRailroad:
        return _executeAdvanceToNearestRailroad(currentPosition);
      case CardEffectType.advanceToNearestUtility:
        return _executeAdvanceToNearestUtility(currentPosition);
      case CardEffectType.goToJail:
        return const CardEffectResult(
          newPosition: 10, // Jail index
          goToJail: true,
        );
      case CardEffectType.collect:
        return CardEffectResult(
          newPosition: currentPosition,
          amount: effect.value ?? 0,
          collect: true,
        );
      case CardEffectType.pay:
        return CardEffectResult(
          newPosition: currentPosition,
          amount: -(effect.value ?? 0),
          pay: true,
        );
      case CardEffectType.payPerHouse:
        // 这个需要根据玩家实际房屋数量计算，暂时返回标记
        return CardEffectResult(
          newPosition: currentPosition,
          payPerHouse: true,
          houseCost: effect.value ?? 25,
        );
      case CardEffectType.goBack:
        final newPos = currentPosition - (effect.value ?? 3);
        return CardEffectResult(
          newPosition: newPos < 0 ? 40 + newPos : newPos,
        );
      case CardEffectType.getOutOfJailFree:
        return const CardEffectResult(
          newPosition: -1, // -1 表示获得出狱卡
          getOutOfJailCard: true,
        );
      case CardEffectType.electionChairman:
        return CardEffectResult(
          newPosition: currentPosition,
          payEachPlayer: true,
          amount: effect.value ?? 50,
        );
      case CardEffectType.birthday:
        return CardEffectResult(
          newPosition: currentPosition,
          collectFromEachPlayer: true,
          amount: effect.value ?? 10,
        );
    }
  }

  /// 执行前进到指定位置
  static CardEffectResult _executeAdvanceTo(CardEffect effect, int currentPosition) {
    int targetIndex = _findCellIndexByName(effect.target ?? 'Go');
    
    bool shouldPassGo = targetIndex < currentPosition;
    
    return CardEffectResult(
      newPosition: targetIndex,
      passGo: shouldPassGo,
    );
  }

  /// 执行前进到最近火车站
  static CardEffectResult _executeAdvanceToNearestRailroad(int currentPosition) {
    final nearestIndex = _findNearestRailroad(currentPosition);
    return CardEffectResult(
      newPosition: nearestIndex,
      passGo: nearestIndex < currentPosition,
      advanceToNearestRailroad: true,
    );
  }

  /// 执行前进到最近公用事业
  static CardEffectResult _executeAdvanceToNearestUtility(int currentPosition) {
    final nearestIndex = _findNearestUtility(currentPosition);
    return CardEffectResult(
      newPosition: nearestIndex,
      passGo: nearestIndex < currentPosition,
      advanceToNearestUtility: true,
    );
  }

  /// 根据名称查找格子索引
  static int _findCellIndexByName(String name) {
    for (int i = 0; i < boardCells.length; i++) {
      if (boardCells[i].name.contains(name) || name.contains(boardCells[i].name)) {
        return i;
      }
    }
    return 0; // 默认返回Go
  }

  /// 找到最近的火车站
  static int _findNearestRailroad(int fromPosition) {
    int minDistance = 999;
    int nearestIndex = railroadIndices[0];
    
    for (final idx in railroadIndices) {
      int distance = idx - fromPosition;
      if (distance <= 0) distance += 40;
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = idx;
      }
    }
    
    return nearestIndex;
  }

  /// 找到最近的公用事业
  static int _findNearestUtility(int fromPosition) {
    int minDistance = 999;
    int nearestIndex = utilityIndices[0];
    
    for (final idx in utilityIndices) {
      int distance = idx - fromPosition;
      if (distance <= 0) distance += 40;
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = idx;
      }
    }
    
    return nearestIndex;
  }

  /// 检查格子是否是机会卡或社区福利卡
  static bool isCardSpace(int cellIndex) {
    return chanceIndices.contains(cellIndex) || communityChestIndices.contains(cellIndex);
  }

  /// 获取卡牌类型
  static CardType? getCardType(int cellIndex) {
    if (chanceIndices.contains(cellIndex)) return CardType.chance;
    if (communityChestIndices.contains(cellIndex)) return CardType.communityChest;
    return null;
  }
}

/// 卡牌效果执行结果
class CardEffectResult {
  final int newPosition;
  final int amount;              // 正数=获得, 负数=支付
  final bool collect;             // 获得资金
  final bool pay;                 // 支付资金
  final bool passGo;              // 经过起点
  final bool goToJail;            // 前往监狱
  final bool getOutOfJailCard;    // 获得出狱卡
  final bool payPerHouse;         // 按房屋支付
  final int? houseCost;           // 房屋维修费用
  final bool payEachPlayer;       // 支付给每个玩家
  final bool collectFromEachPlayer; // 从每个玩家获得
  final bool advanceToNearestRailroad;  // 前进到火车站
  final bool advanceToNearestUtility;   // 前进到公用事业

  const CardEffectResult({
    this.newPosition = 0,
    this.amount = 0,
    this.collect = false,
    this.pay = false,
    this.passGo = false,
    this.goToJail = false,
    this.getOutOfJailCard = false,
    this.payPerHouse = false,
    this.houseCost,
    this.payEachPlayer = false,
    this.collectFromEachPlayer = false,
    this.advanceToNearestRailroad = false,
    this.advanceToNearestUtility = false,
  });

  bool get hasMoneyEffect => collect || pay || payEachPlayer || collectFromEachPlayer;
  bool get needsPropertyInfo => payPerHouse;
}
