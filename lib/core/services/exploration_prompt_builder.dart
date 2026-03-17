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
请以第一人称写一篇你外出探索世界的日记。用优美的中文文字讲述你的冒险故事。

### 要求
1. 包含 **$stops 个地点** 的冒险故事
2. 每个地点用生动的语言描述：
   - 地点名称（可以是中国或世界的真实地名，也可以是虚构的奇妙地方）
   - 你是怎么到达这个地方的
   - 你遇到了什么有趣的事情
   - 你的感受和想法
3. **必须体现你的性格**：
   - 性格特点要在故事中自然表现出来
   - 习惯会影响你的选择和行为
   - 遇到害怕的事物时要表现出害怕
4. **适当展现你的技能**（如果有）
5. **语言风格要符合你的说话风格**，用你特有的语气
6. **故事要有起伏**：
   - 有开心的事情
   - 有困难或挫折
   - 有惊喜或意外
   - 有疲惫想回家的时候
7. **最后要表达**：
   - 很想念主人
   - 期待回家和主人分享

### 重要：输出格式
请直接输出 Markdown 格式的日记，不要输出任何 JSON 或代码块标记。格式示例：

# 球球的探索日记

## 第一站：社区小花园
- **怎么去的**：早上趁主人不注意，我从门缝偷偷钻了出去，一路上摇着尾巴小跑
- **遇到**：一群在花丛中采蜜的蜜蜂，还有一只叫"小灰"的流浪猫
- **感受**：春天的花真香呀！但是蜜蜂有点可怕，我喵了一声就跑开了

## 第二站：宠物公园
...

## 回家
夕阳西下，我该回家了。今天遇到了好多新朋友，学到了新东西。最想的是主人，不知道他有没有担心我。回到家我要蹭蹭主人的腿，告诉他我今天的故事。

记住：你就是 $petName，一直可爱的小${_getPetTypeText(petType)}，用自己的语气来讲述这个故事！
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
      String text = content.trim();
      
      // 移除可能的代码块标记
      text = text.replaceAll(RegExp(r'^```.*'), '');
      text = text.replaceAll(RegExp(r'```$'), '');
      text = text.trim();
      
      // 从 Markdown 中提取标题
      String title = '探索日记';
      final titleMatch = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(text);
      if (titleMatch != null) {
        title = titleMatch.group(1)!.trim();
      }
      
      // 从 Markdown 中提取各地点
      List<ExplorationStop> stops = [];
      final stopMatches = RegExp(
        r'##\s+第[一二三四五六七八九十\d]+站[：:]\s*(.+?)(?=\n##|\n$|$)',
        multiLine: true,
      ).allMatches(text);
      
      int order = 1;
      for (final match in stopMatches) {
        final stopText = match.group(1) ?? '';
        
        // 提取地点名称
        String name = stopText.trim();
        
        // 提取怎么去的
        String transport = '';
        final transportMatch = RegExp(r'\*\*怎么去的[：:]\*\*?\s*(.+?)(?=\n|\*\*|$)').firstMatch(stopText);
        if (transportMatch != null) {
          transport = transportMatch.group(1)!.trim();
        }
        
        // 提取遇到
        String encounter = '';
        final encounterMatch = RegExp(r'\*\*遇到[：:]\*\*?\s*(.+?)(?=\n|\*\*|$)').firstMatch(stopText);
        if (encounterMatch != null) {
          encounter = encounterMatch.group(1)!.trim();
        }
        
        // 提取感受
        String feeling = '';
        final feelingMatch = RegExp(r'\*\*感受[：:]\*\*?\s*(.+?)(?=\n|\*\*|$)').firstMatch(stopText);
        if (feelingMatch != null) {
          feeling = feelingMatch.group(1)!.trim();
        }
        
        if (name.isNotEmpty) {
          stops.add(ExplorationStop(
            order: order++,
            name: name,
            type: 'real',
            transport: transport,
            encounter: encounter,
            feeling: feeling,
            moodChange: _estimateMoodFromContent(feeling),
          ));
        }
      }
      
      // 提取回家的内容
      String? homecoming;
      final homecomingMatch = RegExp(
        r'##\s*回家[：:]?\s*\n*(.+?)(?=\n##|\n$|$)',
        multiLine: true,
      ).firstMatch(text);
      if (homecomingMatch != null) {
        homecoming = homecomingMatch.group(1)!.trim();
      }
      
      // 估计心情
      String? moodAfter = _estimateMoodFromContent(text);
      
      return ExplorationDiaryParseResult(
        title: title,
        content: text, // 直接使用 AI 返回的原文
        stops: stops,
        moodAfter: moodAfter,
        isValid: true,
      );
    } catch (e) {
      // 如果解析失败，直接返回原文
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
  
  static String? _estimateMoodFromContent(String content) {
    final lowerContent = content.toLowerCase();
    if (lowerContent.contains('开心') || lowerContent.contains('高兴') || lowerContent.contains('快乐')) {
      return 'happy';
    }
    if (lowerContent.contains('兴奋') || lowerContent.contains('激动')) {
      return 'excited';
    }
    if (lowerContent.contains('累') || lowerContent.contains('疲惫') || lowerContent.contains('困')) {
      return 'tired';
    }
    if (lowerContent.contains('害怕') || lowerContent.contains('怕') || lowerContent.contains('惊恐')) {
      return 'scared';
    }
    return 'neutral';
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
