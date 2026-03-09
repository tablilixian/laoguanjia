import 'package:supabase/supabase.dart';

class Pet {
  final String id;
  final String householdId;
  final String name;
  final String type;
  final String? breed;
  final int hunger;
  final int happiness;
  final int cleanliness;
  final int health;
  final int level;
  final int experience;
  final DateTime createdAt;
  final DateTime updatedAt;

  Pet({
    required this.id,
    required this.householdId,
    required this.name,
    required this.type,
    this.breed,
    required this.hunger,
    required this.happiness,
    required this.cleanliness,
    required this.health,
    required this.level,
    required this.experience,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'],
      householdId: json['household_id'],
      name: json['name'],
      type: json['type'],
      breed: json['breed'],
      hunger: json['hunger'],
      happiness: json['happiness'],
      cleanliness: json['cleanliness'],
      health: json['health'],
      level: json['level'],
      experience: json['experience'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'type': type,
      'breed': breed,
      'hunger': hunger,
      'happiness': happiness,
      'cleanliness': cleanliness,
      'health': health,
      'level': level,
      'experience': experience,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Pet copyWith({
    String? id,
    String? householdId,
    String? name,
    String? type,
    String? breed,
    int? hunger,
    int? happiness,
    int? cleanliness,
    int? health,
    int? level,
    int? experience,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Pet(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      hunger: hunger ?? this.hunger,
      happiness: happiness ?? this.happiness,
      cleanliness: cleanliness ?? this.cleanliness,
      health: health ?? this.health,
      level: level ?? this.level,
      experience: experience ?? this.experience,
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
