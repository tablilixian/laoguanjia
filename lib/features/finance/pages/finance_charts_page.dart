import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../data/models/member.dart';
import '../providers/finance_chart_providers.dart';
import '../providers/finance_providers.dart';

class FinanceChartsPage extends ConsumerStatefulWidget {
  const FinanceChartsPage({super.key});

  @override
  ConsumerState<FinanceChartsPage> createState() => _FinanceChartsPageState();
}

class _FinanceChartsPageState extends ConsumerState<FinanceChartsPage> {
  final Set<String> _selectedMembers = {};
  final _fmt = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trendAsync = ref.watch(memberNetWorthTrendProvider);
    final pieAsync = ref.watch(memberNetWorthPieProvider);
    final passiveIncomeAsync = ref.watch(passiveIncomeTrendProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('财务图表')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financeDataProvider);
          await ref.read(financeDataProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle(theme, '成员净资产趋势'),
            const SizedBox(height: 8),
            trendAsync.when(
              data: (series) => _buildMemberTrendChart(theme, series),
              loading: () => const _ChartLoading(),
              error: (_, __) => const _ChartEmpty(),
            ),
            const SizedBox(height: 32),

            _sectionTitle(theme, '净资产分布'),
            const SizedBox(height: 8),
            pieAsync.when(
              data: (data) => _buildPieChart(theme, data),
              loading: () => const _ChartLoading(),
              error: (_, __) => const _ChartEmpty(),
            ),
            const SizedBox(height: 32),

            _sectionTitle(theme, '被动收入趋势'),
            const SizedBox(height: 8),
            passiveIncomeAsync.when(
              data: (data) => _buildPassiveIncomeChart(theme, data),
              loading: () => const _ChartLoading(),
              error: (_, __) => const _ChartEmpty(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  // ==================== 成员趋势折线图 ====================

  Widget _buildMemberTrendChart(ThemeData theme, List<MemberChartSeries> series) {
    if (series.isEmpty) return const _ChartEmpty();

    if (_selectedMembers.isEmpty) {
      _selectedMembers.addAll(series.map((s) => s.member.id));
    }

    final visibleSeries = series.where((s) => _selectedMembers.contains(s.member.id)).toList();
    if (visibleSeries.isEmpty) return const _ChartEmpty();

    final allPoints = series.expand((s) => s.points).toList();
    final minY = allPoints.map((p) => p.netWorth).reduce((a, b) => a < b ? a : b);
    final maxY = allPoints.map((p) => p.netWorth).reduce((a, b) => a > b ? a : b);
    final yPadding = (maxY - minY) * 0.15;
    final yMin = minY - yPadding;
    final yMax = maxY + yPadding;

    final xLabels = <int>[];
    final labelTexts = <String>[];
    if (series.isNotEmpty && series.first.points.isNotEmpty) {
      for (var i = 0; i < series.first.points.length; i++) {
        xLabels.add(i);
        labelTexts.add(series.first.points[i].monthLabel);
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 280,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _niceInterval(yMin, yMax),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: xLabels.length > 6 ? (xLabels.length / 5).ceilToDouble() : 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labelTexts.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labelTexts[idx],
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 64,
                        interval: _niceInterval(yMin, yMax),
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              _formatAxisY(value),
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (xLabels.length - 1).toDouble(),
                  minY: yMin,
                  maxY: yMax,
                  lineBarsData: visibleSeries.map((s) {
                    return LineChartBarData(
                      spots: s.points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.netWorth)).toList(),
                      color: s.color,
                      barWidth: 2.5,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      dotData: FlDotData(
                        show: s.points.length <= 12,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 3,
                          color: s.color,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(show: false),
                    );
                  }).toList(),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final s = visibleSeries[spot.barIndex];
                          return LineTooltipItem(
                            '${s.member.name}\n¥${_fmt.format(spot.y)}',
                            TextStyle(
                              color: s.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: series.map((s) {
                final selected = _selectedMembers.contains(s.member.id);
                return FilterChip(
                  label: Text(
                    s.member.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? null : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  selected: selected,
                  selectedColor: s.color.withValues(alpha: 0.15),
                  checkmarkColor: s.color,
                  side: BorderSide(color: selected ? s.color : theme.dividerColor),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedMembers.add(s.member.id);
                      } else {
                        _selectedMembers.remove(s.member.id);
                      }
                    });
                  },
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 净资产分布饼图 ====================

  Widget _buildPieChart(ThemeData theme, Map<Member, double> data) {
    if (data.isEmpty) return const _ChartEmpty();

    final total = data.values.fold<double>(0, (a, b) => a + b);
    final colors = chartColors;

    final sections = data.entries.toList().asMap().entries.map((e) {
      final idx = e.key;
      final entry = e.value;
      final percentage = (entry.value / total * 100);
      return PieChartSectionData(
        value: entry.value,
        color: colors[idx % colors.length],
        radius: 60,
        title: '${percentage.toStringAsFixed(1)}%',
        titleStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: null,
      );
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: data.entries.toList().asMap().entries.map((e) {
                final idx = e.key;
                final entry = e.value;
                final percentage = (entry.value / total * 100);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[idx % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.key.name}  ${percentage.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 被动收入趋势折线图 ====================

  Widget _buildPassiveIncomeChart(ThemeData theme, List<({int year, int month, double value})> data) {
    if (data.isEmpty) return const _ChartEmpty();

    final minY = data.map((d) => d.value).reduce((a, b) => a < b ? a : b);
    final maxY = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final yPadding = (maxY - minY) * 0.2;
    final yMin = (minY - yPadding).clamp(0.0, double.infinity);
    final yMax = maxY + yPadding;

    final chartColor = Colors.green;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _niceInterval(yMin, yMax),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: data.length > 6 ? (data.length / 5).ceilToDouble() : 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                          final d = data[idx];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${d.year % 100}/${d.month}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 64,
                        interval: _niceInterval(yMin, yMax),
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              _formatAxisY(value),
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (data.length - 1).toDouble(),
                  minY: yMin,
                  maxY: yMax,
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                      color: chartColor,
                      barWidth: 3,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      dotData: FlDotData(
                        show: data.length <= 12,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 4,
                          color: chartColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: chartColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final d = data[spot.spotIndex];
                          return LineTooltipItem(
                            '${d.year}年${d.month}月\n¥${_fmt.format(spot.y)}',
                            TextStyle(
                              color: chartColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 辅助方法 ====================

  double _niceInterval(double min, double max) {
    final range = max - min;
    if (range <= 0) return 1;
    final rough = range / 4;
    final magnitude = pow(10, (log(rough) / ln10).floor()).toDouble();
    final residual = rough / magnitude;
    double nice;
    if (residual <= 1.5) {
      nice = 1;
    } else if (residual <= 3.5) {
      nice = 2;
    } else if (residual <= 7.5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * magnitude;
  }

  String _formatAxisY(double value) {
    if (value.abs() >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    return '${value.toInt()}';
  }
}

// ==================== 通用小组件 ====================

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '暂无数据',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
