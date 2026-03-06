import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/register_page.dart';
import 'features/dashboard/pages/dashboard_page.dart';
import 'features/home_shell.dart';
import 'features/settings/pages/settings_page.dart';

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/tasks',
          builder: (context, state) =>
              const _PlaceholderPage(title: '任务', icon: Icons.task),
        ),
        GoRoute(
          path: '/shopping',
          builder: (context, state) =>
              const _PlaceholderPage(title: '购物', icon: Icons.shopping_cart),
        ),
        GoRoute(
          path: '/calendar',
          builder: (context, state) =>
              const _PlaceholderPage(title: '日历', icon: Icons.calendar_today),
        ),
        GoRoute(
          path: '/bills',
          builder: (context, state) =>
              const _PlaceholderPage(title: '账单', icon: Icons.receipt_long),
        ),
        GoRoute(
          path: '/assets',
          builder: (context, state) =>
              const _PlaceholderPage(title: '资产', icon: Icons.devices),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('$title - 待实现', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class HomeManagerApp extends StatelessWidget {
  const HomeManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppTheme.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
