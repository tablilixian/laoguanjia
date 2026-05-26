import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// 主动收入确认弹窗
///
/// 当 Δ净资产 ≥ ¥100 时弹出，询问用户是否包含主动收入。
Future<double?> showActiveIncomeDialog(
  BuildContext context, {
  required double netWorthChange,
}) {
  final controller = TextEditingController();
  final formatter = NumberFormat('#,###');

  return showDialog<double>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('收入确认'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本次净资产新增 ¥${formatter.format(netWorthChange)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '是否包含主动收入？（如工资、奖金、红包等）\n留空则全部算作被动收入。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: InputDecoration(
                labelText: '主动收入金额',
                prefixText: '¥ ',
                border: const OutlineInputBorder(),
                hintText: '0',
                suffixText: netWorthChange > 0
                    ? '（剩余 ¥${formatter.format(netWorthChange)} 算被动收入）'
                    : null,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('跳过'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              final amount = text.isNotEmpty ? double.tryParse(text) ?? 0 : 0;
              Navigator.of(context).pop(amount);
            },
            child: const Text('确认'),
          ),
        ],
      );
    },
  );
}
