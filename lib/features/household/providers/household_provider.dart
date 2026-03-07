import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/household.dart';
import '../../../data/models/member.dart';
import '../../../data/supabase/supabase_client.dart';

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

      final householdResponse = await _client
          .from('households')
          .insert({'name': name})
          .select()
          .single();

      print('家庭创建成功: ${householdResponse['id']}');

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

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final householdProvider =
    StateNotifierProvider<HouseholdNotifier, HouseholdState>((ref) {
  return HouseholdNotifier();
});
