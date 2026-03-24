# 白屏问题分析与解决方案

## 问题分析

应用启动后出现白屏，主要原因如下：

### 1. 异步初始化没有错误处理
- `SupabaseClientManager.initialize()` 可能失败或超时
- `initLibtorrent()` 可能失败或超时
- 没有错误处理机制，导致应用卡在初始化阶段

### 2. 同步调度器初始化问题
- `SyncScheduler` 在构造函数中直接访问 `SupabaseClientManager.client`
- 如果 Supabase 初始化失败，会导致应用崩溃
- 没有检查 Supabase 是否已初始化

### 3. 欢迎页初始化阻塞
- `WelcomePage._startInitialization()` 中等待所有初始化完成
- 如果任何一个初始化失败或超时，会阻塞页面跳转
- 没有错误处理和超时机制

### 4. 路由重定向没有错误处理
- `GoRouter.redirect` 中直接访问 `Supabase.instance.client.auth.currentUser`
- 如果 Supabase 未初始化，会导致错误
- 没有错误处理机制

## 解决方案

### 1. main.dart - 添加错误处理
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseClientManager.initialize();
    print('Supabase 初始化成功');
  } catch (e) {
    print('Supabase 初始化失败: $e');
  }

  try {
    await initLibtorrent();
  } catch (e) {
    print('Libtorrent 初始化失败: $e');
  }

  runApp(const ProviderScope(child: HomeManagerApp()));
}
```

### 2. supabase_client.dart - 添加超时处理
```dart
static Future<void> initialize() async {
  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
      debug: kDebugMode,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Supabase 初始化超时，请检查网络连接');
      },
    );
    _client = Supabase.instance.client;
  } on TimeoutException {
    rethrow;
  } catch (e) {
    throw Exception('Supabase 初始化失败: $e');
  }
}
```

### 3. libtorrent_helper.dart - 添加超时处理
```dart
Future<void> initLibtorrent() async {
  try {
    await LibtorrentFlutter.init().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException('LibtorrentFlutter 初始化超时');
      },
    );
    print('LibtorrentFlutter 初始化成功');
  } on TimeoutException {
    print('LibtorrentFlutter 初始化超时，将使用离线模式');
  } catch (e) {
    print('LibtorrentFlutter 初始化失败: $e，将使用离线模式');
  }
}
```

### 4. sync_scheduler.dart - 添加初始化检查
```dart
void initialize() {
  if (!SupabaseClientManager.isInitialized) {
    print('Supabase 未初始化，跳过同步调度器初始化');
    return;
  }

  try {
    _syncEngine = SyncEngine(
      localDb: AppDatabase(),
      remoteDb: SupabaseClientManager.client,
    );
    _initialized = true;
    _startPeriodicSync();
    _listenToConnectivity();
    print('同步调度器初始化成功');
  } catch (e) {
    print('同步调度器初始化失败: $e');
  }
}
```

### 5. welcome_page.dart - 添加错误处理
```dart
Future<void> _startInitialization() async {
  try {
    await Future.wait([
      _initAI(),
      _initWeather(),
      _initHousehold(),
      _preloadProviders(),
      _initSync(),
    ]);
  } catch (e) {
    debugPrint('初始化过程中出现错误: $e，继续跳转到主页');
  }

  if (mounted) {
    context.go('/home');
  }
}
```

### 6. app.dart - 添加路由重定向错误处理
```dart
redirect: (context, state) {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null;

    if (isLoggedIn) {
      if (state.uri.path == '/login' || state.uri.path == '/register') {
        return '/welcome';
      }
      if (state.uri.path == '/welcome') {
        return null;
      }
    }

    if (!isLoggedIn &&
        !state.uri.path.startsWith('/login') &&
        !state.uri.path.startsWith('/register')) {
      return '/login';
    }

    return null;
  } catch (e) {
    print('路由重定向错误: $e，保持当前路由');
    return null;
  }
},
```

## 修复效果

1. **防止应用崩溃** - 即使初始化失败，应用也能正常启动
2. **优雅降级** - 网络服务失败时，应用可以离线运行
3. **更好的用户体验** - 用户不会看到白屏，而是能看到登录页面或主页
4. **调试友好** - 添加了详细的日志输出，方便排查问题

## 测试建议

1. 在无网络环境下测试应用启动
2. 在网络不稳定的环境下测试应用启动
3. 检查控制台日志，确认初始化流程
4. 验证离线模式下应用的基本功能

## 后续优化建议

1. 添加启动页（Splash Screen）显示加载状态
2. 实现重试机制，自动重试失败的初始化
3. 添加网络状态监听，在网络恢复时自动重试
4. 实现更详细的错误提示，告知用户具体问题
