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

/// 宠物管家 V2 主页
///
/// 展示宠物列表、状态、快捷互动。
class PetV2HomePage extends ConsumerWidget {
  const PetV2HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metasAsync = ref.watch(petV2MetasProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '宠物管家',
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
          if (metas.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildPetList(context, ref, metas);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
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
            '点击右上角添加你的第一个宠物管家',
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

  Widget _buildPetList(
    BuildContext context,
    WidgetRef ref,
    List<PetMeta> metas,
  ) {
    final selectedPetId = ref.watch(currentPetV2IdProvider);
    final petId = selectedPetId ?? metas.first.id;

    // Set first pet as selected if none selected
    if (selectedPetId == null && metas.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentPetV2IdProvider.notifier).state = metas.first.id;
      });
    }

    return CustomScrollView(
      slivers: [
        // Pet selector tabs
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: metas.length,
                itemBuilder: (context, index) {
                  final meta = metas[index];
                  final isSelected = meta.id == petId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(meta.name),
                      selected: isSelected,
                      onSelected: (_) {
                        ref.read(currentPetV2IdProvider.notifier).state =
                            meta.id;
                      },
                      selectedColor: const Color(0xFFFFE0B2),
                      checkmarkColor: const Color(0xFFFF9800),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Pet detail card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<PetLocalData?>(
              future: ref.read(petV2ServiceProvider).getPetData(petId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('加载失败: ${snapshot.error}'));
                }
                final data = snapshot.data;
                if (data == null) return const SizedBox.shrink();

                return _buildPetDetail(context, ref, data);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPetDetail(
    BuildContext context,
    WidgetRef ref,
    PetLocalData data,
  ) {
    final meta = ref
        .read(petV2MetasProvider)
        .value
        ?.firstWhere((m) => m.id == data.petId);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar + name + mood
            PetAvatarWidget(
              type: meta?.type ?? 'other',
              mood: data.state.currentMood,
              size: 100,
            ),
            const SizedBox(height: 12),
            Text(
              meta?.name ?? data.petId.substring(0, 6),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lv.${data.state.level} · 亲密度 Lv.${data.relationship.intimacyLevel}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),

            // Mood bubble
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
            const SizedBox(height: 20),

            // Interaction buttons
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
          ],
        ),
      ),
    );
  }

  String _moodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'neutral':
        return '😐';
      case 'excited':
        return '🤩';
      case 'hungry':
        return '🤤';
      case 'tired':
        return '😴';
      default:
        return '🙂';
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
      case 'feed':
        return '🍖 喂食成功！肚子饱饱的~';
      case 'play':
        return '🎾 玩得真开心！';
      case 'bath':
        return '🛁 洗得干干净净~';
      case 'train':
        return '📚 训练完成，好聪明！';
      default:
        return '互动成功！';
    }
  }
}
