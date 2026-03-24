import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class OptimizedRefreshIndicator extends StatelessWidget {
  final Widget child;
  final RefreshCallback onRefresh;
  final String? refreshingText;
  final String? completeText;

  const OptimizedRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshingText,
    this.completeText,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryGold,
      backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.1),
      displacement: 40.0,
      strokeWidth: 2.5,
      child: child,
    );
  }
}

class SyncRefreshProgress extends StatefulWidget {
  final int syncedCount;
  final int totalCount;
  final String? message;

  const SyncRefreshProgress({
    super.key,
    required this.syncedCount,
    required this.totalCount,
    this.message,
  });

  @override
  State<SyncRefreshProgress> createState() => _SyncRefreshProgressState();
}

class _SyncRefreshProgressState extends State<SyncRefreshProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.totalCount > 0 ? widget.syncedCount / widget.totalCount : 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(SyncRefreshProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncedCount != widget.syncedCount ||
        oldWidget.totalCount != widget.totalCount) {
      final targetProgress =
          widget.totalCount > 0 ? widget.syncedCount / widget.totalCount : 0.0;
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: targetProgress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _progressAnimation.value;
    final percentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.message ?? '正在同步...',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已同步: ${widget.syncedCount}/${widget.totalCount} 个物品',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progressAnimation.value,
                  backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryGold,
                  ),
                  minHeight: 4,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Text(
                '$percentage%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
