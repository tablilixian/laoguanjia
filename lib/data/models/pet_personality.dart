class PetPersonality {
  final String id;
  final String petId;
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
  final DateTime createdAt;
  final DateTime updatedAt;

  PetPersonality({
    required this.id,
    required this.petId,
    required this.openness,
    required this.agreeableness,
    required this.extraversion,
    required this.conscientiousness,
    required this.neuroticism,
    required this.traits,
    required this.habits,
    required this.fears,
    required this.speechStyle,
    this.originDescription,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PetPersonality.fromJson(Map<String, dynamic> json) {
    return PetPersonality(
      id: json['id'],
      petId: json['pet_id'],
      openness: (json['openness'] as num).toDouble(),
      agreeableness: (json['agreeableness'] as num).toDouble(),
      extraversion: (json['extraversion'] as num).toDouble(),
      conscientiousness: (json['conscientiousness'] as num).toDouble(),
      neuroticism: (json['neuroticism'] as num).toDouble(),
      traits: List<String>.from(json['traits'] ?? []),
      habits: List<String>.from(json['habits'] ?? []),
      fears: List<String>.from(json['fears'] ?? []),
      speechStyle: json['speech_style'] ?? 'normal',
      originDescription: json['origin_description'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pet_id': petId,
      'openness': openness,
      'agreeableness': agreeableness,
      'extraversion': extraversion,
      'conscientiousness': conscientiousness,
      'neuroticism': neuroticism,
      'traits': traits,
      'habits': habits,
      'fears': fears,
      'speech_style': speechStyle,
      'origin_description': originDescription,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PetPersonality copyWith({
    String? id,
    String? petId,
    double? openness,
    double? agreeableness,
    double? extraversion,
    double? conscientiousness,
    double? neuroticism,
    List<String>? traits,
    List<String>? habits,
    List<String>? fears,
    String? speechStyle,
    String? originDescription,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PetPersonality(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      openness: openness ?? this.openness,
      agreeableness: agreeableness ?? this.agreeableness,
      extraversion: extraversion ?? this.extraversion,
      conscientiousness: conscientiousness ?? this.conscientiousness,
      neuroticism: neuroticism ?? this.neuroticism,
      traits: traits ?? this.traits,
      habits: habits ?? this.habits,
      fears: fears ?? this.fears,
      speechStyle: speechStyle ?? this.speechStyle,
      originDescription: originDescription ?? this.originDescription,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
