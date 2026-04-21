// 地产大亨 - 棋盘主题系统模型定义
// 
// 本文件定义了主题系统的核心数据结构，包括：
// - 主题类型枚举
// - 主题元信息
// - 棋盘单元格配置（地产、特殊格、站点）
// - 完整主题配置
// - 卡牌模板（支持占位符替换）
// 
// 使用方法：
// 1. 定义一个新的主题（继承 BoardTheme）
// 2. 实现 buildCells() 方法构建 Cell 列表
// 3. 在 theme_provider.dart 中注册主题

import '../../models/models.dart';

/// ============================================================================
/// 主题类型枚举
/// ============================================================================

/// 主题类型
/// 用于标识不同的主题家族，便于扩展
enum BoardThemeType {
  /// 中国城市（默认）
  chinaCities,
  
  /// 国际城市（美国版）
  international,
  
  /// 欧洲城市（预留）
  // europe,
  
  /// 自定义主题（用于特殊/历史主题等）
  custom,
}

/// ============================================================================
/// 主题元信息
/// ============================================================================

/// 主题元信息
/// 包含主题的标识、显示名称、描述等元数据
class BoardThemeInfo {
  /// 主题唯一标识
  /// 用于存储和检索，如 'china_cities', 'international'
  final String id;
  
  /// 显示名称
  /// 在UI中显示，如 '中国城市'、'美国版'
  final String name;
  
  /// 主题描述
  /// 用于帮助玩家理解主题内容
  final String description;
  
  /// 主题类型
  final BoardThemeType type;
  
  /// 图标资源路径（可选）
  /// 可以是主题图标或预览图的路径
  final String iconAsset;
  
  const BoardThemeInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.iconAsset = '',
  });
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardThemeInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

/// ============================================================================
/// 棋盘单元格配置
/// ============================================================================

/// 地产格子配置
/// 用于配置28个可购买地产的信息
/// 
/// 【字段说明】
/// - index: 格子在棋盘上的位置（0-39）
/// - name: 地产名称，用于显示和卡牌引用
/// - color: 所属颜色组，用于判定同色组和租金计算
/// - price: 购买价格
/// - mortgageValue: 抵押价格
/// - baseRent: 无房时的基础租金
/// - rentWithHouse: [1房, 2房, 3房, 4房, 酒店] 的租金
/// - housePrice: 在该地产上建一栋房的成本
class ThemeCellConfig {
  final int index;
  final String name;
  final PropertyColor color;
  final int price;
  final int mortgageValue;
  final int baseRent;
  final List<int> rentWithHouse;
  final int housePrice;
  
  const ThemeCellConfig({
    required this.index,
    required this.name,
    required this.color,
    required this.price,
    required this.mortgageValue,
    required this.baseRent,
    required this.rentWithHouse,
    required this.housePrice,
  });
}

/// 特殊格子配置
/// 用于配置10个特殊格子（起点、税务、监狱等）
class ThemeSpecialCellConfig {
  final int index;
  final String name;
  final CellType type;
  
  const ThemeSpecialCellConfig({
    required this.index,
    required this.name,
    required this.type,
  });
}

/// 站点配置
/// 用于配置6个站点（4个火车站 + 2个公用事业）
class ThemeStationCellConfig {
  final int index;
  final String name;
  final CellType type;
  final int price;
  final int mortgageValue;
  final int? stationIndex; // 火车站序号（0-3），公用事业为null
  
  const ThemeStationCellConfig({
    required this.index,
    required this.name,
    required this.type,
    required this.price,
    required this.mortgageValue,
    this.stationIndex,
  });
}

/// ============================================================================
/// 完整主题配置
/// ============================================================================

/// 完整主题配置
/// 包含地产、特殊格子、站点等所有棋盘配置
/// 
/// 【使用方式】
/// 1. 在具体主题类中实现 properties、specialCells、stations
/// 2. 调用 buildCells() 构建可用于游戏的 Cell 列表
/// 3. 在 theme_provider.dart 中注册
class BoardTheme {
  /// 主题元信息
  final BoardThemeInfo info;
  
  /// 28个地产配置
  final List<ThemeCellConfig> properties;
  
  /// 10个特殊格子配置
  final List<ThemeSpecialCellConfig> specialCells;
  
  /// 6个站点配置（4铁路 + 2公用事业）
  final List<ThemeStationCellConfig> stations;
  
  /// 颜色组映射
  /// Key: 颜色组，Value: 该组包含的格子索引列表
  final Map<PropertyColor, List<int>> colorGroupMap;
  
  const BoardTheme({
    required this.info,
    required this.properties,
    required this.specialCells,
    required this.stations,
    required this.colorGroupMap,
  });
  
  /// 构建完整的 Cell 列表（40格）
  /// 用于游戏初始化和棋盘渲染
  /// 
  /// 【棋盘布局】
  /// - 0-10: 下边缘（从左到右，含左下角和右下角）
  /// - 11-19: 右边缘（从下到上）
  /// - 20-29: 上边缘（从右到左，含右上角）
  /// - 30-39: 左边缘（从上到下，含左上角和左下角）
  List<Cell> buildCells() {
    final cells = <Cell>[];
    
    // 1. 添加特殊格子（按索引排序）
    final specialMap = {for (var s in specialCells) s.index: s};
    
    // 2. 添加站点（按索引排序）
    final stationMap = {for (var s in stations) s.index: s};
    
    // 3. 添加地产（按索引排序）
    final propertyMap = {for (var p in properties) p.index: p};
    
    // 4. 按索引顺序构建所有40个格子
    for (int i = 0; i < 40; i++) {
      if (specialMap.containsKey(i)) {
        // 特殊格子
        final s = specialMap[i]!;
        cells.add(Cell(
          index: i,
          name: s.name,
          type: s.type,
        ));
      } else if (stationMap.containsKey(i)) {
        // 站点（铁路或公用事业）
        final s = stationMap[i]!;
        if (s.type == CellType.railroad) {
          cells.add(Cell(
            index: i,
            name: s.name,
            type: CellType.railroad,
            price: s.price,
            mortgageValue: s.mortgageValue,
            railroadIndex: s.stationIndex,
          ));
        } else {
          cells.add(Cell(
            index: i,
            name: s.name,
            type: CellType.utility,
            price: s.price,
            mortgageValue: s.mortgageValue,
            isUtility: true,
          ));
        }
      } else if (propertyMap.containsKey(i)) {
        // 地产
        final p = propertyMap[i]!;
        cells.add(Cell(
          index: i,
          name: p.name,
          type: CellType.property,
          color: p.color,
          price: p.price,
          mortgageValue: p.mortgageValue,
          baseRent: p.baseRent,
          rentWithHouse: p.rentWithHouse,
          housePrice: p.housePrice,
        ));
      } else {
        // 不应该出现的情况
        throw StateError('棋盘配置不完整，缺失格子 $i');
      }
    }
    
    return cells;
  }
  
  /// 根据格子名称查找索引
  /// 用于卡牌效果定位
  int? findCellIndexByName(String name) {
    final cells = buildCells();
    for (final cell in cells) {
      if (cell.name == name) {
        return cell.index;
      }
    }
    return null;
  }
  
  /// 获取火车站索引列表（按顺序）
  List<int> get railroadIndices {
    final railroads = stations.where((s) => s.type == CellType.railroad).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return railroads.map((s) => s.index).toList();
  }
  
  /// 获取公用事业索引列表（按顺序）
  List<int> get utilityIndices {
    final utils = stations.where((s) => s.type == CellType.utility).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return utils.map((s) => s.index).toList();
  }
  
  /// 特殊格子索引
  int get goIndex => specialCells.firstWhere((s) => s.type == CellType.go).index;
  int get jailIndex => specialCells.firstWhere((s) => s.type == CellType.jail).index;
  int get freeParkingIndex => specialCells.firstWhere((s) => s.type == CellType.freeParking).index;
  int get goToJailIndex => specialCells.firstWhere((s) => s.type == CellType.goToJail).index;
  int get incomeTaxIndex => specialCells.firstWhere((s) => s.type == CellType.incomeTax).index;
  int get luxuryTaxIndex => specialCells.firstWhere((s) => s.type == CellType.luxuryTax).index;
}

/// ============================================================================
/// 卡牌模板系统
/// ============================================================================

/// 卡牌效果模板
/// 用于定义可配置的卡牌效果，支持占位符
class CardEffectTemplate {
  final CardEffectType type;
  final int? value;
  final String? targetPlaceholder; // 目标位置占位符，如 {{station}}、{{utility}}
  final bool passGo;
  
  const CardEffectTemplate({
    required this.type,
    this.value,
    this.targetPlaceholder,
    this.passGo = false,
  });
}

/// 卡牌模板
/// 包含可配置的标题和描述，支持占位符替换
class CardTemplate {
  final String id;
  final CardType type;
  final String titleTemplate;
  final String descriptionTemplate;
  final CardEffectTemplate effect;
  
  const CardTemplate({
    required this.id,
    required this.type,
    required this.titleTemplate,
    required this.descriptionTemplate,
    required this.effect,
  });
  
  /// 构建具体卡牌
  /// [theme]: 当前使用的主题
  GameCard buildCard(BoardTheme theme) {
    // 替换标题和描述中的占位符
    final title = _replacePlaceholders(titleTemplate, theme);
    final desc = _replacePlaceholders(descriptionTemplate, theme);
    
    // 解析目标位置
    String? resolvedTarget;
    if (effect.targetPlaceholder != null) {
      resolvedTarget = _resolveTarget(effect.targetPlaceholder!, theme);
    }
    
    return GameCard(
      id: id,
      type: type,
      title: title,
      description: desc,
      effect: CardEffect(
        type: effect.type,
        value: effect.value,
        target: resolvedTarget,
        passGo: effect.passGo,
      ),
    );
  }
  
  /// 替换占位符
  String _replacePlaceholders(String template, BoardTheme theme) {
    var result = template;
    
    // 替换 {{go}} → 起点名称
    result = result.replaceAll('{{go}}', theme.specialCells
        .firstWhere((s) => s.type == CellType.go).name);
    
    // 替换 {{jail}} → 监狱名称
    result = result.replaceAll('{{jail}}', theme.specialCells
        .firstWhere((s) => s.type == CellType.jail).name);
    
    // 替换 {{railroad}} → 第一个火车站名称
    if (template.contains('{{railroad}}')) {
      final railroad = theme.stations
          .firstWhere((s) => s.type == CellType.railroad);
      result = result.replaceAll('{{railroad}}', railroad.name);
    }
    
    // 替换 {{utility}} → 第一个公用事业名称
    if (template.contains('{{utility}}')) {
      final utility = theme.stations
          .firstWhere((s) => s.type == CellType.utility);
      result = result.replaceAll('{{utility}}', utility.name);
    }
    
    return result;
  }
  
  /// 解析目标位置占位符
  String? _resolveTarget(String placeholder, BoardTheme theme) {
    switch (placeholder) {
      case '{{go}}':
        return theme.specialCells
            .firstWhere((s) => s.type == CellType.go).name;
      case '{{jail}}':
        return theme.specialCells
            .firstWhere((s) => s.type == CellType.jail).name;
      case '{{station}}': case '{{railroad}}':
        // 返回第一个火车站名称
        return theme.stations
            .firstWhere((s) => s.type == CellType.railroad).name;
      case '{{utility}}':
        return theme.stations
            .firstWhere((s) => s.type == CellType.utility).name;
      case '{{parkPlace}}':
        // 深蓝色组的最贵地产
        final darkBlue = theme.properties
            .where((p) => p.color == PropertyColor.darkBlue)
            .toList()
          ..sort((a, b) => b.price.compareTo(a.price));
        return darkBlue.isNotEmpty ? darkBlue.first.name : null;
      case '{{boardwalk}}':
        // 深蓝色组的最贵地产（Boardwalk特指）
        final darkBlue = theme.properties
            .where((p) => p.color == PropertyColor.darkBlue)
            .toList()
          ..sort((a, b) => b.price.compareTo(a.price));
        return darkBlue.length > 1 ? darkBlue[1].name : darkBlue.first.name;
      default:
        // 尝试按名称查找
        if (placeholder.startsWith('{{') && placeholder.endsWith('}}')) {
          final name = placeholder.substring(2, placeholder.length - 2);
          final cell = theme.buildCells().where((c) => c.name == name).firstOrNull;
          return cell?.name;
        }
        return placeholder;
    }
  }
}

/// 卡牌模板集合
/// 包含命运卡和公益卡模板
class CardTemplates {
  final List<CardTemplate> chanceCards;
  final List<CardTemplate> communityChestCards;
  
  const CardTemplates({
    required this.chanceCards,
    required this.communityChestCards,
  });
  
  /// 根据模板构建具体卡牌
  /// [theme]: 当前使用的主题
  /// [type]: 卡牌类型
  List<GameCard> buildCards(BoardTheme theme, CardType type) {
    final templates = type == CardType.chance 
        ? chanceCards 
        : communityChestCards;
    return templates.map((t) => t.buildCard(theme)).toList();
  }
  
  /// 构建所有卡牌
  List<GameCard> buildAllCards(BoardTheme theme) {
    return [
      ...buildCards(theme, CardType.chance),
      ...buildCards(theme, CardType.communityChest),
    ];
  }
}

/// ============================================================================
/// 占位符常量
/// ============================================================================

/// 预定义的占位符
/// 用于卡牌模板中的占位符替换
class ThemePlaceholders {
  static const String go = '{{go}}';
  static const String jail = '{{jail}}';
  static const String railroad = '{{railroad}}';
  static const String utility = '{{utility}}';
  static const String station = '{{station}}';
  static const String parkPlace = '{{parkPlace}}';
  static const String boardwalk = '{{boardwalk}}';
  
  ThemePlaceholders._(); // 禁止实例化
}