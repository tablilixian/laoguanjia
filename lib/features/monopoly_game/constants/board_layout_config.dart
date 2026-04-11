// 地产大亨 - 棋盘布局配置
// 定义棋盘的布局参数，支持多种布局方案

import 'package:flutter/material.dart';

/// 棋盘布局配置类
/// 
/// 该类定义了棋盘的布局参数，包括：
/// - 水平和垂直边的格子数量
/// - 格子大小计算方式
/// - 角落格子的位置
/// - 玩家棋子的排列方式
/// 
/// 通过配置不同的布局参数，可以实现：
/// - 正方形棋盘（如 11x11）
/// - 宽扁形棋盘（如 9x13）
/// - 窄长形棋盘（如 13x9）
/// 
/// 注意：总格子数必须为 40，且满足公式：2H + 2V - 4 = 40
class BoardLayoutConfig {
  /// 水平边（上边和下边）的格子数量
  final int horizontalCells;
  
  /// 垂直边（左边和右边）的格子数量
  final int verticalCells;
  
  /// 格子大小比例（相对于默认计算值）
  /// 1.0 表示使用默认大小，> 1.0 表示更大，< 1.0 表示更小
  final double cellSizeRatio;
  
  /// 格子最小尺寸（像素）
  /// 用于确保格子不会太小而无法显示内容
  final double minCellSize;
  
  /// 格子最大尺寸（像素）
  /// 用于确保格子不会太大而超出屏幕
  final double maxCellSize;
  
  /// 玩家棋子大小比例（相对于格子大小）
  final double tokenSizeRatio;
  
  /// 多个玩家在同一格子时的排列间距比例
  final double tokenSpacingRatio;
  
  /// 格子内容边距比例（相对于格子大小）
  final double cellPaddingRatio;
  
  /// 格子名称字体大小比例（相对于格子大小）
  final double nameFontSizeRatio;
  
  /// 颜色条高度比例（相对于格子大小）
  final double colorBarHeightRatio;
  
  /// 布局名称（用于显示和调试）
  final String name;
  
  /// 布局描述
  final String description;

  const BoardLayoutConfig({
    required this.horizontalCells,
    required this.verticalCells,
    this.cellSizeRatio = 1.0,
    this.minCellSize = 30.0,
    this.maxCellSize = 100.0,
    this.tokenSizeRatio = 0.35,
    this.tokenSpacingRatio = 0.3,
    this.cellPaddingRatio = 0.05,
    this.nameFontSizeRatio = 0.1,
    this.colorBarHeightRatio = 0.15,
    this.name = '自定义布局',
    this.description = '',
  }) : assert(
         2 * horizontalCells + 2 * verticalCells - 4 == 40,
         '总格子数必须为 40，当前配置：2*$horizontalCells + 2*$verticalCells - 4 = ${2 * horizontalCells + 2 * verticalCells - 4}',
       );

  /// 计算总格子数
  int get totalCells => 2 * horizontalCells + 2 * verticalCells - 4;

  /// 计算格子大小
  /// 
  /// [boardSize] 棋盘总大小（宽度或高度中的较小值）
  /// 返回计算后的格子大小
  double calculateCellSize(double boardSize) {
    final defaultSize = boardSize / horizontalCells;
    final adjustedSize = defaultSize * cellSizeRatio;
    
    if (adjustedSize < minCellSize) return minCellSize;
    if (adjustedSize > maxCellSize) return maxCellSize;
    return adjustedSize;
  }

  /// 计算实际棋盘宽度
  /// 
  /// 根据格子大小和水平格子数，计算实际需要的棋盘宽度
  double calculateActualBoardWidth(double cellSize) {
    return cellSize * horizontalCells;
  }

  /// 计算实际棋盘高度
  /// 
  /// 根据格子大小和垂直格子数，计算实际需要的棋盘高度
  double calculateActualBoardHeight(double cellSize) {
    return cellSize * verticalCells;
  }

  /// 计算玩家棋子大小
  double calculateTokenSize(double cellSize) {
    return cellSize * tokenSizeRatio;
  }

  /// 计算格子内边距
  double calculateCellPadding(double cellSize) {
    return cellSize * cellPaddingRatio;
  }

  /// 计算名称字体大小
  double calculateNameFontSize(double cellSize) {
    return cellSize * nameFontSizeRatio;
  }

  /// 计算颜色条高度
  double calculateColorBarHeight(double cellSize) {
    return cellSize * colorBarHeightRatio;
  }

  /// 获取格子在棋盘上的位置
  /// 
  /// [cellIndex] 格子索引（0-39）
  /// [boardWidth] 棋盘宽度
  /// [boardHeight] 棋盘高度
  /// [cellSize] 格子大小
  /// 返回格子的左上角位置
  /// 
  /// 布局规则：
  /// - 下边：包括左下角和右下角，格子从左到右排列
  /// - 右边：不包括右下角，包括右上角，格子从下到上排列
  /// - 上边：不包括右上角，包括左上角，格子从右到左排列
  /// - 左边：不包括左上角和左下角，格子从上到下排列
  Offset getCellPosition(int cellIndex, double boardWidth, double boardHeight, double cellSize) {
    final side = getCellSide(cellIndex);
    final position = getCellPositionOnSide(cellIndex);
    
    double x, y;
    
    switch (side) {
      case BoardSide.bottom:
        x = position * cellSize;
        y = boardHeight - cellSize;
        break;
      case BoardSide.right:
        x = boardWidth - cellSize;
        y = boardHeight - (position + 2) * cellSize;
        break;
      case BoardSide.top:
        x = boardWidth - (position + 2) * cellSize;
        y = 0;
        break;
      case BoardSide.left:
        x = 0;
        y = (position + 1) * cellSize;
        break;
    }
    
    return Offset(x, y);
  }

  /// 获取格子所在的边
  /// 
  /// 布局逻辑：
  /// - 下边：0 到 horizontalCells-1（包括左下角和右下角）
  /// - 右边：horizontalCells 到 horizontalCells+verticalCells-2（不包括右下角，包括右上角）
  /// - 上边：horizontalCells+verticalCells-1 到 2*horizontalCells+verticalCells-3（不包括右上角，包括左上角）
  /// - 左边：2*horizontalCells+verticalCells-2 到 39（不包括左上角和左下角）
  BoardSide getCellSide(int cellIndex) {
    if (cellIndex < horizontalCells) {
      return BoardSide.bottom;
    } else if (cellIndex < horizontalCells + verticalCells - 1) {
      return BoardSide.right;
    } else if (cellIndex < 2 * horizontalCells + verticalCells - 2) {
      return BoardSide.top;
    } else {
      return BoardSide.left;
    }
  }

  /// 获取格子在所在边上的位置（从起点开始计数）
  int getCellPositionOnSide(int cellIndex) {
    if (cellIndex < horizontalCells) {
      return cellIndex;
    } else if (cellIndex < horizontalCells + verticalCells - 1) {
      return cellIndex - horizontalCells;
    } else if (cellIndex < 2 * horizontalCells + verticalCells - 2) {
      return cellIndex - horizontalCells - verticalCells + 1;
    } else {
      return cellIndex - 2 * horizontalCells - verticalCells + 2;
    }
  }

  /// 获取角落格子索引
  /// 
  /// 返回四个角落格子的索引：
  /// - 0: 左下角（起点）
  /// - 1: 右下角
  /// - 2: 右上角
  /// - 3: 左上角
  List<int> getCornerIndices() {
    return [
      0,                                          // 左下角（起点）
      horizontalCells - 1,                        // 右下角
      horizontalCells + verticalCells - 2,        // 右上角
      2 * horizontalCells + verticalCells - 3,    // 左上角
    ];
  }

  /// 判断是否为角落格子
  bool isCorner(int cellIndex) {
    return getCornerIndices().contains(cellIndex);
  }

  /// 计算玩家棋子在格子上的位置
  /// 
  /// [cellIndex] 格子索引
  /// [boardWidth] 棋盘宽度
  /// [boardHeight] 棋盘高度
  /// [cellSize] 格子大小
  /// [playerIndex] 玩家索引
  /// [playerCount] 总玩家数
  Offset calculateTokenPosition(
    int cellIndex,
    double boardWidth,
    double boardHeight,
    double cellSize,
    int playerIndex,
    int playerCount,
  ) {
    final basePosition = getCellPosition(cellIndex, boardWidth, boardHeight, cellSize);
    
    final tokenOffset = (playerIndex * cellSize * tokenSpacingRatio) % (cellSize * 0.4);
    final tokenStep = (cellSize * 0.4) * (playerIndex ~/ 2);
    
    final side = getCellSide(cellIndex);
    double x = basePosition.dx;
    double y = basePosition.dy;
    
    switch (side) {
      case BoardSide.bottom:
        x += tokenStep;
        y += tokenOffset;
        break;
      case BoardSide.right:
        x += tokenOffset;
        y += tokenStep;
        break;
      case BoardSide.top:
        x += tokenStep;
        y += tokenOffset;
        break;
      case BoardSide.left:
        x += tokenOffset;
        y += tokenStep;
        break;
    }
    
    return Offset(x + 5, y + 5);
  }

  /// 复制并修改配置
  BoardLayoutConfig copyWith({
    int? horizontalCells,
    int? verticalCells,
    double? cellSizeRatio,
    double? minCellSize,
    double? maxCellSize,
    double? tokenSizeRatio,
    double? tokenSpacingRatio,
    double? cellPaddingRatio,
    double? nameFontSizeRatio,
    double? colorBarHeightRatio,
    String? name,
    String? description,
  }) {
    return BoardLayoutConfig(
      horizontalCells: horizontalCells ?? this.horizontalCells,
      verticalCells: verticalCells ?? this.verticalCells,
      cellSizeRatio: cellSizeRatio ?? this.cellSizeRatio,
      minCellSize: minCellSize ?? this.minCellSize,
      maxCellSize: maxCellSize ?? this.maxCellSize,
      tokenSizeRatio: tokenSizeRatio ?? this.tokenSizeRatio,
      tokenSpacingRatio: tokenSpacingRatio ?? this.tokenSpacingRatio,
      cellPaddingRatio: cellPaddingRatio ?? this.cellPaddingRatio,
      nameFontSizeRatio: nameFontSizeRatio ?? this.nameFontSizeRatio,
      colorBarHeightRatio: colorBarHeightRatio ?? this.colorBarHeightRatio,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return 'BoardLayoutConfig(name: $name, horizontalCells: $horizontalCells, verticalCells: $verticalCells, totalCells: $totalCells)';
  }
}

/// 棋盘边的枚举
enum BoardSide {
  /// 下边（从左到右）
  bottom,
  /// 右边（从下到上）
  right,
  /// 上边（从右到左）
  top,
  /// 左边（从上到下）
  left,
}

/// 预设布局配置
class BoardLayoutPresets {
  BoardLayoutPresets._();

  /// 标准正方形布局（11x11）
  /// 适合平板或横屏模式
  static const BoardLayoutConfig standard = BoardLayoutConfig(
    horizontalCells: 11,
    verticalCells: 11,
    name: '标准布局',
    description: '经典的正方形布局，适合平板或横屏模式',
  );

  /// 宽扁形布局（9x13）
  /// 适合手机竖屏模式，格子更大更清晰
  static const BoardLayoutConfig wide = BoardLayoutConfig(
    horizontalCells: 9,
    verticalCells: 13,
    cellSizeRatio: 1,
    name: '宽扁布局',
    description: '适合手机竖屏，格子更大更清晰',
  );

  /// 超宽扁形布局（8x14）
  /// 更适合手机竖屏，格子最大
  static const BoardLayoutConfig extraWide = BoardLayoutConfig(
    horizontalCells: 8,
    verticalCells: 14,
    cellSizeRatio: 1.2,
    name: '超宽扁布局',
    description: '最适合手机竖屏，格子最大',
  );

  /// 窄长形布局（13x9）
  /// 适合横屏或特殊需求
  static const BoardLayoutConfig narrow = BoardLayoutConfig(
    horizontalCells: 13,
    verticalCells: 9,
    cellSizeRatio: 1.1,
    name: '窄长布局',
    description: '适合横屏模式',
  );

  /// 紧凑布局（10x12）
  /// 平衡的布局方案
  static const BoardLayoutConfig compact = BoardLayoutConfig(
    horizontalCells: 10,
    verticalCells: 12,
    cellSizeRatio: 1.05,
    name: '紧凑布局',
    description: '平衡的布局方案',
  );

  /// 获取所有预设配置
  static List<BoardLayoutConfig> get all => [
    standard,
    wide,
    extraWide,
    narrow,
    compact,
  ];

  /// 根据名称获取配置
  static BoardLayoutConfig? getByName(String name) {
    for (final config in all) {
      if (config.name == name) return config;
    }
    return null;
  }

  /// 根据屏幕尺寸推荐布局
  static BoardLayoutConfig recommendForScreen(Size screenSize) {
    final aspectRatio = screenSize.width / screenSize.height;
    
    if (aspectRatio > 1.2) {
      return narrow;
    } else if (aspectRatio < 0.8) {
      return extraWide;
    } else if (aspectRatio < 0.9) {
      return wide;
    } else {
      return standard;
    }
  }
}
