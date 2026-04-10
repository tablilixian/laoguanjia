// 地产大亨 - 棋盘布局配置测试
import 'package:flutter_test/flutter_test.dart';
import 'package:home_manager/features/monopoly_game/constants/board_layout_config.dart';

void main() {
  group('BoardLayoutConfig', () {
    test('标准布局应该有正确的格子数', () {
      final config = BoardLayoutPresets.standard;
      expect(config.horizontalCells, equals(11));
      expect(config.verticalCells, equals(11));
      expect(config.totalCells, equals(40));
    });

    test('宽扁布局应该有正确的格子数', () {
      final config = BoardLayoutPresets.wide;
      expect(config.horizontalCells, equals(9));
      expect(config.verticalCells, equals(13));
      expect(config.totalCells, equals(40));
    });

    test('超宽扁布局应该有正确的格子数', () {
      final config = BoardLayoutPresets.extraWide;
      expect(config.horizontalCells, equals(8));
      expect(config.verticalCells, equals(14));
      expect(config.totalCells, equals(40));
    });

    test('窄长布局应该有正确的格子数', () {
      final config = BoardLayoutPresets.narrow;
      expect(config.horizontalCells, equals(13));
      expect(config.verticalCells, equals(9));
      expect(config.totalCells, equals(40));
    });

    test('紧凑布局应该有正确的格子数', () {
      final config = BoardLayoutPresets.compact;
      expect(config.horizontalCells, equals(10));
      expect(config.verticalCells, equals(12));
      expect(config.totalCells, equals(40));
    });

    test('格子大小计算应该在有效范围内', () {
      final config = BoardLayoutPresets.standard;
      final boardSize = 400.0;
      final cellSize = config.calculateCellSize(boardSize);
      
      expect(cellSize, greaterThanOrEqualTo(config.minCellSize));
      expect(cellSize, lessThanOrEqualTo(config.maxCellSize));
    });

    test('格子位置计算应该正确', () {
      final config = BoardLayoutPresets.standard;
      final boardWidth = 400.0;
      final boardHeight = 400.0;
      final cellSize = config.calculateCellSize(boardWidth);
      
      final position0 = config.getCellPosition(0, boardWidth, boardHeight, cellSize);
      expect(position0.dx, equals(0));
      expect(position0.dy, closeTo(boardHeight - cellSize, 0.01));
      
      final position10 = config.getCellPosition(10, boardWidth, boardHeight, cellSize);
      expect(position10.dx, closeTo(boardWidth - cellSize, 0.01));
      expect(position10.dy, closeTo(boardHeight - cellSize, 0.01));
      
      final position11 = config.getCellPosition(11, boardWidth, boardHeight, cellSize);
      expect(position11.dx, closeTo(boardWidth - cellSize, 0.01));
      expect(position11.dy, closeTo(boardHeight - 2 * cellSize, 0.01));
      
      final position20 = config.getCellPosition(20, boardWidth, boardHeight, cellSize);
      expect(position20.dx, closeTo(boardWidth - cellSize, 0.01));
      expect(position20.dy, closeTo(0, 0.01));
      
      final position30 = config.getCellPosition(30, boardWidth, boardHeight, cellSize);
      expect(position30.dx, closeTo(0, 0.01));
      expect(position30.dy, closeTo(0, 0.01));
      
      final position31 = config.getCellPosition(31, boardWidth, boardHeight, cellSize);
      expect(position31.dx, equals(0));
      expect(position31.dy, closeTo(cellSize, 0.01));
    });

    test('角落格子索引应该正确', () {
      final config = BoardLayoutPresets.standard;
      final corners = config.getCornerIndices();
      
      expect(corners.length, equals(4));
      expect(corners[0], equals(0));
      expect(corners[1], equals(10));
      expect(corners[2], equals(20));
      expect(corners[3], equals(30));
    });

    test('格子边判断应该正确', () {
      final config = BoardLayoutPresets.standard;
      
      expect(config.getCellSide(0), equals(BoardSide.bottom));
      expect(config.getCellSide(5), equals(BoardSide.bottom));
      expect(config.getCellSide(10), equals(BoardSide.bottom));
      expect(config.getCellSide(11), equals(BoardSide.right));
      expect(config.getCellSide(15), equals(BoardSide.right));
      expect(config.getCellSide(20), equals(BoardSide.right));
      expect(config.getCellSide(21), equals(BoardSide.top));
      expect(config.getCellSide(30), equals(BoardSide.top));
      expect(config.getCellSide(31), equals(BoardSide.left));
      expect(config.getCellSide(39), equals(BoardSide.left));
    });

    test('无效配置应该抛出断言错误', () {
      expect(
        () => BoardLayoutConfig(horizontalCells: 10, verticalCells: 10),
        throwsA(isA<AssertionError>()),
      );
    });

    test('所有预设配置的总格子数都应该为40', () {
      for (final config in BoardLayoutPresets.all) {
        expect(config.totalCells, equals(40), 
          reason: '${config.name} 的总格子数应该为 40');
      }
    });

    test('格子大小比例应该影响计算结果', () {
      final config1 = BoardLayoutConfig(
        horizontalCells: 11,
        verticalCells: 11,
        cellSizeRatio: 1.0,
      );
      
      final config2 = BoardLayoutConfig(
        horizontalCells: 11,
        verticalCells: 11,
        cellSizeRatio: 1.2,
      );
      
      final boardSize = 400.0;
      final cellSize1 = config1.calculateCellSize(boardSize);
      final cellSize2 = config2.calculateCellSize(boardSize);
      
      expect(cellSize2, greaterThan(cellSize1));
    });

    test('角落格子不应该重叠', () {
      final config = BoardLayoutPresets.wide; // 9x13 布局
      final availableWidth = 300.0;
      final cellSize = config.calculateCellSize(availableWidth);
      
      final boardWidth = config.calculateActualBoardWidth(cellSize);
      final boardHeight = config.calculateActualBoardHeight(cellSize);
      
      final corners = config.getCornerIndices();
      
      final positions = <int, Offset>{};
      for (final cornerIndex in corners) {
        positions[cornerIndex] = config.getCellPosition(cornerIndex, boardWidth, boardHeight, cellSize);
      }
      
      final position8 = config.getCellPosition(8, boardWidth, boardHeight, cellSize);
      final position9 = config.getCellPosition(9, boardWidth, boardHeight, cellSize);
      
      expect(position8.dx, closeTo(position9.dx, 0.01));
      expect(position8.dy, isNot(closeTo(position9.dy, 0.01)));
      
      expect(position9.dy, lessThan(position8.dy));
    });

    test('所有格子位置应该唯一', () {
      final config = BoardLayoutPresets.wide; // 9x13 布局
      final availableWidth = 300.0;
      final cellSize = config.calculateCellSize(availableWidth);
      
      final boardWidth = config.calculateActualBoardWidth(cellSize);
      final boardHeight = config.calculateActualBoardHeight(cellSize);
      
      final positions = <String, int>{};
      
      for (int i = 0; i < 40; i++) {
        final pos = config.getCellPosition(i, boardWidth, boardHeight, cellSize);
        final key = '${pos.dx.toStringAsFixed(2)}_${pos.dy.toStringAsFixed(2)}';
        
        expect(positions.containsKey(key), isFalse, 
          reason: '格子 $i 与格子 ${positions[key]} 位置重叠');
        
        positions[key] = i;
      }
      
      expect(positions.length, equals(40));
    });
  });
}
