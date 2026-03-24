import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/household_item.dart';

class SyncStatusBadge extends StatelessWidget {
  final SyncStatus syncStatus;

  const SyncStatusBadge({
    super.key,
    required this.syncStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (syncStatus == SyncStatus.synced) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    Color backgroundColor;
    Color textColor;
    IconData iconData;
    String label;

    switch (syncStatus) {
      case SyncStatus.pending:
        backgroundColor = AppTheme.warning.withValues(alpha: 0.15);
        textColor = AppTheme.warning;
        iconData = Icons.pending;
        label = '待同步';
        break;
      case SyncStatus.error:
        backgroundColor = AppTheme.error.withValues(alpha: 0.15);
        textColor = AppTheme.error;
        iconData = Icons.error_outline;
        label = '同步失败';
        break;
      case SyncStatus.synced:
        backgroundColor = AppTheme.success.withValues(alpha: 0.15);
        textColor = AppTheme.success;
        iconData = Icons.check_circle_outline;
        label = '已同步';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 12,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
