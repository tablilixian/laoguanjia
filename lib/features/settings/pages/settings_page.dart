import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: ListView(
        children: [
          // User Info
          authUser.when(
            data: (user) => UserAccountsDrawerHeader(
              accountName: Text(user?.email?.split('@').first ?? '用户'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  (user?.email?.substring(0, 1) ?? 'U').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
            loading: () => const ListTile(
              leading: CircularProgressIndicator(),
              title: Text('加载中...'),
            ),
            error: (_, __) =>
                const ListTile(leading: Icon(Icons.error), title: Text('加载失败')),
          ),
          const Divider(),
          // Menu Items
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('家庭管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to household management
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outlined),
            title: const Text('成员管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to member management
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outlined),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '老管家',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 老管家',
              );
            },
          ),
          const Divider(),
          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认退出'),
                  content: const Text('确定要退出登录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('退出'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await ref.read(authStateProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
