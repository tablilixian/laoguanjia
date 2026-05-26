import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/finance/finance_calculator.dart';
import '../../../data/finance/finance_storage.dart';
import '../../../data/finance/models/finance_account.dart';
import '../../../data/finance/models/finance_data.dart';
import '../../../data/finance/models/finance_snapshot.dart';
import '../../household/providers/household_provider.dart';

// ==================== 基础 Provider ====================

/// Storage 单例注入
final financeStorageProvider = Provider<FinanceStorage>((ref) {
  return FinanceStorage.instance;
});

/// 当前家庭 ID
final _currentHouseholdIdProvider = Provider<String?>((ref) {
  final householdState = ref.watch(householdProvider);
  return householdState.currentHousehold?.id;
});

/// 完整财务数据
final financeDataProvider = FutureProvider<FinanceData>((ref) async {
  final householdId = ref.watch(_currentHouseholdIdProvider);
  if (householdId == null) return FinanceData.empty();
  final storage = ref.watch(financeStorageProvider);
  return storage.load(householdId);
});

/// 数据刷新（调用 invalidate 触发重新加载）
final financeRefreshProvider = Provider<void>((ref) {
  ref.invalidate(financeDataProvider);
});

// ==================== 账户 Provider ====================

/// 所有账户列表
final financeAccountsProvider = FutureProvider<List<FinanceAccount>>((ref) async {
  final data = await ref.watch(financeDataProvider.future);
  return data.accounts;
});

/// 成员 → 账户映射
final memberAccountsProvider =
    FutureProvider.family<List<FinanceAccount>, String>((ref, memberId) async {
  final data = await ref.watch(financeDataProvider.future);
  return data.accounts.where((a) => a.memberId == memberId).toList();
});

// ==================== 快照 Provider ====================

/// 所有快照
final financeSnapshotsProvider = FutureProvider<List<FinanceSnapshot>>((ref) async {
  final data = await ref.watch(financeDataProvider.future);
  return data.snapshots;
});

/// 某个账户的快照
final accountSnapshotsProvider =
    FutureProvider.family<List<FinanceSnapshot>, String>(
        (ref, accountId) async {
  final data = await ref.watch(financeDataProvider.future);
  final snapshots =
      data.snapshots.where((s) => s.accountId == accountId).toList()
        ..sort((a, b) => b.recordDate.compareTo(a.recordDate));
  return snapshots;
});

/// 某个账户的最新快照
final latestSnapshotProvider =
    FutureProvider.family<FinanceSnapshot?, String>((ref, accountId) async {
  final accountIdValue = accountId;
  final snapshots = await ref.watch(accountSnapshotsProvider(accountIdValue).future);
  return snapshots.isNotEmpty ? snapshots.first : null;
});

// ==================== 指标计算 Provider ====================

/// 月度财务指标
final monthlyMetricsProvider =
    FutureProvider.family<MonthlyMetrics?, ({int year, int month})>(
        (ref, params) async {
  final data = await ref.watch(financeDataProvider.future);
  return FinanceCalculator.calculateMonthly(data.snapshots, params.year, params.month);
});

/// 当前月份的指标
final currentMonthMetricsProvider = FutureProvider<MonthlyMetrics?>((ref) async {
  final now = DateTime.now();
  final asyncValue = ref.watch(
    monthlyMetricsProvider((year: now.year, month: now.month)),
  );
  return asyncValue.valueOrNull;
});

/// 获取所有有数据的月份
final availableMonthsProvider = FutureProvider<List<(int, int)>>((ref) async {
  final data = await ref.watch(financeDataProvider.future);
  return FinanceCalculator.getAvailableMonths(data.snapshots);
});

// ==================== 汇总指标 ====================

/// 总资产（所有账户最新快照的 assetAmount 之和）
final totalAssetsProvider = FutureProvider<double>((ref) async {
  final data = await ref.watch(financeDataProvider.future);
  final accountIds = data.accounts.map((a) => a.id).toSet();
  double total = 0;
  for (final accountId in accountIds) {
    final latest = await ref.watch(latestSnapshotProvider(accountId).future);
    if (latest != null) {
      total += latest.assetAmount;
    }
  }
  return total;
});

/// 总负债（所有账户最新快照的 liabilityAmount 之和）
final totalLiabilitiesProvider = FutureProvider<double>((ref) async {
  final data = await ref.watch(financeDataProvider.future);
  final accountIds = data.accounts.map((a) => a.id).toSet();
  double total = 0;
  for (final accountId in accountIds) {
    final latest = await ref.watch(latestSnapshotProvider(accountId).future);
    if (latest != null) {
      total += latest.liabilityAmount;
    }
  }
  return total;
});

/// 总净资产（所有账户最新快照的 netWorth 之和）
final totalNetWorthProvider = FutureProvider<double>((ref) async {
  final data = await ref.watch(financeDataProvider.future);
  final accountIds = data.accounts.map((a) => a.id).toSet();
  double total = 0;
  for (final accountId in accountIds) {
    final latest = await ref.watch(latestSnapshotProvider(accountId).future);
    if (latest != null) {
      total += latest.netWorth;
    }
  }
  return total;
});

/// 家庭成员列表（从 householdProvider 获取）
final memberListProvider = Provider((ref) {
  final householdState = ref.watch(householdProvider);
  return householdState.members;
});
