import '../models/item_location.dart';
import 'location_template.dart';

class LocationTemplateLibrary {
  static final Map<String, LocationTemplate> roomTemplates = {
    '主卧': LocationTemplate.direction(
      directions: DirectionConfig.eightDirectionsWithCenter(),
      heights: HeightConfig.threeLevels(),
    ),
    '次卧': LocationTemplate.direction(
      directions: DirectionConfig.eightDirectionsWithCenter(),
      heights: HeightConfig.threeLevels(),
    ),
    '客厅': LocationTemplate.direction(
      directions: DirectionConfig.eightDirectionsWithCenter(),
      heights: HeightConfig.threeLevels(),
    ),
    '厨房': LocationTemplate.direction(
      directions: DirectionConfig.fourDirectionsWithCenter(),
      heights: HeightConfig.threeLevels(),
    ),
    '餐厅': LocationTemplate.direction(
      directions: DirectionConfig.fourDirections(),
      heights: null,
    ),
    '书房': LocationTemplate.direction(
      directions: DirectionConfig.fourDirectionsWithCenter(),
      heights: HeightConfig.threeLevels(),
    ),
    '卫生间': LocationTemplate.direction(
      directions: DirectionConfig.fourDirections(),
      heights: null,
    ),
    '阳台': LocationTemplate.direction(
      directions: DirectionConfig.fourDirections(),
      heights: HeightConfig.twoLevels(),
    ),
    '玄关': LocationTemplate.direction(
      directions: DirectionConfig.fourDirections(),
      heights: null,
    ),
    '储物间': LocationTemplate.direction(
      directions: DirectionConfig.fourDirections(),
      heights: null,
    ),
    '车库': LocationTemplate.direction(
      directions: DirectionConfig.fourDirections(),
      heights: HeightConfig.twoLevels(),
    ),
    '儿童房': LocationTemplate.direction(
      directions: DirectionConfig.eightDirectionsWithCenter(),
      heights: HeightConfig.threeLevels(),
    ),
  };

  static final Map<String, LocationTemplate> furnitureTemplates = {
    '衣柜': LocationTemplate.numbering(
      config: const IndexConfig(totalSlots: 3, namingPattern: '第{n}层'),
    ),
    '书架': LocationTemplate.numbering(
      config: const IndexConfig(totalSlots: 4, namingPattern: '第{n}层'),
    ),
    '书柜': LocationTemplate.numbering(
      config: const IndexConfig(totalSlots: 3, namingPattern: '第{n}层'),
    ),
    '橱柜': LocationTemplate.numbering(
      config: const IndexConfig(totalSlots: 2, namingPattern: '第{n}层'),
    ),
    '斗柜': LocationTemplate.numbering(
      config: const IndexConfig(totalSlots: 4, namingPattern: '第{n}层'),
    ),
    '床头柜': LocationTemplate.numbering(
      config: const IndexConfig(totalSlots: 2, namingPattern: '第{n}层'),
    ),
    '浴室柜': LocationTemplate.numbering(
      config: const IndexConfig(totalSlots: 2, namingPattern: '第{n}层'),
    ),
    '餐边柜': LocationTemplate.numbering(
      config: const IndexConfig(totalSlots: 3, namingPattern: '第{n}层'),
    ),
    '鞋柜': LocationTemplate.numbering(
      config: const IndexConfig(totalSlots: 4, columns: 2, namingPattern: '第{n}格'),
    ),
    '电视柜': LocationTemplate.numbering(
      config: const IndexConfig(totalSlots: 2, namingPattern: '第{n}层'),
    ),
    '收纳盒': LocationTemplate.grid(
      config: const GridConfig(rows: 3, cols: 3),
    ),
    '抽屉内部': LocationTemplate.grid(
      config: const GridConfig(rows: 2, cols: 3),
    ),
    '收纳箱': LocationTemplate.stack(
      config: const StackConfig(levels: 3, labels: ['上层', '中层', '下层']),
    ),
    '行李箱': LocationTemplate.stack(
      config: const StackConfig(levels: 2, labels: ['上层', '下层']),
    ),
  };

  static LocationTemplate? getRoomTemplate(String roomName) {
    return roomTemplates[roomName];
  }

  static LocationTemplate? getFurnitureTemplate(String furnitureName) {
    return furnitureTemplates[furnitureName];
  }

  static List<String> get roomTemplateNames => roomTemplates.keys.toList();
  static List<String> get furnitureTemplateNames => furnitureTemplates.keys.toList();
}

class LocationTemplateSuggestion {
  final LocationTemplate template;
  final double confidence;
  final List<LocationTemplate> alternatives;

  const LocationTemplateSuggestion({
    required this.template,
    required this.confidence,
    this.alternatives = const [],
  });
}

class LocationTemplateSuggester {
  static final Map<List<String>, String> _furnitureKeywords = {
    ['衣柜', '衣橱', '大衣柜']: '衣柜',
    ['书架', '书柜', '书橱']: '书架',
    ['橱柜', '吊柜', '地柜']: '橱柜',
    ['斗柜', '五斗柜', '六斗柜']: '斗柜',
    ['床头柜', '床边柜']: '床头柜',
    ['浴室柜', '洗手台柜']: '浴室柜',
    ['餐边柜', '餐柜']: '餐边柜',
    ['鞋柜', '鞋架', '鞋盒']: '鞋柜',
    ['电视柜', '电视柜', '影音柜']: '电视柜',
    ['收纳盒', '储物盒']: '收纳盒',
    ['抽屉']: '收纳盒',
    ['收纳箱', '整理箱', '储物箱']: '收纳箱',
    ['行李箱', '旅行箱', '拉杆箱']: '行李箱',
  };

  static final Map<List<String>, String> _roomKeywords = {
    ['主卧', '主卧室', '主人房']: '主卧',
    ['次卧', '次卧室', '客房', '客卧']: '次卧',
    ['客厅', '起居室', '大厅']: '客厅',
    ['厨房', '灶台']: '厨房',
    ['餐厅', '饭厅', '餐桌']: '餐厅',
    ['书房', '书房', '工作室']: '书房',
    ['卫生间', '洗手间', '厕所', '浴室', '厕所']: '卫生间',
    ['阳台', '露台']: '阳台',
    ['玄关', '门厅', '入口']: '玄关',
    ['储物间', '储藏室', '杂物间']: '储物间',
    ['车库', '停车位']: '车库',
    ['儿童房', '儿童卧室', '小孩房']: '儿童房',
  };

  static LocationTemplateSuggestion? suggest(String locationName, {bool isRoot = true}) {
    final keywords = isRoot ? _roomKeywords : _furnitureKeywords;
    final templates = isRoot ? LocationTemplateLibrary.roomTemplates : LocationTemplateLibrary.furnitureTemplates;

    for (final entry in keywords.entries) {
      for (final keyword in entry.key) {
        if (locationName.contains(keyword) || keyword.contains(locationName)) {
          final templateName = entry.value;
          final template = templates[templateName];
          if (template != null) {
            return LocationTemplateSuggestion(
              template: template,
              confidence: 0.9,
              alternatives: _getAlternatives(templateName, isRoot),
            );
          }
        }
      }
    }

    return null;
  }

  static List<LocationTemplate> _getAlternatives(String matchedName, bool isRoot) {
    final templates = isRoot ? LocationTemplateLibrary.roomTemplates : LocationTemplateLibrary.furnitureTemplates;
    return templates.entries
        .where((e) => e.key != matchedName)
        .take(2)
        .map((e) => e.value)
        .toList();
  }

  static List<String> getSuggestedTemplateNames(String locationName, {bool isRoot = true}) {
    final suggestion = suggest(locationName, isRoot: isRoot);
    if (suggestion == null) return [];
    
    final names = <String>[suggestion.template.type.label];
    for (final alt in suggestion.alternatives) {
      names.add(alt.type.label);
    }
    return names;
  }
}
