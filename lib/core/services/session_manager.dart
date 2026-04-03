import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/supabase/supabase_client.dart';
import '../../features/household/providers/household_provider.dart';

/// 会话管理器：处理登录/退出时的状态生命周期
///
/// 核心职责：
/// 1. 退出登录时清除所有用户相关的 UI 状态
/// 2. 登录成功后触发数据重新加载
/// 3. 避免账号切换时的数据串号问题
class SessionManager {
  final Ref ref;

  SessionManager(this.ref);

  /// 退出登录时的完整清理流程
  ///
  /// 调用顺序很重要：
  /// 1. 先清除 UI 状态（避免 Supabase signOut 后仍有旧数据闪烁）
  /// 2. 再执行 Supabase 退出
  Future<void> signOut() async {
    // 1. 清除所有用户相关的 Riverpod 状态
    _clearAllUserState();

    // 2. 执行 Supabase 退出
    await SupabaseClientManager.client.auth.signOut();
  }

  /// 登录成功后的初始化流程
  Future<void> onSignIn() async {
    // 重新加载家庭信息
    await ref.read(householdProvider.notifier).refresh();
  }

  /// 清除所有用户相关的 Riverpod 状态
  void _clearAllUserState() {
    // 重置家庭状态为初始空状态
    ref.read(householdProvider.notifier).reset();

    // 其他 provider 的 reset 可以在这里逐步添加:
    // ref.read(tasksProvider.notifier).reset();
    // ref.read(petsProvider.notifier).reset();
    // ref.read(paginatedItemsProvider.notifier).reset();
    // ref.read(tagsProvider.notifier).reset();
    // ref.read(locationsProvider.notifier).reset();
    // ref.read(itemTypesProvider.notifier).reset();
  }
}

/// Riverpod Provider，方便在任何地方使用
final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(ref);
});
