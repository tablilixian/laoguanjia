import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sync_status_bar.dart';

class HomeShell extends StatefulWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '首页'),
    _NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: '物品'),
    _NavItem(icon: Icons.task_outlined, activeIcon: Icons.task, label: '任务'),
    _NavItem(icon: Icons.pets_outlined, activeIcon: Icons.pets, label: '宠物'),
  ];

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home/items')) return 1;
    if (location.startsWith('/home/tasks') || location.startsWith('/tasks'))
      return 2;
    if (location.startsWith('/home/pets')) return 3;
    if (location.startsWith('/home')) return 0;
    // 其他页面默认选中首页
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/home/items');
        break;
      case 2:
        context.go('/home/tasks');
        break;
      case 3:
        context.go('/home/pets');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.path;

    // Update selected index based on current route
    _selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('老管家'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_esports_outlined),
            onPressed: () => context.push('/game/monopoly'),
            tooltip: '游戏',
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => context.push('/ai-chat'),
            tooltip: 'AI 助手',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
            tooltip: '设置',
          ),
        ],
      ),
      body: SyncStatusBar(child: widget.child),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (index) {
                return _buildNavItem(
                  context: context,
                  item: _navItems[index],
                  index: index,
                  isSelected: _selectedIndex == index,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required _NavItem item,
    required int index,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _onItemTapped(index, context),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGold.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected
                      ? AppTheme.primaryGold
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                )
                .animate(target: isSelected ? 1 : 0)
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 200.ms,
                ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                    item.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 150.ms)
                  .slideX(begin: -0.2, end: 0, duration: 150.ms),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
