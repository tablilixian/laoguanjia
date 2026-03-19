import '../models/item_location.dart';
import '../location_template/location_template.dart';

class LocationPathService {
  static String formatArrow(String path) {
    return path.replaceAll('-', ' → ');
  }

  static String formatSlash(String path) {
    return path.replaceAll('-', ' / ');
  }

  static String formatNatural(String path) {
    return path.replaceAll('-', '的');
  }

  static String buildLocationPath(List<ItemLocation> locations, String locationId) {
    final pathParts = <String>[];
    String? currentId = locationId;

    while (currentId != null) {
      final location = locations.firstWhere(
        (l) => l.id == currentId,
        orElse: () => throw Exception('Location not found: $currentId'),
      );
      pathParts.insert(0, location.name);
      currentId = location.parentId;
    }

    return pathParts.join(' → ');
  }

  static String buildPositionDescription({
    required ItemLocation location,
    Map<String, dynamic>? slotPosition,
  }) {
    if (slotPosition == null) {
      return location.name;
    }

    final positionStr = _formatSlotPosition(location, slotPosition);
    return '${location.name}的$positionStr';
  }

  static String _formatSlotPosition(
    ItemLocation location,
    Map<String, dynamic> slotPosition,
  ) {
    if (location.templateType == null) {
      return _formatGenericPosition(slotPosition);
    }

    switch (location.templateType!) {
      case LocationTemplateType.direction:
        final direction = slotPosition['direction'] as String? ?? '';
        final height = slotPosition['height'] as String?;
        return height != null ? '$direction$height' : direction;

      case LocationTemplateType.numbering:
        final index = slotPosition['index'] as int?;
        if (index == null) return '';
        final template = LocationTemplate.fromConfigJson(location.templateConfig);
        if (template.indexConfig != null) {
          final slots = template.indexConfig!.generateSlotNames();
          final slotIndex = index - template.indexConfig!.startFrom;
          if (slotIndex >= 0 && slotIndex < slots.length) {
            return slots[slotIndex];
          }
        }
        return '第$index层';

      case LocationTemplateType.grid:
        final row = slotPosition['row'];
        final col = slotPosition['col'];
        if (row != null && col != null) {
          return '$col$row';
        }
        return '';

      case LocationTemplateType.stack:
        final level = slotPosition['level'] as int?;
        if (level == null) return '';
        final template = LocationTemplate.fromConfigJson(location.templateConfig);
        if (template.stackConfig != null) {
          final slots = template.stackConfig!.generateSlotNames();
          if (level > 0 && level <= slots.length) {
            return slots[level - 1];
          }
        }
        return '第$level层';

      case LocationTemplateType.none:
        return _formatGenericPosition(slotPosition);
    }
  }

  static String _formatGenericPosition(Map<String, dynamic> slotPosition) {
    final parts = <String>[];
    slotPosition.forEach((key, value) {
      if (value != null) {
        parts.add('$value');
      }
    });
    return parts.join('');
  }

  static String formatSlotForDisplay(
    ItemLocation location,
    Map<String, dynamic>? slotPosition,
  ) {
    if (slotPosition == null) return '';
    return _formatSlotPosition(location, slotPosition);
  }

  /// 简化版：直接格式化槽位信息（不需要位置模板信息）
  static String formatSlotForDisplaySimple(Map<String, dynamic>? slotPosition) {
    if (slotPosition == null) return '';
    final parts = <String>[];
    slotPosition.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        parts.add(value.toString());
      }
    });
    return parts.join(' - ');
  }

  static Map<String, dynamic>? parseSlotString(
    ItemLocation location,
    String slotString,
  ) {
    if (location.templateType == null || slotString.isEmpty) {
      return null;
    }

    switch (location.templateType!) {
      case LocationTemplateType.direction:
        return _parseDirectionSlot(slotString);

      case LocationTemplateType.numbering:
        return _parseIndexSlot(location, slotString);

      case LocationTemplateType.grid:
        return _parseGridSlot(location, slotString);

      case LocationTemplateType.stack:
        return _parseStackSlot(location, slotString);

      case LocationTemplateType.none:
        return null;
    }
  }

  static Map<String, dynamic> _parseDirectionSlot(String slotString) {
    final directions = ['东', '南', '西', '北', '东北', '西北', '东南', '西南', '中心'];
    final heights = ['上层', '中层', '下层'];

    String? direction;
    String? height;

    for (final dir in directions) {
      if (slotString.contains(dir)) {
        direction = dir;
        break;
      }
    }

    for (final h in heights) {
      if (slotString.contains(h)) {
        height = h;
        break;
      }
    }

    if (direction == null) return {};

    final result = <String, dynamic>{'direction': direction};
    if (height != null) {
      result['height'] = height;
    }
    return result;
  }

  static Map<String, dynamic> _parseIndexSlot(ItemLocation location, String slotString) {
    final template = LocationTemplate.fromConfigJson(location.templateConfig);
    if (template.indexConfig == null) return {};

    final slots = template.indexConfig!.generateSlotNames();
    for (int i = 0; i < slots.length; i++) {
      if (slotString == slots[i]) {
        return {'index': template.indexConfig!.startFrom + i};
      }
    }

    final match = RegExp(r'(\d+)').firstMatch(slotString);
    if (match != null) {
      final index = int.tryParse(match.group(1)!);
      if (index != null) {
        return {'index': index};
      }
    }

    return {};
  }

  static Map<String, dynamic> _parseGridSlot(ItemLocation location, String slotString) {
    if (slotString.length >= 2) {
      return {
        'col': slotString[0],
        'row': slotString.substring(1),
      };
    }
    return {};
  }

  static Map<String, dynamic> _parseStackSlot(ItemLocation location, String slotString) {
    final template = LocationTemplate.fromConfigJson(location.templateConfig);
    if (template.stackConfig == null) return {};

    final slots = template.stackConfig!.generateSlotNames();
    for (int i = 0; i < slots.length; i++) {
      if (slotString == slots[i]) {
        return {'level': i + 1};
      }
    }

    final match = RegExp(r'(\d+)').firstMatch(slotString);
    if (match != null) {
      final level = int.tryParse(match.group(1)!);
      if (level != null) {
        return {'level': level};
      }
    }

    return {};
  }
}
