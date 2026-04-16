// 地产大亨 - 游戏Toast组件
import 'package:flutter/material.dart';

/// Toast类型
enum GameToastType {
  /// 资金收入（绿色，向上箭头）
  moneyIncome,

  /// 资金支出（红色，向下箭头）
  moneyExpense,

  /// 抽卡结果（紫色）
  card,

  /// 警告（橙色）
  warning,

  /// 错误/禁止（红色）
  error,

  /// 成功（绿色）
  success,

  /// 信息（蓝色）
  info,

  /// 特殊事件（橙色，对子、入狱等）
  special,
}

/// Toast数据
class GameToast {
  final String id;
  final GameToastType type;
  final String title;
  final String? subtitle;
  final int? amount; // 金额变化，正数为收入，负数为支出
  final Duration duration;
  final DateTime createdAt;

  GameToast({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.amount,
    Duration? duration,
    DateTime? createdAt,
  }) : duration = duration ?? const Duration(milliseconds: 2000),
       createdAt = createdAt ?? DateTime.now();

  /// 是否是资金相关
  bool get isMoney => amount != null && amount != 0;

  /// 资金变化符号
  String get moneySign => (amount ?? 0) > 0 ? '+' : '';
}

/// 单个Toast组件
class GameToastWidget extends StatefulWidget {
  final GameToast toast;
  final VoidCallback onDismiss;

  const GameToastWidget({
    super.key,
    required this.toast,
    required this.onDismiss,
  });

  @override
  State<GameToastWidget> createState() => _GameToastWidgetState();
}

class _GameToastWidgetState extends State<GameToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 从上方滑入
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // 自动消失
    Future.delayed(
      widget.toast.duration - const Duration(milliseconds: 300),
      () {
        if (mounted) {
          _controller.reverse().then((_) {
            if (mounted) {
              widget.onDismiss();
            }
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    switch (widget.toast.type) {
      case GameToastType.moneyIncome:
        return const Color(0xFF4CAF50);
      case GameToastType.moneyExpense:
        return const Color(0xFFF44336);
      case GameToastType.card:
        return const Color(0xFF9C27B0);
      case GameToastType.warning:
        return const Color(0xFFFF9800);
      case GameToastType.error:
        return const Color(0xFFD32F2F);
      case GameToastType.success:
        return const Color(0xFF388E3C);
      case GameToastType.info:
        return const Color(0xFF1976D2);
      case GameToastType.special:
        return const Color(0xFFFF5722);
    }
  }

  IconData get _icon {
    switch (widget.toast.type) {
      case GameToastType.moneyIncome:
        return Icons.arrow_upward;
      case GameToastType.moneyExpense:
        return Icons.arrow_downward;
      case GameToastType.card:
        return Icons.style;
      case GameToastType.warning:
        return Icons.warning_amber;
      case GameToastType.error:
        return Icons.block;
      case GameToastType.success:
        return Icons.check_circle;
      case GameToastType.info:
        return Icons.info;
      case GameToastType.special:
        return Icons.casino;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = (widget.toast.amount ?? 0) > 0;
    final isNegative = (widget.toast.amount ?? 0) < 0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(_icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              // 内容
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.toast.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.toast.subtitle != null)
                      Text(
                        widget.toast.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // 金额显示
              if (isPositive || isNegative) ...[
                const SizedBox(width: 8),
                Text(
                  '${widget.toast.moneySign}${widget.toast.amount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
