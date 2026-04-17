import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_engine.dart';
import '../../data/local_db/app_database.dart';
import '../../data/supabase/supabase_client.dart';
import '../../data/local_db/connection/connection_native.dart';
import '../services/storage_service.dart';

class SyncScheduler {
  static final SyncScheduler _instance = SyncScheduler._internal();
  factory SyncScheduler() => _instance;
  SyncScheduler._internal();

  Timer? _periodicTimer;
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  bool _initialized = false;
  bool _autoSyncEnabled = true;

  SyncEngine? _syncEngine;

  void initialize() async {
    if (!SupabaseClientManager.isInitialized) {
      print('Supabase 未初始化，跳过同步调度器初始化');
      return;
    }

    try {
      // 读取自动同步设置
      _autoSyncEnabled = await StorageService.isAutoSyncEnabled();
      print('自动同步: $_autoSyncEnabled');

      _syncEngine = SyncEngine(
        localDb: getDatabase(),
        remoteDb: SupabaseClientManager.client,
      );
      _initialized = true;

      if (_autoSyncEnabled) {
        _startPeriodicSync();
        _listenToConnectivity();
      }
      print('同步调度器初始化成功');
    } catch (e) {
      print('同步调度器初始化失败: $e');
    }
  }

  /// 更新自动同步设置并重启定时器
  Future<void> setAutoSyncEnabled(bool enabled) async {
    _autoSyncEnabled = enabled;
    await StorageService.setAutoSyncEnabled(enabled);

    if (enabled && _initialized) {
      _startPeriodicSync();
      _listenToConnectivity();
    } else {
      _periodicTimer?.cancel();
      _connectivitySubscription?.cancel();
    }
    print('自动同步已${enabled ? '开启' : '关闭'}');
  }

  /// 获取当前自动同步设置状态
  bool get autoSyncEnabled => _autoSyncEnabled;

  void _startPeriodicSync() {
    if (!_initialized || !_autoSyncEnabled) return;

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => sync(),
    );
  }

  void _listenToConnectivity() {
    if (!_initialized || !_autoSyncEnabled) return;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (results.any((r) => r != ConnectivityResult.none)) {
          sync();
        }
      },
    );
  }

  /// 执行一次完整同步（所有模块）
  ///
  /// 同步顺序：Tasks → Items → Locations → Tags → TypeConfigs
  /// 由定时任务（5 分钟）、网络恢复、App 前台恢复触发
  Future<void> sync() async {
    if (_isSyncing || !_initialized || _syncEngine == null) return;

    _isSyncing = true;
    try {
      // 1. 同步任务
      await _syncEngine!.syncTasks();
      // 2. 同步物品（含位置、标签、类型配置的增量同步）
      await _syncEngine!.syncItems();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      print('同步失败: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> forceSync() async {
    _isSyncing = false;
    await sync();
  }

  Future<void> forceFullSync({
    void Function(int current, int total)? onProgress,
  }) async {
    if (_isSyncing || !_initialized || _syncEngine == null) return;

    _isSyncing = true;
    try {
      await _syncEngine!.forceFullSync(onProgress: onProgress);
      _lastSyncTime = DateTime.now();
    } catch (e) {
      print('全量同步失败: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> resetAndSync({
    void Function(int current, int total)? onProgress,
  }) async {
    if (_isSyncing || !_initialized || _syncEngine == null) return;

    _isSyncing = true;
    try {
      await _syncEngine!.resetLocalData();
      await _syncEngine!.forceFullSync(onProgress: onProgress);
      _lastSyncTime = DateTime.now();
    } catch (e) {
      print('重置同步失败: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _isSyncing;
  bool get isInitialized => _initialized;

  void dispose() {
    _periodicTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
