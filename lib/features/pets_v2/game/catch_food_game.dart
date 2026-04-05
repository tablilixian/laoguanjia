import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/features/pets_v2/providers/pet_v2_provider.dart';

/// 接食物小游戏
///
/// 宠物张嘴接掉落的食物，接到得分，漏接扣分。
/// 游戏结果影响宠物的饥饿值和心情值。
class CatchFoodGamePage extends ConsumerStatefulWidget {
  const CatchFoodGamePage({super.key});

  @override
  ConsumerState<CatchFoodGamePage> createState() => _CatchFoodGamePageState();
}

class _CatchFoodGamePageState extends ConsumerState<CatchFoodGamePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _gameController;
  late AnimationController _petMouthController;

  int _score = 0;
  int _missed = 0;
  int _combo = 0;
  int _maxCombo = 0;
  bool _isPlaying = false;
  bool _isGameOver = false;

  /// 食物列表: {x, y, type, speed}
  final List<Map<String, dynamic>> _foods = [];
  final math.Random _random = math.Random();

  /// 宠物水平位置 (0.0 - 1.0)
  double _petX = 0.5;

  /// 游戏时长 (秒)
  static const int gameDuration = 30;
  int _remainingTime = gameDuration;

  /// 食物类型及分值
  static const _foodTypes = [
    {'emoji': '🍖', 'points': 10, 'speed': 1.0},
    {'emoji': '🍕', 'points': 15, 'speed': 1.2},
    {'emoji': '🍗', 'points': 10, 'speed': 0.8},
    {'emoji': '🍎', 'points': 5, 'speed': 1.5},
    {'emoji': '🐟', 'points': 20, 'speed': 1.8},
    {'emoji': '⭐', 'points': 30, 'speed': 2.0},
  ];

  @override
  void initState() {
    super.initState();
    _gameController = AnimationController(
      duration: const Duration(milliseconds: 16), // ~60fps
      vsync: this,
    );
    _gameController.addListener(_gameLoop);

    _petMouthController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _gameController.dispose();
    _petMouthController.dispose();
    super.dispose();
  }

  void _gameLoop() {
    if (!_isPlaying) return;

    // 更新食物位置
    for (final food in _foods) {
      food['y'] = (food['y'] as double) + (food['speed'] as double) * 0.008;
    }

    // 检测碰撞
    _foods.removeWhere((food) {
      final y = food['y'] as double;
      final x = food['x'] as double;

      // 食物到达底部
      if (y > 0.85) {
        // 检测是否在宠物范围内
        if ((x - _petX).abs() < 0.1) {
          _onCatch(food);
          return true;
        } else {
          _onMiss();
          return true;
        }
      }
      return false;
    });

    // 生成新食物
    if (_random.nextDouble() < 0.04) {
      _spawnFood();
    }

    setState(() {});
  }

  void _spawnFood() {
    final type = _foodTypes[_random.nextInt(_foodTypes.length)];
    _foods.add({
      'x': 0.1 + _random.nextDouble() * 0.8,
      'y': -0.05,
      'type': type,
    });
  }

  void _onCatch(Map<String, dynamic> food) {
    final points = food['type']['points'] as int;
    _combo++;
    if (_combo > _maxCombo) _maxCombo = _combo;
    _score += points + (_combo > 5 ? _combo : 0);
    _petMouthController.forward(from: 0);
  }

  void _onMiss() {
    _missed++;
    _combo = 0;
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _missed = 0;
      _combo = 0;
      _maxCombo = 0;
      _foods.clear();
      _remainingTime = gameDuration;
      _petX = 0.5;
    });
    _gameController.repeat();

    // 倒计时
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isPlaying) return false;
      setState(() => _remainingTime--);
      if (_remainingTime <= 0) {
        _endGame();
        return false;
      }
      return true;
    });
  }

  void _endGame() {
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });
    _gameController.stop();

    // 更新宠物状态
    _applyGameResult();
  }

  void _applyGameResult() {
    final petId = ref.read(currentPetV2IdProvider);
    if (petId == null) return;

    ref.read(petV2ServiceProvider).interact(petId, 'play');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '🎮 接食物',
          style: TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isGameOver ? _buildGameOver() : _buildGameArea(),
    );
  }

  Widget _buildGameArea() {
    return Stack(
      children: [
        // 游戏区域
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _petX += details.delta.dx / constraints.maxWidth;
                  _petX = _petX.clamp(0.05, 0.95);
                });
              },
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _CatchFoodPainter(
                  foods: _foods,
                  petX: _petX,
                  petMouthOpen: _petMouthController.value,
                ),
              ),
            );
          },
        ),

        // HUD
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _hudItem('🏆', '$_score'),
              _hudItem('⏱️', '$_remainingTime'),
              _hudItem('🔥', 'x$_combo'),
              _hudItem('❌', '$_missed'),
            ],
          ),
        ),

        // 开始按钮
        if (!_isPlaying)
          Center(
            child: ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始游戏'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _hudItem(String icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    final rating = _score > 300 ? '🌟🌟🌟' : _score > 150 ? '🌟🌟' : _score > 50 ? '🌟' : '💪';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              '游戏结束!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 24),
            _resultRow('得分', '$_score'),
            _resultRow('最高连击', 'x$_maxCombo'),
            _resultRow('漏接', '$_missed'),
            _resultRow('评级', rating),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.replay),
              label: const Text('再来一次'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回房间'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// 接食物游戏绘制器
class _CatchFoodPainter extends CustomPainter {
  final List<Map<String, dynamic>> foods;
  final double petX;
  final double petMouthOpen;

  _CatchFoodPainter({
    required this.foods,
    required this.petX,
    required this.petMouthOpen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制背景渐变
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE3F2FD),
          const Color(0xFFFFF8F0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 绘制地面
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.88, size.width, size.height * 0.12),
      Paint()..color = const Color(0xFFD7CCC8),
    );

    // 绘制食物
    for (final food in foods) {
      final x = (food['x'] as double) * size.width;
      final y = (food['y'] as double) * size.height;
      final emoji = food['type']['emoji'] as String;

      final tp = TextPainter(
        text: TextSpan(text: emoji, style: const TextStyle(fontSize: 30)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // 绘制宠物
    final petScreenX = petX * size.width;
    final petScreenY = size.height * 0.82;

    // 宠物身体
    canvas.drawCircle(
      Offset(petScreenX, petScreenY),
      25,
      Paint()..color = const Color(0xFFFFCC80),
    );

    // 宠物眼睛
    canvas.drawCircle(
      Offset(petScreenX - 8, petScreenY - 5),
      3,
      Paint()..color = const Color(0xFF5D4037),
    );
    canvas.drawCircle(
      Offset(petScreenX + 8, petScreenY - 5),
      3,
      Paint()..color = const Color(0xFF5D4037),
    );

    // 宠物嘴巴 (根据接食物状态开合)
    final mouthOpen = petMouthOpen * 8;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(petScreenX, petScreenY + 8),
        width: 12,
        height: 6 + mouthOpen,
      ),
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _CatchFoodPainter oldDelegate) {
    return oldDelegate.foods != foods ||
        oldDelegate.petX != petX ||
        oldDelegate.petMouthOpen != petMouthOpen;
  }
}
