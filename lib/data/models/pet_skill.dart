class PetSkill {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int level;
  final List<String> keywords;
  final bool isVisible;
  final int unlockIntimacy;

  PetSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.level,
    required this.keywords,
    required this.isVisible,
    required this.unlockIntimacy,
  });

  factory PetSkill.fromJson(Map<String, dynamic> json) {
    return PetSkill(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '✨',
      level: json['level'] ?? 1,
      keywords: List<String>.from(json['keywords'] ?? []),
      isVisible: json['is_visible'] ?? true,
      unlockIntimacy: json['unlock_intimacy'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'level': level,
      'keywords': keywords,
      'is_visible': isVisible,
      'unlock_intimacy': unlockIntimacy,
    };
  }

  PetSkill copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    int? level,
    List<String>? keywords,
    bool? isVisible,
    int? unlockIntimacy,
  }) {
    return PetSkill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      level: level ?? this.level,
      keywords: keywords ?? this.keywords,
      isVisible: isVisible ?? this.isVisible,
      unlockIntimacy: unlockIntimacy ?? this.unlockIntimacy,
    );
  }

  static final List<PetSkill> allSkills = [
    PetSkill(
      id: 'emotional',
      name: '情感陪伴',
      description: '善于倾听和安慰，能帮你排解烦恼',
      icon: '💕',
      level: 1,
      keywords: ['心情', '烦恼', '倾诉', '安慰', '难过', '开心', '想你'],
      isVisible: true,
      unlockIntimacy: 0,
    ),
    PetSkill(
      id: 'coding',
      name: '编程助手',
      description: '懂代码会 debug，还能讲解算法',
      icon: '💻',
      level: 1,
      keywords: ['代码', '编程', 'bug', '算法', '开发', '函数', '变量'],
      isVisible: true,
      unlockIntimacy: 0,
    ),
    PetSkill(
      id: 'study',
      name: '学习伙伴',
      description: '陪你学习，解答问题',
      icon: '📚',
      level: 1,
      keywords: ['学习', '考试', '作业', '英语', '数学', '物理', '化学'],
      isVisible: true,
      unlockIntimacy: 0,
    ),
    PetSkill(
      id: 'fitness',
      name: '健身教练',
      description: '制定训练计划，监督你运动',
      icon: '🏋️',
      level: 1,
      keywords: ['锻炼', '健身', '运动', '减肥', '跑步', '瑜伽', '训练'],
      isVisible: true,
      unlockIntimacy: 0,
    ),
    PetSkill(
      id: 'cooking',
      name: '烹饪大师',
      description: '教做菜，分享食谱',
      icon: '🍳',
      level: 1,
      keywords: ['菜谱', '烹饪', '食材', '做饭', '做菜', '好吃'],
      isVisible: true,
      unlockIntimacy: 0,
    ),
    PetSkill(
      id: 'travel',
      name: '旅行攻略',
      description: '帮你规划旅行，提供景点建议',
      icon: '✈️',
      level: 1,
      keywords: ['旅行', '旅游', '景点', '攻略', '酒店', '机票'],
      isVisible: false,
      unlockIntimacy: 2,
    ),
    PetSkill(
      id: 'music',
      name: '音乐伙伴',
      description: '聊音乐，分享好歌',
      icon: '🎵',
      level: 1,
      keywords: ['音乐', '歌曲', '歌手', '乐器', '歌', '听歌'],
      isVisible: false,
      unlockIntimacy: 2,
    ),
    PetSkill(
      id: 'finance',
      name: '投资顾问',
      description: '基础的理财知识',
      icon: '💰',
      level: 1,
      keywords: ['投资', '理财', '股票', '基金', '钱', '赚钱'],
      isVisible: false,
      unlockIntimacy: 3,
    ),
    PetSkill(
      id: 'pet_care',
      name: '养宠专家',
      description: '教你如何养宠物',
      icon: '🐾',
      level: 1,
      keywords: ['宠物', '养猫', '养狗', '洗澡', '喂食'],
      isVisible: false,
      unlockIntimacy: 1,
    ),
    PetSkill(
      id: 'diy',
      name: '手工达人',
      description: '喜欢动手做各种小东西',
      icon: '🧶',
      level: 1,
      keywords: ['手工', 'DIY', '制作', '编织', '折纸'],
      isVisible: false,
      unlockIntimacy: 2,
    ),
  ];

  static List<PetSkill> getSkillsByIntimacy(int intimacyLevel) {
    return allSkills.where((s) => s.unlockIntimacy <= intimacyLevel).toList();
  }

  static List<PetSkill> getVisibleSkills(int intimacyLevel) {
    return allSkills
        .where((s) => s.isVisible || s.unlockIntimacy <= intimacyLevel)
        .toList();
  }

  static PetSkill? detectSkillFromMessage(String message) {
    for (final skill in allSkills) {
      for (final keyword in skill.keywords) {
        if (message.contains(keyword)) {
          return skill;
        }
      }
    }
    return null;
  }
}
