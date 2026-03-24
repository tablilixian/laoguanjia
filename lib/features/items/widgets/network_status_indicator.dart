import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class NetworkStatusIndicator extends StatelessWidget {
  final bool isOnline;

  const NetworkStatusIndicator({
    super.key,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isOnline ? AppTheme.success : AppTheme.error;
    final icon = isOnline ? Icons.cloud_done : Icons.cloud_off;
    final label = isOnline ? '在线' : '离线';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
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
