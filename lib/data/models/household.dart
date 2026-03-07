class Household {
  final String id;
  final String name;
  final String? inviteCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  Household({
    required this.id,
    required this.name,
    this.inviteCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Household.fromMap(Map<String, dynamic> map) {
    return Household(
      id: map['id'] as String,
      name: map['name'] as String,
      inviteCode: map['invite_code'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Household copyWith({
    String? id,
    String? name,
    String? inviteCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
