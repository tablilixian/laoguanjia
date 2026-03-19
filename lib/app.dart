import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/register_page.dart';
import 'features/auth/pages/email_verification_page.dart';
import 'features/dashboard/pages/dashboard_page.dart';
import 'features/home_shell.dart';
import 'features/settings/pages/settings_page.dart';
import 'features/settings/pages/ai_settings_page.dart';
import 'features/settings/pages/debug_page.dart';
import 'features/household/pages/create_household_page.dart';
import 'features/household/pages/join_household_page.dart';
import 'features/tasks/pages/tasks_page.dart';
import 'features/tasks/pages/task_create_page.dart';
import 'features/tasks/pages/task_detail_page.dart';
import 'features/debug/pages/database_test_page.dart';
import 'features/debug/pages/supabase_diagnostic_page.dart';
import 'features/debug/pages/direct_supabase_test_page.dart';
import 'features/debug/pages/item_debug_page.dart';
import 'features/pets/pages/pet_page.dart';
import 'features/pets/pages/pet_create_page.dart';
import 'features/pets/pages/pet_detail_page.dart';
import 'features/pets/pages/pet_chat_page.dart';
import 'features/pets/pages/pet_memories_page.dart';
import 'features/pets/pages/pet_explore_page.dart';
import 'features/pets/pages/pet_explore_detail_page.dart';
import 'features/pets/pages/pet_exploration_list_page.dart';
import 'features/ai_chat/pages/ai_chat_page.dart';
import 'data/models/pet.dart';
import 'features/weather/pages/weather_settings_page.dart';
import 'features/items/pages/items_list_page.dart';
import 'features/items/pages/item_detail_page.dart';
import 'features/items/pages/item_create_page.dart';
import 'features/items/pages/item_locations_page.dart';
import 'features/items/pages/item_tags_page.dart';
import 'features/items/pages/item_type_manage_page.dart';
import 'features/items/pages/item_stats_page.dart';
import 'features/items/pages/item_ai_assistant_page.dart';
import 'features/items/pages/location_create_edit_page.dart';
import 'features/items/pages/location_init_wizard.dart';
import 'features/welcome/pages/welcome_page.dart';

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    // 检查用户是否已登录
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null;

    // 如果用户已登录
    if (isLoggedIn) {
      // 如果在登录页或注册页，重定向到欢迎页
      if (state.uri.path == '/login' || state.uri.path == '/register') {
        return '/welcome';
      }
      // 如果已经在欢迎页，不重定向
      if (state.uri.path == '/welcome') {
        return null;
      }
    }

    // 如果用户未登录，重定向到登录页
    if (!isLoggedIn &&
        !state.uri.path.startsWith('/login') &&
        !state.uri.path.startsWith('/register')) {
      return '/login';
    }

    return null; // 不重定向
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomePage()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/email-verification',
      builder: (context, state) =>
          EmailVerificationPage(email: state.extra as String),
    ),
    GoRoute(
      path: '/create-household',
      builder: (context, state) => const CreateHouseholdPage(),
    ),
    GoRoute(
      path: '/join-household',
      builder: (context, state) => const JoinHouseholdPage(),
    ),
    GoRoute(
      path: '/debug/database',
      builder: (context, state) => const DatabaseTestPage(),
    ),
    GoRoute(
      path: '/debug/supabase',
      builder: (context, state) => const SupabaseDiagnosticPage(),
    ),
    GoRoute(
      path: '/debug/direct',
      builder: (context, state) => const DirectSupabaseTestPage(),
    ),
    GoRoute(
      path: '/debug/items',
      builder: (context, state) => const ItemDebugPage(),
    ),
    GoRoute(path: '/ai-chat', builder: (context, state) => const AIChatPage()),
    GoRoute(
      path: '/settings/ai',
      builder: (context, state) => const AISettingsPage(),
    ),
    GoRoute(
      path: '/settings/weather',
      builder: (context, state) => const WeatherSettingsPage(),
    ),
    GoRoute(path: '/debug', builder: (context, state) => const DebugPage()),
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/home/pets',
          builder: (context, state) => const PetPage(),
        ),
        GoRoute(
          path: '/home/pets/create',
          builder: (context, state) => const PetCreatePage(),
        ),
        GoRoute(
          path: '/home/pets/:petId',
          builder: (context, state) {
            final petId = state.pathParameters['petId']!;
            return PetDetailPage(petId: petId);
          },
        ),
        GoRoute(
          path: '/home/pets/:petId/chat',
          builder: (context, state) {
            final petId = state.pathParameters['petId']!;
            final pet = state.extra as Pet?;
            return PetChatPage(pet: pet!);
          },
        ),
        GoRoute(
          path: '/home/pets/:petId/memories',
          builder: (context, state) {
            final pet = state.extra as Pet?;
            return PetMemoriesPage(pet: pet!);
          },
        ),
        GoRoute(
          path: '/home/pets/:petId/explore',
          builder: (context, state) {
            final petId = state.pathParameters['petId']!;
            final pet = state.extra as Pet?;
            return PetExplorePage(petId: petId, pet: pet);
          },
        ),
        GoRoute(
          path: '/home/pets/:petId/explore/:diaryId',
          builder: (context, state) {
            final petId = state.pathParameters['petId']!;
            final diaryId = state.pathParameters['diaryId']!;
            final extra = state.extra as Map<String, dynamic>?;
            return ExplorationDiaryDetailPage(
              petId: petId,
              diaryId: diaryId,
              extra: extra,
            );
          },
        ),
        GoRoute(
          path: '/home/pets/:petId/explorations',
          builder: (context, state) {
            final pet = state.extra as Pet?;
            return ExplorationDiaryListPage(pet: pet!);
          },
        ),
        // ========== Household Items 路由 ==========
        GoRoute(
          path: '/home/items',
          builder: (context, state) => const ItemsListPage(),
        ),
        GoRoute(
          path: '/home/items/create',
          builder: (context, state) => const ItemCreatePage(),
        ),
        // 具体路径要在参数路径之前
        GoRoute(
          path: '/home/items/locations',
          builder: (context, state) => const ItemLocationsPage(),
        ),
        GoRoute(
          path: '/items/location/edit',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return LocationCreateEditPage(
              location: extra?['location'] as dynamic,
              parentId: extra?['parentId'] as String?,
            );
          },
        ),
        GoRoute(
          path: '/home/items/locations/init',
          builder: (context, state) => const _LocationInitWrapper(),
        ),
        GoRoute(
          path: '/home/items/tags',
          builder: (context, state) => const ItemTagsPage(),
        ),
        GoRoute(
          path: '/home/items/types',
          builder: (context, state) => const ItemTypeManagePage(),
        ),
        GoRoute(
          path: '/home/items/stats',
          builder: (context, state) => const ItemStatsPage(),
        ),
        GoRoute(
          path: '/home/items/ai',
          builder: (context, state) => const ItemAIAssistantPage(),
        ),
        GoRoute(
          path: '/home/items/:itemId',
          builder: (context, state) {
            final itemId = state.pathParameters['itemId']!;
            return ItemDetailPage(itemId: itemId);
          },
        ),
        GoRoute(
          path: '/home/items/:itemId/edit',
          builder: (context, state) {
            final itemId = state.pathParameters['itemId']!;
            return ItemCreatePage(itemId: itemId);
          },
        ),
        // ========== Tasks 路由 ==========
        GoRoute(
          path: '/home/tasks',
          builder: (context, state) => const TasksPage(),
        ),
        GoRoute(
          path: '/home/tasks/create',
          builder: (context, state) {
            // 尝试不同的方法获取查询参数
            final taskId = state.extra as String?;
            return TaskCreatePage(taskId: taskId);
          },
        ),
        GoRoute(
          path: '/home/tasks/:taskId',
          builder: (context, state) {
            final taskId = state.pathParameters['taskId']!;
            return TaskDetailPage(taskId: taskId);
          },
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

class _LocationInitWrapper extends StatelessWidget {
  const _LocationInitWrapper();

  @override
  Widget build(BuildContext context) {
    // 位置初始化向导作为全屏弹窗显示
    return Scaffold(
      body: LocationInitWizard(),
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
