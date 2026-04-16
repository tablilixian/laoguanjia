import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../constants/board_config.dart';
import '../../constants/game_constants.dart';
import '../../providers/game_provider.dart';
import '../../services/rent_calculator.dart';

class PlayerDetailPanel extends ConsumerWidget {
  final VoidCallback onClose;
  final String? playerId;

  const PlayerDetailPanel({
    super.key,
    required this.onClose,
    this.playerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final targetPlayer = playerId != null
        ? gameState.players.firstWhere((p) => p.id == playerId, 
            orElse: () => gameState.currentPlayer)
        : gameState.currentPlayer;
    
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(targetPlayer),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBasicInfo(targetPlayer),
                  const SizedBox(height: 16),
                  if (targetPlayer.isHuman) ...[
                    _buildAutoPlayCard(targetPlayer, ref),
                    const SizedBox(height: 16),
                  ],
                  _buildAssetStats(targetPlayer, gameState),
                  const SizedBox(height: 16),
                  _buildPropertyList(targetPlayer, gameState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Player player) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: player.tokenColor,
      ),
      child: Row(
        children: [
          Container(
            width: GameConstants.playerAvatarSize.toDouble(),
            height: GameConstants.playerAvatarSize.toDouble(),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                player.name[0],
                style: TextStyle(
                  color: player.tokenColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  player.isHuman ? '真人玩家' : 'AI玩家',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(Player player) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '基本信息',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('现金', '\$${player.cash}', 
              color: player.cash < GameConstants.lowCashWarningThreshold ? Colors.red : Colors.green),
            if (player.isInJail) ...[
              _buildInfoRow('状态', '在监狱', color: Colors.orange),
              _buildInfoRow('监狱剩余', '${player.jailTurns} 回合'),
            ],
            if (player.isBankrupt)
              _buildInfoRow('状态', '破产', color: Colors.red),
            if (player.hasGetOutOfJailFree)
              _buildInfoRow('出狱卡', '✓ 拥有', color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoPlayCard(Player player, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '自动游戏',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('自动操作'),
                Switch(
                  value: player.isAutoPlay,
                  onChanged: (value) {
                    ref.read(gameProvider.notifier).toggleAutoPlay(player.id);
                  },
                  activeColor: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '开启后AI将自动帮你进行游戏操作',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetStats(Player player, GameState gameState) {
    final properties = gameState.properties
        .where((p) => p.ownerId == player.id)
        .toList();
    
    int totalPropertyValue = 0;
    int totalHouseValue = 0;
    int totalHouses = 0;
    int totalHotels = 0;
    
    for (var prop in properties) {
      final cell = boardCells[prop.cellIndex];
      totalPropertyValue += cell.price ?? 0;
      if (prop.hasHotel) {
        totalHotels++;
        totalHouseValue += (cell.housePrice ?? 0) * 4;
      } else {
        totalHouses += prop.houses;
        totalHouseValue += (cell.housePrice ?? 0) * prop.houses;
      }
    }
    
    final totalAssets = player.cash + totalPropertyValue + totalHouseValue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '资产统计',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('地产价值', '\$$totalPropertyValue'),
            _buildInfoRow('房屋价值', '\$$totalHouseValue'),
            _buildInfoRow('房屋数量', '$totalHouses 栋'),
            _buildInfoRow('酒店数量', '$totalHotels 家'),
            const Divider(),
            _buildInfoRow('总资产', '\$$totalAssets', 
              color: Colors.blue, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyList(Player player, GameState gameState) {
    final properties = gameState.properties
        .where((p) => p.ownerId == player.id)
        .toList();

    if (properties.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '地产列表',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              const Text('暂无地产'),
            ],
          ),
        ),
      );
    }

    final normalProperties = properties.where((p) => 
        boardCells[p.cellIndex].type == CellType.property).toList();
    final railroads = properties.where((p) => 
        boardCells[p.cellIndex].type == CellType.railroad).toList();
    final utilities = properties.where((p) => 
        boardCells[p.cellIndex].type == CellType.utility).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '地产列表 (${properties.length})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        if (normalProperties.isNotEmpty) ...[
          const Text('城市地产', style: TextStyle(fontWeight: FontWeight.bold)),
          ...normalProperties.map((p) => _buildPropertyItem(p)),
          const SizedBox(height: 8),
        ],
        if (railroads.isNotEmpty) ...[
          const Text('高铁站', style: TextStyle(fontWeight: FontWeight.bold)),
          ...railroads.map((p) => _buildPropertyItem(p)),
          const SizedBox(height: 8),
        ],
        if (utilities.isNotEmpty) ...[
          const Text('公用事业', style: TextStyle(fontWeight: FontWeight.bold)),
          ...utilities.map((p) => _buildPropertyItem(p)),
        ],
      ],
    );
  }

  Widget _buildPropertyItem(PropertyState property) {
    final cell = boardCells[property.cellIndex];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          if (cell.color != null)
            Container(
              width: 4,
              height: 40,
              color: Color(propertyColorValues[cell.color] ?? 0xFF808080),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cell.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _getPropertyStatus(property),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (property.hasHotel)
            const Icon(Icons.business, color: Colors.red, size: 20)
          else if (property.houses > 0)
            Row(
              children: List.generate(
                property.houses,
                (i) => const Icon(Icons.home, color: Colors.orange, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _getPropertyStatus(PropertyState property) {
    if (property.isMortgaged) return '已抵押';
    if (property.hasHotel) return '酒店';
    if (property.houses > 0) return '${property.houses}栋房屋';
    return '无房屋';
  }
}
