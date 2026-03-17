import 'package:supabase/supabase.dart';
import 'package:home_manager/data/models/pet_skill.dart';

class Pet {
  final String id;
  final String householdId;
  final String? ownerId;
  final String name;
  final String type;
  final String? breed;
  final int hunger;
  final int happiness;
  final int cleanliness;
  final int health;
  final int level;
  final int experience;
  final String? personalityId;
  final String? currentMood;
  final String? moodText;
  final List<PetSkill> skills;
  final DateTime createdAt;
  final DateTime updatedAt;

  Pet({
    required this.id,
    required this.householdId,
    this.ownerId,
    required this.name,
    required this.type,
    this.breed,
    required this.hunger,
    required this.happiness,
    required this.cleanliness,
    required this.health,
    required this.level,
    required this.experience,
    this.personalityId,
    this.currentMood,
    this.moodText,
    required this.skills,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    final skillsJson = json['skills'];
    List<PetSkill> skills = [];
    if (skillsJson != null) {
      if (skillsJson is List) {
        skills = skillsJson.map((s) => PetSkill.fromJson(s)).toList();
      }
    }
    return Pet(
      id: json['id'],
      householdId: json['household_id'],
      ownerId: json['owner_id'],
      name: json['name'],
      type: json['type'],
      breed: json['breed'],
      hunger: json['hunger'],
      happiness: json['happiness'],
      cleanliness: json['cleanliness'],
      health: json['health'],
      level: json['level'],
      experience: json['experience'],
      personalityId: json['personality_id'],
      currentMood: json['current_mood'],
      moodText: json['mood_text'],
      skills: skills,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'owner_id': ownerId,
      'name': name,
      'type': type,
      'breed': breed,
      'hunger': hunger,
      'happiness': happiness,
      'cleanliness': cleanliness,
      'health': health,
      'level': level,
      'experience': experience,
      'personality_id': personalityId,
      'current_mood': currentMood,
      'mood_text': moodText,
      'skills': skills.map((s) => s.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Pet copyWith({
    String? id,
    String? householdId,
    String? ownerId,
    String? name,
    String? type,
    String? breed,
    int? hunger,
    int? happiness,
    int? cleanliness,
    int? health,
    int? level,
    int? experience,
    String? personalityId,
    String? currentMood,
    String? moodText,
    List<PetSkill>? skills,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Pet(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      hunger: hunger ?? this.hunger,
      happiness: happiness ?? this.happiness,
      cleanliness: cleanliness ?? this.cleanliness,
      health: health ?? this.health,
      level: level ?? this.level,
      experience: experience ?? this.experience,
      personalityId: personalityId ?? this.personalityId,
      currentMood: currentMood ?? this.currentMood,
      moodText: moodText ?? this.moodText,
      skills: skills ?? this.skills,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PetInteraction {
  final String id;
  final String petId;
  final String type;
  final int value;
  final DateTime createdAt;

  PetInteraction({
    required this.id,
    required this.petId,
    required this.type,
    required this.value,
    required this.createdAt,
  });

  factory PetInteraction.fromJson(Map<String, dynamic> json) {
    return PetInteraction(
      id: json['id'],
      petId: json['pet_id'],
      type: json['type'],
      value: json['value'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pet_id': petId,
      'type': type,
      'value': value,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
