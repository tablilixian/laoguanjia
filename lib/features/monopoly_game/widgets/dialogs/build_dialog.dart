// 地产大亨 - 建造房屋对话框
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../constants/board_config.dart';
import '../../providers/game_provider.dart';
import '../../services/rent_calculator.dart';

class BuildHouseDialog extends ConsumerWidget {
  final int propertyIndex;
  final VoidCallback onBuild;
  final VoidCallback onSell;
  final VoidCallback onMortgage;
  final VoidCallback onRedeem;
  final VoidCallback onClose;

  const BuildHouseDialog({
    super.key,
    required this.propertyIndex,
    required this.onBuild,
    required this.onSell,
    required this.onMortgage,
    required this.onRedeem,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final cell = boardCells[propertyIndex];
    final property = gameState.properties.firstWhere((p) => p.cellIndex == propertyIndex);
    final player = gameState.currentPlayer;
    
    if (cell.type != CellType.property || cell.color == null) {
      return const SizedBox.shrink();
    }

    final color = cell.color!;
    final indices = colorGroupProperties[color]!;
    final price = RentCalculator.getHousePrice(propertyIndex);
    final mortgageValue = RentCalculator.getMortgageValue(propertyIndex);
    final redeemValue = RentCalculator.getRedeemValue(propertyIndex);

    return AlertDialog(
      title: Text(cell.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 颜色组信息
            _buildColorGroupInfo(color, indices, gameState, player.id),
            const Divider(),
            // 当前建筑状态
            _buildBuildingStatus(property, cell),
            const SizedBox(height: 16),
            // 玩家现金
            _buildInfoRow('您的现金', '\$${player.cash}', 
                color: player.cash >= price ? Colors.green : Colors.red),
          ],
        ),
      ),
      actions: [
        // 抵押/赎回按钮
        if (property.isMortgaged)
          ElevatedButton(
            onPressed: player.cash >= redeemValue ? onRedeem : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: Text('赎回 (\$$redeemValue)'),
          )
        else if (property.houses == 0)
          ElevatedButton(
            onPressed: player.cash >= mortgageValue ? onMortgage : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: Text('抵押 +\$$mortgageValue'),
          ),
        
        const Spacer(),
        
        // 出售按钮
        if (property.houses > 0)
          TextButton(
            onPressed: onSell,
            child: const Text('出售房屋', style: TextStyle(color: Colors.orange)),
          ),
        
        // 建造按钮
        if (!property.isMortgaged && property.houses < 5)
          ElevatedButton(
            onPressed: player.cash >= price ? onBuild : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('建造 +\$$price'),
          ),
        
        TextButton(onPressed: onClose, child: const Text('关闭')),
      ],
    );
  }

  Widget _buildColorGroupInfo(PropertyColor color, List<int> indices, GameState gameState, String playerId) {
    final ownedIndices = indices.where((i) => 
      gameState.properties.any((p) => p.cellIndex == i && p.ownerId == playerId && !p.isMortgaged)
    ).toList();
    final isComplete = ownedIndices.length == indices.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isComplete ? Colors.green : Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                color: Color(propertyColorValues[color] ?? 0xFF808080),
              ),
              const SizedBox(width: 8),
              Text(
                '${color.name.toUpperCase()} 色组',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isComplete 
                ? '✅ 完整色组 - 租金翻倍!'
                : '进度: ${ownedIndices.length}/${indices.length}',
            style: TextStyle(
              color: isComplete ? Colors.green : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingStatus(PropertyState property, Cell cell) {
    if (property.hasHotel) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, color: Colors.red, size: 32),
            SizedBox(width: 8),
            Text('酒店', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('房屋: ', style: const TextStyle(fontSize: 16)),
        ...List.generate(4, (i) => Icon(
          i < property.houses ? Icons.home : Icons.home_outlined,
          color: i < property.houses ? Colors.orange : Colors.grey,
        )),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// 显示建造房屋对话框
void showBuildHouseDialog(BuildContext context, int propertyIndex) {
  showDialog(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (ctx, ref, child) {
        final notifier = ref.read(gameProvider.notifier);
        return BuildHouseDialog(
          propertyIndex: propertyIndex,
          onBuild: () {
            notifier.buildHouse(propertyIndex);
            Navigator.pop(dialogContext);
          },
          onSell: () {
            Navigator.pop(dialogContext);
          },
          onMortgage: () {
            notifier.mortgageProperty(propertyIndex);
            Navigator.pop(dialogContext);
          },
          onRedeem: () {
            notifier.redeemMortgage(propertyIndex);
            Navigator.pop(dialogContext);
          },
          onClose: () => Navigator.pop(dialogContext),
        );
      },
    ),
  );
}
