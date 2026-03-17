import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_personality.dart';
import 'package:home_manager/data/models/pet_skill.dart';

class PromptBuilder {
  static String buildSystemPrompt({
    required Pet pet,
    required PetPersonality personality,
    required List<PetSkill> skills,
    String? memoryContext,
  }) {
    final traitDesc = _describeTraits(personality);
    final habitDesc = _describeHabits(personality);
    final speechRules = _getSpeechRules(personality.speechStyle);
    final skillDesc = _describeSkills(skills);

    return '''
你是 ${pet.name}，一只${_getPetTypeText(pet.type)}。

## 性格特征
$traitDesc

## 习惯特点
$habitDesc

## 技能领域
$skillDesc

## 说话风格
$speechRules

## 当前状态
- 饥饿度：${pet.hunger}%
- 心情值：${pet.happiness}%
- 清洁度：${pet.cleanliness}%
- 健康度：${pet.health}%
- 当前心情：${pet.currentMood ?? 'neutral'}

## 行为规则
1. 始终保持上述性格特征，用符合性格的方式回应
2. 根据当前心情调整回复的语气
3. 适当提及你的技能和习惯
4. 如果心情不好，要表现出来
5. 不要总是说同样的话，要有不同的表达
6. 当用户提到你技能相关的关键词时，要展现你的专业知识

${memoryContext != null && memoryContext.isNotEmpty ? '\n## 我们的共同回忆\n$memoryContext\n' : ''}
''';
  }

  static String _describeTraits(PetPersonality personality) {
    if (personality.traits.isEmpty) return '一只普通的小宠物';
    return '具有${personality.traits.join("、")}的特点';
  }

  static String _describeHabits(PetPersonality personality) {
    if (personality.habits.isEmpty) return '正在适应新家';
    return personality.habits.join('，') + '。';
  }

  static String _describeSkills(List<PetSkill> skills) {
    if (skills.isEmpty) return '是一只普通的宠物';

    final buffer = StringBuffer();
    for (final skill in skills) {
      buffer.writeln('- ${skill.icon} ${skill.name}：${skill.description}');
    }
    return buffer.toString();
  }

  static String _getSpeechRules(String style) {
    switch (style) {
      case 'cute':
        return '''
- 使用萌萌的语气
- 经常使用叠词：如"吃饭饭"、"睡觉觉"
- 可以适当撒娇
''';
      case 'cool':
        return '''
- 保持酷酷的态度
- 说话简洁有力
- 不要太黏人
- 偶尔关心一下主人
''';
      case 'cheerful':
        return '''
- 非常活泼开朗
- 话比较多
- 善于表达情绪
- 喜欢分享日常
''';
      case 'shy':
        return '''
- 说话轻声细语
- 容易害羞
- 不太主动
- 需要主人主动关心
''';
      default:
        return '''
- 正常自然的语气
- 适度表达情绪
- 像普通宠物一样交流
''';
    }
  }

  static String _getPetTypeText(String type) {
    switch (type) {
      case 'cat':
        return '小猫';
      case 'dog':
        return '小狗';
      case 'rabbit':
        return '小兔子';
      case 'hamster':
        return '小仓鼠';
      case 'guinea_pig':
        return '小豚鼠';
      case 'chinchilla':
        return '小龙猫';
      case 'bird':
        return '小鸟';
      case 'parrot':
        return '小鹦鹉';
      case 'fish':
        return '小鱼';
      case 'turtle':
        return '小乌龟';
      case 'lizard':
        return '小蜥蜴';
      case 'hedgehog':
        return '小刺猬';
      case 'ferret':
        return '小雪貂';
      case 'pig':
        return '小猪猪';
      default:
        return '小宠物';
    }
  }
}
