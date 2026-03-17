import 'package:flutter/material.dart';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_memory.dart';
import 'package:home_manager/data/repositories/pet_ai_repository.dart';

class PetMemoriesPage extends StatefulWidget {
  final Pet pet;

  const PetMemoriesPage({super.key, required this.pet});

  @override
  State<PetMemoriesPage> createState() => _PetMemoriesPageState();
}

class _PetMemoriesPageState extends State<PetMemoriesPage> {
  final PetAIRepository _repository = PetAIRepository();
  List<PetMemory> _memories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    try {
      final memories = await _repository.getMemories(widget.pet.id);
      setState(() {
        _memories = memories;
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
            _getPetIcon(widget.pet.type),
            const SizedBox(width: 8),
            Text('${widget.pet.name} 的回忆'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _memories.isEmpty
          ? _buildEmptyState()
          : _buildMemoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_album_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无回忆',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '多和 ${widget.pet.name} 互动，会产生回忆哦',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryList() {
    final grouped = _groupMemoriesByType();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 里程碑
        if (grouped['milestone']?.isNotEmpty ?? false) ...[
          _buildSectionHeader('🎉 里程碑', Colors.orange),
          ...grouped['milestone']!.map((m) => _buildMemoryCard(m)),
          const SizedBox(height: 16),
        ],
        // 对话
        if (grouped['conversation']?.isNotEmpty ?? false) ...[
          _buildSectionHeader('💬 对话', Colors.blue),
          ...grouped['conversation']!.map((m) => _buildMemoryCard(m)),
          const SizedBox(height: 16),
        ],
        // 互动
        if (grouped['interaction']?.isNotEmpty ?? false) ...[
          _buildSectionHeader('🎮 互动', Colors.green),
          ...grouped['interaction']!.map((m) => _buildMemoryCard(m)),
          const SizedBox(height: 16),
        ],
        // 情绪
        if (grouped['emotion']?.isNotEmpty ?? false) ...[
          _buildSectionHeader('😊 情绪', Colors.purple),
          ...grouped['emotion']!.map((m) => _buildMemoryCard(m)),
          const SizedBox(height: 16),
        ],
        // 其他
        if (grouped['fact']?.isNotEmpty ?? false) ...[
          _buildSectionHeader('📝 记忆', Colors.grey),
          ...grouped['fact']!.map((m) => _buildMemoryCard(m)),
        ],
      ],
    );
  }

  Map<String, List<PetMemory>> _groupMemoriesByType() {
    final grouped = <String, List<PetMemory>>{};
    for (final memory in _memories) {
      grouped.putIfAbsent(memory.memoryType, () => []).add(memory);
    }
    return grouped;
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(PetMemory memory) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _getTypeEmoji(memory.memoryType),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  memory.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              _buildImportanceStars(memory.importance),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            memory.description,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                _formatDate(memory.occurredAt),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              if (memory.emotion != null) ...[
                const SizedBox(width: 12),
                Text(
                  _getEmotionText(memory.emotion!),
                  style: TextStyle(
                    color: _getEmotionColor(memory.emotion!),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImportanceStars(int importance) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < importance ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 14,
        );
      }),
    );
  }

  String _getTypeEmoji(String type) {
    switch (type) {
      case 'milestone':
        return '🎉';
      case 'conversation':
        return '💬';
      case 'interaction':
        return '🎮';
      case 'emotion':
        return '😊';
      case 'fact':
        return '📝';
      default:
        return '💭';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getEmotionText(String emotion) {
    switch (emotion) {
      case 'joy':
        return '开心';
      case 'sadness':
        return '难过';
      case 'fear':
        return '害怕';
      case 'anger':
        return '生气';
      case 'surprise':
        return '惊讶';
      default:
        return '平静';
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case 'joy':
        return Colors.orange;
      case 'sadness':
        return Colors.blue;
      case 'fear':
        return Colors.purple;
      case 'anger':
        return Colors.red;
      case 'surprise':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Widget _getPetIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'cat':
        icon = Icons.pets;
        color = Colors.purple;
        break;
      case 'dog':
        icon = Icons.pets;
        color = Colors.brown;
        break;
      case 'rabbit':
      case 'hamster':
      case 'guinea_pig':
      case 'chinchilla':
        icon = Icons.face;
        color = Colors.pink;
        break;
      case 'bird':
      case 'parrot':
        icon = Icons.flutter_dash;
        color = Colors.orange;
        break;
      case 'fish':
      case 'turtle':
        icon = Icons.water;
        color = Colors.blue;
        break;
      case 'lizard':
        icon = Icons.pest_control;
        color = Colors.green;
        break;
      default:
        icon = Icons.pets;
        color = Colors.grey;
    }
    return Icon(icon, color: color, size: 24);
  }
}
