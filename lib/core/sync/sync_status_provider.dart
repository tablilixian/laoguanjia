import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_status.dart';
import 'sync_scheduler.dart';
import '../services/storage_service.dart';

final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  return SyncStatusNotifier();
});

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  final SyncScheduler _scheduler = SyncScheduler();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _statusTimer;

  SyncStatusNotifier() : super(SyncStatus()) {
    _init();
  }

  Future<void> _init() async {
    await _loadLastSyncTime();
    await _loadAutoSyncSetting();
    _listenToConnectivity();
    _startStatusTimer();
  }

  Future<void> _loadAutoSyncSetting() async {
    final autoSyncEnabled = _scheduler.autoSyncEnabled;
    state = state.copyWith(autoSyncEnabled: autoSyncEnabled);
  }

  Future<void> _loadLastSyncTime() async {
    final lastSync = await StorageService.getLastSyncTime();
    if (lastSync != null) {
      state = state.copyWith(lastSyncTime: lastSync);
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final isOffline = results.every((r) => r == ConnectivityResult.none);
        state = state.copyWith(isOffline: isOffline);
      },
    );
  }

  void _startStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateStatus(),
    );
  }

  void _updateStatus() {
    if (_scheduler.isSyncing) {
      state = state.copyWith(state: SyncState.syncing);
    } else if (state.state == SyncState.syncing) {
      state = state.copyWith(
        state: SyncState.success,
        lastSyncTime: DateTime.now(),
      );
    }
  }

  Future<void> sync() async {
    if (state.state == SyncState.syncing) return;

    state = state.copyWith(
      state: SyncState.syncing,
      totalItems: null,
      syncedItems: null,
      errorMessage: null,
    );

    try {
      await _scheduler.forceSync();
      await StorageService.saveLastSyncTime(DateTime.now());
      state = state.copyWith(
        state: SyncState.success,
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        state: SyncState.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> forceFullSync() async {
    if (state.state == SyncState.syncing) return;

    state = state.copyWith(
      state: SyncState.syncing,
      totalItems: null,
      syncedItems: null,
      errorMessage: null,
    );

    try {
      await _scheduler.forceFullSync(
        onProgress: (current, total) {
          updateProgress(current, total);
        },
      );
      await StorageService.saveLastSyncTime(DateTime.now());
      state = state.copyWith(
        state: SyncState.success,
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        state: SyncState.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> resetAndSync() async {
    if (state.state == SyncState.syncing) return;

    state = state.copyWith(
      state: SyncState.syncing,
      totalItems: null,
      syncedItems: null,
      errorMessage: null,
    );

    try {
      await _scheduler.resetAndSync(
        onProgress: (current, total) {
          updateProgress(current, total);
        },
      );
      await StorageService.saveLastSyncTime(DateTime.now());
      state = state.copyWith(
        state: SyncState.success,
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        state: SyncState.error,
        errorMessage: e.toString(),
      );
    }
  }

  void updateProgress(int synced, int total) {
    state = state.copyWith(
      syncedItems: synced,
      totalItems: total,
    );
  }

  Future<void> updateAutoSyncEnabled(bool enabled) async {
    await _scheduler.setAutoSyncEnabled(enabled);
    state = state.copyWith(autoSyncEnabled: enabled);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }
}
