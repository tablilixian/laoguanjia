import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/finance/finance_calculator.dart';
import '../../../data/finance/models/finance_account.dart';
import '../../../data/finance/models/finance_snapshot.dart';
import '../../../data/models/member.dart';
import 'finance_providers.dart';

class MemberNetWorthPoint {
  final int year;
  final int month;
  final double netWorth;

  const MemberNetWorthPoint({
    required this.year,
    required this.month,
    required this.netWorth,
  });

  int get monthIndex => year * 12 + month;
  String get monthLabel => '${year % 100}/$month';
}

class MemberChartSeries {
  final Member member;
  final Color color;
  final List<MemberNetWorthPoint> points;

  const MemberChartSeries({
    required this.member,
    required this.color,
    required this.points,
  });
}

const chartColors = [
  Color(0xFF4C9AFF),
  Color(0xFF34C759),
  Color(0xFFFF9500),
  Color(0xFFAF52DE),
  Color(0xFF5AC8FA),
  Color(0xFFFF2D55),
  Color(0xFF5856D6),
  Color(0xFF00C7BE),
];

final memberNetWorthTrendProvider = FutureProvider<List<MemberChartSeries>>((ref) async {
  final data = await ref.watch(financeDataProvider.future);
  final members = ref.watch(memberListProvider);

  final months = FinanceCalculator.getAvailableMonths(data.snapshots);
  final sortedMonths = [...months]..sort((a, b) {
    final aIdx = a.$1 * 12 + a.$2;
    final bIdx = b.$1 * 12 + b.$2;
    return aIdx.compareTo(bIdx);
  });

  final accountsByMember = <String, List<FinanceAccount>>{};
  for (final account in data.accounts) {
    accountsByMember.putIfAbsent(account.memberId, () => []).add(account);
  }

  final result = <MemberChartSeries>[];
  for (var i = 0; i < members.length; i++) {
    final member = members[i];
    final memberAccounts = accountsByMember[member.id] ?? [];
    if (memberAccounts.isEmpty) continue;

    final accountIds = memberAccounts.map((a) => a.id).toSet();
    final points = <MemberNetWorthPoint>[];

    for (final (year, month) in sortedMonths) {
      final monthEnd = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
      double totalNetWorth = 0;
      for (final accountId in accountIds) {
        totalNetWorth += FinanceCalculator.netWorthAt(data.snapshots, accountId, monthEnd);
      }
      points.add(MemberNetWorthPoint(year: year, month: month, netWorth: totalNetWorth));
    }

    if (points.isNotEmpty) {
      result.add(MemberChartSeries(
        member: member,
        color: chartColors[i % chartColors.length],
        points: points,
      ));
    }
  }

  return result;
});

final memberNetWorthPieProvider = FutureProvider<Map<Member, double>>((ref) async {
  final data = await ref.watch(financeDataProvider.future);
  final members = ref.watch(memberListProvider);

  final latestByAccount = <String, FinanceSnapshot>{};
  for (final snapshot in data.snapshots) {
    final existing = latestByAccount[snapshot.accountId];
    if (existing == null || snapshot.recordDate.isAfter(existing.recordDate)) {
      latestByAccount[snapshot.accountId] = snapshot;
    }
  }

  final result = <Member, double>{};
  for (final member in members) {
    final memberAccounts = data.accounts.where((a) => a.memberId == member.id);
    double total = 0;
    for (final account in memberAccounts) {
      final latest = latestByAccount[account.id];
      if (latest != null) {
        total += latest.netWorth;
      }
    }
    if (total != 0) {
      result[member] = total;
    }
  }

  return result;
});

final passiveIncomeTrendProvider = FutureProvider<List<({int year, int month, double value})>>((ref) async {
  final months = await ref.watch(availableMonthsProvider.future);
  final sortedMonths = [...months]..sort((a, b) {
    final aIdx = a.$1 * 12 + a.$2;
    final bIdx = b.$1 * 12 + b.$2;
    return aIdx.compareTo(bIdx);
  });

  final result = <({int year, int month, double value})>[];
  for (final (year, month) in sortedMonths) {
    final metrics = await ref.watch(monthlyMetricsProvider((year: year, month: month)).future);
    if (metrics != null) {
      result.add((year: year, month: month, value: metrics.passiveIncome));
    }
  }
  return result;
});
