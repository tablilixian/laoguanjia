import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/data/models/pet_local_data.dart';
import 'package:home_manager/data/models/pet_meta.dart';
import 'package:home_manager/features/pets_v2/providers/pet_v2_provider.dart';
import 'package:home_manager/features/pets_v2/widgets/pet_avatar.dart';
import 'package:home_manager/features/pets_v2/widgets/status_bar.dart';
import 'package:home_manager/features/pets_v2/widgets/interaction_button.dart';
import 'package:home_manager/features/pets_v2/widgets/mood_bubble.dart';

/// 宠物 V2 主页 — 重新设计
///
/// 展示宠物列表、详细状态、快捷互动、经验进度、关系统计等。
class PetV2HomePage extends ConsumerStatefulWidget {
  const PetV2HomePage({super.key});

  @override
  ConsumerState<PetV2HomePage> createState() => _PetV2HomePageState();
}

class _PetV2HomePageState extends ConsumerState<PetV2HomePage> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metasAsync = ref.watch(petV2MetasProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '宠物',
          style: TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF5D4037)),
            onPressed: () => context.push('/home/pets_v2/create'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF5D4037)),
            onPressed: () => context.push('/home/pets_v2/settings'),
          ),
        ],
      ),
      body: metasAsync.when(
        data: (metas) {
          if (metas.isEmpty) return _buildEmptyState(context);
          return _buildPetCarousel(context, ref, metas);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFFF9800),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          switch (index) {
            case 0:
              context.push('/home/pets_v2/room');
              break;
            case 1:
              context.push('/home/pets_v2/briefing');
              break;
            case 2:
              context.push('/home/pets_v2/tasks');
              break;
            case 3:
              context.push('/home/pets_v2/items');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '房间',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed_outlined),
            activeIcon: Icon(Icons.dynamic_feed),
            label: '播报',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_outlined),
            activeIcon: Icon(Icons.task),
            label: '任务',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: '物品',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pets, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '还没有宠物',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右上角添加宠物',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/home/pets_v2/create'),
            icon: const Icon(Icons.add),
            label: const Text('添加宠物'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCarousel(
    BuildContext context,
    WidgetRef ref,
    List<PetMeta> metas,
  ) {
    return Column(
      children: [
        // Page indicator dots
        if (metas.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(metas.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? const Color(0xFFFF9800)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        // Horizontal pet cards
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: metas.length,
            itemBuilder: (context, index) {
              final meta = metas[index];
              return _PetCard(meta: meta, key: ValueKey(meta.id));
            },
          ),
        ),
      ],
    );
  }
}

/// 单个宠物卡片
class _PetCard extends ConsumerStatefulWidget {
  final PetMeta meta;

  const _PetCard({required this.meta, super.key});

  @override
  ConsumerState<_PetCard> createState() => _PetCardState();
}

class _PetCardState extends ConsumerState<_PetCard> {
  bool _showDetails = false;

  static const _typeEmojis = {
    'cat': '🐱',
    'dog': '🐶',
    'rabbit': '🐰',
    'hamster': '🐹',
    'bird': '🐦',
    'fish': '🐟',
    'turtle': '🐢',
    'lizard': '🦎',
    'snake': '🐍',
    'horse': '🐴',
    'cow': '🐮',
    'pig': '🐷',
    'sheep': '🐑',
    'goat': '🐐',
    'chicken': '🐔',
    'duck': '🦆',
    'frog': '🐸',
    'hedgehog': '🦔',
    'other': '🐾',
  };

  @override
  Widget build(BuildContext context) {
    final petDataAsync = ref.watch(currentPetV2DataProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: petDataAsync.when(
        data: (data) {
          if (data == null) return const _EmptyPetCard();
          return _buildLoadedCard(data);
        },
        loading: () => const Card(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const Card(
          child: Center(child: Text('加载失败')),
        ),
      ),
    );
  }

  Widget _buildLoadedCard(PetLocalData data) {
    final meta = widget.meta;
    final emoji = _typeEmojis[meta.type] ?? '🐾';
    final expPercent = data.state.level > 0
        ? data.state.experience / (data.state.level * 100)
        : 0.0;
    final daysSince = data.relationship.firstInteractionAt != null
        ? DateTime.now().difference(data.relationship.firstInteractionAt!).inDays
        : 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar + Name + Type
            Row(
              children: [
                PetAvatarWidget(
                  type: meta.type,
                  mood: data.state.currentMood,
                  size: 72,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            meta.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(emoji, style: const TextStyle(fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (meta.breed != null && meta.breed!.isNotEmpty)
                        Text(
                          meta.breed!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _badge('Lv.${data.state.level}', const Color(0xFFFF9800)),
                          const SizedBox(width: 6),
                          _badge('亲密度 ${data.relationship.intimacyLevel}', const Color(0xFFE91E63)),
                          if (daysSince > 0) ...[
                            const SizedBox(width: 6),
                            _badge('$daysSince 天', const Color(0xFF4CAF50)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Mood bubble
            const SizedBox(height: 12),
            if (data.state.moodText != null && data.state.moodText!.isNotEmpty)
              MoodBubble(
                text: data.state.moodText!,
                emoji: _moodEmoji(data.state.currentMood),
              ),
            const SizedBox(height: 16),

            // Status bars
            PetStatusBar(label: '饥饿', value: data.state.hunger, icon: '🍖'),
            PetStatusBar(label: '心情', value: data.state.happiness, icon: '😊'),
            PetStatusBar(label: '清洁', value: data.state.cleanliness, icon: '🛁'),
            PetStatusBar(label: '健康', value: data.state.health, icon: '💪'),

            // Experience bar
            const SizedBox(height: 12),
            _expBar(data.state.level, data.state.experience, expPercent),

            // Interaction buttons
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                PetInteractionButton(
                  icon: Icons.restaurant,
                  label: '喂食',
                  color: const Color(0xFFFF7043),
                  onTap: () => _interact(ref, data.petId, 'feed', context),
                ),
                PetInteractionButton(
                  icon: Icons.sports_baseball,
                  label: '玩耍',
                  color: const Color(0xFF42A5F5),
                  onTap: () => _interact(ref, data.petId, 'play', context),
                ),
                PetInteractionButton(
                  icon: Icons.bathtub,
                  label: '洗澡',
                  color: const Color(0xFF26C6DA),
                  onTap: () => _interact(ref, data.petId, 'bath', context),
                ),
                PetInteractionButton(
                  icon: Icons.school,
                  label: '训练',
                  color: const Color(0xFFAB47BC),
                  onTap: () => _interact(ref, data.petId, 'train', context),
                ),
              ],
            ),

            // Expandable details
            const SizedBox(height: 16),
            InkWell(
              onTap: () => setState(() => _showDetails = !_showDetails),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showDetails ? '收起详情' : '查看详情',
                      style: const TextStyle(
                        color: Color(0xFFFF9800),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showDetails ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFFFF9800),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_showDetails) _buildDetails(data),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(PetLocalData data) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '互动统计',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 8),
          _statRow('总互动', '${data.relationship.totalInteractions} 次'),
          _statRow('喂食', '${data.relationship.feedCount} 次'),
          _statRow('玩耍', '${data.relationship.playCount} 次'),
          _statRow('聊天', '${data.relationship.chatCount} 次'),
          _statRow('探索', '${data.state.explorationCount} 次'),
          const SizedBox(height: 8),
          const Text(
            '人格特征',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 8),
          if (data.personality.traits.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: data.personality.traits
                  .map((t) => _traitChip(t))
                  .toList(),
            )
          else
            const Text('暂无特征', style: TextStyle(color: Colors.grey, fontSize: 13)),
          if (data.state.skills.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              '已解锁技能',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: data.state.skills
                  .where((s) => s.unlocked)
                  .map((s) => _skillChip(s.name))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _expBar(int level, int exp, double percent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '经验',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5D4037),
              ),
            ),
            Text(
              '$exp / ${level * 100}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: const Color(0xFFFFE0B2),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF9800)),
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _traitChip(String trait) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE1BEE7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        trait,
        style: const TextStyle(fontSize: 12, color: Color(0xFF7B1FA2)),
      ),
    );
  }

  Widget _skillChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E6C9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        name,
        style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
      ),
    );
  }

  String _moodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy': return '😊';
      case 'sad': return '😢';
      case 'neutral': return '😐';
      case 'excited': return '🤩';
      case 'hungry': return '🤤';
      case 'tired': return '😴';
      default: return '🙂';
    }
  }

  Future<void> _interact(
    WidgetRef ref,
    String petId,
    String type,
    BuildContext context,
  ) async {
    try {
      await ref.read(petV2ServiceProvider).interact(petId, type);
      ref.invalidate(currentPetV2DataProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_interactionFeedback(type)),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('互动失败: $e')),
        );
      }
    }
  }

  String _interactionFeedback(String type) {
    switch (type) {
      case 'feed': return '🍖 喂食成功！肚子饱饱的~';
      case 'play': return '🎾 玩得真开心！';
      case 'bath': return '🛁 洗得干干净净~';
      case 'train': return '📚 训练完成，好聪明！';
      default: return '互动成功！';
    }
  }
}

class _EmptyPetCard extends StatelessWidget {
  const _EmptyPetCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Center(child: Text('暂无宠物数据')),
    );
  }
}
