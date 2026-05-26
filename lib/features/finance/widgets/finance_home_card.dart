import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/finance_providers.dart';

/// 首页财务概览卡片
///
/// 展示：总资产/总负债/净资产、财富自由进度条、资产增长金币动画
class FinanceHomeCard extends ConsumerStatefulWidget {
  const FinanceHomeCard({super.key});

  @override
  ConsumerState<FinanceHomeCard> createState() => _FinanceHomeCardState();
}

class _FinanceHomeCardState extends ConsumerState<FinanceHomeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final _particles = <_CoinParticle>[];
  final _random = Random();
  final _fmt = NumberFormat('#,###');
  double _dailyEstimate = 0;
  int _particleCounter = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _animController.addListener(_spawnParticles);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _spawnParticles() {
    // 每 2-4 秒生成一个粒子
    if (_dailyEstimate <= 0) return;
    if (_random.nextDouble() > 0.008) return; // ~3s interval at 60fps

    final id = _particleCounter++;
    final startX = 40 + _random.nextDouble() * 200;
    final amount = _dailyEstimate / 5; // 每粒子表示约 1/5 日均
    final isPositive = amount >= 0;

    setState(() {
      _particles.add(_CoinParticle(
        id: id,
        startX: startX,
        amount: amount,
        isPositive: isPositive,
        birthTime: DateTime.now(),
      ));
    });

    // 3.5s 后移除
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _particles.removeWhere((p) => p.id == id);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetsAsync = ref.watch(totalAssetsProvider);
    final liabilitiesAsync = ref.watch(totalLiabilitiesProvider);
    final netWorthAsync = ref.watch(totalNetWorthProvider);
    final metricsAsync = ref.watch(currentMonthMetricsProvider);

    // 计算日均增长
    metricsAsync.whenData((metrics) {
      if (metrics != null) {
        final daysInMonth = DateTime(metrics.year, metrics.month + 1, 0).day;
        final day = DateTime.now().day;
        final daysPassed = day.clamp(1, daysInMonth);
        _dailyEstimate = metrics.netWorthChange / daysPassed;
      }
    });

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/home/finance'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.05),
                theme.colorScheme.tertiary.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Stack(
            children: [
              // 粒子层
              ..._particles.map((p) => _buildParticleWidget(p, theme)),
              // 内容层
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 16),
                  _buildAssetSection(theme, assetsAsync, liabilitiesAsync,
                      netWorthAsync),
                  const SizedBox(height: 16),
                  _buildWealthFreedomBar(theme, metricsAsync),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 头部 ====================

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: theme.colorScheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '财务概览',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }

  // ==================== 资产区 ====================

  Widget _buildAssetSection(
    ThemeData theme,
    AsyncValue<double> assetsAsync,
    AsyncValue<double> liabilitiesAsync,
    AsyncValue<double> netWorthAsync,
  ) {
    return Column(
      children: [
        // 总资产 | 总负债
        Row(
          children: [
            Expanded(
              child: _buildAmountLabel(
                theme,
                '总资产',
                assetsAsync,
                theme.colorScheme.primary,
              ),
            ),
            if (liabilitiesAsync.whenOrNull(data: (v) => v) != null &&
                (liabilitiesAsync.asData?.value ?? 0) > 0)
              Expanded(
                child: _buildAmountLabel(
                  theme,
                  '总负债',
                  liabilitiesAsync,
                  Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // 净资产（大号）
        netWorthAsync.when(
          data: (v) => Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('净资产', style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              Text(
                '¥${_fmt.format(v)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          loading: () => const SizedBox(
            height: 24,
            child: LinearProgressIndicator(),
          ),
          error: (_, __) => const Text('暂无数据'),
        ),
      ],
    );
  }

  Widget _buildAmountLabel(
    ThemeData theme,
    String label,
    AsyncValue<double> asyncValue,
    Color color,
  ) {
    return asyncValue.when(
      data: (v) => Row(
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(width: 4),
          Text(
            '¥${_fmt.format(v)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
      loading: () => const SizedBox(
        width: 60,
        height: 16,
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ==================== 财富自由进度条 ====================

  Widget _buildWealthFreedomBar(
    ThemeData theme,
    AsyncValue<dynamic> metricsAsync,
  ) {
    return metricsAsync.when(
      data: (metrics) {
        if (metrics == null) {
          return Text(
            '还没有财务数据，点此开始记录',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          );
        }

        final ratio = metrics.passiveIncomeCoverageRatio;
        final percent = (ratio * 100).clamp(0, 100);
        final progress = ratio.clamp(0, 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏝️', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '财富自由进度',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: percent >= 100
                        ? Colors.green
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  percent >= 100
                      ? Colors.green
                      : percent > 50
                          ? Colors.orange
                          : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '被动收入 ¥${_fmt.format(metrics.passiveIncome)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '月支出 ¥${_fmt.format(metrics.totalExpense)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ==================== 金币粒子动画 ====================

  Widget _buildParticleWidget(_CoinParticle p, ThemeData theme) {
    final elapsed = DateTime.now().difference(p.birthTime).inMilliseconds / 1000;
    final opacity = (1 - elapsed / 3).clamp(0.0, 1.0);
    final offsetY = -(elapsed * 60); // 向上飘
    final offsetX = sin(elapsed * 2) * 10; // 左右摆动

    if (opacity <= 0) return const SizedBox.shrink();

    return Positioned(
      left: p.startX + offsetX,
      bottom: 20 + (-offsetY).clamp(0, 180).toDouble(),
      child: Opacity(
        opacity: opacity,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.isPositive ? '🪙' : '💸',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 2),
            Text(
              '${p.isPositive ? '+' : '-'}¥${_fmt.format(p.amount.abs())}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: p.isPositive ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 金币粒子数据
class _CoinParticle {
  final int id;
  final double startX;
  final double amount;
  final bool isPositive;
  final DateTime birthTime;

  const _CoinParticle({
    required this.id,
    required this.startX,
    required this.amount,
    required this.isPositive,
    required this.birthTime,
  });
}
