// 地产大亨 - 购买对话框
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../constants/board_config.dart';
import '../../providers/game_provider.dart';
import '../../services/rent_calculator.dart';

class BuyPropertyDialog extends ConsumerWidget {
  final int propertyIndex;
  final VoidCallback onBuy;
  final VoidCallback onReject;

  const BuyPropertyDialog({
    super.key,
    required this.propertyIndex,
    required this.onBuy,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final cell = boardCells[propertyIndex];
    final property = gameState.properties.firstWhere((p) => p.cellIndex == propertyIndex);
    final price = cell.price ?? 0;
    final player = gameState.currentPlayer;
    final diceTotal = gameState.lastDiceTotal > 0 ? gameState.lastDiceTotal : 7;

    RentCalculator.calculateRent(
      cellIndex: propertyIndex,
      properties: gameState.properties,
      players: gameState.players,
      diceTotal: diceTotal,
    );

    return AlertDialog(
      title: Text(cell.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('购买价格', '\$$price'),
            const SizedBox(height: 8),
            _buildInfoRow('抵押价值', '\$${cell.mortgageValue ?? 0}'),
            if (cell.color != null) ...[
              const SizedBox(height: 12),
              _checkColorGroup(cell.color!, gameState),
            ],
            const Divider(height: 24),
            _buildRentSection(cell, property, gameState, diceTotal),
            const Divider(height: 24),
            _buildPlayerCashRow(player.cash, price),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onReject,
          child: const Text('不购买'),
        ),
        ElevatedButton(
          onPressed: player.cash >= price ? onBuy : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('购买'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPlayerCashRow(int cash, int price) {
    final canAfford = cash >= price;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: canAfford ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('💰 您的现金', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '\$$cash',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: canAfford ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentSection(Cell cell, PropertyState property, GameState gameState, int diceTotal) {
    final PropertyColor? color = cell.color;

    if (cell.type == CellType.property && color != null) {
      return _buildPropertyRentTable(cell, color, gameState);
    } else if (cell.type == CellType.railroad) {
      return _buildRailroadRentInfo(property, gameState);
    } else if (cell.type == CellType.utility) {
      return _buildUtilityRentInfo(diceTotal);
    }

    return const SizedBox.shrink();
  }

  Widget _buildPropertyRentTable(Cell cell, PropertyColor color, GameState gameState) {
    final indices = colorGroupProperties[color]!;
    final ownedByMe = indices.where((i) => 
      gameState.properties.any((p) => p.cellIndex == i && p.ownerId == gameState.currentPlayer.id)
    ).length;
    final isComplete = ownedByMe == indices.length;
    final colorName = propertyColorNames[color] ?? color.name;

    final baseRent = cell.baseRent ?? 0;
    final rentWithHouse = cell.rentWithHouse ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 购买后租金收入',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              _rentRow('无房屋', isComplete ? baseRent * 2 : baseRent, 
                  isComplete ? '(翻倍)' : ''),
              ...rentWithHouse.asMap().entries.map((entry) {
                final idx = entry.key;
                final rent = entry.value;
                final label = idx == 4 ? '酒店' : '${idx + 1}栋房屋';
                return _rentRow(label, rent, null);
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isComplete 
              ? '✅ 拥有完整 $colorName 色组，租金翻倍！'
              : '💡 购买全部 $colorName 色组后租金翻倍 (当前: $ownedByMe/${indices.length})',
          style: TextStyle(
            fontSize: 12,
            color: isComplete ? Colors.green : Colors.orange.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _rentRow(String label, int rent, String? suffix) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Row(
            children: [
              Text('\$$rent', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (suffix != null)
                Text(suffix, style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRailroadRentInfo(PropertyState property, GameState gameState) {
    final railroadIndices = [5, 15, 25, 35];
    final ownedCount = railroadIndices.where((i) => 
      gameState.properties.any((p) => p.cellIndex == i && p.ownerId == gameState.currentPlayer.id)
    ).length;

    final rentTable = [25, 50, 100, 200];
    final currentRent = rentTable[ownedCount > 0 ? ownedCount - 1 : 0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 购买后租金收入',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              _rentRow('拥有1个车站', rentTable[0], null),
              _rentRow('拥有2个车站', rentTable[1], null),
              _rentRow('拥有3个车站', rentTable[2], null),
              _rentRow('拥有4个车站', rentTable[3], null),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('当前可收', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('\$$currentRent', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '💡 拥有越多车站，租金越高 (当前: $ownedCount/4)',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
        ),
      ],
    );
  }

  Widget _buildUtilityRentInfo(int diceTotal) {
    final rent1 = diceTotal * 4;
    final rent2 = diceTotal * 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 购买后租金收入',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              Text('当前骰子: $diceTotal', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              _rentRow('拥有1个公用事业', rent1, '($diceTotal×4)'),
              _rentRow('拥有2个公用事业', rent2, '($diceTotal×10)'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '💡 拥有2个公用事业后，租金按骰子数×10计算',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
        ),
      ],
    );
  }

  Widget _checkColorGroup(PropertyColor color, GameState gameState) {
    final indices = colorGroupProperties[color]!;
    final ownedCount = indices.where((i) => 
      gameState.properties.any((p) => p.cellIndex == i && p.ownerId == gameState.currentPlayer.id)
    ).length;
    
    final isComplete = ownedCount == indices.length;
    final colorName = propertyColorNames[color] ?? color.name;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            color: Color(propertyColorValues[color] ?? 0xFF808080),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isComplete 
                  ? '完整色组 - 租金翻倍!'
                  : '$colorName 组 ($ownedCount/${indices.length})',
              style: TextStyle(
                color: isComplete ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 显示购买对话框
void showBuyPropertyDialog(BuildContext context, int propertyIndex) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Consumer(
      builder: (ctx, ref, child) {
        final notifier = ref.read(gameProvider.notifier);
        return BuyPropertyDialog(
          propertyIndex: propertyIndex,
          onBuy: () {
            notifier.buyProperty(propertyIndex);
            Navigator.pop(dialogContext);
          },
          onReject: () {
            notifier.rejectPurchase();
            Navigator.pop(dialogContext);
          },
        );
      },
    ),
  );
}
