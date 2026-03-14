class ItemTag {
  final String id;
  final String householdId;
  final String name;
  final String color;
  final String? icon;
  final String category;
  // 适用的物品类型列表，如 ['appliance', 'furniture']，为空表示适用于所有类型
  final List<String> applicableTypes;
  final DateTime createdAt;

  const ItemTag({
    required this.id,
    required this.householdId,
    required this.name,
    this.color = '#6B7280',
    this.icon,
    this.category = 'other',
    this.applicableTypes = const [],
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
      applicableTypes: (map['applicable_types'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
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
      'applicable_types': applicableTypes,
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
    List<String>? applicableTypes,
    DateTime? createdAt,
  }) {
    return ItemTag(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      applicableTypes: applicableTypes ?? this.applicableTypes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 检查标签是否适用于指定物品类型
  bool isApplicableTo(String itemType) {
    if (applicableTypes.isEmpty) return true; // 空表示适用于所有类型
    return applicableTypes.contains(itemType);
  }
}
