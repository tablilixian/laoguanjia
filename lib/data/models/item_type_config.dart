class ItemTypeConfig {
  final String id;
  final String? householdId;
  final String typeKey;
  final String typeLabel;
  final String icon;
  final String color;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;

  const ItemTypeConfig({
    required this.id,
    this.householdId,
    required this.typeKey,
    required this.typeLabel,
    this.icon = '📦',
    this.color = '#6B7280',
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isPreset => householdId == null;

  factory ItemTypeConfig.fromMap(Map<String, dynamic> map) {
    // 处理 sort_order 可能是字符串的情况
    int parseSortOrder(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }
    
    // 处理 is_active 可能是字符串的情况
    bool parseIsActive(dynamic value) {
      if (value == null) return true;
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      if (value is int) {
        return value != 0;
      }
      return true;
    }
    
    return ItemTypeConfig(
      id: map['id'] as String,
      householdId: map['household_id'] as String?,
      typeKey: map['type_key'] as String,
      typeLabel: map['type_label'] as String,
      icon: map['icon'] as String? ?? '📦',
      color: map['color'] as String? ?? '#6B7280',
      sortOrder: parseSortOrder(map['sort_order']),
      isActive: parseIsActive(map['is_active']),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'household_id': householdId,
      'type_key': typeKey,
      'type_label': typeLabel,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toRemoteJson() {
    return {
      'id': id,
      'household_id': householdId,
      'type_key': typeKey,
      'type_label': typeLabel,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'version': 1,
    };
  }

  ItemTypeConfig copyWith({
    String? id,
    String? householdId,
    String? typeKey,
    String? typeLabel,
    String? icon,
    String? color,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ItemTypeConfig(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      typeKey: typeKey ?? this.typeKey,
      typeLabel: typeLabel ?? this.typeLabel,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
