import 'package:flutter/material.dart';

/// 宠物状态条组件
///
/// 圆角进度条，颜色随值变化 (绿→黄→红)，带动画效果。
class PetStatusBar extends StatelessWidget {
  final String label;
  final int value;
  final String icon;

  const PetStatusBar({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  Color _getColor() {
    if (value > 60) return const Color(0xFF4CAF50);
    if (value > 30) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5D4037),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                height: 10,
                color: _getColor().withValues(alpha: 0.2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value / 100,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getColor(),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '$value%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
