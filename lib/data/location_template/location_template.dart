import '../models/item_location.dart';

class DirectionConfig {
  final bool enabled;
  final List<String> labels;
  final bool includeCenter;

  const DirectionConfig({
    required this.enabled,
    required this.labels,
    this.includeCenter = false,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'labels': labels,
        'includeCenter': includeCenter,
      };

  factory DirectionConfig.fromJson(Map<String, dynamic> json) {
    return DirectionConfig(
      enabled: json['enabled'] as bool? ?? true,
      labels: (json['labels'] as List<dynamic>?)?.cast<String>() ?? [],
      includeCenter: json['includeCenter'] as bool? ?? false,
    );
  }

  static DirectionConfig fourDirections() {
    return const DirectionConfig(
      enabled: true,
      labels: ['东', '南', '西', '北'],
      includeCenter: false,
    );
  }

  static DirectionConfig fourDirectionsWithCenter() {
    return const DirectionConfig(
      enabled: true,
      labels: ['东', '南', '西', '北'],
      includeCenter: true,
    );
  }

  static DirectionConfig eightDirections() {
    return const DirectionConfig(
      enabled: true,
      labels: ['东', '南', '西', '北', '东北', '西北', '东南', '西南'],
      includeCenter: false,
    );
  }

  static DirectionConfig eightDirectionsWithCenter() {
    return const DirectionConfig(
      enabled: true,
      labels: ['东', '南', '西', '北', '东北', '西北', '东南', '西南'],
      includeCenter: true,
    );
  }
}

class HeightConfig {
  final bool enabled;
  final List<String> labels;

  const HeightConfig({
    required this.enabled,
    required this.labels,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'labels': labels,
      };

  factory HeightConfig.fromJson(Map<String, dynamic> json) {
    return HeightConfig(
      enabled: json['enabled'] as bool? ?? false,
      labels: (json['labels'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  static HeightConfig threeLevels() {
    return const HeightConfig(
      enabled: true,
      labels: ['上层', '中层', '下层'],
    );
  }

  static HeightConfig twoLevels() {
    return const HeightConfig(
      enabled: true,
      labels: ['上层', '下层'],
    );
  }
}

class IndexConfig {
  final int totalSlots;
  final int startFrom;
  final String namingPattern;
  final int columns;

  const IndexConfig({
    required this.totalSlots,
    this.startFrom = 1,
    this.namingPattern = '第{n}层',
    this.columns = 1,
  });

  Map<String, dynamic> toJson() => {
        'totalSlots': totalSlots,
        'startFrom': startFrom,
        'namingPattern': namingPattern,
        'columns': columns,
      };

  factory IndexConfig.fromJson(Map<String, dynamic> json) {
    return IndexConfig(
      totalSlots: json['totalSlots'] as int? ?? 4,
      startFrom: json['startFrom'] as int? ?? 1,
      namingPattern: json['namingPattern'] as String? ?? '第{n}层',
      columns: json['columns'] as int? ?? 1,
    );
  }

  List<String> generateSlotNames() {
    return List.generate(
      totalSlots,
      (i) => namingPattern.replaceAll('{n}', '${startFrom + i}'),
    );
  }
}

class GridConfig {
  final int rows;
  final int cols;
  final List<String>? rowLabels;
  final List<String>? colLabels;

  const GridConfig({
    required this.rows,
    required this.cols,
    this.rowLabels,
    this.colLabels,
  });

  Map<String, dynamic> toJson() => {
        'rows': rows,
        'cols': cols,
        'rowLabels': rowLabels,
        'colLabels': colLabels,
      };

  factory GridConfig.fromJson(Map<String, dynamic> json) {
    return GridConfig(
      rows: json['rows'] as int? ?? 3,
      cols: json['cols'] as int? ?? 3,
      rowLabels: (json['rowLabels'] as List<dynamic>?)?.cast<String>(),
      colLabels: (json['colLabels'] as List<dynamic>?)?.cast<String>(),
    );
  }

  String getCellLabel(int row, int col) {
    final rowLabel = rowLabels != null && row < rowLabels!.length
        ? rowLabels![row]
        : '${row + 1}';
    final colLabel = colLabels != null && col < colLabels!.length
        ? colLabels![col]
        : '${col + 1}';
    return '$colLabel$rowLabel';
  }

  List<String> generateSlotNames() {
    final slots = <String>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        slots.add(getCellLabel(r, c));
      }
    }
    return slots;
  }
}

class StackConfig {
  final int levels;
  final List<String>? labels;

  const StackConfig({
    required this.levels,
    this.labels,
  });

  Map<String, dynamic> toJson() => {
        'levels': levels,
        'labels': labels,
      };

  factory StackConfig.fromJson(Map<String, dynamic> json) {
    return StackConfig(
      levels: json['levels'] as int? ?? 3,
      labels: (json['labels'] as List<dynamic>?)?.cast<String>(),
    );
  }

  List<String> generateSlotNames() {
    if (labels != null) return labels!;
    return List.generate(levels, (i) => '第${i + 1}层');
  }
}

class LocationTemplate {
  final LocationTemplateType type;
  final DirectionConfig? directionConfig;
  final HeightConfig? heightConfig;
  final IndexConfig? indexConfig;
  final GridConfig? gridConfig;
  final StackConfig? stackConfig;

  const LocationTemplate._({
    required this.type,
    this.directionConfig,
    this.heightConfig,
    this.indexConfig,
    this.gridConfig,
    this.stackConfig,
  });

  factory LocationTemplate.direction({
    required DirectionConfig directions,
    HeightConfig? heights,
  }) {
    return LocationTemplate._(
      type: LocationTemplateType.direction,
      directionConfig: directions,
      heightConfig: heights,
    );
  }

  factory LocationTemplate.numbering({
    required IndexConfig config,
  }) {
    return LocationTemplate._(
      type: LocationTemplateType.numbering,
      indexConfig: config,
    );
  }

  factory LocationTemplate.grid({
    required GridConfig config,
  }) {
    return LocationTemplate._(
      type: LocationTemplateType.grid,
      gridConfig: config,
    );
  }

  factory LocationTemplate.stack({
    required StackConfig config,
  }) {
    return LocationTemplate._(
      type: LocationTemplateType.stack,
      stackConfig: config,
    );
  }

  factory LocationTemplate.none() {
    return const LocationTemplate._(
      type: LocationTemplateType.none,
    );
  }

  Map<String, dynamic> toConfigJson() {
    switch (type) {
      case LocationTemplateType.direction:
        return {
          'template': 'direction',
          'directions': directionConfig?.toJson(),
          'heights': heightConfig?.toJson(),
        };
      case LocationTemplateType.numbering:
        return {
          'template': 'index',
          ...indexConfig!.toJson(),
        };
      case LocationTemplateType.grid:
        return {
          'template': 'grid',
          ...gridConfig!.toJson(),
        };
      case LocationTemplateType.stack:
        return {
          'template': 'stack',
          ...stackConfig!.toJson(),
        };
      case LocationTemplateType.none:
        return {'template': 'none'};
    }
  }

  List<String> getAllSlots() {
    switch (type) {
      case LocationTemplateType.direction:
        return _generateDirectionSlots();
      case LocationTemplateType.numbering:
        return indexConfig!.generateSlotNames();
      case LocationTemplateType.grid:
        return gridConfig!.generateSlotNames();
      case LocationTemplateType.stack:
        return stackConfig!.generateSlotNames();
      case LocationTemplateType.none:
        return [];
    }
  }

  List<String> _generateDirectionSlots() {
    if (directionConfig == null) return [];
    final slots = <String>[];
    for (final dir in directionConfig!.labels) {
      if (heightConfig?.enabled == true) {
        for (final height in heightConfig!.labels) {
          slots.add('$dir$height');
        }
      } else {
        slots.add(dir);
      }
    }
    if (directionConfig!.includeCenter) {
      if (heightConfig?.enabled == true) {
        for (final height in heightConfig!.labels) {
          slots.add('中心$height');
        }
      } else {
        slots.add('中心');
      }
    }
    return slots;
  }

  int get totalSlots => getAllSlots().length;

  static LocationTemplate fromConfigJson(Map<String, dynamic>? json) {
    if (json == null) return LocationTemplate.none();

    final template = json['template'] as String?;
    switch (template) {
      case 'direction':
        return LocationTemplate.direction(
          directions: DirectionConfig.fromJson(
            json['directions'] as Map<String, dynamic>? ?? {},
          ),
          heights: json['heights'] != null
              ? HeightConfig.fromJson(json['heights'] as Map<String, dynamic>)
              : null,
        );
      case 'index':
      case 'numbering':
        return LocationTemplate.numbering(
          config: IndexConfig.fromJson(json),
        );
      case 'grid':
        return LocationTemplate.grid(
          config: GridConfig.fromJson(json),
        );
      case 'stack':
        return LocationTemplate.stack(
          config: StackConfig.fromJson(json),
        );
      default:
        return LocationTemplate.none();
    }
  }
}
