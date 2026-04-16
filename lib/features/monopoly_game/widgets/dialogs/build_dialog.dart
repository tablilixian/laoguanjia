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
    final canBuild = RentCalculator.canBuildHouse(player.id, color, gameState.properties);
    final buildReason = _getBuildReason(property, player.id, color, gameState, price);

    return AlertDialog(
      title: Row(
        children: [
          if (property.isMortgaged)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.lock, color: Colors.orange, size: 20),
            ),
          Expanded(child: Text(cell.name)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildColorGroupSection(color, indices, gameState, player.id),
            const SizedBox(height: 16),
            _buildBuildingStatus(property, cell),
            const SizedBox(height: 16),
            _buildPlayerCashRow(player.cash, price),
            if (buildReason != null) ...[
              const SizedBox(height: 16),
              _buildBuildReasonCard(buildReason),
            ],
          ],
        ),
      ),
      actions: _buildActions(property, player, price, mortgageValue, redeemValue, canBuild),
    );
  }

  List<Widget> _buildActions(PropertyState property, Player player, int price, int mortgageValue, int redeemValue, bool canBuild) {
    final actions = <Widget>[];

    if (property.isMortgaged) {
      actions.add(
        ElevatedButton(
          onPressed: player.cash >= redeemValue ? onRedeem : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: Text('赎回 (\$$redeemValue)'),
        ),
      );
    } else if (property.houses == 0) {
      actions.add(
        ElevatedButton(
          onPressed: player.cash >= mortgageValue ? onMortgage : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          child: Text('抵押 +\$$mortgageValue'),
        ),
      );
    }

    if (property.houses > 0) {
      actions.add(
        TextButton(
          onPressed: onSell,
          child: const Text('出售房屋', style: TextStyle(color: Colors.orange)),
        ),
      );
    }

    if (!property.isMortgaged && property.houses < 5) {
      final isEnabled = canBuild && player.cash >= price;
      actions.add(
        ElevatedButton(
          onPressed: isEnabled ? onBuild : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? Colors.green : Colors.grey,
          ),
          child: Text(
            property.houses == 4 ? '升级酒店 +\$$price' : '建造 +\$$price',
          ),
        ),
      );
    }

    actions.add(TextButton(onPressed: onClose, child: const Text('关闭')));
    return actions;
  }

  Widget _buildColorGroupSection(PropertyColor color, List<int> indices, GameState gameState, String playerId) {
    final colorName = propertyColorNames[color] ?? color.name;
    final colorValue = Color(propertyColorValues[color] ?? 0xFF808080);

    final ownedByMe = <_PropertyInfo>[];
    final ownedByOther = <_PropertyInfo>[];
    final unowned = <_PropertyInfo>[];

    for (final idx in indices) {
      final cell = boardCells[idx];
      final prop = gameState.properties.where((p) => p.cellIndex == idx).firstOrNull;
      
      if (prop == null || prop.ownerId == null || prop.ownerId!.isEmpty) {
        unowned.add(_PropertyInfo(cell.name, idx, false));
      } else if (prop.ownerId == playerId) {
        ownedByMe.add(_PropertyInfo(cell.name, idx, prop.isMortgaged));
      } else {
        final owner = gameState.players.firstWhere((p) => p.id == prop.ownerId, orElse: () => gameState.players.first);
        ownedByOther.add(_PropertyInfo('${cell.name} (${owner.name})', idx, prop.isMortgaged));
      }
    }

    final isComplete = ownedByMe.length == indices.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isComplete ? Colors.green : Colors.grey, width: isComplete ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colorValue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$colorName 色组',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isComplete ? '✅ 已垄断 - 租金翻倍，可建造房屋！' : '📊 进度: ${ownedByMe.length}/${indices.length}',
            style: TextStyle(
              color: isComplete ? Colors.green : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (ownedByMe.isNotEmpty) ...[
            const Text('🏠 您的地产:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: ownedByMe.map((p) => _buildPropertyChip(p, true)).toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (ownedByOther.isNotEmpty) ...[
            const Text('🏢 别人的地产:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: ownedByOther.map((p) => _buildPropertyChip(p, false)).toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (unowned.isNotEmpty) ...[
            const Text('🏁 无主地产:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: unowned.map((p) => _buildPropertyChip(p, false)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPropertyChip(_PropertyInfo info, bool isMine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMine ? Colors.green.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: info.isMortgaged ? Colors.orange : (isMine ? Colors.green : Colors.grey),
          width: info.isMortgaged ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info.isMortgaged)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.lock, size: 12, color: Colors.orange),
            ),
          Text(
            info.name,
            style: TextStyle(
              fontSize: 11,
              color: info.isMortgaged ? Colors.orange.shade700 : Colors.black87,
              decoration: info.isMortgaged ? TextDecoration.lineThrough : null,
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
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, color: Colors.red.shade700, size: 32),
            const SizedBox(width: 8),
            Text(
              '酒店',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('房屋: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ...List.generate(4, (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              i < property.houses ? Icons.home : Icons.home_outlined,
              color: i < property.houses ? Colors.orange : Colors.grey.shade300,
              size: 24,
            ),
          )),
          if (property.houses == 4)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '(可升级酒店)',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
              ),
            ),
        ],
      ),
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

  Widget _buildBuildReasonCard(BuildReason reason) {
    MaterialColor bgColor;
    MaterialColor borderColor;
    IconData icon;
    
    switch (reason.type) {
      case BuildReasonType.notComplete:
        bgColor = Colors.orange;
        borderColor = Colors.orange;
        icon = Icons.warning_amber_rounded;
        break;
      case BuildReasonType.mortgaged:
        bgColor = Colors.red;
        borderColor = Colors.red;
        icon = Icons.lock;
        break;
      case BuildReasonType.noCash:
        bgColor = Colors.red;
        borderColor = Colors.red;
        icon = Icons.money_off;
        break;
      case BuildReasonType.alreadyHasHotel:
        bgColor = Colors.grey;
        borderColor = Colors.grey;
        icon = Icons.business;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: borderColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason.message,
              style: TextStyle(color: borderColor.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  BuildReason? _getBuildReason(PropertyState property, String playerId, PropertyColor color, GameState gameState, int price) {
    if (property.hasHotel) {
      return BuildReason(
        type: BuildReasonType.alreadyHasHotel,
        message: '该地产已有酒店，无法再建造房屋',
      );
    }

    if (property.isMortgaged) {
      return BuildReason(
        type: BuildReasonType.mortgaged,
        message: '该地产已被抵押，无法建造房屋',
      );
    }

    if (gameState.currentPlayer.cash < price) {
      return BuildReason(
        type: BuildReasonType.noCash,
        message: '现金不足，需要 \$${price}，现有 \$${gameState.currentPlayer.cash}',
      );
    }

    final canBuild = RentCalculator.canBuildHouse(playerId, color, gameState.properties);
    if (!canBuild) {
      final indices = colorGroupProperties[color]!;
      final ownedCount = indices.where((i) => 
        gameState.properties.any((p) => p.cellIndex == i && p.ownerId == playerId && !p.isMortgaged)
      ).length;
      final totalCount = indices.length;
      
      return BuildReason(
        type: BuildReasonType.notComplete,
        message: '需要拥有完整${propertyColorNames[color] ?? color.name}色组才能建造（当前: $ownedCount/$totalCount）',
      );
    }

    return null;
  }
}

class _PropertyInfo {
  final String name;
  final int index;
  final bool isMortgaged;

  _PropertyInfo(this.name, this.index, this.isMortgaged);
}

enum BuildReasonType {
  notComplete,
  mortgaged,
  noCash,
  alreadyHasHotel,
}

class BuildReason {
  final BuildReasonType type;
  final String message;

  BuildReason({required this.type, required this.message});
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
