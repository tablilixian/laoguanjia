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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载宠物信息失败: $e')),
      );
    }
  }

  Future<void> _interact(String type) async {
    try {
      await ref.read(petNotifierProvider.notifier).interactWithPet(type);
      _loadPet();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getInteractionMessage(type))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('互动失败: $e')),
      );
    }
  }

  String getInteractionMessage(String type) {
    switch (type) {
      case 'feed':
        return '喂食成功！';
      case 'play':
        return '玩耍愉快！';
      case 'bath':
        return '洗澡完成！';
      case 'train':
        return '训练成功！';
      default:
        return '互动成功！';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_pet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // 编辑宠物信息
            },
          ),
        ],
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
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 宠物头像
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
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
                      const SizedBox(width: 20),
                      // 宠物基本信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pet.name,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${getPetTypeText(_pet.type)} • ${_pet.breed ?? '未知品种'}',
                              style: const TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('等级 ${_pet.level}', style: const TextStyle(color: Colors.blue)),
                                ),
                                const SizedBox(width: 12),
                                Text('经验 ${_pet.experience}/${_pet.level * 100}', style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 状态面板
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('宠物状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      _buildStatusCard('饥饿度', _pet.hunger, Colors.orange, Icons.fastfood),
                      const SizedBox(height: 16),
                      _buildStatusCard('心情值', _pet.happiness, Colors.blue, Icons.emoji_emotions),
                      const SizedBox(height: 16),
                      _buildStatusCard('清洁度', _pet.cleanliness, Colors.green, Icons.water),
                      const SizedBox(height: 16),
                      _buildStatusCard('健康度', _pet.health, Colors.red, Icons.favorite),
                    ],
                  ),
                ),
              ),
            ),

            // 互动按钮区域
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('互动功能', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildInteractionButton('喂食', Icons.fastfood, Colors.orange, 'feed'),
                          _buildInteractionButton('玩耍', Icons.sports_esports, Colors.blue, 'play'),
                          _buildInteractionButton('洗澡', Icons.water, Colors.green, 'bath'),
                          _buildInteractionButton('训练', Icons.fitness_center, Colors.red, 'train'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 成长记录
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('成长记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(Icons.cake, '创建时间', _pet.createdAt.toString().split(' ')[0]),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildInfoItem(Icons.history, '上次更新', _pet.updatedAt.toString().split(' ')[0]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget getPetIcon(String type) {
    switch (type) {
      case 'cat':
        return const Icon(Icons.pets, size: 60, color: Colors.purple);
      case 'dog':
        return const Icon(Icons.pets, size: 60, color: Colors.brown);
      case 'rabbit':
        return const Icon(Icons.face, size: 60, color: Colors.pink);
      default:
        return const Icon(Icons.help, size: 60, color: Colors.grey);
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
      default:
        return '其他';
    }
  }

  Widget _buildStatusCard(String label, int value, Color color, IconData icon) {
    return Container(
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: value / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [color.withOpacity(0.8), color],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('$value/100', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blue, size: 24),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInteractionButton(String label, IconData icon, Color color, String type) {
    return ElevatedButton(
      onPressed: () => _interact(type),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
