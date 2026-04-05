import 'package:home_manager/data/models/pet.dart';

/// 宠物云端元数据模型
///
/// 仅存储身份关联字段，用于 household 关联和跨设备识别。
/// 所有动态状态 (hunger/happiness/level 等) 存于本地 JSON。
class PetMeta {
  final String id;
  final String householdId;
  final String? ownerId;
  final String name;
  final String type;
  final String? breed;
  final String? avatarUrl;
  final Map<String, dynamic>? stateSnapshot;
  final DateTime? lastSyncAt;
  final DateTime? createdAt;

  const PetMeta({
    this.id = '',
    required this.householdId,
    this.ownerId,
    required this.name,
    required this.type,
    this.breed,
    this.avatarUrl,
    this.stateSnapshot,
    this.lastSyncAt,
    this.createdAt,
  });

  factory PetMeta.fromJson(Map<String, dynamic> json) {
    return PetMeta(
      id: json['id'] as String? ?? '',
      householdId: json['household_id'] as String,
      ownerId: json['owner_id'] as String?,
      name: json['name'] as String,
      type: json['type'] as String,
      breed: json['breed'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      stateSnapshot: json['state_snapshot'] as Map<String, dynamic>?,
      lastSyncAt: json['last_sync_at'] != null
          ? DateTime.parse(json['last_sync_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'household_id': householdId,
      if (ownerId != null) 'owner_id': ownerId,
      'name': name,
      'type': type,
      if (breed != null) 'breed': breed,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (stateSnapshot != null) 'state_snapshot': stateSnapshot,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt!.toIso8601String(),
    };
  }

  PetMeta copyWith({
    String? id,
    String? householdId,
    String? ownerId,
    String? name,
    String? type,
    String? breed,
    String? avatarUrl,
    Map<String, dynamic>? stateSnapshot,
    DateTime? lastSyncAt,
    DateTime? createdAt,
  }) {
    return PetMeta(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      stateSnapshot: stateSnapshot ?? this.stateSnapshot,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 从旧 Pet 模型转换为 PetMeta (迁移用)
  factory PetMeta.fromOldPet(Pet pet) {
    return PetMeta(
      id: pet.id,
      householdId: pet.householdId,
      ownerId: pet.ownerId,
      name: pet.name,
      type: pet.type,
      breed: pet.breed,
    );
  }
}
