class ItemTag {
  final String id;
  final String householdId;
  final String name;
  final String color;
  final String? icon;
  final String category;
  final DateTime createdAt;

  const ItemTag({
    required this.id,
    required this.householdId,
    required this.name,
    this.color = '#6B7280',
    this.icon,
    this.category = 'other',
    required this.createdAt,
  });

  factory ItemTag.fromMap(Map<String, dynamic> map) {
    return ItemTag(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      name: map['name'] as String,
      color: map['color'] as String? ?? '#6B7280',
      icon: map['icon'] as String?,
      category: map['category'] as String? ?? 'other',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'color': color,
      'icon': icon,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ItemTag copyWith({
    String? id,
    String? householdId,
    String? name,
    String? color,
    String? icon,
    String? category,
    DateTime? createdAt,
  }) {
    return ItemTag(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
