/// 探索日记模型
/// 对应数据库表: pet_exploration_diaries
class ExplorationDiary {
  final String id;
  final String petId;
  final String title;
  final String content;
  final List<ExplorationStop> stops;
  final String explorationType;
  final int durationMinutes;
  final String? moodAfter;
  final int intimacyLevelAtExplore;
  final DateTime createdAt;

  ExplorationDiary({
    required this.id,
    required this.petId,
    required this.title,
    required this.content,
    required this.stops,
    required this.explorationType,
    required this.durationMinutes,
    this.moodAfter,
    required this.intimacyLevelAtExplore,
    required this.createdAt,
  });

  factory ExplorationDiary.fromJson(Map<String, dynamic> json) {
    // 解析 stops 字段
    List<ExplorationStop> stops = [];
    final stopsJson = json['stops'];
    if (stopsJson != null) {
      if (stopsJson is List) {
        stops = stopsJson.map((s) => ExplorationStop.fromJson(s)).toList();
      }
    }

    return ExplorationDiary(
      id: json['id'],
      petId: json['pet_id'],
      title: json['title'],
      content: json['content'],
      stops: stops,
      explorationType: json['exploration_type'] ?? 'normal',
      durationMinutes: json['duration_minutes'] ?? 60,
      moodAfter: json['mood_after'],
      intimacyLevelAtExplore: json['intimacy_level_at_explore'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pet_id': petId,
      'title': title,
      'content': content,
      'stops': stops.map((s) => s.toJson()).toList(),
      'exploration_type': explorationType,
      'duration_minutes': durationMinutes,
      'mood_after': moodAfter,
      'intimacy_level_at_explore': intimacyLevelAtExplore,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ExplorationDiary copyWith({
    String? id,
    String? petId,
    String? title,
    String? content,
    List<ExplorationStop>? stops,
    String? explorationType,
    int? durationMinutes,
    String? moodAfter,
    int? intimacyLevelAtExplore,
    DateTime? createdAt,
  }) {
    return ExplorationDiary(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      title: title ?? this.title,
      content: content ?? this.content,
      stops: stops ?? this.stops,
      explorationType: explorationType ?? this.explorationType,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      moodAfter: moodAfter ?? this.moodAfter,
      intimacyLevelAtExplore: intimacyLevelAtExplore ?? this.intimacyLevelAtExplore,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 探索类型常量
  static const String typeNormal = 'normal';
  static const String typeSpecial = 'special';
  static const String typeAuto = 'auto';

  /// 心情常量
  static const List<String> moods = [
    'excited',
    'tired',
    'happy',
    'scared',
    'neutral',
  ];
}

/// 探索地点停留点
class ExplorationStop {
  final int order;
  final String name;
  final String type; // 'real' or 'fictional'
  final String transport;
  final String encounter;
  final String feeling;
  final String? moodChange;

  ExplorationStop({
    required this.order,
    required this.name,
    required this.type,
    required this.transport,
    required this.encounter,
    required this.feeling,
    this.moodChange,
  });

  factory ExplorationStop.fromJson(Map<String, dynamic> json) {
    return ExplorationStop(
      order: json['order'] ?? 1,
      name: json['name'] ?? '',
      type: json['type'] ?? 'real',
      transport: json['transport'] ?? '',
      encounter: json['encounter'] ?? '',
      feeling: json['feeling'] ?? '',
      moodChange: json['mood_change'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'name': name,
      'type': type,
      'transport': transport,
      'encounter': encounter,
      'feeling': feeling,
      'mood_change': moodChange,
    };
  }
}

/// 探索检查结果
class ExplorationCheckResult {
  final bool canExplore;
  final String? reason;
  final Map<String, dynamic>? stats;

  ExplorationCheckResult({
    required this.canExplore,
    this.reason,
    this.stats,
  });

  factory ExplorationCheckResult.success({Map<String, dynamic>? stats}) {
    return ExplorationCheckResult(canExplore: true, stats: stats);
  }

  factory ExplorationCheckResult.failure(String reason) {
    return ExplorationCheckResult(canExplore: false, reason: reason);
  }
}

/// 探索配置模型
class ExplorationConfig {
  final String petType;
  final List<Location> realLocations;
  final List<Location> fictionalLocations;
  final List<Encounter> encounters;

  ExplorationConfig({
    required this.petType,
    required this.realLocations,
    required this.fictionalLocations,
    required this.encounters,
  });
}

/// 地点模型
class Location {
  final String name;
  final String description;
  final String region; // 'urban', 'suburb', 'nature'
  final List<String> suitableTypes;

  Location({
    required this.name,
    required this.description,
    required this.region,
    required this.suitableTypes,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      region: json['region'] ?? 'urban',
      suitableTypes: List<String>.from(json['suitable_types'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'region': region,
      'suitable_types': suitableTypes,
    };
  }
}

/// 遭遇模型
class Encounter {
  final String id;
  final String description;
  final String moodEffect;
  final List<String> petTypes;

  Encounter({
    required this.id,
    required this.description,
    required this.moodEffect,
    required this.petTypes,
  });

  factory Encounter.fromJson(Map<String, dynamic> json) {
    return Encounter(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      moodEffect: json['mood_effect'] ?? 'neutral',
      petTypes: List<String>.from(json['pet_types'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'mood_effect': moodEffect,
      'pet_types': petTypes,
    };
  }
}
