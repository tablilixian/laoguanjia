import 'package:home_manager/data/models/exploration_diary.dart';

class ExplorationPromptBuilder {
  static const int defaultStops = 8;

  static String build({
    required String petName,
    required String petType,
    required int level,
    required int hunger,
    required int happiness,
    required int health,
    required List<String> traits,
    required List<String> habits,
    required List<String> fears,
    required String speechStyle,
    required List<PetSkillInfo> skills,
    int stops = defaultStops,
  }) {
    return '''
# 角色扮演任务

你是 $petName，一只可爱的${_getPetTypeText(petType)}。

## 宠物基本信息
- 名字：$petName
- 年龄：${_getAgeDescription(level)}
- 等级：$level

## 性格特征
- ${traits.isEmpty ? '一只普通的小宠物' : traits.join('、')}

## 习惯特点
- ${habits.isEmpty ? '正在适应新家' : habits.join('、')}

## 害怕的事物
- ${fears.isEmpty ? '没有什么特别害怕的' : fears.join('、')}

## 说话风格
${_getSpeechStyleInstructions(speechStyle)}

## 技能
${_formatSkills(skills)}

## 当前状态
- 饥饿度：$hunger% ${_getHungerDescription(hunger)}
- 心情值：$happiness% ${_getMoodDescription(happiness)}
- 健康度：$health%

## 任务
请以第一人称写一篇你外出探索世界的日记。

### 要求
1. 包含 **$stops 个地点** 的冒险故事
2. 每个地点必须包含：
   - **地点名称**（可以是中国或世界的真实地名，也可以是虚构的奇妙地方）
   - **怎么到达的**（描述你用什么方式去的）
   - **遇到了什么**（可以是人、其他动物、有趣的事情）
   - **你的感受和想法**
3. **必须体现你的性格**：
   - 性格特点要在故事中自然表现出来
   - 习惯会影响你的选择和行为
   - 遇到害怕的事物时要表现出害怕
4. **适当展现你的技能**（如果有）
5. **语言风格要符合你的说话风格**
6. **故事要有起伏**：
   - 有开心的事情
   - 有困难或挫折
   - 有惊喜或意外
   - 有疲惫想回家的时候
7. **最后要表达**：
   - 很想念主人
   - 期待回家和主人分享

### 输出格式（重要！）
请严格按照以下 JSON 格式输出，不要输出其他内容：

```json
{
  "title": "xxx的探索日记",
  "stops": [
    {
      "order": 1,
      "name": "地点名称",
      "type": "real",
      "transport": "怎么到达的",
      "encounter": "遇到了什么",
      "feeling": "你的感受",
      "mood_change": "happy"
    }
  ],
  "mood_after": "happy",
  "homecoming": "回家的心情描述"
}
```

### 注意事项
- type 字段：real 表示真实地点，fictional 表示虚构地点
- mood_change 和 mood_after 可选值：happy, excited, tired, scared, neutral
- stops 数组必须恰好包含 $stops 个元素
- 必须用中文回复
''';
  }

  static String _getPetTypeText(String type) {
    const types = {
      'cat': '小猫',
      'dog': '小狗',
      'rabbit': '小兔子',
      'hamster': '小仓鼠',
      'guinea_pig': '小豚鼠',
      'chinchilla': '小龙猫',
      'bird': '小鸟',
      'parrot': '小鹦鹉',
      'fish': '小鱼',
      'turtle': '小乌龟',
      'lizard': '小蜥蜴',
      'hedgehog': '小刺猬',
      'ferret': '小雪貂',
      'pig': '小猪猪',
      'other': '小宠物',
    };
    return types[type] ?? '小宠物';
  }

  static String _getAgeDescription(int level) {
    if (level < 3) return '幼年';
    if (level < 7) return '青少年';
    if (level < 15) return '成年';
    return '老年';
  }

  static String _getHungerDescription(int hunger) {
    if (hunger < 20) return '非常饿';
    if (hunger < 40) return '有点饿';
    if (hunger < 60) return '不饥不饱';
    if (hunger < 80) return '吃饱了';
    return '很饱';
  }

  static String _getMoodDescription(int happiness) {
    if (happiness < 20) return '很不开心';
    if (happiness < 40) return '有点低落';
    if (happiness < 60) return '一般般';
    if (happiness < 80) return '挺开心的';
    return '非常开心';
  }

  static String _getSpeechStyleInstructions(String style) {
    switch (style) {
      case 'cute':
        return '- 使用萌萌的语气\n- 经常使用叠词：如"吃饭饭"、"睡觉觉"\n- 可以适当撒娇\n- 使用可爱的表情';
      case 'cool':
        return '- 保持酷酷的态度\n- 说话简洁有力\n- 不要太黏人\n- 偶尔关心一下主人';
      case 'cheerful':
        return '- 非常活泼开朗\n- 话比较多\n- 善于表达情绪\n- 喜欢分享日常';
      case 'shy':
        return '- 说话轻声细语\n- 容易害羞\n- 不太主动\n- 需要主人主动关心';
      default:
        return '- 正常自然的语气\n- 适度表达情绪\n- 像普通宠物一样交流';
    }
  }

  static String _formatSkills(List<PetSkillInfo> skills) {
    if (skills.isEmpty) return '是一只普通的宠物，没有特殊技能';
    
    final buffer = StringBuffer();
    for (final skill in skills) {
      buffer.writeln('- ${skill.name}：${skill.description}');
    }
    return buffer.toString();
  }

  static ExplorationDiaryParseResult parseAIResponse(String content) {
    try {
      String jsonStr = content.trim();
      
      // 尝试提取 JSON 块
      final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1)!;
      }

      // 移除可能的 markdown 标记
      jsonStr = jsonStr.replaceAll(RegExp(r'^```.*'), '');
      jsonStr = jsonStr.replaceAll(RegExp(r'```$'), '');
      jsonStr = jsonStr.trim();

      final Map<String, dynamic> json = _parseJson(jsonStr);
      
      final title = json['title'] ?? '探索日记';
      final moodAfter = json['mood_after'];
      final homecoming = json['homecoming'];
      
      List<ExplorationStop> stops = [];
      if (json['stops'] is List) {
        stops = (json['stops'] as List)
            .map((s) => ExplorationStop.fromJson(s))
            .toList();
      }

      // 构建完整的 Markdown 内容
      final markdownContent = _buildMarkdownContent(title, stops, homecoming);

      return ExplorationDiaryParseResult(
        title: title,
        content: markdownContent,
        stops: stops,
        moodAfter: moodAfter,
        isValid: true,
      );
    } catch (e) {
      return ExplorationDiaryParseResult(
        title: '探索日记',
        content: content,
        stops: [],
        moodAfter: null,
        isValid: false,
        error: e.toString(),
      );
    }
  }

  static Map<String, dynamic> _parseJson(String jsonStr) {
    // 尝试处理常见的 JSON 格式问题
    jsonStr = jsonStr.replaceAll(RegExp(r',(\s*[}\]])' ), r'$1');
    
    // 处理单引号为双引号的问题
    if (!jsonStr.contains('"') && jsonStr.contains("'")) {
      jsonStr = jsonStr.replaceAllMapped(
        RegExp(r"'([^']*)'"),
        (m) => '"${m.group(1)}"',
      );
    }

    return _parseJsonValue(jsonStr);
  }

  static Map<String, dynamic> _parseJsonValue(String jsonStr) {
    jsonStr = jsonStr.trim();
    
    if (jsonStr.startsWith('{') && jsonStr.endsWith('}')) {
      final result = <String, dynamic>{};
      final content = jsonStr.substring(1, jsonStr.length - 1);
      
      int depth = 0;
      int start = 0;
      bool inString = false;
      bool escaped = false;
      
      for (int i = 0; i < content.length; i++) {
        final char = content[i];
        
        if (escaped) {
          escaped = false;
          continue;
        }
        
        if (char == '\\') {
          escaped = true;
          continue;
        }
        
        if (char == '"') {
          inString = !inString;
          continue;
        }
        
        if (!inString) {
          if (char == '{' || char == '[') depth++;
          if (char == '}' || char == ']') depth--;
          
          if (char == ',' && depth == 0) {
            final pair = content.substring(start, i).trim();
            _parseKeyValuePair(pair, result);
            start = i + 1;
          }
        }
      }
      
      final lastPair = content.substring(start).trim();
      if (lastPair.isNotEmpty) {
        _parseKeyValuePair(lastPair, result);
      }
      
      return result;
    }
    
    return {};
  }

  static void _parseKeyValuePair(String pair, Map<String, dynamic> result) {
    final colonIndex = pair.indexOf(':');
    if (colonIndex == -1) return;
    
    String key = pair.substring(0, colonIndex).trim();
    String value = pair.substring(colonIndex + 1).trim();
    
    // 移除 key 的引号
    if (key.startsWith('"') && key.endsWith('"')) {
      key = key.substring(1, key.length - 1);
    }
    
    // 解析 value
    dynamic parsedValue;
    if (value.startsWith('{')) {
      parsedValue = _parseJsonValue(value);
    } else if (value.startsWith('[')) {
      parsedValue = _parseJsonArray(value);
    } else if (value.startsWith('"')) {
      parsedValue = _parseStringValue(value);
    } else if (value == 'true') {
      parsedValue = true;
    } else if (value == 'false') {
      parsedValue = false;
    } else if (value == 'null') {
      parsedValue = null;
    } else if (value.contains('.')) {
      parsedValue = double.tryParse(value) ?? value;
    } else {
      parsedValue = int.tryParse(value) ?? value;
    }
    
    result[key] = parsedValue;
  }

  static String _parseStringValue(String value) {
    if (value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  static List<dynamic> _parseJsonArray(String arrayStr) {
    if (!arrayStr.startsWith('[') || !arrayStr.endsWith(']')) {
      return [];
    }
    
    final content = arrayStr.substring(1, arrayStr.length - 1).trim();
    if (content.isEmpty) return [];
    
    final result = <dynamic>[];
    int depth = 0;
    int start = 0;
    bool inString = false;
    bool escaped = false;
    
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      
      if (escaped) {
        escaped = false;
        continue;
      }
      
      if (char == '\\') {
        escaped = true;
        continue;
      }
      
      if (char == '"') {
        inString = !inString;
        continue;
      }
      
      if (!inString) {
        if (char == '{' || char == '[') depth++;
        if (char == '}' || char == ']') depth--;
        
        if (char == ',' && depth == 0) {
          final item = content.substring(start, i).trim();
          if (item.startsWith('{')) {
            result.add(_parseJsonValue(item));
          } else if (item.startsWith('"')) {
            result.add(_parseStringValue(item));
          }
          start = i + 1;
        }
      }
    }
    
    final lastItem = content.substring(start).trim();
    if (lastItem.isNotEmpty) {
      if (lastItem.startsWith('{')) {
        result.add(_parseJsonValue(lastItem));
      } else if (lastItem.startsWith('"')) {
        result.add(_parseStringValue(lastItem));
      }
    }
    
    return result;
  }

  static String _buildMarkdownContent(
    String title,
    List<ExplorationStop> stops,
    String? homecoming,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('# $title');
    buffer.writeln();
    
    for (final stop in stops) {
      buffer.writeln('## ${_getOrdinal(stop.order)}站：${stop.name}');
      buffer.writeln('- **怎么去的**：${stop.transport}');
      buffer.writeln('- **遇到**：${stop.encounter}');
      buffer.writeln('- **感受**：${stop.feeling}');
      buffer.writeln();
    }
    
    if (homecoming != null) {
      buffer.writeln('## 回家');
      buffer.writeln(homecoming);
    }
    
    return buffer.toString();
  }

  static String _getOrdinal(int n) {
    const ordinals = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    if (n <= 10) return ordinals[n];
    return n.toString();
  }
}

class PetSkillInfo {
  final String name;
  final String description;
  final String icon;

  PetSkillInfo({
    required this.name,
    required this.description,
    this.icon = '',
  });
}

class ExplorationDiaryParseResult {
  final String title;
  final String content;
  final List<ExplorationStop> stops;
  final String? moodAfter;
  final bool isValid;
  final String? error;

  ExplorationDiaryParseResult({
    required this.title,
    required this.content,
    required this.stops,
    this.moodAfter,
    required this.isValid,
    this.error,
  });
}
