import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../household/providers/household_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final householdState = ref.watch(householdProvider);
    final theme = Theme.of(context);

    final hour = DateTime.now().hour;
    String greeting = hour < 12 ? '早上好' : (hour < 18 ? '下午好' : '晚上好');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 180,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient(),
                borderRadius: BorderRadius.circular(24),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '👋 $greeting',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              householdState.currentHousehold?.name ?? '未加入家庭',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '老管家',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '今天有 3 项待办任务',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '功能',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _FeatureCard(
                        title: '任务',
                        subtitle: '管理家庭任务',
                        icon: Icons.task_alt,
                        color: const Color(0xFF7EB8A2),
                        onTap: () => context.go('/home/tasks'),
                      ),
                      _FeatureCard(
                        title: '购物',
                        subtitle: '购物清单',
                        icon: Icons.shopping_bag_outlined,
                        color: const Color(0xFFE8B87C),
                        onTap: () => context.go('/shopping'),
                      ),
                      _FeatureCard(
                        title: '日历',
                        subtitle: '日程安排',
                        icon: Icons.calendar_month_outlined,
                        color: const Color(0xFFB8A2D4),
                        onTap: () => context.go('/calendar'),
                      ),
                      _FeatureCard(
                        title: '账单',
                        subtitle: '家庭账单',
                        icon: Icons.receipt_long_outlined,
                        color: const Color(0xFF8CB8D4),
                        onTap: () => context.go('/bills'),
                      ),
                      _FeatureCard(
                        title: '资产',
                        subtitle: '管理资产',
                        icon: Icons.devices_outlined,
                        color: const Color(0xFFD4B88C),
                        onTap: () => context.go('/assets'),
                      ),
                      _FeatureCard(
                        title: '宠物',
                        subtitle: '宠物档案',
                        icon: Icons.pets_outlined,
                        color: const Color(0xFFE8A0B0),
                        onTap: () => context.go('/home/pets'),
                      ),
                      _FeatureCard(
                        title: '视频库',
                        subtitle: '免费视频播放',
                        icon: Icons.video_library_outlined,
                        color: const Color(0xFF64B5F6),
                        onTap: () => context.go('/home/video'),
                      ),
                      _FeatureCard(
                        title: '图片库',
                        subtitle: '免费图片浏览',
                        icon: Icons.image_outlined,
                        color: const Color(0xFF81C784),
                        onTap: () => context.go('/home/image'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '快捷操作',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickActionCard(
                    title: 'AI 助手',
                    subtitle: '智能问答与语音播报',
                    icon: Icons.smart_toy_outlined,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    onTap: () => context.push('/ai-chat'),
                  ),
                  const SizedBox(height: 12),
                  _QuickActionCard(
                    title: '创建任务',
                    subtitle: '添加新的家庭任务',
                    icon: Icons.add_task,
                    gradient: AppTheme.primaryGradient(),
                    onTap: () => context.push('/home/tasks/create'),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
