import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/household.dart';
import '../../../data/models/member.dart';
import '../../../data/supabase/supabase_client.dart';

String _generateInviteCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
}

class HouseholdState {
  final Household? currentHousehold;
  final List<Member> members;
  final bool isLoading;
  final String? errorMessage;

  HouseholdState({
    this.currentHousehold,
    this.members = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  HouseholdState copyWith({
    Household? currentHousehold,
    List<Member>? members,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HouseholdState(
      currentHousehold: currentHousehold ?? this.currentHousehold,
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class HouseholdNotifier extends StateNotifier<HouseholdState> {
  final _client = SupabaseClientManager.client;

  HouseholdNotifier() : super(HouseholdState()) {
    _loadCurrentHousehold();
  }

  Future<void> _loadCurrentHousehold() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final memberResponse = await _client
          .from('members')
          .select('*, households(*)')
          .eq('user_id', userId)
          .single();

      if (memberResponse != null) {
        final householdData = memberResponse['households'] as Map<String, dynamic>;
        final household = Household.fromMap(householdData);
        final members = await _loadMembers(household.id);

        state = state.copyWith(
          currentHousehold: household,
          members: members,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<List<Member>> _loadMembers(String householdId) async {
    final response = await _client
        .from('members')
        .select()
        .eq('household_id', householdId);

    return (response as List).map((e) => Member.fromMap(e)).toList();
  }

  Future<bool> createHousehold({
    required String name,
    required String memberName,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '用户未登录',
        );
        return false;
      }

      print('创建家庭: $name, 用户ID: $userId');

      final inviteCode = _generateInviteCode();

      final householdResponse = await _client
          .from('households')
          .insert({'name': name, 'invite_code': inviteCode})
          .select()
          .single();

      print('家庭创建成功: ${householdResponse['id']}, 邀请码: $inviteCode');

      final household = Household.fromMap(householdResponse);

      await _client.from('members').insert({
        'household_id': household.id,
        'name': memberName,
        'role': 'admin',
        'user_id': userId,
      });

      print('成员创建成功');

      final members = await _loadMembers(household.id);

      state = state.copyWith(
        currentHousehold: household,
        members: members,
        isLoading: false,
      );

      return true;
    } catch (e, stackTrace) {
      print('创建家庭失败: $e');
      print('堆栈跟踪: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '创建家庭失败: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> joinByInviteCode({
    required String inviteCode,
    required String memberName,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '用户未登录',
        );
        return false;
      }

      final householdResponse = await _client
          .from('households')
          .select()
          .eq('invite_code', inviteCode.toUpperCase())
          .maybeSingle();

      if (householdResponse == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '邀请码无效',
        );
        return false;
      }

      final existingMember = await _client
          .from('members')
          .select()
          .eq('user_id', userId)
          .eq('household_id', householdResponse['id'])
          .maybeSingle();

      if (existingMember != null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '你已经是该家庭成员',
        );
        return false;
      }

      await _client.from('members').insert({
        'household_id': householdResponse['id'],
        'name': memberName,
        'role': 'member',
        'user_id': userId,
      });

      final household = Household.fromMap(householdResponse);
      final members = await _loadMembers(household.id);

      state = state.copyWith(
        currentHousehold: household,
        members: members,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加入家庭失败: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> refreshInviteCode() async {
    if (state.currentHousehold == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final newCode = _generateInviteCode();

      await _client
          .from('households')
          .update({'invite_code': newCode})
          .eq('id', state.currentHousehold!.id);

      final updatedHousehold = state.currentHousehold!.copyWith(
        inviteCode: newCode,
      );

      state = state.copyWith(
        currentHousehold: updatedHousehold,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '刷新邀请码失败: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> joinHousehold({
    required String householdId,
    required String memberName,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '用户未登录',
        );
        return false;
      }

      final householdResponse = await _client
          .from('households')
          .select()
          .eq('id', householdId)
          .single();

      if (householdResponse == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '家庭不存在',
        );
        return false;
      }

      await _client.from('members').insert({
        'household_id': householdId,
        'name': memberName,
        'role': 'member',
        'user_id': userId,
      });

      final household = Household.fromMap(householdResponse);
      final members = await _loadMembers(householdId);

      state = state.copyWith(
        currentHousehold: household,
        members: members,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> addMember({
    required String name,
    required MemberRole role,
  }) async {
    if (state.currentHousehold == null) return;

    try {
      await _client.from('members').insert({
        'household_id': state.currentHousehold!.id,
        'name': name,
        'role': role.name,
      });

      final members = await _loadMembers(state.currentHousehold!.id);
      state = state.copyWith(members: members);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> removeMember(String memberId) async {
    if (state.currentHousehold == null) return;

    try {
      await _client.from('members').delete().eq('id', memberId);

      final members = await _loadMembers(state.currentHousehold!.id);
      state = state.copyWith(members: members);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadCurrentHousehold();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<bool> updateHouseholdName(String newName) async {
    if (state.currentHousehold == null) return false;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final currentMember = state.members.firstWhere(
        (m) => m.userId == userId,
        orElse: () => throw Exception('未找到成员信息'),
      );

      if (currentMember.role != MemberRole.admin) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '只有管理员可以修改家庭名称',
        );
        return false;
      }

      await _client
          .from('households')
          .update({'name': newName})
          .eq('id', state.currentHousehold!.id);

      final updatedHousehold = state.currentHousehold!.copyWith(
        name: newName,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        currentHousehold: updatedHousehold,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '修改家庭名称失败: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> leaveHousehold() async {
    if (state.currentHousehold == null) return false;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final currentMember = state.members.firstWhere(
        (m) => m.userId == userId,
        orElse: () => throw Exception('未找到成员信息'),
      );

      if (currentMember.role == MemberRole.admin) {
        if (state.members.length == 1) {
          await _client.from('households').delete().eq('id', state.currentHousehold!.id);
        } else {
          state = state.copyWith(
            isLoading: false,
            errorMessage: '管理员退出前需要先转让权限',
          );
          return false;
        }
      } else {
        await _client.from('members').delete().eq('user_id', userId);
      }

      state = state.copyWith(
        currentHousehold: null,
        members: [],
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '退出家庭失败: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> deleteHousehold() async {
    if (state.currentHousehold == null) return false;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final currentMember = state.members.firstWhere(
        (m) => m.userId == userId,
        orElse: () => throw Exception('未找到成员信息'),
      );

      if (currentMember.role != MemberRole.admin) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '只有管理员可以删除家庭',
        );
        return false;
      }

      await _client.from('households').delete().eq('id', state.currentHousehold!.id);

      state = state.copyWith(
        currentHousehold: null,
        members: [],
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '删除家庭失败: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> transferAdminRole(String toMemberId) async {
    if (state.currentHousehold == null) return false;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final currentMember = state.members.firstWhere(
        (m) => m.userId == userId,
        orElse: () => throw Exception('未找到成员信息'),
      );

      if (currentMember.role != MemberRole.admin) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '只有管理员可以转让权限',
        );
        return false;
      }

      final targetMember = state.members.firstWhere(
        (m) => m.id == toMemberId,
        orElse: () => throw Exception('未找到目标成员'),
      );

      if (targetMember.role == MemberRole.admin) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '目标成员已经是管理员',
        );
        return false;
      }

      await _client.from('members').update({'role': 'admin'}).eq('id', toMemberId);
      await _client.from('members').update({'role': 'member'}).eq('id', currentMember.id);

      final updatedMembers = await _loadMembers(state.currentHousehold!.id);

      state = state.copyWith(
        members: updatedMembers,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '转让管理员权限失败: ${e.toString()}',
      );
      return false;
    }
  }
}

final householdProvider =
    StateNotifierProvider<HouseholdNotifier, HouseholdState>((ref) {
  return HouseholdNotifier();
});
