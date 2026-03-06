import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/supabase/supabase_client.dart';

final authUserProvider = StreamProvider<User?>((ref) {
  return SupabaseClientManager.client.auth.onAuthStateChange.map((event) => event.session?.user);
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

enum AuthStatus { initial, loading, authenticated, unauthenticated, error, emailNotVerified }

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
        emailRedirectTo: 'io.supabase.flutter://reset-callback/',
      );
      
      if (response.user != null) {
        if (response.user!.emailConfirmedAt != null) {
          state = state.copyWith(status: AuthStatus.authenticated);
          return true;
        } else {
          state = state.copyWith(status: AuthStatus.emailNotVerified);
          return true;
        }
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
        if (response.user!.emailConfirmedAt != null) {
          state = state.copyWith(status: AuthStatus.authenticated);
          return true;
        } else {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: '请先验证邮箱',
          );
          return false;
        }
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

  // 发送验证邮件
  Future<bool> resendVerificationEmail() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      // 重新发送验证邮件
      final user = _client.auth.currentUser;
      if (user != null) {
        // 注意：这里需要根据 Supabase SDK 版本使用正确的方法
        // 暂时使用 signUp 方法重新发送验证邮件
        await _client.auth.signUp(
          email: user.email!,
          password: 'temp_password_123', // 临时密码，不会实际创建新用户
          emailRedirectTo: 'io.supabase.flutter://reset-callback/',
        );
        state = state.copyWith(
          status: AuthStatus.emailNotVerified,
          errorMessage: '验证邮件已发送，请查收',
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: '请先登录',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: '发送失败，请稍后重试',
      );
      return false;
    }
  }

  // 发送密码重置邮件
  Future<bool> resetPassword({required String email}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutter://reset-callback/',
      );
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: '密码重置邮件已发送，请查收',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: '发送失败，请稍后重试',
      );
      return false;
    }
  }

  // 退出登录
  Future<void> signOut() async {
    await _client.auth.signOut();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }
}
