import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../data/finance/finance_snapshot_analyzer.dart';
import '../../../data/finance/finance_storage.dart';
import '../../../data/finance/models/finance_snapshot.dart';
import '../../household/providers/household_provider.dart';
import '../providers/finance_providers.dart';
import '../widgets/active_income_dialog.dart';

class SnapshotCreatePage extends ConsumerStatefulWidget {
  const SnapshotCreatePage({super.key});

  @override
  ConsumerState<SnapshotCreatePage> createState() =>
      _SnapshotCreatePageState();
}

class _SnapshotCreatePageState extends ConsumerState<SnapshotCreatePage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedAccountId;
  final _assetController = TextEditingController();
  final _liabilityController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _assetController.dispose();
    _liabilityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(financeAccountsProvider);
    final members = ref.watch(memberListProvider);
    final memberMap = {for (final m in members) m.id: m};

    // 如果从账户详情页传入 accountId，预填
    final extraAccountId =
        GoRouterState.of(context).extra is Map
            ? (GoRouterState.of(context).extra as Map)['accountId'] as String?
            : null;

    if (extraAccountId != null && _selectedAccountId == null) {
      _selectedAccountId = extraAccountId;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('录快照'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 选择账户
            accountsAsync.when(
              data: (accounts) {
                // 构建带成员前缀的平铺列表
                final items = accounts.map((a) {
                  final memberName =
                      memberMap[a.memberId]?.name ?? '未知';
                  return DropdownMenuItem<String>(
                    value: a.id,
                    child: Text('$memberName · ${a.name} (${a.type.label})'),
                  );
                }).toList();

                return DropdownButtonFormField<String>(
                  initialValue: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: '选择账户',
                    border: OutlineInputBorder(),
                  ),
                  items: items,
                  onChanged: (v) {
                    setState(() => _selectedAccountId = v);
                  },
                  validator: (v) =>
                      v == null ? '请选择账户' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('加载账户失败'),
            ),
            const SizedBox(height: 16),

            // 资产金额
            TextFormField(
              controller: _assetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '当前资产余额',
                hintText: '如: 50000',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入资产余额';
                if (double.tryParse(v) == null) return '请输入有效数字';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 负债金额
            TextFormField(
              controller: _liabilityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '当前负债金额（可选）',
                hintText: '信用卡账单、贷款等',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 备注
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                hintText: '如：发工资了、买了家电...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // 保存按钮
            FilledButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? '保存中...' : '保存快照'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final householdId =
        ref.read(householdProvider).currentHousehold?.id;
    if (householdId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先加入家庭')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final assetAmount =
          double.parse(_assetController.text.trim());
      final liabilityAmount = _liabilityController.text.trim().isNotEmpty
          ? double.parse(_liabilityController.text.trim())
          : 0.0;

      final newSnapshot = FinanceSnapshot(
        id: const Uuid().v4(),
        accountId: _selectedAccountId!,
        recordDate: DateTime.now(),
        assetAmount: assetAmount,
        liabilityAmount: liabilityAmount,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      // 智能分析
      final previous = await FinanceStorage.instance
          .getLatestSnapshot(householdId, _selectedAccountId!);
      final analysis = FinanceSnapshotAnalyzer.analyze(
        newSnapshot: newSnapshot,
        previousSnapshot: previous,
      );

      double activeIncome = 0;

      // 大额增长：弹窗询问
      if (analysis.isAskActiveIncome && mounted) {
        final result = await showActiveIncomeDialog(
          context,
          netWorthChange: analysis.netWorthChange,
        );
        activeIncome = result ?? 0;
      }

      // 保存
      final finalSnapshot = FinanceSnapshot(
        id: newSnapshot.id,
        accountId: newSnapshot.accountId,
        recordDate: newSnapshot.recordDate,
        assetAmount: newSnapshot.assetAmount,
        liabilityAmount: newSnapshot.liabilityAmount,
        activeIncome: activeIncome,
        notes: newSnapshot.notes,
      );

      await FinanceStorage.instance
          .addSnapshot(householdId, finalSnapshot);

      ref.invalidate(financeDataProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('快照保存成功')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
