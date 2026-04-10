// 地产大亨 - 租金计算服务
import '../models/models.dart';
import '../constants/board_config.dart';

/// 租金计算结果
class RentResult {
  final int amount;
  final bool doubled;        // 是否因完整色组而翻倍
  final String description;

  const RentResult({
    required this.amount,
    this.doubled = false,
    required this.description,
  });
}

/// 租金计算器
class RentCalculator {
  /// 计算指定地产的租金
  static RentResult calculateRent({
    required int cellIndex,
    required List<PropertyState> properties,
    required List<Player> players,
    required int diceTotal,
  }) {
    final cell = boardCells[cellIndex];
    if (cell.type != CellType.property && cell.type != CellType.railroad && cell.type != CellType.utility) {
      return const RentResult(amount: 0, description: '此格子不收取租金');
    }

    // 找到该地产的拥有者
    final propertyState = properties.firstWhere(
      (p) => p.cellIndex == cellIndex,
      orElse: () => PropertyState(cellIndex: cellIndex),
    );

    if (propertyState.ownerId == null || propertyState.isMortgaged) {
      return const RentResult(amount: 0, description: '此地产未被拥有或已抵押');
    }

    switch (cell.type) {
      case CellType.property:
        return _calculatePropertyRent(cell, propertyState, properties, players);
      case CellType.railroad:
        return _calculateRailroadRent(propertyState, properties);
      case CellType.utility:
        return _calculateUtilityRent(propertyState, properties, diceTotal);
      default:
        return const RentResult(amount: 0, description: '无效的地产类型');
    }
  }

  /// 计算普通地产租金
  static RentResult _calculatePropertyRent(
    Cell cell,
    PropertyState propertyState,
    List<PropertyState> properties,
    List<Player> players,
  ) {
    final color = cell.color!;
    final ownedInGroup = _getOwnedInColorGroup(color, propertyState.ownerId!, properties);
    final colorGroupSize = colorGroupProperties[color]!.length;
    final hasCompleteSet = ownedInGroup.length == colorGroupSize;

    // 检查是否有完整色组（且未被抵押）
    final allUnmortgaged = ownedInGroup.every((p) => !p.isMortgaged);
    final bool doubled = hasCompleteSet && allUnmortgaged;

    int rent = 0;
    String description = '';

    if (propertyState.houses == 0) {
      // 无房屋
      rent = cell.baseRent!;
      if (doubled) {
        rent *= 2;
        description = '完整色组租金翻倍';
      } else {
        description = '基础租金';
      }
    } else if (propertyState.hasHotel) {
      // 有酒店（houses >= 5）
      rent = cell.rentWithHouse![4]; // 索引 4 是酒店租金（最后一个元素）
      description = '酒店租金';
    } else {
      // 有房屋（1-4栋）
      rent = cell.rentWithHouse![propertyState.houses - 1]; // houses=1对应索引0，houses=4对应索引3
      description = '${propertyState.houses}栋房屋租金';
    }

    return RentResult(
      amount: rent,
      doubled: doubled,
      description: description,
    );
  }

  /// 计算火车站租金
  static RentResult _calculateRailroadRent(
    PropertyState propertyState,
    List<PropertyState> properties,
  ) {
    final railroadCount = _getOwnedRailroads(propertyState.ownerId!, properties).length;
    final rent = railroadRentTable[railroadCount] ?? 25;

    return RentResult(
      amount: rent,
      description: '拥有$railroadCount个火车站',
    );
  }

  /// 计算公用事业租金
  static RentResult _calculateUtilityRent(
    PropertyState propertyState,
    List<PropertyState> properties,
    int diceTotal,
  ) {
    final utilityCount = _getOwnedUtilities(propertyState.ownerId!, properties).length;
    final multiplier = utilityRentMultiplier[utilityCount] ?? 4;
    final rent = diceTotal * multiplier;

    return RentResult(
      amount: rent,
      description: '拥有$utilityCount个公用事业 × ${diceTotal}点',
    );
  }

  /// 获取某玩家在指定色组拥有的地产
  static List<PropertyState> _getOwnedInColorGroup(
    PropertyColor color,
    String ownerId,
    List<PropertyState> properties,
  ) {
    final indices = colorGroupProperties[color]!;
    return properties.where((p) => indices.contains(p.cellIndex) && p.ownerId == ownerId).toList();
  }

  /// 获取某玩家拥有的火车站
  static List<PropertyState> _getOwnedRailroads(String ownerId, List<PropertyState> properties) {
    return properties.where((p) => railroadIndices.contains(p.cellIndex) && p.ownerId == ownerId).toList();
  }

  /// 获取某玩家拥有的公用事业
  static List<PropertyState> _getOwnedUtilities(String ownerId, List<PropertyState> properties) {
    return properties.where((p) => utilityIndices.contains(p.cellIndex) && p.ownerId == ownerId).toList();
  }

  /// 检查玩家是否可以建造房屋
  static bool canBuildHouse(String playerId, PropertyColor color, List<PropertyState> properties) {
    final ownedInGroup = _getOwnedInColorGroup(color, playerId, properties);
    final colorGroupSize = colorGroupProperties[color]!.length;

    // 必须拥有完整色组
    if (ownedInGroup.length != colorGroupSize) return false;

    // 检查是否有未抵押的
    if (!ownedInGroup.every((p) => !p.isMortgaged)) return false;

    return true;
  }

  /// 计算建造房屋的费用
  static int getHousePrice(int cellIndex) {
    return boardCells[cellIndex].housePrice ?? 0;
  }

  /// 计算抵押价值
  static int getMortgageValue(int cellIndex) {
    return boardCells[cellIndex].mortgageValue ?? 0;
  }

  /// 计算赎回抵押的费用（抵押价值 + 10%利息）
  static int getRedeemValue(int cellIndex) {
    final mortgageValue = getMortgageValue(cellIndex);
    return (mortgageValue * 1.1).round();
  }

  /// 计算房屋/酒店维修费用（卡牌效果）
  static int calculateRepairCost(List<PropertyState> properties, int houseCost, int hotelCost) {
    int total = 0;
    for (final p in properties) {
      if (p.hasHotel) {
        total += hotelCost;
      } else if (p.houses > 0) {
        total += p.houses * houseCost;
      }
    }
    return total;
  }
}
