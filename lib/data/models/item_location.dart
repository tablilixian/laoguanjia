class ItemLocation {
  final String id;
  final String householdId;
  final String name;
  final String? description;
  final String icon;
  final String? color;
  final String? parentId;
  final int depth;
  final String? path;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItemLocation({
    required this.id,
    required this.householdId,
    required this.name,
    this.description,
    this.icon = '📍',
    this.color,
    this.parentId,
    this.depth = 0,
    this.path,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isRoot => parentId == null;

  factory ItemLocation.fromMap(Map<String, dynamic> map) {
    return ItemLocation(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: map['icon'] as String? ?? '📍',
      color: map['color'] as String?,
      parentId: map['parent_id'] as String?,
      depth: map['depth'] as int? ?? 0,
      path: map['path'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'parent_id': parentId,
      'depth': depth,
      'path': path,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ItemLocation copyWith({
    String? id,
    String? householdId,
    String? name,
    String? description,
    String? icon,
    String? color,
    String? parentId,
    int? depth,
    String? path,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemLocation(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      parentId: parentId ?? this.parentId,
      depth: depth ?? this.depth,
      path: path ?? this.path,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
