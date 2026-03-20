import 'package:flutter/material.dart';
import '../../../../data/models/item_location.dart';
import '../../../../data/location_template/location_template.dart';
import 'direction_diagram.dart';
import 'index_diagram.dart';
import 'grid_diagram.dart';
import 'stack_diagram.dart';
import 'grid9_diagram.dart';

class LocationDiagramWidget extends StatelessWidget {
  final LocationTemplateType templateType;
  final Map<String, dynamic>? templateConfig;
  final Map<String, dynamic>? initialPosition;
  final Set<String> occupiedSlots;
  final ValueChanged<Map<String, dynamic>?>? onPositionChanged;

  /// 是否使用九宫格模式（用于父级槽位选择）
  final bool useGrid9Mode;

  const LocationDiagramWidget({
    super.key,
    required this.templateType,
    this.templateConfig,
    this.initialPosition,
    this.occupiedSlots = const {},
    this.onPositionChanged,
    this.useGrid9Mode = false,
  });

  @override
  Widget build(BuildContext context) {
    // 如果是方向型且启用九宫格模式，使用九宫格组件
    if (templateType == LocationTemplateType.direction && useGrid9Mode) {
      return _buildGrid9Diagram();
    }

    switch (templateType) {
      case LocationTemplateType.direction:
        return _buildDirectionDiagram();
      case LocationTemplateType.numbering:
        return _buildIndexDiagram();
      case LocationTemplateType.grid:
        return _buildGridDiagram();
      case LocationTemplateType.stack:
        return _buildStackDiagram();
      case LocationTemplateType.none:
        return _buildNoneMessage();
    }
  }

  Widget _buildGrid9Diagram() {
    final heightConfig = templateConfig?['heights'] != null
        ? HeightConfig.fromJson(
            templateConfig!['heights'] as Map<String, dynamic>,
          )
        : null;

    String? selectedDirection;
    String? selectedHeight;

    if (initialPosition != null) {
      selectedDirection = initialPosition!['direction'] as String?;
      selectedHeight = initialPosition!['height'] as String?;
    }

    return SimpleGrid9Selector(
      heightOptions: heightConfig?.labels ?? [],
      selectedDirection: selectedDirection,
      selectedHeight: selectedHeight,
      onDirectionSelected: (direction) {
        if (direction.isEmpty) {
          // 方向被清除
          onPositionChanged?.call(null);
        } else {
          final pos = <String, dynamic>{'direction': direction};
          if (selectedHeight != null) {
            pos['height'] = selectedHeight;
          }
          onPositionChanged?.call(pos);
        }
      },
      onHeightSelected: (height) {
        final pos = <String, dynamic>{'direction': selectedDirection ?? ''};
        if (height != null) {
          pos['height'] = height;
        }
        onPositionChanged?.call(pos);
      },
    );
  }

  Widget _buildDirectionDiagram() {
    final config = DirectionConfig.fromJson(
      templateConfig?['directions'] as Map<String, dynamic>? ?? {},
    );
    final heightConfig = templateConfig?['heights'] != null
        ? HeightConfig.fromJson(
            templateConfig!['heights'] as Map<String, dynamic>,
          )
        : null;

    String? selectedDirection;
    String? selectedHeight;

    if (initialPosition != null) {
      selectedDirection = initialPosition!['direction'] as String?;
      selectedHeight = initialPosition!['height'] as String?;
    }

    return DirectionDiagram(
      directionConfig: config,
      heightConfig: heightConfig,
      selectedDirection: selectedDirection,
      selectedHeight: selectedHeight,
      occupiedSlots: occupiedSlots,
      onDirectionSelected: (direction) {
        final pos = <String, dynamic>{'direction': direction};
        if (heightConfig?.enabled == true && selectedHeight != null) {
          pos['height'] = selectedHeight;
        }
        onPositionChanged?.call(pos);
      },
      onHeightSelected: (height) {
        final pos = <String, dynamic>{
          'direction': selectedDirection ?? '',
          'height': height,
        };
        onPositionChanged?.call(pos);
      },
    );
  }

  Widget _buildIndexDiagram() {
    final config = IndexConfig.fromJson(templateConfig ?? {});
    String? selectedIndex;

    if (initialPosition != null) {
      final index = initialPosition!['index'] as int?;
      if (index != null) {
        final slotNames = config.generateSlotNames();
        if (index >= config.startFrom &&
            index < config.startFrom + config.totalSlots) {
          selectedIndex = slotNames[index - config.startFrom];
        }
      }
    }

    return IndexDiagram(
      config: config,
      selectedIndex: selectedIndex,
      occupiedSlots: occupiedSlots,
      onIndexSelected: (index) {
        final slotNames = config.generateSlotNames();
        final slotIndex = slotNames.indexOf(index);
        onPositionChanged?.call({'index': config.startFrom + slotIndex});
      },
    );
  }

  Widget _buildGridDiagram() {
    final config = GridConfig.fromJson(templateConfig ?? {});
    String? selectedCell;

    if (initialPosition != null) {
      final row = initialPosition!['row'];
      final col = initialPosition!['col'];
      if (row != null && col != null) {
        selectedCell = config.getCellLabel(
          (row is String
              ? config.rowLabels?.indexOf(row as String) ?? -1
              : (row as int) - 1),
          (col is String
              ? config.colLabels?.indexOf(col as String) ?? -1
              : (col as int) - 1),
        );
      }
    }

    return GridDiagram(
      config: config,
      selectedCell: selectedCell,
      occupiedSlots: occupiedSlots,
      onCellSelected: (cell) {
        onPositionChanged?.call(config.getCellPosition(cell));
      },
    );
  }

  Widget _buildStackDiagram() {
    final config = StackConfig.fromJson(templateConfig ?? {});
    String? selectedLevel;

    if (initialPosition != null) {
      final level = initialPosition!['level'] as int?;
      if (level != null && level > 0 && level <= config.levels) {
        final labels = config.generateSlotNames();
        selectedLevel = labels[level - 1];
      }
    }

    return StackDiagram(
      config: config,
      selectedLevel: selectedLevel,
      occupiedSlots: occupiedSlots,
      onLevelSelected: (level) {
        final labels = config.generateSlotNames();
        final index = labels.indexOf(level);
        onPositionChanged?.call({'level': index + 1});
      },
    );
  }

  Widget _buildNoneMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: const Column(
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('此位置未设置模板', style: TextStyle(fontSize: 14, color: Colors.grey)),
          SizedBox(height: 4),
          Text(
            '可使用文字描述物品位置',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

extension GridConfigExtension on GridConfig {
  Map<String, dynamic> getCellPosition(String label) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (getCellLabel(r, c) == label) {
          return {
            'row': rowLabels != null && r < rowLabels!.length
                ? rowLabels![r]
                : r + 1,
            'col': colLabels != null && c < colLabels!.length
                ? colLabels![c]
                : c + 1,
          };
        }
      }
    }
    return {'row': 1, 'col': 1};
  }
}
