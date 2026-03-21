import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../sync/sync_status.dart';
import '../sync/sync_status_provider.dart';

class SyncStatusBar extends ConsumerWidget {
  final Widget child;

  const SyncStatusBar({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        if (syncStatus.state == SyncState.syncing ||
            syncStatus.state == SyncState.error ||
            syncStatus.isOffline)
          _buildStatusBar(context, theme, syncStatus, ref),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildStatusBar(
    BuildContext context,
    ThemeData theme,
    SyncStatus status,
    WidgetRef ref,
  ) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String text;

    switch (status.state) {
      case SyncState.syncing:
        backgroundColor = AppTheme.primaryGold.withOpacity(0.1);
        textColor = AppTheme.primaryGold;
        icon = Icons.sync;
        text = status.statusText;
        break;
      case SyncState.error:
        backgroundColor = AppTheme.error.withOpacity(0.1);
        textColor = AppTheme.error;
        icon = Icons.error_outline;
        text = status.statusText;
        break;
      case SyncState.offline:
        backgroundColor = AppTheme.warning.withOpacity(0.1);
        textColor = AppTheme.warning;
        icon = Icons.wifi_off;
        text = '离线模式';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: backgroundColor,
      child: Row(
        children: [
          if (status.state == SyncState.syncing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor,
              ),
            )
          else
            Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
              ),
            ),
          ),
          if (status.state == SyncState.error)
            TextButton(
              onPressed: () => ref.read(syncStatusProvider.notifier).sync(),
              child: Text(
                '重试',
                style: TextStyle(color: textColor),
              ),
            ),
        ],
      ),
    );
  }
}
