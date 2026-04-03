import 'dart:convert';

enum LocationTemplateType {
  direction,
  numbering,
  grid,
  stack,
  none;

  String get label {
    switch (this) {
      case LocationTemplateType.direction:
        return '方向型';
      case LocationTemplateType.numbering:
        return '编号型';
      case LocationTemplateType.grid:
        return '网格型';
      case LocationTemplateType.stack:
        return '堆叠型';
      case LocationTemplateType.none:
        return '无模板';
    }
  }

  String get description {
    switch (this) {
      case LocationTemplateType.direction:
        return '适用于客厅、卧室等开放空间';
      case LocationTemplateType.numbering:
        return '适用于书架、衣柜等格子';
      case LocationTemplateType.grid:
        return '适用于收纳盒、抽屉内部';
      case LocationTemplateType.stack:
        return '适用于堆叠的箱子、盒子';
      case LocationTemplateType.none:
        return '纯文字描述，无可视化';
    }
  }

  /// 数据库中使用的值
  /// numbering -> index (其他保持不变)
  String get dbValue {
    switch (this) {
      case LocationTemplateType.direction:
        return 'direction';
      case LocationTemplateType.numbering:
        return 'index';
      case LocationTemplateType.grid:
        return 'grid';
      case LocationTemplateType.stack:
        return 'stack';
      case LocationTemplateType.none:
        return 'none';
    }
  }

  static LocationTemplateType? fromString(String? value) {
    if (value == null) return null;
    // 支持 'numbering' 和 'index' 两种表示方式
    if (value == 'numbering' || value == 'index') {
      return LocationTemplateType.numbering;
    }
    return LocationTemplateType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LocationTemplateType.none,
    );
  }
}

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
  final DateTime? deletedAt;

  final LocationTemplateType? templateType;
  final Map<String, dynamic>? templateConfig;
  final Map<String, dynamic>? positionInParent;
  final String? positionDescription;

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
    this.deletedAt,
    this.templateType,
    this.templateConfig,
    this.positionInParent,
    this.positionDescription,
  });

  bool get isRoot => parentId == null;
  bool get hasTemplate =>
      templateType != null && templateType != LocationTemplateType.none;

  factory ItemLocation.fromMap(Map<String, dynamic> map) {
    // 解析 template_config：可能是 Map 或 JSON 字符串
    Map<String, dynamic>? parseTemplateConfig(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
      return null;
    }
    
    // 解析 position_in_parent：可能是 Map 或 JSON 字符串
    Map<String, dynamic>? parsePositionInParent(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
      return null;
    }
    
    // 解析 int 字段，可能是字符串
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }
    
    return ItemLocation(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: map['icon'] as String? ?? '📍',
      color: map['color'] as String?,
      parentId: map['parent_id'] as String?,
      depth: parseInt(map['depth']),
      path: map['path'] as String?,
      sortOrder: parseInt(map['sort_order']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null 
          ? DateTime.parse(map['deleted_at'] as String) 
          : null,
      templateType: LocationTemplateType.fromString(
        map['template_type'] as String?,
      ),
      templateConfig: parseTemplateConfig(map['template_config']),
      positionInParent: parsePositionInParent(map['position_in_parent']),
      positionDescription: map['position_description'] as String?,
    );
  }

  Map<String, dynamic> toRemoteJson() {
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
      'template_type': templateType?.dbValue,
      'template_config': templateConfig,
      'position_in_parent': positionInParent,
      'position_description': positionDescription,
      'deleted_at': deletedAt?.toIso8601String(),
      'version': 1,
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
    DateTime? deletedAt,
    LocationTemplateType? templateType,
    Map<String, dynamic>? templateConfig,
    Map<String, dynamic>? positionInParent,
    String? positionDescription,
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
      deletedAt: deletedAt ?? this.deletedAt,
      templateType: templateType ?? this.templateType,
      templateConfig: templateConfig ?? this.templateConfig,
      positionInParent: positionInParent ?? this.positionInParent,
      positionDescription: positionDescription ?? this.positionDescription,
    );
  }
}
