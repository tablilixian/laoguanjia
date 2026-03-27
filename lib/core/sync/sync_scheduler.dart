import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_engine.dart';
import '../../data/local_db/app_database.dart';
import '../../data/supabase/supabase_client.dart';
import '../../data/local_db/connection/connection_native.dart';

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

  SyncEngine? _syncEngine;

  void initialize() {
    if (!SupabaseClientManager.isInitialized) {
      print('Supabase 未初始化，跳过同步调度器初始化');
      return;
    }

    try {
      _syncEngine = SyncEngine(
        localDb: getDatabase(),
        remoteDb: SupabaseClientManager.client,
      );
      _initialized = true;
      _startPeriodicSync();
      _listenToConnectivity();
      print('同步调度器初始化成功');
    } catch (e) {
      print('同步调度器初始化失败: $e');
    }
  }

  void _startPeriodicSync() {
    if (!_initialized) return;

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => sync(),
    );
  }

  void _listenToConnectivity() {
    if (!_initialized) return;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (results.any((r) => r != ConnectivityResult.none)) {
          sync();
        }
      },
    );
  }

  Future<void> sync() async {
    if (_isSyncing || !_initialized || _syncEngine == null) return;

    _isSyncing = true;
    try {
      await _syncEngine!.syncTasks();
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
