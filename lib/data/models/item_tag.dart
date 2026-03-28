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
  final DateTime updatedAt;
  // 标签序号（用于位图，0-62）
  final int? tagIndex;

  const ItemTag({
    required this.id,
    required this.householdId,
    required this.name,
    this.color = '#6B7280',
    this.icon,
    this.category = 'other',
    this.applicableTypes = const [],
    required this.createdAt,
    required this.updatedAt,
    this.tagIndex,
  });

  factory ItemTag.fromMap(Map<String, dynamic> map) {
    // 处理 applicable_types 可能是字符串、数组或 PostgreSQL ARRAY 格式
    List<String> parseApplicableTypes(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      if (value is String) {
        // 空数组
        if (value.isEmpty || value == '[]' || value == '{}' || value == 'ARRAY[]') {
          return [];
        }
        // PostgreSQL ARRAY 格式: {a,b,c}
        if (value.startsWith('{') && value.endsWith('}')) {
          try {
            final inner = value.substring(1, value.length - 1);
            if (inner.isEmpty) return [];
            return inner.split(',').map((e) => e.trim().replaceAll('"', '')).where((e) => e.isNotEmpty).toList();
          } catch (_) {
            return [];
          }
        }
        // JSON 数组格式: ["a","b"]
        if (value.startsWith('[')) {
          try {
            final content = value.substring(1, value.length - 1);
            return content.split(',').map((e) => e.trim().replaceAll('"', '').replaceAll("'", '')).where((e) => e.isNotEmpty).toList();
          } catch (_) {
            return [];
          }
        }
        // 单个值
        return [value];
      }
      return [];
    }
    
    // 处理 tag_index 可能是字符串的情况
    int? parseTagIndex(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }
    
    return ItemTag(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      name: map['name'] as String,
      color: map['color'] as String? ?? '#6B7280',
      icon: map['icon'] as String?,
      category: map['category'] as String? ?? 'other',
      applicableTypes: parseApplicableTypes(map['applicable_types']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.parse(map['created_at'] as String),
      tagIndex: parseTagIndex(map['tag_index']),
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
      'updated_at': updatedAt.toIso8601String(),
      'tag_index': tagIndex,
    };
  }

  Map<String, dynamic> toRemoteJson() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'color': color,
      'icon': icon,
      'category': category,
      'applicable_types': applicableTypes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'version': 1,
      'tag_index': tagIndex,
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
    DateTime? updatedAt,
    int? tagIndex,
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
      updatedAt: updatedAt ?? this.updatedAt,
      tagIndex: tagIndex ?? this.tagIndex,
    );
  }

  /// 检查标签是否适用于指定物品类型
  bool isApplicableTo(String itemType) {
    if (applicableTypes.isEmpty) return true; // 空表示适用于所有类型
    return applicableTypes.contains(itemType);
  }
}
