import 'package:flutter/widgets.dart';
import 'sync_scheduler.dart';

/// App 生命周期同步管理器
///
/// 职责：监听 App 从后台恢复到前台的事件，自动触发同步
///
/// 使用场景：
/// - 用户将 App 切到后台，几小时后再切回前台
/// - 此时远端数据可能已被其他设备修改，需要同步最新数据
///
/// 注册方式：
/// - 在 main.dart 或 WelcomePage 中调用 AppLifecycleSync().register()
/// - 在 dispose 时调用 AppLifecycleSync().unregister()
class AppLifecycleSync extends WidgetsBindingObserver {
  static final AppLifecycleSync _instance = AppLifecycleSync._internal();
  factory AppLifecycleSync() => _instance;
  AppLifecycleSync._internal();

  bool _registered = false;

  /// 注册生命周期监听
  ///
  /// 应在 App 启动或用户登录后调用
  void register() {
    if (_registered) return;
    WidgetsBinding.instance.addObserver(this);
    _registered = true;
    debugPrint('🔄 [AppLifecycleSync] 已注册生命周期监听');
  }

  /// 取消注册
  ///
  /// 应在 App 退出或用户登出时调用
  void unregister() {
    if (!_registered) return;
    WidgetsBinding.instance.removeObserver(this);
    _registered = false;
    debugPrint('🔄 [AppLifecycleSync] 已取消生命周期监听');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App 从后台恢复到前台 → 触发同步
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 [AppLifecycleSync] App 恢复到前台，触发同步');
      // fire-and-forget：不阻塞 UI，同步在后台进行
      SyncScheduler().sync();
    }
  }

  bool get isRegistered => _registered;
}
