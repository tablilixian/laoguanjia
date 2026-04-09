// 地产大亨 - 棋盘组件
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../constants/board_config.dart';
import '../../providers/game_provider.dart';

/// 棋盘组件 - 显示40格环形棋盘
class GameBoard extends ConsumerWidget {
  const GameBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight 
            ? constraints.maxWidth 
            : constraints.maxHeight;
        final cellSize = size / 11; // 11个格子宽（包括角落）
        
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(
            children: [
              // 棋盘网格
              _buildBoardGrid(size, cellSize, gameState),
              // 玩家棋子
              ..._buildPlayerTokens(size, cellSize, gameState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoardGrid(double size, double cellSize, GameState gameState) {
    return CustomPaint(
      size: Size(size, size),
      painter: _BoardPainter(cellSize: cellSize, gameState: gameState),
    );
  }

  List<Widget> _buildPlayerTokens(double size, double cellSize, GameState gameState) {
    final List<Widget> tokens = [];
    final playerCount = gameState.players.length;
    
    for (int i = 0; i < playerCount; i++) {
      final player = gameState.players[i];
      if (player.isBankrupt) continue;
      
      final position = _calculateTokenPosition(player.position, size, cellSize, i, playerCount);
      
      tokens.add(
        Positioned(
          left: position.dx,
          top: position.dy,
          child: PlayerToken(
            color: player.tokenColor,
            size: cellSize * 0.35,
            isActive: i == gameState.currentPlayerIndex,
          ),
        ),
      );
    }
    
    return tokens;
  }

  Offset _calculateTokenPosition(int cellIndex, double boardSize, double cellSize, int playerIndex, int playerCount) {
    final corners = cellSize;
    final innerSize = cellSize * 9;
    final innerStart = corners;
    
    // 计算每个位置的坐标
    // 棋盘布局: 0-10(下边缘), 10-20(右边缘), 20-30(上边缘), 30-40(左边缘)
    // 实际上是0-9, 10-19, 20-29, 30-39 (40格)
    
    int side, position;
    if (cellIndex < 10) {
      side = 0; // 下边缘，从左到右
      position = cellIndex;
    } else if (cellIndex < 20) {
      side = 1; // 右边缘，从下到上
      position = cellIndex - 10;
    } else if (cellIndex < 30) {
      side = 2; // 上边缘，从右到左
      position = cellIndex - 20;
    } else {
      side = 3; // 左边缘，从上到下
      position = cellIndex - 30;
    }
    
    double x, y;
    final tokenOffset = (playerIndex * cellSize * 0.3) % (cellSize * 0.4);
    final tokenStep = (cellSize * 0.4) * (playerIndex ~/ 2);
    
    switch (side) {
      case 0: // 下边缘
        x = corners + position * cellSize + tokenStep;
        y = boardSize - corners - cellSize + tokenOffset;
        break;
      case 1: // 右边缘
        x = boardSize - corners - cellSize + tokenOffset;
        y = corners + position * cellSize + tokenStep;
        break;
      case 2: // 上边缘
        x = corners + (9 - position) * cellSize + tokenStep;
        y = corners + tokenOffset;
        break;
      case 3: // 左边缘
      default:
        x = corners + tokenOffset;
        y = corners + (9 - position) * cellSize + tokenStep;
        break;
    }
    
    return Offset(x + 5, y + 5);
  }
}

/// 玩家棋子组件
class PlayerToken extends StatelessWidget {
  final Color color;
  final double size;
  final bool isActive;

  const PlayerToken({
    super.key,
    required this.color,
    required this.size,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? Colors.yellow : Colors.white,
          width: isActive ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: isActive
          ? Icon(
              Icons.circle,
              size: size * 0.3,
              color: Colors.yellow,
            )
          : null,
    );
  }
}

/// 格子组件
class CellWidget extends StatelessWidget {
  final Cell cell;
  final PropertyState? propertyState;
  final double size;
  final VoidCallback? onTap;

  const CellWidget({
    super.key,
    required this.cell,
    this.propertyState,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _getCellColor(),
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
        child: Column(
          children: [
            // 颜色条（仅地产）
            if (cell.color != null)
              Container(
                height: size * 0.15,
                color: Color(propertyColorValues[cell.color] ?? 0xFF808080),
              ),
            // 格子内容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 格子名称
                    Expanded(
                      child: Text(
                        _getShortName(),
                        style: TextStyle(
                          fontSize: size * 0.08,
                          fontWeight: FontWeight.bold,
                          color: _getTextColor(),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    // 建筑/拥有者指示
                    if (_showBuildingIndicator())
                      _buildBuildingIndicator(size),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCellColor() {
    switch (cell.type) {
      case CellType.go:
        return const Color(0xFF4CAF50);
      case CellType.jail:
        return const Color(0xFFFF9800);
      case CellType.freeParking:
        return const Color(0xFF2196F3);
      case CellType.goToJail:
        return const Color(0xFFF44336);
      case CellType.chance:
      case CellType.communityChest:
        return const Color(0xFFE0E0E0);
      case CellType.incomeTax:
      case CellType.luxuryTax:
        return const Color(0xFF9E9E9E);
      default:
        return Colors.white;
    }
  }

  Color _getTextColor() {
    if (cell.color != null) return Colors.black;
    if (cell.type == CellType.go) return Colors.white;
    if (cell.type == CellType.goToJail) return Colors.white;
    return Colors.black87;
  }

  String _getShortName() {
    String name = cell.name;
    // 简化名称
    name = name.replaceAll(' Avenue', '');
    name = name.replaceAll(' Place', '');
    name = name.replaceAll(' Railroad', '');
    name = name.replaceAll(' R.R.', '');
    if (name.length > 8) {
      name = name.substring(0, 7);
    }
    return name;
  }

  bool _showBuildingIndicator() {
    return propertyState != null && 
           propertyState!.ownerId != null && 
           cell.type == CellType.property;
  }

  Widget _buildBuildingIndicator(double size) {
    final houses = propertyState!.houses;
    if (houses >= 5) {
      return Icon(Icons.business, size: size * 0.15, color: Colors.red);
    } else if (houses > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          houses,
          (i) => Icon(Icons.home, size: size * 0.12, color: Colors.orange),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// 棋盘绘制器
class _BoardPainter extends CustomPainter {
  final double cellSize;
  final GameState gameState;

  _BoardPainter({required this.cellSize, required this.gameState});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 绘制格子边框
    for (int i = 0; i < 40; i++) {
      final rect = _getCellRect(i, size);
      canvas.drawRect(rect, paint);
    }
  }

  Rect _getCellRect(int cellIndex, Size size) {
    final corners = cellSize;
    final innerSize = cellSize * 9;
    
    int side, position;
    if (cellIndex < 10) {
      side = 0;
      position = cellIndex;
    } else if (cellIndex < 20) {
      side = 1;
      position = cellIndex - 10;
    } else if (cellIndex < 30) {
      side = 2;
      position = cellIndex - 20;
    } else {
      side = 3;
      position = cellIndex - 30;
    }

    double left, top, width, height;
    width = height = cellSize;

    switch (side) {
      case 0:
        left = corners + position * cellSize;
        top = size.height - corners - cellSize;
        break;
      case 1:
        left = size.width - corners - cellSize;
        top = corners + position * cellSize;
        break;
      case 2:
        left = corners + (9 - position) * cellSize;
        top = corners;
        break;
      case 3:
      default:
        left = corners;
        top = corners + (9 - position) * cellSize;
        break;
    }

    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
