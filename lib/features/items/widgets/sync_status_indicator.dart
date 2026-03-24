import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/offline_items_provider.dart';

class SyncStatusIndicator extends StatelessWidget {
  final SyncState syncState;
  final String? syncMessage;

  const SyncStatusIndicator({
    super.key,
    required this.syncState,
    this.syncMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (syncState == SyncState.idle) {
      return const SizedBox.shrink();
    }

    return _SyncStatusContent(
      syncState: syncState,
      syncMessage: syncMessage,
    );
  }
}

class _SyncStatusContent extends StatelessWidget {
  final SyncState syncState;
  final String? syncMessage;

  const _SyncStatusContent({
    required this.syncState,
    this.syncMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (iconColor, iconData, message) = _getSyncStateInfo(theme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (syncState == SyncState.syncing)
            const SizedBox(
              width: 16,
              height: 16,
              child: _SyncingIndicator(),
            )
          else
            Icon(
              iconData,
              size: 16,
              color: iconColor,
            ),
          const SizedBox(width: 8),
          Text(
            message,
            style: theme.textTheme.labelMedium?.copyWith(
              color: iconColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _getSyncStateInfo(ThemeData theme) {
    switch (syncState) {
      case SyncState.syncing:
        return (
          AppTheme.primaryGold,
          Icons.sync,
          syncMessage ?? '正在同步...',
        );
      case SyncState.success:
        return (
          AppTheme.success,
          Icons.check_circle,
          syncMessage ?? '同步成功',
        );
      case SyncState.error:
        return (
          AppTheme.error,
          Icons.error,
          syncMessage ?? '同步失败',
        );
      case SyncState.idle:
        return (
          Colors.grey,
          Icons.sync,
          '',
        );
    }
  }
}

class _SyncingIndicator extends StatelessWidget {
  const _SyncingIndicator();

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
    );
  }
}
