enum SyncState { idle, syncing, success, error, offline }

class SyncStatus {
  final SyncState state;
  final DateTime? lastSyncTime;
  final int? totalItems;
  final int? syncedItems;
  final String? errorMessage;
  final bool isOffline;
  final bool autoSyncEnabled;

  SyncStatus({
    this.state = SyncState.idle,
    this.lastSyncTime,
    this.totalItems,
    this.syncedItems,
    this.errorMessage,
    this.isOffline = false,
    this.autoSyncEnabled = true,
  });

  SyncStatus copyWith({
    SyncState? state,
    DateTime? lastSyncTime,
    int? totalItems,
    int? syncedItems,
    String? errorMessage,
    bool? isOffline,
    bool? autoSyncEnabled,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      totalItems: totalItems ?? this.totalItems,
      syncedItems: syncedItems ?? this.syncedItems,
      errorMessage: errorMessage ?? this.errorMessage,
      isOffline: isOffline ?? this.isOffline,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
    );
  }

  String get statusText {
    switch (state) {
      case SyncState.idle:
        return lastSyncTime != null
            ? '上次同步: ${_formatTime(lastSyncTime!)}'
            : '未同步';
      case SyncState.syncing:
        if (totalItems != null && syncedItems != null) {
          return '正在同步... $syncedItems/$totalItems';
        }
        return '正在同步...';
      case SyncState.success:
        return '同步成功';
      case SyncState.error:
        return '同步失败: ${errorMessage ?? "未知错误"}';
      case SyncState.offline:
        return '离线模式';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} 小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} 分钟前';
    } else {
      return '刚刚';
    }
  }
}
