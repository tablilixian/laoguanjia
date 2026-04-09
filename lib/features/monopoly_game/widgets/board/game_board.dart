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
    return Stack(
      children: [
        // 绘制格子边框
        CustomPaint(
          size: Size(size, size),
          painter: _BoardPainter(cellSize: cellSize, gameState: gameState),
        ),
        // 绘制格子内容
        ..._buildCells(size, cellSize, gameState),
      ],
    );
  }

  List<Widget> _buildCells(double boardSize, double cellSize, GameState gameState) {
    final List<Widget> cells = [];
    
    for (int i = 0; i < 40; i++) {
      final cell = boardCells[i];
      final propertyState = gameState.properties.firstWhere(
        (p) => p.cellIndex == i,
        orElse: () => PropertyState(cellIndex: i),
      );
      
      final position = _getCellPosition(i, boardSize, cellSize);
      
      cells.add(
        Positioned(
          left: position.dx,
          top: position.dy,
          child: CellWidget(
            cell: cell,
            propertyState: propertyState,
            size: cellSize,
          ),
        ),
      );
    }
    
    return cells;
  }

  Offset _getCellPosition(int cellIndex, double boardSize, double cellSize) {
    // 40 格布局：每边 11 格（包括角），4 个角共享
    // 下边：0-10（11 格，从左到右）
    // 右边：10-20（11 格，从下到上）
    // 上边：20-30（11 格，从右到左）
    // 左边：30-39（10 格，从上到下，因为 0 已经算在下边）
    
    int side, position;
    if (cellIndex <= 10) {
      // 下边：0-10（11 格）
      side = 0;
      position = cellIndex;
    } else if (cellIndex <= 20) {
      // 右边：10-20（11 格）
      side = 1;
      position = cellIndex - 10;
    } else if (cellIndex <= 30) {
      // 上边：20-30（11 格）
      side = 2;
      position = cellIndex - 20;
    } else {
      // 左边：30-39（10 格）
      side = 3;
      position = cellIndex - 30;
    }

    double x, y;
    switch (side) {
      case 0: // 下边（从左到右，0 在最左，10 在最右）
        x = position * cellSize;
        y = boardSize - cellSize;
        break;
      case 1: // 右边（从下到上，10 在最下，20 在最上）
        x = boardSize - cellSize;
        y = boardSize - position * cellSize - cellSize;
        break;
      case 2: // 上边（从右到左，20 在最右，30 在最左）
        x = boardSize - position * cellSize - cellSize;
        y = 0;
        break;
      case 3: // 左边（从上到下，30 在最上，39 在最下）
        x = 0;
        y = position * cellSize;
        break;
      default:
        x = 0;
        y = 0;
    }
    
    return Offset(x, y);
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
    if (cellIndex <= 10) {
      side = 0;
      position = cellIndex;
    } else if (cellIndex <= 20) {
      side = 1;
      position = cellIndex - 10;
    } else if (cellIndex <= 30) {
      side = 2;
      position = cellIndex - 20;
    } else {
      side = 3;
      position = cellIndex - 30;
    }
    
    double x, y;
    final tokenOffset = (playerIndex * cellSize * 0.3) % (cellSize * 0.4);
    final tokenStep = (cellSize * 0.4) * (playerIndex ~/ 2);
    
    switch (side) {
      case 0: // 下边（从左到右）
        x = position * cellSize + tokenStep;
        y = boardSize - cellSize + tokenOffset;
        break;
      case 1: // 右边（从下到上）
        x = boardSize - cellSize + tokenOffset;
        y = boardSize - position * cellSize - cellSize + tokenStep;
        break;
      case 2: // 上边（从右到左）
        x = boardSize - position * cellSize - cellSize + tokenStep;
        y = tokenOffset;
        break;
      case 3: // 左边（从上到下）
        x = tokenOffset;
        y = position * cellSize + tokenStep;
        break;
      default:
        x = 0;
        y = 0;
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
                          fontSize: size * 0.1,  // 增大字体
                          fontWeight: FontWeight.bold,
                          color: _getTextColor(),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,  // 增加行数
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
    // 显示编号 + 名称，方便调试
    return '${cell.index}:${cell.name}';
  }

  bool _showBuildingIndicator() {
    return propertyState != null && 
           propertyState!.ownerId != null && 
           (cell.type == CellType.property || 
            cell.type == CellType.railroad || 
            cell.type == CellType.utility);
  }

  Widget _buildBuildingIndicator(double size) {
    final houses = propertyState!.houses;
    
    // 地产类型显示房屋/酒店或拥有者指示
    if (cell.type == CellType.property) {
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
      } else {
        // 新购买的地产显示拥有者指示
        return Icon(Icons.home_outlined, size: size * 0.15, color: Colors.blue);
      }
    }
    
    // 铁路和公用事业显示拥有者指示
    if (cell.type == CellType.railroad || cell.type == CellType.utility) {
      return Icon(
        cell.type == CellType.railroad ? Icons.train : Icons.bolt,
        size: size * 0.15,
        color: Colors.blue,
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
    // 40 格布局：每边 11 格（包括角），4 个角共享
    // 下边：0-10（11 格）
    // 右边：10-20（11 格）
    // 上边：20-30（11 格）
    // 左边：30-39（10 格）
    
    int side, position;
    if (cellIndex <= 10) {
      side = 0;
      position = cellIndex;
    } else if (cellIndex <= 20) {
      side = 1;
      position = cellIndex - 10;
    } else if (cellIndex <= 30) {
      side = 2;
      position = cellIndex - 20;
    } else {
      side = 3;
      position = cellIndex - 30;
    }

    double left, top, width, height;
    width = height = cellSize;

    switch (side) {
      case 0: // 下边（从左到右）
        left = position * cellSize;
        top = size.height - cellSize;
        break;
      case 1: // 右边（从下到上）
        left = size.width - cellSize;
        top = size.height - position * cellSize - cellSize;
        break;
      case 2: // 上边（从右到左）
        left = size.width - position * cellSize - cellSize;
        top = 0;
        break;
      case 3: // 左边（从上到下）
        left = 0;
        top = position * cellSize;
        break;
      default:
        left = 0;
        top = 0;
    }

    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
