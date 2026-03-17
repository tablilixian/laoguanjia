class PetRelationship {
  final String petId;
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
  final DateTime createdAt;
  final DateTime updatedAt;

  PetRelationship({
    required this.petId,
    required this.trustLevel,
    required this.intimacyLevel,
    required this.totalInteractions,
    required this.feedCount,
    required this.playCount,
    required this.chatCount,
    this.lastInteractionAt,
    required this.joyScore,
    required this.sadnessScore,
    this.firstInteractionAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PetRelationship.fromJson(Map<String, dynamic> json) {
    return PetRelationship(
      petId: json['pet_id'],
      trustLevel: json['trust_level'] ?? 0,
      intimacyLevel: json['intimacy_level'] ?? 0,
      totalInteractions: json['total_interactions'] ?? 0,
      feedCount: json['feed_count'] ?? 0,
      playCount: json['play_count'] ?? 0,
      chatCount: json['chat_count'] ?? 0,
      lastInteractionAt: json['last_interaction_at'] != null
          ? DateTime.parse(json['last_interaction_at'])
          : null,
      joyScore: (json['joy_score'] as num?)?.toDouble() ?? 0,
      sadnessScore: (json['sadness_score'] as num?)?.toDouble() ?? 0,
      firstInteractionAt: json['first_interaction_at'] != null
          ? DateTime.parse(json['first_interaction_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_id': petId,
      'trust_level': trustLevel,
      'intimacy_level': intimacyLevel,
      'total_interactions': totalInteractions,
      'feed_count': feedCount,
      'play_count': playCount,
      'chat_count': chatCount,
      'last_interaction_at': lastInteractionAt?.toIso8601String(),
      'joy_score': joyScore,
      'sadness_score': sadnessScore,
      'first_interaction_at': firstInteractionAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PetRelationship copyWith({
    String? petId,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PetRelationship(
      petId: petId ?? this.petId,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const List<String> intimacyStages = [
    '陌生',
    '认识',
    '熟悉',
    '亲近',
    '亲密',
    '家人',
  ];

  String get intimacyStageName {
    if (intimacyLevel < 0 || intimacyLevel >= intimacyStages.length) {
      return '陌生';
    }
    return intimacyStages[intimacyLevel];
  }

  static int calculateIntimacyLevel(int totalInteractions) {
    if (totalInteractions >= 200) return 5;
    if (totalInteractions >= 100) return 4;
    if (totalInteractions >= 50) return 3;
    if (totalInteractions >= 20) return 2;
    if (totalInteractions >= 5) return 1;
    return 0;
  }
}
