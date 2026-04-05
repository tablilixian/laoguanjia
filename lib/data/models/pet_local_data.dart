/// 宠物本地完整数据模型
///
/// 单 JSON 文件承载宠物所有交互数据，按月存储。
/// 文件路径: `pets/pet_{petId}_YYYY-MM.json`
class PetLocalData {
  final String version;
  final String petId;
  final String month;
  final DateTime generatedAt;
  final PetState state;
  final PetPersonalityData personality;
  final PetRelationshipData relationship;
  final List<PetInteractionData> interactions;
  final List<PetMemoryData> memories;
  final List<PetConversationData> conversations;
  final List<PetExplorationData> explorations;

  const PetLocalData({
    this.version = '2.0',
    required this.petId,
    required this.month,
    required this.generatedAt,
    required this.state,
    required this.personality,
    required this.relationship,
    this.interactions = const [],
    this.memories = const [],
    this.conversations = const [],
    this.explorations = const [],
  });

  /// 创建空的本地数据 (新宠物初始化用)
  factory PetLocalData.empty(String petId) {
    final now = DateTime.now();
    return PetLocalData(
      petId: petId,
      month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      generatedAt: now,
      state: PetState.initial(),
      personality: PetPersonalityData.initial(),
      relationship: PetRelationshipData.initial(),
    );
  }

  factory PetLocalData.fromJson(Map<String, dynamic> json) {
    return PetLocalData(
      version: json['version'] as String? ?? '2.0',
      petId: json['petId'] as String,
      month: json['month'] as String,
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
      state: PetState.fromJson(Map<String, dynamic>.from(json['state'] as Map)),
      personality: PetPersonalityData.fromJson(
        Map<String, dynamic>.from(json['personality'] as Map),
      ),
      relationship: PetRelationshipData.fromJson(
        Map<String, dynamic>.from(json['relationship'] as Map),
      ),
      interactions: (json['interactions'] as List<dynamic>?)
              ?.map((e) => PetInteractionData.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      memories: (json['memories'] as List<dynamic>?)
              ?.map((e) => PetMemoryData.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      conversations: (json['conversations'] as List<dynamic>?)
              ?.map((e) =>
                  PetConversationData.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      explorations: (json['explorations'] as List<dynamic>?)
              ?.map((e) =>
                  PetExplorationData.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'petId': petId,
      'month': month,
      'generatedAt': generatedAt.toIso8601String(),
      'state': state.toJson(),
      'personality': personality.toJson(),
      'relationship': relationship.toJson(),
      'interactions': interactions.map((e) => e.toJson()).toList(),
      'memories': memories.map((e) => e.toJson()).toList(),
      'conversations': conversations.map((e) => e.toJson()).toList(),
      'explorations': explorations.map((e) => e.toJson()).toList(),
    };
  }

  PetLocalData copyWith({
    String? version,
    String? petId,
    String? month,
    DateTime? generatedAt,
    PetState? state,
    PetPersonalityData? personality,
    PetRelationshipData? relationship,
    List<PetInteractionData>? interactions,
    List<PetMemoryData>? memories,
    List<PetConversationData>? conversations,
    List<PetExplorationData>? explorations,
  }) {
    return PetLocalData(
      version: version ?? this.version,
      petId: petId ?? this.petId,
      month: month ?? this.month,
      generatedAt: generatedAt ?? this.generatedAt,
      state: state ?? this.state,
      personality: personality ?? this.personality,
      relationship: relationship ?? this.relationship,
      interactions: interactions ?? this.interactions,
      memories: memories ?? this.memories,
      conversations: conversations ?? this.conversations,
      explorations: explorations ?? this.explorations,
    );
  }
}

/// 宠物状态
class PetState {
  final int hunger;
  final int happiness;
  final int cleanliness;
  final int health;
  final int level;
  final int experience;
  final String currentMood;
  final String? moodText;
  final List<PetSkillData> skills;
  final int explorationCount;
  final int todayExplorationCount;
  final DateTime? lastExploredAt;
  final DateTime? lastFedAt;
  final DateTime? lastPlayedAt;
  final DateTime? lastBathedAt;

  const PetState({
    this.hunger = 50,
    this.happiness = 50,
    this.cleanliness = 50,
    this.health = 100,
    this.level = 1,
    this.experience = 0,
    this.currentMood = 'neutral',
    this.moodText,
    this.skills = const [],
    this.explorationCount = 0,
    this.todayExplorationCount = 0,
    this.lastExploredAt,
    this.lastFedAt,
    this.lastPlayedAt,
    this.lastBathedAt,
  });

  factory PetState.initial() {
    return const PetState();
  }

  factory PetState.fromJson(Map<String, dynamic> json) {
    return PetState(
      hunger: json['hunger'] as int? ?? 50,
      happiness: json['happiness'] as int? ?? 50,
      cleanliness: json['cleanliness'] as int? ?? 50,
      health: json['health'] as int? ?? 100,
      level: json['level'] as int? ?? 1,
      experience: json['experience'] as int? ?? 0,
      currentMood: json['currentMood'] as String? ?? 'neutral',
      moodText: json['moodText'] as String?,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => PetSkillData.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      explorationCount: json['explorationCount'] as int? ?? 0,
      todayExplorationCount: json['todayExplorationCount'] as int? ?? 0,
      lastExploredAt: json['lastExploredAt'] != null
          ? DateTime.parse(json['lastExploredAt'] as String)
          : null,
      lastFedAt: json['lastFedAt'] != null
          ? DateTime.parse(json['lastFedAt'] as String)
          : null,
      lastPlayedAt: json['lastPlayedAt'] != null
          ? DateTime.parse(json['lastPlayedAt'] as String)
          : null,
      lastBathedAt: json['lastBathedAt'] != null
          ? DateTime.parse(json['lastBathedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hunger': hunger,
      'happiness': happiness,
      'cleanliness': cleanliness,
      'health': health,
      'level': level,
      'experience': experience,
      'currentMood': currentMood,
      if (moodText != null) 'moodText': moodText,
      'skills': skills.map((e) => e.toJson()).toList(),
      'explorationCount': explorationCount,
      'todayExplorationCount': todayExplorationCount,
      if (lastExploredAt != null)
        'lastExploredAt': lastExploredAt!.toIso8601String(),
      if (lastFedAt != null) 'lastFedAt': lastFedAt!.toIso8601String(),
      if (lastPlayedAt != null) 'lastPlayedAt': lastPlayedAt!.toIso8601String(),
      if (lastBathedAt != null) 'lastBathedAt': lastBathedAt!.toIso8601String(),
    };
  }

  PetState copyWith({
    int? hunger,
    int? happiness,
    int? cleanliness,
    int? health,
    int? level,
    int? experience,
    String? currentMood,
    String? moodText,
    List<PetSkillData>? skills,
    int? explorationCount,
    int? todayExplorationCount,
    DateTime? lastExploredAt,
    DateTime? lastFedAt,
    DateTime? lastPlayedAt,
    DateTime? lastBathedAt,
  }) {
    return PetState(
      hunger: hunger ?? this.hunger,
      happiness: happiness ?? this.happiness,
      cleanliness: cleanliness ?? this.cleanliness,
      health: health ?? this.health,
      level: level ?? this.level,
      experience: experience ?? this.experience,
      currentMood: currentMood ?? this.currentMood,
      moodText: moodText ?? this.moodText,
      skills: skills ?? this.skills,
      explorationCount: explorationCount ?? this.explorationCount,
      todayExplorationCount:
          todayExplorationCount ?? this.todayExplorationCount,
      lastExploredAt: lastExploredAt ?? this.lastExploredAt,
      lastFedAt: lastFedAt ?? this.lastFedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      lastBathedAt: lastBathedAt ?? this.lastBathedAt,
    );
  }

  /// 应用互动效果到状态
  PetState applyInteraction(String type) {
    final effects = _interactionEffects[type];
    if (effects == null) return this;

    int newHunger = (hunger + (effects['hunger'] ?? 0)).clamp(0, 100);
    int newHappiness =
        (happiness + (effects['happiness'] ?? 0)).clamp(0, 100);
    int newCleanliness =
        (cleanliness + (effects['cleanliness'] ?? 0)).clamp(0, 100);
    int newExperience = experience + (effects['experience'] ?? 0);
    int newLevel = level;

    while (newExperience >= newLevel * 100) {
      newExperience -= newLevel * 100;
      newLevel++;
    }

    final now = DateTime.now();
    return copyWith(
      hunger: newHunger,
      happiness: newHappiness,
      cleanliness: newCleanliness,
      experience: newExperience,
      level: newLevel,
      lastFedAt: type == 'feed' ? now : lastFedAt,
      lastPlayedAt: type == 'play' ? now : lastPlayedAt,
      lastBathedAt: type == 'bath' ? now : lastBathedAt,
    );
  }

  static const Map<String, Map<String, int>> _interactionEffects = {
    'feed': {'hunger': 20, 'happiness': 5, 'experience': 5},
    'play': {'happiness': 20, 'hunger': -5, 'experience': 10},
    'bath': {'cleanliness': 30, 'happiness': -5, 'experience': 5},
    'train': {'happiness': 10, 'hunger': -10, 'experience': 15},
  };
}

/// 宠物技能
class PetSkillData {
  final String id;
  final String name;
  final bool unlocked;
  final int level;

  const PetSkillData({
    required this.id,
    required this.name,
    this.unlocked = false,
    this.level = 0,
  });

  factory PetSkillData.fromJson(Map<String, dynamic> json) {
    return PetSkillData(
      id: json['id'] as String,
      name: json['name'] as String,
      unlocked: json['unlocked'] as bool? ?? false,
      level: json['level'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unlocked': unlocked,
        'level': level,
      };
}

/// 宠物人格 (五维模型)
class PetPersonalityData {
  final double openness;
  final double agreeableness;
  final double extraversion;
  final double conscientiousness;
  final double neuroticism;
  final List<String> traits;
  final List<String> habits;
  final List<String> fears;
  final String speechStyle;
  final String? originDescription;

  const PetPersonalityData({
    this.openness = 0.5,
    this.agreeableness = 0.5,
    this.extraversion = 0.5,
    this.conscientiousness = 0.5,
    this.neuroticism = 0.5,
    this.traits = const [],
    this.habits = const [],
    this.fears = const [],
    this.speechStyle = 'normal',
    this.originDescription,
  });

  factory PetPersonalityData.initial() {
    return const PetPersonalityData();
  }

  factory PetPersonalityData.fromJson(Map<String, dynamic> json) {
    return PetPersonalityData(
      openness: (json['openness'] as num?)?.toDouble() ?? 0.5,
      agreeableness:
          (json['agreeableness'] as num?)?.toDouble() ?? 0.5,
      extraversion: (json['extraversion'] as num?)?.toDouble() ?? 0.5,
      conscientiousness:
          (json['conscientiousness'] as num?)?.toDouble() ?? 0.5,
      neuroticism: (json['neuroticism'] as num?)?.toDouble() ?? 0.5,
      traits: (json['traits'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      habits: (json['habits'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      fears: (json['fears'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      speechStyle: json['speechStyle'] as String? ?? 'normal',
      originDescription: json['originDescription'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'openness': openness,
      'agreeableness': agreeableness,
      'extraversion': extraversion,
      'conscientiousness': conscientiousness,
      'neuroticism': neuroticism,
      'traits': traits,
      'habits': habits,
      'fears': fears,
      'speechStyle': speechStyle,
      if (originDescription != null)
        'originDescription': originDescription,
    };
  }
}

/// 宠物关系
class PetRelationshipData {
  final int trustLevel;
  final int intimacyLevel;
  final int totalInteractions;
  final int feedCount;
  final int playCount;
  final int chatCount;
  final DateTime? lastInteractionAt;
  final double joyScore;
  final double sadnessScore;
  final DateTime? firstInteractionAt;

  const PetRelationshipData({
    this.trustLevel = 0,
    this.intimacyLevel = 0,
    this.totalInteractions = 0,
    this.feedCount = 0,
    this.playCount = 0,
    this.chatCount = 0,
    this.lastInteractionAt,
    this.joyScore = 0,
    this.sadnessScore = 0,
    this.firstInteractionAt,
  });

  factory PetRelationshipData.initial() {
    return const PetRelationshipData();
  }

  factory PetRelationshipData.fromJson(Map<String, dynamic> json) {
    return PetRelationshipData(
      trustLevel: json['trustLevel'] as int? ?? 0,
      intimacyLevel: json['intimacyLevel'] as int? ?? 0,
      totalInteractions: json['totalInteractions'] as int? ?? 0,
      feedCount: json['feedCount'] as int? ?? 0,
      playCount: json['playCount'] as int? ?? 0,
      chatCount: json['chatCount'] as int? ?? 0,
      lastInteractionAt: json['lastInteractionAt'] != null
          ? DateTime.parse(json['lastInteractionAt'] as String)
          : null,
      joyScore: (json['joyScore'] as num?)?.toDouble() ?? 0,
      sadnessScore: (json['sadnessScore'] as num?)?.toDouble() ?? 0,
      firstInteractionAt: json['firstInteractionAt'] != null
          ? DateTime.parse(json['firstInteractionAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trustLevel': trustLevel,
      'intimacyLevel': intimacyLevel,
      'totalInteractions': totalInteractions,
      'feedCount': feedCount,
      'playCount': playCount,
      'chatCount': chatCount,
      if (lastInteractionAt != null)
        'lastInteractionAt': lastInteractionAt!.toIso8601String(),
      'joyScore': joyScore,
      'sadnessScore': sadnessScore,
      if (firstInteractionAt != null)
        'firstInteractionAt': firstInteractionAt!.toIso8601String(),
    };
  }

  /// 记录一次互动
  PetRelationshipData recordInteraction(String type) {
    final now = DateTime.now();
    int newTotal = totalInteractions + 1;
    int newFeed = feedCount + (type == 'feed' ? 1 : 0);
    int newPlay = playCount + (type == 'play' ? 1 : 0);
    int newChat = chatCount + (type == 'chat' ? 1 : 0);

    int newIntimacy = _calculateIntimacyLevel(newTotal);
    double newTrust =
        (newFeed * 2 + newPlay * 2 + newChat * 3) * 0.5 + (trustLevel * 0.5);
    int newTrustLevel = newTrust.clamp(0, 100).round();

    return copyWith(
      totalInteractions: newTotal,
      feedCount: newFeed,
      playCount: newPlay,
      chatCount: newChat,
      intimacyLevel: newIntimacy,
      trustLevel: newTrustLevel,
      lastInteractionAt: now,
      firstInteractionAt: firstInteractionAt ?? now,
    );
  }

  PetRelationshipData copyWith({
    int? trustLevel,
    int? intimacyLevel,
    int? totalInteractions,
    int? feedCount,
    int? playCount,
    int? chatCount,
    DateTime? lastInteractionAt,
    double? joyScore,
    double? sadnessScore,
    DateTime? firstInteractionAt,
  }) {
    return PetRelationshipData(
      trustLevel: trustLevel ?? this.trustLevel,
      intimacyLevel: intimacyLevel ?? this.intimacyLevel,
      totalInteractions: totalInteractions ?? this.totalInteractions,
      feedCount: feedCount ?? this.feedCount,
      playCount: playCount ?? this.playCount,
      chatCount: chatCount ?? this.chatCount,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
      joyScore: joyScore ?? this.joyScore,
      sadnessScore: sadnessScore ?? this.sadnessScore,
      firstInteractionAt: firstInteractionAt ?? this.firstInteractionAt,
    );
  }

  static int _calculateIntimacyLevel(int totalInteractions) {
    if (totalInteractions < 10) return 1;
    if (totalInteractions < 30) return 2;
    if (totalInteractions < 60) return 3;
    if (totalInteractions < 100) return 4;
    return 5;
  }
}

/// 互动记录
class PetInteractionData {
  final String id;
  final String type;
  final int value;
  final DateTime createdAt;

  const PetInteractionData({
    required this.id,
    required this.type,
    required this.value,
    required this.createdAt,
  });

  factory PetInteractionData.fromJson(Map<String, dynamic> json) {
    return PetInteractionData(
      id: json['id'] as String,
      type: json['type'] as String,
      value: json['value'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'value': value,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// 记忆
class PetMemoryData {
  final String id;
  final String memoryType;
  final String title;
  final String description;
  final String emotion;
  final int importance;
  final DateTime occurredAt;

  const PetMemoryData({
    required this.id,
    required this.memoryType,
    required this.title,
    required this.description,
    required this.emotion,
    required this.importance,
    required this.occurredAt,
  });

  factory PetMemoryData.fromJson(Map<String, dynamic> json) {
    return PetMemoryData(
      id: json['id'] as String,
      memoryType: json['memoryType'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      emotion: json['emotion'] as String,
      importance: json['importance'] as int,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'memoryType': memoryType,
        'title': title,
        'description': description,
        'emotion': emotion,
        'importance': importance,
        'occurredAt': occurredAt.toIso8601String(),
      };
}

/// 对话记录
class PetConversationData {
  final String role;
  final String content;
  final DateTime createdAt;

  const PetConversationData({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory PetConversationData.fromJson(Map<String, dynamic> json) {
    return PetConversationData(
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// 探索/巡查日记
class PetExplorationData {
  final String id;
  final String title;
  final String content;
  final String explorationType;
  final int durationMinutes;
  final String moodAfter;
  final List<Map<String, String>> findings;
  final DateTime createdAt;

  const PetExplorationData({
    required this.id,
    required this.title,
    required this.content,
    required this.explorationType,
    required this.durationMinutes,
    required this.moodAfter,
    this.findings = const [],
    required this.createdAt,
  });

  factory PetExplorationData.fromJson(Map<String, dynamic> json) {
    return PetExplorationData(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      explorationType: json['explorationType'] as String,
      durationMinutes: json['durationMinutes'] as int,
      moodAfter: json['moodAfter'] as String,
      findings: (json['findings'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'explorationType': explorationType,
        'durationMinutes': durationMinutes,
        'moodAfter': moodAfter,
        'findings': findings,
        'createdAt': createdAt.toIso8601String(),
      };
}
