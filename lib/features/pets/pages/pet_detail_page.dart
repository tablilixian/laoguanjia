import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/features/pets/providers/pets_provider.dart';

class PetDetailPage extends ConsumerStatefulWidget {
  final String petId;

  const PetDetailPage({super.key, required this.petId});

  @override
  ConsumerState<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends ConsumerState<PetDetailPage> {
  late Pet _pet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPet();
  }

  Future<void> _loadPet() async {
    try {
      final pets = await ref.read(petsProvider.future);
      final pet = pets.firstWhere((p) => p.id == widget.petId);
      setState(() {
        _pet = pet;
        _isLoading = false;
      });
      ref.read(petNotifierProvider.notifier).state = pet;
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载宠物信息失败: $e')));
      }
    }
  }

  Future<void> _interact(String type) async {
    try {
      await ref.read(petNotifierProvider.notifier).interactWithPet(type);
      _loadPet();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getInteractionMessage(type)),
            duration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('互动失败: $e')));
      }
    }
  }

  String getInteractionMessage(String type) {
    switch (type) {
      case 'feed':
        return '🍚 喂食成功！';
      case 'play':
        return '🎮 玩耍愉快！';
      case 'bath':
        return '🛁 洗澡完成！';
      case 'train':
        return '💪 训练成功！';
      default:
        return '互动成功！';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_pet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              context.push('/home/pets/${widget.petId}/memories', extra: _pet);
            },
            tooltip: '回忆',
          ),
          IconButton(
            icon: const Icon(Icons.explore),
            onPressed: () {
              context.push('/home/pets/${widget.petId}/explorations', extra: _pet);
            },
            tooltip: '探索日记',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/home/pets/${widget.petId}/chat', extra: _pet);
        },
        icon: const Icon(Icons.chat),
        label: const Text('聊天'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 顶部宠物信息卡片
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(child: getPetIcon(_pet.type)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _pet.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Lv.${_pet.level}',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${getPetTypeText(_pet.type)} • ${_pet.breed ?? '未知品种'}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '亲密度 ${_pet.level ~/ 2 + 1}/5',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '经验 ${_pet.experience}/${_pet.level * 100}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 心情气泡
                  if (_pet.moodText != null && _pet.moodText!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getMoodColor(_pet.currentMood).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getMoodColor(
                            _pet.currentMood,
                          ).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _getMoodEmoji(_pet.currentMood),
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pet.moodText!,
                              style: TextStyle(
                                color: _getMoodColor(_pet.currentMood),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 状态 + 互动合并面板
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 状态条
                      Row(
                        children: [
                          _buildStatusChip('🍚', _pet.hunger, Colors.orange),
                          const SizedBox(width: 8),
                          _buildStatusChip('😊', _pet.happiness, Colors.blue),
                          const SizedBox(width: 8),
                          _buildStatusChip(
                            '🛁',
                            _pet.cleanliness,
                            Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _buildStatusChip('❤️', _pet.health, Colors.red),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      // 互动按钮 - 紧凑排列
                      Row(
                        children: [
                          Expanded(
                            child: _buildInteractionButton(
                              '🍚',
                              '喂食',
                              Colors.orange,
                              'feed',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInteractionButton(
                              '🎮',
                              '玩耍',
                              Colors.blue,
                              'play',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInteractionButton(
                              '🛁',
                              '洗澡',
                              Colors.green,
                              'bath',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInteractionButton(
                              '💪',
                              '训练',
                              Colors.purple,
                              'train',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 性格+技能标签
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.purple, size: 18),
                      SizedBox(width: 8),
                      Text(
                        '技能',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_pet.skills.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pet.skills.map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                skill.icon,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                skill.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  else
                    const Text(
                      '暂无技能',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ),

            // 探索世界按钮
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () {
                  context.push('/home/pets/${widget.petId}/explore', extra: _pet);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.red.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '🗺️',
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '探索世界',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '让${_pet.name}外出冒险，发现新故事',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 80), // 为 FAB 留空间
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String emoji, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              '$value%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionButton(
    String emoji,
    String label,
    Color color,
    String type,
  ) {
    return InkWell(
      onTap: () => _interact(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget getPetIcon(String type) {
    switch (type) {
      case 'cat':
        return const Icon(Icons.pets, size: 40, color: Colors.purple);
      case 'dog':
        return const Icon(Icons.pets, size: 40, color: Colors.brown);
      case 'rabbit':
      case 'hamster':
      case 'guinea_pig':
      case 'chinchilla':
        return const Icon(Icons.face, size: 40, color: Colors.pink);
      case 'bird':
      case 'parrot':
        return const Icon(Icons.flutter_dash, size: 40, color: Colors.orange);
      case 'fish':
      case 'turtle':
        return const Icon(Icons.water, size: 40, color: Colors.blue);
      case 'lizard':
        return const Icon(Icons.pest_control, size: 40, color: Colors.green);
      default:
        return const Icon(Icons.help, size: 40, color: Colors.grey);
    }
  }

  String getPetTypeText(String type) {
    switch (type) {
      case 'cat':
        return '猫咪';
      case 'dog':
        return '狗狗';
      case 'rabbit':
        return '兔子';
      case 'hamster':
        return '仓鼠';
      case 'guinea_pig':
        return '豚鼠';
      case 'chinchilla':
        return '龙猫';
      case 'bird':
        return '鸟类';
      case 'parrot':
        return '鹦鹉';
      case 'fish':
        return '鱼';
      case 'turtle':
        return '乌龟';
      case 'lizard':
        return '蜥蜴';
      case 'hedgehog':
        return '刺猬';
      case 'ferret':
        return '雪貂';
      case 'pig':
        return '猪';
      default:
        return '其他';
    }
  }

  Color _getMoodColor(String? mood) {
    switch (mood) {
      case 'happy':
        return Colors.orange;
      case 'excited':
        return Colors.amber;
      case 'sad':
        return Colors.blue;
      case 'angry':
        return Colors.red;
      case 'scared':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getMoodEmoji(String? mood) {
    switch (mood) {
      case 'happy':
        return '😊';
      case 'excited':
        return '🎉';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      case 'scared':
        return '😨';
      case 'neutral':
        return '😐';
      default:
        return '😐';
    }
  }
}
