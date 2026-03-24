import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/offline_items_provider.dart';

class SyncActionBar extends ConsumerWidget {
  const SyncActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsState = ref.watch(offlineItemsProvider);
    final theme = Theme.of(context);
    final pendingCount = itemsState.pendingSyncCount;
    final isSyncing = itemsState.syncState == SyncState.syncing;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SyncButton(
              isSyncing: isSyncing,
              onPressed: isSyncing
                  ? null
                  : () => ref.read(offlineItemsProvider.notifier).sync(),
            ),
          ),
          const SizedBox(width: 16),
          _PendingSyncCount(pendingCount: pendingCount),
        ],
      ),
    );
  }
}

class _SyncButton extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback? onPressed;

  const _SyncButton({
    required this.isSyncing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: isSyncing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: _SyncingProgressIndicator(),
            )
          : const Icon(Icons.sync, size: 20),
      label: Text(
        isSyncing ? '同步中...' : '立即同步',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppTheme.primaryGold.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _SyncingProgressIndicator extends StatelessWidget {
  const _SyncingProgressIndicator();

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
    );
  }
}

class _PendingSyncCount extends StatelessWidget {
  final int pendingCount;

  const _PendingSyncCount({
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPending = pendingCount > 0;
    final color = hasPending ? AppTheme.warning : AppTheme.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasPending ? Icons.pending : Icons.check_circle,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            hasPending ? '待同步: $pendingCount 个' : '全部已同步',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
