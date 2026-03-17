import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/exploration_diary.dart';
import 'package:home_manager/core/services/exploration_service.dart';

class ExplorationDiaryListPage extends ConsumerStatefulWidget {
  final Pet pet;

  const ExplorationDiaryListPage({super.key, required this.pet});

  @override
  ConsumerState<ExplorationDiaryListPage> createState() =>
      _ExplorationDiaryListPageState();
}

class _ExplorationDiaryListPageState
    extends ConsumerState<ExplorationDiaryListPage> {
  final ExplorationService _explorationService = ExplorationService();

  List<ExplorationDiary> _diaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDiaries();
  }

  Future<void> _loadDiaries() async {
    try {
      final diaries = await _explorationService.getDiaries(
        widget.pet.id,
        limit: 50,
      );
      setState(() {
        _diaries = diaries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              _getPetEmoji(widget.pet.type),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            Text('${widget.pet.name}的探索日记'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/home/pets/${widget.pet.id}/explore', extra: widget.pet);
        },
        icon: const Icon(Icons.explore),
        label: const Text('新的探索'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_diaries.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadDiaries,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _diaries.length,
        itemBuilder: (context, index) {
          return _buildDiaryCard(_diaries[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.explore_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无探索日记',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '让${widget.pet.name}外出探险，发现精彩故事',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/home/pets/${widget.pet.id}/explore', extra: widget.pet);
            },
            icon: const Icon(Icons.explore),
            label: const Text('开始探索'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryCard(ExplorationDiary diary) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          context.push(
            '/home/pets/${widget.pet.id}/explore/${diary.id}',
            extra: {'pet': widget.pet, 'diary': diary},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade300, Colors.red.shade300],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        '🗺️',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          diary.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(diary.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTag(
                    Icons.location_on,
                    '${diary.stops.length}个地点',
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  if (diary.moodAfter != null)
                    _buildTag(
                      _getMoodEmoji(diary.moodAfter!),
                      _getMoodLabel(diary.moodAfter!),
                      Colors.purple,
                    ),
                  const SizedBox(width: 8),
                  _buildTag(
                    Icons.timer,
                    '${diary.durationMinutes}分钟',
                    Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(dynamic icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon is IconData)
            Icon(icon, size: 12, color: color)
          else if (icon is String)
            Text(icon, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return '今天 ${_formatTime(date)}';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      return '昨天 ${_formatTime(date)}';
    } else {
      return '${date.year}年${date.month}月${date.day}日';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getPetEmoji(String type) {
    const emojis = {
      'cat': '🐱',
      'dog': '🐕',
      'rabbit': '🐰',
      'hamster': '🐹',
      'guinea_pig': '🐹',
      'chinchilla': '🐭',
      'bird': '🐦',
      'parrot': '🦜',
      'fish': '🐟',
      'turtle': '🐢',
      'lizard': '🦎',
      'hedgehog': '🦔',
      'ferret': '🦦',
      'pig': '🐷',
    };
    return emojis[type] ?? '🐾';
  }

  String _getMoodEmoji(String mood) {
    const emojis = {
      'happy': '😊',
      'excited': '🤩',
      'tired': '😴',
      'scared': '😨',
      'neutral': '😐',
    };
    return emojis[mood] ?? '😐';
  }

  String _getMoodLabel(String mood) {
    const labels = {
      'happy': '开心',
      'excited': '兴奋',
      'tired': '疲惫',
      'scared': '害怕',
      'neutral': '平静',
    };
    return labels[mood] ?? '平静';
  }
}
