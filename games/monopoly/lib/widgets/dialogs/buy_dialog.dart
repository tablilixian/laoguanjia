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
    
    // 计算租金
    final rentResult = RentCalculator.calculateRent(
      cellIndex: propertyIndex,
      properties: gameState.properties,
      players: gameState.players,
      diceTotal: 7,
    );

    return AlertDialog(
      title: Text(cell.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 地产价格
          _buildInfoRow('购买价格', '\$$price'),
          const SizedBox(height: 8),
          // 抵押价值
          _buildInfoRow('抵押价值', '\$${cell.mortgageValue ?? 0}'),
          const SizedBox(height: 8),
          // 当前租金
          _buildInfoRow('当前租金', '\$${rentResult.amount}'),
          if (cell.color != null) ...[
            const SizedBox(height: 8),
            // 检查色组完整性
            _checkColorGroup(cell.color!, gameState),
          ],
          const Divider(),
          // 玩家现金
          _buildInfoRow(
            '您的现金', 
            '\$${player.cash}',
            color: player.cash >= price ? Colors.green : Colors.red,
          ),
        ],
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

  Widget _checkColorGroup(PropertyColor color, GameState gameState) {
    final indices = colorGroupProperties[color]!;
    final ownedCount = indices.where((i) => 
      gameState.properties.any((p) => p.cellIndex == i && p.ownerId == gameState.currentPlayer.id)
    ).length;
    
    final isComplete = ownedCount == indices.length;
    final colorName = color.name;
    
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
