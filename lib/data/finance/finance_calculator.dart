import 'models/finance_snapshot.dart';

/// 月度财务指标
class MonthlyMetrics {
  final int year;
  final int month;
  final double totalIncome; // 主动收入 + 被动收入
  final double activeIncome;
  final double passiveIncome;
  final double totalExpense;
  final double netWorthChange; // 本月净资产变化
  final double savingsRate; // 储蓄率

  const MonthlyMetrics({
    required this.year,
    required this.month,
    required this.totalIncome,
    required this.activeIncome,
    required this.passiveIncome,
    required this.totalExpense,
    required this.netWorthChange,
    required this.savingsRate,
  });

  /// 被动收入覆盖率
  double get passiveIncomeCoverageRatio {
    if (totalExpense <= 0) return 0;
    return passiveIncome / totalExpense;
  }

  /// 格式化百分比显示 (0.02 → "2.0%")
  String get coverageRatioPercent =>
      '${(passiveIncomeCoverageRatio * 100).toStringAsFixed(1)}%';

  /// 格式化储蓄率
  String get savingsRatePercent =>
      '${(savingsRate * 100).toStringAsFixed(1)}%';
}

/// 快照范围（用于获取某时间范围内的快照）
class SnapshotRange {
  final DateTime start;
  final DateTime end;
  final List<FinanceSnapshot> beforeRange; // 范围之前的最新快照(用于计算期初净资产)
  final List<FinanceSnapshot> inRange; // 范围内的快照

  const SnapshotRange({
    required this.start,
    required this.end,
    required this.beforeRange,
    required this.inRange,
  });
}

/// 核心指标计算器
class FinanceCalculator {
  /// 获取某个月份的起止时间
  static (DateTime, DateTime) _monthRange(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    return (start, end);
  }

  /// 计算某个账户在某时间点的净资产
  /// 通过查找该时间点之前的最新快照
  static double netWorthAt(
    List<FinanceSnapshot> snapshots,
    String accountId,
    DateTime at,
  ) {
    final relevant = snapshots
        .where((s) =>
            s.accountId == accountId && !s.recordDate.isAfter(at))
        .toList()
      ..sort((a, b) => b.recordDate.compareTo(a.recordDate));

    if (relevant.isEmpty) return 0;
    return relevant.first.netWorth;
  }

  /// 计算某月的净资产变化
  /// 月末净资产 - 月初净资产 = 本月净增
  static double _netWorthChange(
    List<FinanceSnapshot> allSnapshots,
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    // 获取所有账户 ID
    final accountIds = allSnapshots.map((s) => s.accountId).toSet();

    double startNetWorth = 0;
    double endNetWorth = 0;

    for (final accountId in accountIds) {
      startNetWorth += netWorthAt(allSnapshots, accountId, monthStart);
      endNetWorth += netWorthAt(allSnapshots, accountId, monthEnd);
    }

    return endNetWorth - startNetWorth;
  }

  /// 计算指定月份的财务指标
  static MonthlyMetrics calculateMonthly(
    List<FinanceSnapshot> allSnapshots,
    int year,
    int month,
  ) {
    final (monthStart, monthEnd) = _monthRange(year, month);

    // 筛选本月快照
    final monthSnapshots = allSnapshots.where((s) {
      final date = s.recordDate;
      // 包括本月的快照，以及本月资产变化涉及的上月快照
      return !date.isBefore(monthStart) && date.isBefore(monthEnd);
    }).toList();

    // 计算主动收入（本月快照中用户确认的）
    final activeIncome =
        monthSnapshots.fold<double>(0, (sum, s) => sum + s.activeIncome);

    // 计算净资产变化
    final netWorthDelta =
        _netWorthChange(allSnapshots, monthStart, monthEnd);

    // 被动收入 = 净资产变化 - 主动收入
    // 注意：净资产变化为负时，被动收入也可能为负（投资亏损）
    // 但更常见的场景是：净资产变化 < 主动收入，说明有支出
    // 被动收入 = (月末净资产 - 月初净资产) - 主动收入
    // 这个公式在家庭层面是精确的（跨账户转账相互抵消）
    final passiveIncome = netWorthDelta - activeIncome;

    // 总支出
    // 公式：总支出 = 总收入 - 净资产变化
    // 推导：收入 - 支出 = 净资产变化 → 支出 = 收入 - 净资产变化
    final totalIncome = activeIncome + passiveIncome;
    final totalExpense = totalIncome - netWorthDelta;

    // 储蓄率
    final savingsRate =
        totalIncome > 0 ? netWorthDelta / totalIncome : 0.0;

    return MonthlyMetrics(
      year: year,
      month: month,
      totalIncome: totalIncome,
      activeIncome: activeIncome,
      passiveIncome: passiveIncome,
      totalExpense: totalExpense > 0 ? totalExpense : 0,
      netWorthChange: netWorthDelta,
      savingsRate: savingsRate,
    );
  }

  /// 获取所有有数据的月份列表（降序）
  static List<(int, int)> getAvailableMonths(
    List<FinanceSnapshot> snapshots,
  ) {
    final months = <(int, int)>{};
    for (final s in snapshots) {
      months.add((s.recordDate.year, s.recordDate.month));
    }
    final sorted = months.toList()
      ..sort((a, b) {
        if (a.$1 != b.$1) return b.$1.compareTo(a.$1);
        return b.$2.compareTo(a.$2);
      });
    return sorted;
  }
}
