import 'package:supabase_flutter/supabase_flutter.dart';

enum MemberRole { admin, member }

class Member {
  final String id;
  final String householdId;
  final String name;
  final String? avatarUrl;
  final MemberRole role;
  final String? userId;
  final DateTime createdAt;

  Member({
    required this.id,
    required this.householdId,
    required this.name,
    this.avatarUrl,
    required this.role,
    this.userId,
    required this.createdAt,
  });

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      name: map['name'] as String,
      avatarUrl: map['avatar_url'] as String?,
      role: MemberRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => MemberRole.member,
      ),
      userId: map['user_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'avatar_url': avatarUrl,
      'role': role.name,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
