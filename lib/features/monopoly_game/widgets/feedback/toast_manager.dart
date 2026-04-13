// 地产大亨 - Toast管理器
import 'package:flutter/material.dart';
import 'game_toast.dart';

/// Toast管理器
class ToastManager extends ChangeNotifier {
  static ToastManager? _instance;
  static ToastManager get instance => _instance ??= ToastManager._();

  ToastManager._();

  final List<GameToast> _toasts = [];

  /// 获取所有Toast
  List<GameToast> get toasts => List.unmodifiable(_toasts);

  /// 是否有Toast显示
  bool get hasToasts => _toasts.isNotEmpty;

  /// Toast数量
  int get count => _toasts.length;

  /// 添加Toast
  void show({
    required GameToastType type,
    required String title,
    String? subtitle,
    int? amount,
    Duration? duration,
  }) {
    final toast = GameToast(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      subtitle: subtitle,
      amount: amount,
      duration: duration,
    );
    _toasts.add(toast);
    notifyListeners();
  }

  /// 移除Toast
  void dismiss(String id) {
    _toasts.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// 清空所有Toast
  void clear() {
    _toasts.clear();
    notifyListeners();
  }

  /// 便捷方法：资金收入
  void showMoneyIncome({required String reason, required int amount}) {
    show(
      type: GameToastType.moneyIncome,
      title: '恭喜获得 \$$amount',
      subtitle: reason,
      amount: amount,
    );
  }

  /// 便捷方法：资金支出
  void showMoneyExpense({required String reason, required int amount}) {
    show(
      type: GameToastType.moneyExpense,
      title: '支付 \$$amount',
      subtitle: reason,
      amount: -amount,
    );
  }

  /// 便捷方法：资金变化（自动判断正负）
  void showMoneyChange({
    required String reason,
    required int amount,
    Duration? duration,
  }) {
    if (amount > 0) {
      showMoneyIncome(reason: reason, amount: amount);
    } else if (amount < 0) {
      showMoneyExpense(reason: reason, amount: amount.abs());
    }
  }

  /// 便捷方法：抽卡结果
  void showCard({
    required String cardTitle,
    required String description,
    int? amount,
  }) {
    show(
      type: GameToastType.card,
      title: cardTitle,
      subtitle: description,
      amount: amount,
      duration: const Duration(milliseconds: 2500),
    );
  }

  /// 便捷方法：警告
  void showWarning({required String title, String? subtitle}) {
    show(type: GameToastType.warning, title: title, subtitle: subtitle);
  }

  /// 便捷方法：错误
  void showError({required String title, String? subtitle}) {
    show(type: GameToastType.error, title: title, subtitle: subtitle);
  }

  /// 便捷方法：成功
  void showSuccess({required String title, String? subtitle}) {
    show(type: GameToastType.success, title: title, subtitle: subtitle);
  }

  /// 便捷方法：特殊事件
  void showSpecial({
    required String title,
    String? subtitle,
    Duration? duration,
  }) {
    show(
      type: GameToastType.special,
      title: title,
      subtitle: subtitle,
      duration: duration ?? const Duration(milliseconds: 2500),
    );
  }

  /// 便捷方法：对子提示
  void showDoubles({required int consecutiveCount}) {
    show(
      type: GameToastType.special,
      title: '🎲 对子！再掷一次！',
      subtitle: '连续$consecutiveCount次，3次后入狱',
    );
  }

  /// 便捷方法：入狱
  void showGoToJail() {
    showSpecial(title: '🚫 被送进派出所！', subtitle: '请等待下回合');
  }

  /// 便捷方法：购买成功
  void showBuySuccess({required String propertyName, required int price}) {
    show(
      type: GameToastType.success,
      title: '🏠 购买成功',
      subtitle: propertyName,
      amount: -price,
    );
  }

  /// 便捷方法：建造成功
  void showBuildSuccess({
    required String propertyName,
    required int houses,
    required int price,
  }) {
    final houseText = houses >= 5 ? '酒店' : '${houses}栋房屋';
    show(
      type: GameToastType.success,
      title: '🏗️ 建造成功',
      subtitle: '$propertyName ($houseText)',
      amount: -price,
    );
  }

  /// 便捷方法：现金不足
  void showCashNotEnough({required int needed, required int have}) {
    show(
      type: GameToastType.warning,
      title: '💰 现金不足',
      subtitle: '需要 \$$needed，只有 \$$have',
    );
  }

  /// 便捷方法：无法建造（不满足条件）
  void showCannotBuild({required String reason}) {
    showWarning(title: '⚠️ 无法建造', subtitle: reason);
  }
}

/// Toast显示层组件
class GameToastOverlay extends StatelessWidget {
  final ToastManager manager;

  const GameToastOverlay({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, child) {
        final toasts = manager.toasts;
        if (toasts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 56, // AppBar下方
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: toasts.map((toast) {
              return GameToastWidget(
                key: ValueKey(toast.id),
                toast: toast,
                onDismiss: () => manager.dismiss(toast.id),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
