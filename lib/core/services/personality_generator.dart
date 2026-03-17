import 'dart:math';
import 'package:home_manager/data/models/pet_personality.dart';

class PersonalityGenerator {
  static final Random _random = Random();

  static PetPersonality generate({
    required String petId,
    required String petType,
    required String name,
    String? breed,
  }) {
    final baseTraits = _getBaseTraits(petType);
    final baseHabits = _getBaseHabits(petType);
    final baseFears = _getBaseFears(petType);

    final openness = _randomInRange(0.4, 0.8);
    final agreeableness = _randomInRange(0.5, 0.9);
    final extraversion = _randomInRange(0.3, 0.8);
    final conscientiousness = _randomInRange(0.3, 0.7);
    final neuroticism = _randomInRange(0.2, 0.6);

    final traits = _randomSelect(baseTraits, 2, 4);
    final habits = _randomSelect(baseHabits, 1, 3);
    final fears = _randomSelect(baseFears, 0, 2);

    final speechStyle = _randomSpeechStyle();
    final originDescription = _generateOriginDescription(
      petType,
      name,
      traits,
      habits,
    );

    final now = DateTime.now();
    return PetPersonality(
      id: '',
      petId: petId,
      openness: openness,
      agreeableness: agreeableness,
      extraversion: extraversion,
      conscientiousness: conscientiousness,
      neuroticism: neuroticism,
      traits: traits,
      habits: habits,
      fears: fears,
      speechStyle: speechStyle,
      originDescription: originDescription,
      createdAt: now,
      updatedAt: now,
    );
  }

  static double _randomInRange(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  static List<String> _randomSelect(List<String> source, int min, int max) {
    final count = min + _random.nextInt(max - min + 1);
    final shuffled = List<String>.from(source)..shuffle(_random);
    return shuffled.take(count).toList();
  }

  static List<String> _getBaseTraits(String petType) {
    switch (petType) {
      case 'cat':
        return ['黏人', '高冷', '好奇', '傲娇', '慵懒', '敏捷', '胆小', '贪吃', '爱干净', '记仇'];
      case 'dog':
        return ['忠诚', '活泼', '贪吃', '调皮', '友善', '护主', '好奇', '黏人', '拆家', '兴奋'];
      case 'rabbit':
        return ['胆小', '害羞', '温顺', '蹦跳', '好奇', '警觉', '贪吃', '爱干净', '紧张', '萌'];
      case 'hamster':
        return ['胆小', '活泼', '贪吃', '爱囤粮', '夜间活跃', '好奇', '温顺', '萌'];
      case 'guinea_pig':
        return ['温顺', '胆小', '贪吃', '友好', '爱叫', '萌'];
      case 'chinchilla':
        return ['温顺', '胆小', '爱干净', '活泼', '好奇', '萌'];
      case 'bird':
        return ['活泼', '话痨', '聪明', '好奇', '粘人', '记仇'];
      case 'parrot':
        return ['聪明', '话痨', '粘人', '调皮', '好奇', '模仿'];
      case 'fish':
        return ['安静', '优雅', '悠闲', '好奇', '记忆力好'];
      case 'turtle':
        return ['温顺', '长寿', '慢悠悠', '爱晒太阳', '胆小'];
      case 'lizard':
        return ['酷', '安静', '独特', '爱晒太阳', '捕食'];
      case 'hedgehog':
        return ['胆小', '害羞', '可爱', '夜间活跃', '贪吃'];
      case 'ferret':
        return ['好奇', '活泼', '调皮', '爱玩', '聪明'];
      case 'pig':
        return ['聪明', '贪吃', '爱干净', '粘人', '温顺'];
      default:
        return ['好奇', '友好', '贪吃', '活泼', '安静'];
    }
  }

  static List<String> _getBaseHabits(String petType) {
    switch (petType) {
      case 'cat':
        return [
          '喜欢晒太阳',
          '讨厌洗澡',
          '白天睡觉晚上活跃',
          '听到罐头声就兴奋',
          '喜欢纸箱',
          '爱抓沙发',
          '喜欢高处',
          '埋屎很认真',
        ];
      case 'dog':
        return [
          '喜欢出门遛弯',
          '见到主人激动',
          '喜欢翻垃圾桶',
          '爱玩球',
          '喜欢被人抚摸',
          '听到门铃会叫',
          '喜欢摇尾巴',
        ];
      case 'rabbit':
        return ['喜欢胡萝卜', '喜欢跳来跳去', '受到惊吓会躲起来', '喜欢钻洞', '爱啃东西'];
      case 'hamster':
        return ['喜欢跑轮子', '喜欢囤粮食', '白天睡觉晚上玩', '喜欢钻木屑'];
      case 'guinea_pig':
        return ['喜欢多吃', '爱叫', '喜欢群居', '需要同伴'];
      case 'chinchilla':
        return ['喜欢沙浴', '怕热', '夜间活跃', '喜欢跳来跳去'];
      case 'bird':
        return ['喜欢唱歌', '喜欢照镜子', '喜欢站在肩膀上', '喜欢清脆的声音'];
      case 'parrot':
        return ['喜欢学说话', '爱啃东西', '喜欢和人互动', '需要玩具'];
      case 'fish':
        return ['喜欢在水里游', '对食物敏感', '喜欢灯光'];
      case 'turtle':
        return ['喜欢晒背', '慢慢爬', '需要晒台', '爱干净'];
      case 'lizard':
        return ['喜欢晒太阳', '需要加热灯', '爱捕食昆虫', '安静'];
      case 'hedgehog':
        return ['夜间活动', '爱钻洞', '需要跑轮', '怕噪音'];
      case 'ferret':
        return ['喜欢钻管子', '爱玩闹', '需要大空间活动', '好奇心强'];
      case 'pig':
        return ['爱干净', '会定点上厕所', '喜欢被抚摸', '贪吃'];
      default:
        return ['喜欢好吃的', '喜欢被抚摸'];
    }
  }

  static List<String> _getBaseFears(String petType) {
    switch (petType) {
      case 'cat':
        return ['打雷', '洗澡', '陌生人', '吹风机', '搬家'];
      case 'dog':
        return ['打雷', '烟花', '陌生人', '洗澡', '独自在家'];
      case 'rabbit':
        return ['大声响', '陌生人', '洗澡', '被追逐'];
      case 'hamster':
        return ['大声响', '强光', '猫'];
      case 'guinea_pig':
        return ['大声响', '突然的移动', '孤独'];
      case 'chinchilla':
        return ['潮湿', '高温', '强光'];
      case 'bird':
        return ['猫', '陌生人', '突然的声响'];
      case 'parrot':
        return ['孤独', '冷', '限制自由'];
      case 'fish':
        return ['水质变化', '大鱼'];
      case 'turtle':
        return ['温差大', '脏水'];
      case 'lizard':
        return ['低温', ' Handling不当'];
      case 'hedgehog':
        return ['噪音', '突然的接触'];
      case 'ferret':
        return ['被困', '无聊'];
      case 'pig':
        return ['脏乱', '孤独'];
      default:
        return [];
    }
  }

  static String _randomSpeechStyle() {
    final styles = ['cute', 'cool', 'cheerful', 'shy', 'normal'];
    return styles[_random.nextInt(styles.length)];
  }

  static String _generateOriginDescription(
    String petType,
    String name,
    List<String> traits,
    List<String> habits,
  ) {
    final typeName = _getPetTypeName(petType);
    return '一只名为 $name 的$typeName，具有${traits.join("、")}的特点，${habits.isNotEmpty ? habits.first : "正在适应新家"}。';
  }

  static String _getPetTypeName(String petType) {
    switch (petType) {
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
