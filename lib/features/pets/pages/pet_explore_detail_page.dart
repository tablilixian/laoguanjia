import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/exploration_diary.dart';
import 'package:home_manager/core/services/exploration_service.dart';

class ExplorationDiaryDetailPage extends ConsumerStatefulWidget {
  final String petId;
  final String diaryId;
  final Map<String, dynamic>? extra;

  const ExplorationDiaryDetailPage({
    super.key,
    required this.petId,
    required this.diaryId,
    this.extra,
  });

  @override
  ConsumerState<ExplorationDiaryDetailPage> createState() =>
      _ExplorationDiaryDetailPageState();
}

class _ExplorationDiaryDetailPageState
    extends ConsumerState<ExplorationDiaryDetailPage> {
  final ExplorationService _explorationService = ExplorationService();

  bool _isLoading = true;
  ExplorationDiary? _diary;
  Pet? _pet;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDiary();
  }

  Future<void> _loadDiary() async {
    try {
      // 从 extra 获取数据（如果页面是刚探索完跳转过来的）
      if (widget.extra != null) {
        _pet = widget.extra!['pet'] as Pet?;
        _diary = widget.extra!['diary'] as ExplorationDiary?;
      }

      // 如果没有数据，则从服务端加载
      if (_diary == null) {
        _diary = await _explorationService.getDiaryById(widget.diaryId);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('探索日记'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareDiary,
            tooltip: '分享',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      );
    }

    if (_diary == null) {
      return const Center(child: Text('日记不存在'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日记头部信息
          _buildHeader(),

          const SizedBox(height: 24),

          // 日记内容
          _buildContent(),

          const SizedBox(height: 24),

          // 状态变化
          _buildStatsChange(),

          const SizedBox(height: 24),

          // 操作按钮
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.red.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _getPetEmoji(_pet?.type ?? 'other'),
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _diary!.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(_diary!.createdAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getExplorationTypeLabel(_diary!.explorationType),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SelectableText(
        _diary!.content,
        style: const TextStyle(
          fontSize: 15,
          height: 1.8,
        ),
      ),
    );
  }

  Widget _buildStatsChange() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            '🍚',
            '饱食度',
            '-15',
            Colors.orange,
          ),
          _buildStatItem(
            '😊',
            '心情',
            '+5',
            Colors.blue,
          ),
          _buildStatItem(
            '⏱️',
            '时长',
            '${_diary!.durationMinutes}分钟',
            Colors.green,
          ),
          if (_diary!.moodAfter != null)
            _buildStatItem(
              _getMoodEmoji(_diary!.moodAfter!),
              '心情',
              _getMoodLabel(_diary!.moodAfter!),
              Colors.purple,
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String emoji, String label, String value, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // 再次探索
              context.pushReplacement(
                '/home/pets/${widget.petId}/explore',
                extra: _pet,
              );
            },
            icon: const Icon(Icons.explore),
            label: const Text('再次探索'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.home),
            label: const Text('返回主页'),
          ),
        ),
      ],
    );
  }

  void _shareDiary() {
    // TODO: 实现分享功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能开发中...')),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月'
    ];
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${date.year}年${months[date.month - 1]}${date.day}日 ${weekdays[date.weekday - 1]}';
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

  String _getExplorationTypeLabel(String type) {
    switch (type) {
      case 'normal':
        return '普通探索';
      case 'special':
        return '特殊探索';
      case 'auto':
        return '自动探索';
      default:
        return '探索';
    }
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
