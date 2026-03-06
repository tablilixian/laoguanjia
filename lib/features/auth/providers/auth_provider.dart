import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/supabase/supabase_client.dart';

// 当前登录用户 Provider
final authUserProvider = StreamProvider<User?>((ref) {
  return SupabaseClientManager.client.auth.userChanges();
});

// 是否已登录
final isLoggedInProvider = Provider<bool>((ref) {
  final user = ref.watch(authUserProvider);
  return user.valueOrNull != null;
});

// 认证状态 Provider
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((
  ref,
) {
  return AuthStateNotifier();
});

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  AuthState({this.status = AuthStatus.initial, this.errorMessage});

  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(AuthState(status: AuthStatus.initial));

  final _client = SupabaseClientManager.client;

  // 注册
  Future<bool> signUp({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user != null) {
        state = state.copyWith(status: AuthStatus.authenticated);
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: '注册失败，请稍后重试',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  // 登录
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        state = state.copyWith(status: AuthStatus.authenticated);
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: '登录失败，请检查邮箱和密码',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: '邮箱或密码错误');
      return false;
    }
  }

  // 退出登录
  Future<void> signOut() async {
    await _client.auth.signOut();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }
}
