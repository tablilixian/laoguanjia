import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkStatus {
  final bool isOnline;
  final DateTime? lastChanged;

  NetworkStatus({
    required this.isOnline,
    this.lastChanged,
  });

  NetworkStatus copyWith({
    bool? isOnline,
    DateTime? lastChanged,
  }) {
    return NetworkStatus(
      isOnline: isOnline ?? this.isOnline,
      lastChanged: lastChanged ?? this.lastChanged,
    );
  }
}

class NetworkStatusNotifier extends StateNotifier<NetworkStatus> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  NetworkStatusNotifier() : super(NetworkStatus(isOnline: true)) {
    // 延迟初始化，避免构造函数中访问平台 channel
    Future.microtask(_init);
  }

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        _updateStatus(results);
      },
    );
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    
    if (state.isOnline != isOnline) {
      state = NetworkStatus(
        isOnline: isOnline,
        lastChanged: DateTime.now(),
      );
    }
  }

  void setOnlineStatus(bool isOnline) {
    if (state.isOnline != isOnline) {
      state = NetworkStatus(
        isOnline: isOnline,
        lastChanged: DateTime.now(),
      );
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

final networkStatusProvider =
    StateNotifierProvider<NetworkStatusNotifier, NetworkStatus>((ref) {
  return NetworkStatusNotifier();
});
