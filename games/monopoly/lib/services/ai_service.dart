// 地产大亨 - AI服务
import 'dart:math';
import '../models/models.dart';
import '../constants/board_config.dart';
import 'rent_calculator.dart';

/// AI决策结果
class AIDecision {
  final AIAction action;
  final int? targetIndex;  // 地产索引
  final int? bidAmount;    // 拍卖出价
  final int? buildCount;   // 建造数量

  const AIDecision({
    required this.action,
    this.targetIndex,
    this.bidAmount,
    this.buildCount,
  });
}

/// AI可执行的动作
enum AIAction {
  buy,           // 购买地产
  dontBuy,       // 不购买
  auction,       // 参与拍卖
  build,         // 建造房屋
  sell,          // 出售房屋
  mortgage,      // 抵押地产
  redeem,        // 赎回抵押
  payBail,       // 支付保释金
  useJailCard,   // 使用出狱卡
  endTurn,       // 结束回合
}

/// AI服务
class AIService {
  static final Random _random = Random();

  /// 决定是否购买地产
  static AIDecision decideBuyProperty({
    required Player player,
    required int propertyIndex,
    required List<PropertyState> properties,
    required AIDifficulty difficulty,
    required AIPersonality personality,
  }) {
    final cell = boardCells[propertyIndex];
    final price = cell.price ?? 0;
    
    // 简单难度低概率购买
    if (difficulty == AIDifficulty.easy) {
      if (_random.nextDouble() > 0.6) {
        return const AIDecision(action: AIAction.dontBuy);
      }
    }

    // 检查现金是否足够
    if (player.cash < price) {
      return const AIDecision(action: AIAction.dontBuy);
    }

    // 根据性格决定
    switch (personality) {
      case AIPersonality.aggressive:
        // 激进型：尽可能购买
        if (player.cash >= price) {
          return AIDecision(action: AIAction.buy, targetIndex: propertyIndex);
        }
        break;
      case AIPersonality.conservative:
        // 保守型：保留现金，只买便宜的或高回报的
        if (player.cash >= price * 1.5) {
          // 评估回报率
          final expectedRent = _estimateRent(cell);
          final roi = expectedRent / price;
          if (roi > 0.1 || price < 200) {
            return AIDecision(action: AIAction.buy, targetIndex: propertyIndex);
          }
        }
        break;
      case AIPersonality.random:
        // 随机型
        if (_random.nextBool()) {
          return AIDecision(action: AIAction.buy, targetIndex: propertyIndex);
        }
        break;
    }

    return const AIDecision(action: AIAction.dontBuy);
  }

  /// 决定是否建造房屋
  static AIDecision decideBuildHouse({
    required Player player,
    required List<PropertyState> properties,
    required AIDifficulty difficulty,
    required AIPersonality personality,
  }) {
    // 找到可以建造的色组
    final buildableColors = _findBuildableColors(player.id, properties);
    
    if (buildableColors.isEmpty) {
      return const AIDecision(action: AIAction.endTurn);
    }

    // 简单难度不主动建造
    if (difficulty == AIDifficulty.easy && _random.nextDouble() > 0.4) {
      return const AIDecision(action: AIAction.endTurn);
    }

    // 选择一个色组建造
    final color = buildableColors.first;
    final indices = colorGroupProperties[color]!;
    
    // 计算需要的现金
    int totalCost = 0;
    for (final idx in indices) {
      final prop = properties.firstWhere((p) => p.cellIndex == idx);
      if (prop.houses < 4) {
        totalCost += RentCalculator.getHousePrice(idx);
      }
    }

    // 激进型更愿意建造
    switch (personality) {
      case AIPersonality.aggressive:
        if (player.cash > totalCost * 2) {
          return AIDecision(
            action: AIAction.build,
            targetIndex: indices[0],
            buildCount: 1,
          );
        }
        break;
      case AIPersonality.conservative:
        if (player.cash > totalCost * 3) {
          return AIDecision(
            action: AIAction.build,
            targetIndex: indices[0],
            buildCount: 1,
          );
        }
        break;
      case AIPersonality.random:
        if (_random.nextBool() && player.cash > totalCost * 1.5) {
          return AIDecision(
            action: AIAction.build,
            targetIndex: indices[0],
            buildCount: 1,
          );
        }
        break;
    }

    return const AIDecision(action: AIAction.endTurn);
  }

  /// 决定是否支付保释金
  static AIDecision decideJailBail({
    required Player player,
    required AIDifficulty difficulty,
  }) {
    if (player.hasGetOutOfJailFree) {
      return const AIDecision(action: AIAction.useJailCard);
    }

    // 简单难度倾向于不支付
    if (difficulty == AIDifficulty.easy) {
      if (_random.nextDouble() > 0.5) {
        return const AIDecision(action: AIAction.endTurn); // 等待
      }
    }

    // 有足够现金就支付
    if (player.cash >= 100) {
      return const AIDecision(action: AIAction.payBail);
    }

    return const AIDecision(action: AIAction.endTurn);
  }

  /// 决定拍卖出价
  static AIDecision decideAuctionBid({
    required Player player,
    required int propertyIndex,
    required int currentBid,
    required AIDifficulty difficulty,
  }) {
    final cell = boardCells[propertyIndex];
    final maxBid = cell.price ?? 100;
    
    // 简单难度不参与高价拍卖
    if (difficulty == AIDifficulty.easy && currentBid > maxBid * 0.8) {
      return const AIDecision(action: AIAction.dontBuy);
    }

    // 激进型愿意出更高价
    int willingToPay = maxBid;
    if (difficulty == AIDifficulty.hard) {
      willingToPay = (maxBid * 1.2).round();
    }

    if (currentBid < willingToPay && player.cash > currentBid + 50) {
      return AIDecision(
        action: AIAction.auction,
        bidAmount: currentBid + 50,
      );
    }

    return const AIDecision(action: AIAction.dontBuy);
  }

  /// 估计地产预期租金
  static int _estimateRent(Cell cell) {
    if (cell.type == CellType.property) {
      return cell.baseRent ?? 10;
    } else if (cell.type == CellType.railroad) {
      return 25; // 基础火车站租金
    } else if (cell.type == CellType.utility) {
      return 28; // 平均骰子点数(7) * 4
    }
    return 0;
  }

  /// 找到可以建造房屋的色组
  static List<PropertyColor> _findBuildableColors(String playerId, List<PropertyState> properties) {
    final List<PropertyColor> buildable = [];
    
    for (final entry in colorGroupProperties.entries) {
      final color = entry.key;
      final indices = entry.value;
      
      // 检查是否拥有完整色组
      final owned = properties.where(
        (p) => indices.contains(p.cellIndex) && p.ownerId == playerId && !p.isMortgaged
      );
      
      if (owned.length == indices.length && owned.any((p) => p.houses < 4)) {
        buildable.add(color);
      }
    }
    
    return buildable;
  }

  /// 评估地产价值
  static int evaluatePropertyValue(int propertyIndex, List<PropertyState> properties) {
    final cell = boardCells[propertyIndex];
    int value = cell.price ?? 0;
    
    // 加上预期租金收益
    value += _estimateRent(cell) * 10; // 假设10回合回本
    
    // 如果是完整色组的一部分，价值更高
    if (cell.color != null) {
      final ownedInGroup = properties.where(
        (p) => p.cellIndex != propertyIndex && 
               p.ownerId != null &&
               colorGroupProperties[cell.color]!.contains(p.cellIndex)
      );
      if (ownedInGroup.isNotEmpty) {
        value = (value * 1.5).round();
      }
    }
    
    return value;
  }
}
