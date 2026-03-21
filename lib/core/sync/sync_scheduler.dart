import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_engine.dart';
import '../../data/local_db/app_database.dart';
import '../../data/supabase/supabase_client.dart';

class SyncScheduler {
  static final SyncScheduler _instance = SyncScheduler._internal();
  factory SyncScheduler() => _instance;
  SyncScheduler._internal();

  Timer? _periodicTimer;
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  final AppDatabase _localDb = AppDatabase();
  late final SyncEngine _syncEngine;

  void initialize() {
    _syncEngine = SyncEngine(
      localDb: _localDb,
      remoteDb: SupabaseClientManager.client,
    );

    _startPeriodicSync();
    _listenToConnectivity();
  }

  void _startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => sync(),
    );
  }

  void _listenToConnectivity() {
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
    if (_isSyncing) return;

    _isSyncing = true;
    try {
      await _syncEngine.syncTasks();
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

  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _isSyncing;

  void dispose() {
    _periodicTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
