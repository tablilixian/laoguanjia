import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/features/pets_v2/providers/pet_v2_provider.dart';
import 'package:home_manager/features/pets_v2/widgets/pet_avatar.dart';

/// 宠物房间页 — 2.5D 等距视角，上帝视角观察宠物在家中的活动。
///
/// 使用 CustomPainter 绘制等距房间，宠物精灵根据状态在不同位置活动。
class PetV2RoomPage extends ConsumerStatefulWidget {
  const PetV2RoomPage({super.key});

  @override
  ConsumerState<PetV2RoomPage> createState() => _PetV2RoomPageState();
}

class _PetV2RoomPageState extends ConsumerState<PetV2RoomPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _petMoveController;
  late Animation<Offset> _petPositionAnimation;

  /// 宠物当前位置索引 (0=沙发, 1=食盆, 2=床, 3=窗台)
  int _currentSpotIndex = 0;

  /// 宠物状态
  String _petActivity = '发呆中';

  /// 选中的房间 (0=客厅, 1=卧室, 2=厨房)
  int _selectedRoom = 0;

  /// 房间名称
  static const _roomNames = ['客厅', '卧室', '厨房'];
  static const _roomIcons = ['🛋️', '🛏️', '🍳'];

  /// 宠物活动点位 (等距坐标)
  final List<Offset> _petSpots = [
    const Offset(0.3, 0.5),  // 沙发
    const Offset(0.7, 0.6),  // 食盆
    const Offset(0.5, 0.3),  // 床
    const Offset(0.8, 0.3),  // 窗台
  ];

  final List<String> _spotNames = ['沙发', '食盆', '床', '窗台'];

  @override
  void initState() {
    super.initState();
    _petMoveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _petMoveController.addStatusListener(_onMoveComplete);
    _startRandomActivity();
  }

  @override
  void dispose() {
    _petMoveController.dispose();
    super.dispose();
  }

  /// 宠物移动完成后触发下一次活动
  void _onMoveComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      Future.delayed(const Duration(seconds: 3), _startRandomActivity);
    }
  }

  /// 随机选择下一个活动点位
  void _startRandomActivity() {
    if (!mounted) return;
    final nextIndex = (_currentSpotIndex + 1 + math.Random().nextInt(_petSpots.length - 1)) % _petSpots.length;
    final activities = ['休息中', '吃东西', '睡觉中', '看窗外', '玩耍中'];
    setState(() {
      _currentSpotIndex = nextIndex;
      _petActivity = activities[math.Random().nextInt(activities.length)];
    });
    _petPositionAnimation = Tween<Offset>(
      begin: _petSpots[(_currentSpotIndex - 1 + _petSpots.length) % _petSpots.length],
      end: _petSpots[_currentSpotIndex],
    ).animate(CurvedAnimation(
      parent: _petMoveController,
      curve: Curves.easeInOut,
    ));
    _petMoveController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final petDataAsync = ref.watch(currentPetV2DataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '宠物房间',
          style: TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.games_outlined, color: Color(0xFF5D4037)),
            onPressed: () => _showGameMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 房间切换 Tab
          _buildRoomTabs(),
          // 等距房间
          Expanded(
            child: petDataAsync.when(
              data: (data) => _buildIsometricRoom(data),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
          // 底部信息卡
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildRoomTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_roomNames.length, (index) {
          final isSelected = _selectedRoom == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedRoom = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFE0B2) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF9800) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_roomIcons[index], style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    _roomNames[index],
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: const Color(0xFF5D4037),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildIsometricRoom(dynamic data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _IsometricRoomPainter(
            roomIndex: _selectedRoom,
            petPosition: _petPositionAnimation.value,
            petType: 'cat',
            petActivity: _petActivity,
          ),
          child: AnimatedBuilder(
            animation: _petMoveController,
            builder: (context, child) {
              final offset = _petPositionAnimation.value;
              return Positioned(
                left: offset.dx * constraints.maxWidth,
                top: offset.dy * constraints.maxHeight * 0.6,
                child: GestureDetector(
                  onTap: () => _showPetInfo(context, data),
            child: PetAvatarWidget(
              type: 'cat',
              mood: data.state.currentMood,
              size: 50,
            ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🐱', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _petActivity,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D4037),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '位置: ${_spotNames[_currentSpotIndex]}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _startRandomActivity(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('互动'),
          ),
        ],
      ),
    );
  }

  void _showPetInfo(BuildContext context, dynamic data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '宠物信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (data != null) ...[
              _infoRow('等级', 'Lv.${data.state.level}'),
              _infoRow('亲密度', 'Lv.${data.relationship.intimacyLevel}'),
              _infoRow('心情', data.state.moodText ?? '一般般'),
              _infoRow('当前位置', _spotNames[_currentSpotIndex]),
              _infoRow('正在', _petActivity),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showGameMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '小游戏',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _gameTile(context, '🎮', '接食物', '帮宠物接住掉落的食物', '/home/pets_v2/game/catch_food'),
            _gameTile(context, '🃏', '记忆翻牌', '配对宠物记忆卡片', '/home/pets_v2/game/memory'),
          ],
        ),
      ),
    );
  }

  Widget _gameTile(BuildContext context, String icon, String title, String desc, String route) {
    return ListTile(
      leading: Text(icon, style: const TextStyle(fontSize: 32)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(desc),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context);
        context.push(route);
      },
    );
  }
}

/// 等距房间绘制器
///
/// 使用 2.5D 等距投影绘制房间地板、墙壁和家具。
class _IsometricRoomPainter extends CustomPainter {
  final int roomIndex;
  final Offset petPosition;
  final String petType;
  final String petActivity;

  _IsometricRoomPainter({
    required this.roomIndex,
    required this.petPosition,
    required this.petType,
    required this.petActivity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height * 0.45;
    final tileWidth = size.width * 0.12;
    final tileHeight = tileWidth * 0.5;

    // 绘制等距地板 (4x4 网格)
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        final x = centerX + (col - row) * tileWidth;
        final y = centerY + (col + row) * tileHeight;

        final isEven = (row + col) % 2 == 0;
        final paint = Paint()
          ..color = isEven
              ? const Color(0xFFFFF3E0)
              : const Color(0xFFFFE0B2)
          ..style = PaintingStyle.fill;

        final path = Path()
          ..moveTo(x, y)
          ..lineTo(x + tileWidth, y + tileHeight)
          ..lineTo(x, y + tileHeight * 2)
          ..lineTo(x - tileWidth, y + tileHeight)
          ..close();

        canvas.drawPath(path, paint);

        // 网格线
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFD7CCC8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }

    // 根据房间绘制不同的家具
    _drawFurniture(canvas, size, centerX, centerY, tileWidth, tileHeight);
  }

  void _drawFurniture(Canvas canvas, Size size, double cx, double cy, double tw, double th) {
    final furniture = _getFurnitureForRoom(roomIndex);

    for (final f in furniture) {
      final x = cx + (f['col']! - f['row']!) * tw;
      final y = cy + (f['col']! + f['row']!) * th - (f['height'] ?? 0);

      // 家具阴影
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, y + th),
          width: tw * 1.5,
          height: th,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.1),
      );

      // 家具主体
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y),
            width: (f['width'] ?? tw) * 1.5,
            height: (f['height'] ?? th) * 2,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = f['color']! as Color,
      );

      // 家具图标/文字
      final tp = TextPainter(
        text: TextSpan(text: f['icon'] as String, style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  List<Map<String, dynamic>> _getFurnitureForRoom(int room) {
    switch (room) {
      case 0: // 客厅
        return [
          {'row': 0.5, 'col': 0.5, 'icon': '🛋️', 'color': const Color(0xFF8D6E63), 'width': 30, 'height': 20},
          {'row': 2.5, 'col': 2.5, 'icon': '📺', 'color': const Color(0xFF455A64), 'width': 25, 'height': 15},
          {'row': 1.5, 'col': 3.0, 'icon': '🪴', 'color': const Color(0xFF4CAF50), 'width': 15, 'height': 15},
        ];
      case 1: // 卧室
        return [
          {'row': 1.0, 'col': 1.0, 'icon': '🛏️', 'color': const Color(0xFF7986CB), 'width': 35, 'height': 20},
          {'row': 2.5, 'col': 0.5, 'icon': '🪟', 'color': const Color(0xFF90CAF9), 'width': 20, 'height': 25},
          {'row': 0.5, 'col': 2.5, 'icon': '🗄️', 'color': const Color(0xFF8D6E63), 'width': 20, 'height': 30},
        ];
      case 2: // 厨房
        return [
          {'row': 0.5, 'col': 0.5, 'icon': '🍳', 'color': const Color(0xFF78909C), 'width': 25, 'height': 20},
          {'row': 2.5, 'col': 1.0, 'icon': '🧊', 'color': const Color(0xFF90CAF9), 'width': 20, 'height': 30},
          {'row': 1.0, 'col': 2.5, 'icon': '🍽️', 'color': const Color(0xFFBCAAA4), 'width': 25, 'height': 15},
        ];
      default:
        return [];
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricRoomPainter oldDelegate) {
    return oldDelegate.petPosition != petPosition ||
        oldDelegate.roomIndex != roomIndex;
  }
}
