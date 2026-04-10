// 地产大亨 - 棋盘组件
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../constants/board_config.dart';
import '../../constants/board_layout_config.dart';
import '../../providers/game_provider.dart';

/// 棋盘组件 - 显示40格环形棋盘
/// 
/// 该组件支持通过 [BoardLayoutConfig] 配置不同的布局方案，
/// 可以实现正方形、宽扁形、窄长形等多种棋盘布局。
class GameBoard extends ConsumerWidget {
  /// 棋盘布局配置
  final BoardLayoutConfig layoutConfig;
  
  const GameBoard({
    super.key,
    this.layoutConfig = BoardLayoutPresets.standard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight 
            ? constraints.maxWidth 
            : constraints.maxHeight;
        final cellSize = layoutConfig.calculateCellSize(size);
        final boardWidth = layoutConfig.calculateActualBoardWidth(cellSize);
        final boardHeight = layoutConfig.calculateActualBoardHeight(cellSize);
        
        return Container(
          width: boardWidth,
          height: boardHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(
            children: [
              _buildBoardGrid(boardWidth, boardHeight, cellSize, gameState),
              ..._buildPlayerTokens(boardWidth, boardHeight, cellSize, gameState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoardGrid(double boardWidth, double boardHeight, double cellSize, GameState gameState) {
    return Stack(
      children: [
        CustomPaint(
          size: Size(boardWidth, boardHeight),
          painter: _BoardPainter(
            cellSize: cellSize, 
            gameState: gameState,
            layoutConfig: layoutConfig,
          ),
        ),
        ..._buildCells(boardWidth, boardHeight, cellSize, gameState),
      ],
    );
  }

  List<Widget> _buildCells(double boardWidth, double boardHeight, double cellSize, GameState gameState) {
    final List<Widget> cells = [];
    
    for (int i = 0; i < 40; i++) {
      final cell = boardCells[i];
      final propertyState = gameState.properties.firstWhere(
        (p) => p.cellIndex == i,
        orElse: () => PropertyState(cellIndex: i),
      );
      
      final position = layoutConfig.getCellPosition(i, boardWidth, boardHeight, cellSize);
      
      cells.add(
        Positioned(
          left: position.dx,
          top: position.dy,
          child: CellWidget(
            cell: cell,
            propertyState: propertyState,
            size: cellSize,
            layoutConfig: layoutConfig,
          ),
        ),
      );
    }
    
    return cells;
  }

  List<Widget> _buildPlayerTokens(double boardWidth, double boardHeight, double cellSize, GameState gameState) {
    final List<Widget> tokens = [];
    final playerCount = gameState.players.length;
    
    for (int i = 0; i < playerCount; i++) {
      final player = gameState.players[i];
      if (player.isBankrupt) continue;
      
      final position = layoutConfig.calculateTokenPosition(
        player.position, 
        boardWidth, 
        boardHeight, 
        cellSize, 
        i, 
        playerCount,
      );
      
      final tokenSize = layoutConfig.calculateTokenSize(cellSize);
      
      tokens.add(
        Positioned(
          left: position.dx,
          top: position.dy,
          child: PlayerToken(
            color: player.tokenColor,
            size: tokenSize,
            isActive: i == gameState.currentPlayerIndex,
          ),
        ),
      );
    }
    
    return tokens;
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
  final BoardLayoutConfig layoutConfig;
  final VoidCallback? onTap;

  const CellWidget({
    super.key,
    required this.cell,
    this.propertyState,
    required this.size,
    required this.layoutConfig,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nameFontSize = layoutConfig.calculateNameFontSize(size);
    final colorBarHeight = layoutConfig.calculateColorBarHeight(size);
    
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
            if (cell.color != null)
              Container(
                height: colorBarHeight,
                color: Color(propertyColorValues[cell.color] ?? 0xFF808080),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _getShortName(),
                        style: TextStyle(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.bold,
                          color: _getTextColor(),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ),
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
        return Icon(Icons.home_outlined, size: size * 0.15, color: Colors.blue);
      }
    }
    
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
  final BoardLayoutConfig layoutConfig;

  _BoardPainter({
    required this.cellSize, 
    required this.gameState,
    required this.layoutConfig,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 40; i++) {
      final rect = _getCellRect(i, size);
      canvas.drawRect(rect, paint);
    }
  }

  Rect _getCellRect(int cellIndex, Size size) {
    final position = layoutConfig.getCellPosition(cellIndex, size.width, size.height, cellSize);
    return Rect.fromLTWH(position.dx, position.dy, cellSize, cellSize);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
