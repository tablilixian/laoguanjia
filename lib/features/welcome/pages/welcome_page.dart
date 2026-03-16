import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/ai/ai_settings_service.dart';
import '../../household/providers/household_provider.dart';

/// 欢迎页 - 自动登录后显示，给后台留下云端请求时间
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _sloganController;
  late AnimationController _floatController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _sloganAnimation;

  String _displayedSlogan = '';
  final String _fullSlogan = '让生活更有序，让家更温馨';
  int _sloganIndex = 0;
  Timer? _sloganTimer;

  final List<_FloatingIcon> _floatingIcons = [];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initFloatingIcons();
    // 延迟初始化，等待 widget 构建完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialization();
    });
  }

  void _initAnimations() {
    // Logo 动画: 淡入 + 缩放
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _logoScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));

    // Slogan 动画: 打字机效果
    _sloganController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _sloganAnimation = CurvedAnimation(
      parent: _sloganController,
      curve: Curves.easeInOut,
    );

    // 浮动图标动画
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // 启动动画
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _sloganController.forward();
      _startSloganTyping();
    });
  }

  void _initFloatingIcons() {
    _floatingIcons.addAll([
      _FloatingIcon(Icons.home_rounded, 0.1, 0.2),
      _FloatingIcon(Icons.star_rounded, 0.8, 0.15),
      _FloatingIcon(Icons.auto_awesome_rounded, 0.5, 0.3),
      _FloatingIcon(Icons.favorite_rounded, 0.3, 0.25),
      _FloatingIcon(Icons.wb_sunny_rounded, 0.7, 0.28),
    ]);
  }

  void _startSloganTyping() {
    _sloganTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_sloganIndex < _fullSlogan.length) {
        setState(() {
          _displayedSlogan = _fullSlogan.substring(0, _sloganIndex + 1);
          _sloganIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _startInitialization() async {
    // 并行初始化所有必要数据
    await Future.wait([
      _initAI(),
      _initWeather(),
      _initHousehold(),
      _preloadProviders(),
    ]);

    // 等待动画完成（至少3秒）
    // Logo动画0.5s + Slogan动画0.8s + 额外1.7s = 3秒
    await Future.delayed(const Duration(milliseconds: 1700));

    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _initAI() async {
    try {
      await AISettingsService.init();
      // 只加载本地存储的 API Key，不做额外请求
    } catch (e) {
      debugPrint('AI 初始化跳过: $e');
    }
  }

  Future<void> _initWeather() async {
    try {
      // 触发天气 API Key 加载
      await StorageService.getInstance();
    } catch (e) {
      debugPrint('天气初始化跳过: $e');
    }
  }

  Future<void> _initHousehold() async {
    try {
      // 刷新家庭数据
      ref.read(householdProvider.notifier).refresh();
    } catch (e) {
      debugPrint('家庭数据初始化跳过: $e');
    }
  }

  Future<void> _preloadProviders() async {
    // 预加载存储服务
    try {
      await StorageService.getInstance();
    } catch (e) {
      debugPrint('存储服务预加载跳过: $e');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _sloganController.dispose();
    _floatController.dispose();
    _sloganTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryGold,
              AppTheme.primaryGold.withValues(alpha: 0.9),
              const Color(0xFFE8C9A0),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 浮动装饰图标
              ..._buildFloatingIcons(size),

              // 主内容
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Opacity(
                          opacity: _logoOpacityAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🏠', style: TextStyle(fontSize: 60)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Slogan
                  AnimatedBuilder(
                    animation: _sloganAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _sloganAnimation.value,
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          _displayedSlogan,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 2,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // 加载提示
                  FadeTransition(
                    opacity: _sloganController,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '正在准备您的家...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFloatingIcons(Size size) {
    return _floatingIcons.map((iconData) {
      return AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final offset = sin(_floatController.value * pi + iconData.phase) * 10;
          return Positioned(
            left: size.width * iconData.leftPos,
            top: size.height * iconData.topPos + offset,
            child: Opacity(
              opacity: 0.3,
              child: Transform.rotate(
                angle: _floatController.value * 0.2,
                child: Icon(
                  iconData.icon,
                  size: 24 + iconData.size * 10,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }
}

class _FloatingIcon {
  final IconData icon;
  final double leftPos;
  final double topPos;
  final double size;
  final double phase;

  _FloatingIcon(this.icon, this.leftPos, this.topPos)
    : size = 0.5 + Random().nextDouble() * 0.5,
      phase = Random().nextDouble() * pi * 2;
}
