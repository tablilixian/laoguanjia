import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/features/pets_v2/providers/pet_v2_provider.dart';

/// 记忆翻牌小游戏
///
/// 翻牌配对，配对成功得分。使用宠物相关元素作为卡片内容。
/// 游戏结果影响宠物的经验值。
class MemoryCardGamePage extends ConsumerStatefulWidget {
  const MemoryCardGamePage({super.key});

  @override
  ConsumerState<MemoryCardGamePage> createState() => _MemoryCardGamePageState();
}

class _MemoryCardGamePageState extends ConsumerState<MemoryCardGamePage>
    with SingleTickerProviderStateMixin {
  late List<_Card> _cards;
  int? _firstIndex;
  int? _secondIndex;
  bool _isChecking = false;
  int _moves = 0;
  int _matches = 0;
  bool _isGameOver = false;
  bool _gameStarted = false;

  late AnimationController _flipController;

  /// 卡片内容 (宠物相关 emoji)
  static const _cardEmojis = ['🐱', '🐶', '🐰', '🐹', '🐦', '🐟', '🐢', '🐸'];

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _initGame() {
    final random = math.Random();
    final selected = List.from(_cardEmojis)..shuffle(random);
    final pairs = selected.take(6).toList(); // 6 对 = 12 张卡片
    final allCards = [...pairs, ...pairs]..shuffle(random);

    _cards = allCards.map((emoji) => _Card(emoji: emoji, isFlipped: false, isMatched: false)).toList();
    _firstIndex = null;
    _secondIndex = null;
    _moves = 0;
    _matches = 0;
    _isGameOver = false;
    _gameStarted = true;
    _isChecking = false;
    setState(() {});
  }

  void _onCardTap(int index) {
    if (_isChecking || _isGameOver) return;
    if (_cards[index].isFlipped || _cards[index].isMatched) return;
    if (index == _firstIndex) return;

    setState(() {
      _cards[index].isFlipped = true;
    });

    if (_firstIndex == null) {
      _firstIndex = index;
    } else {
      _secondIndex = index;
      _moves++;
      _isChecking = true;
      _checkMatch();
    }
  }

  void _checkMatch() {
    final first = _cards[_firstIndex!];
    final second = _cards[_secondIndex!];

    Future.delayed(const Duration(milliseconds: 800), () {
      if (first.emoji == second.emoji) {
        setState(() {
          first.isMatched = true;
          second.isMatched = true;
          _matches++;
        });

        if (_matches == _cards.length ~/ 2) {
          setState(() => _isGameOver = true);
          _applyGameResult();
        }
      } else {
        setState(() {
          first.isFlipped = false;
          second.isFlipped = false;
        });
      }

      setState(() {
        _firstIndex = null;
        _secondIndex = null;
        _isChecking = false;
      });
    });
  }

  void _applyGameResult() {
    final petId = ref.read(currentPetV2IdProvider);
    if (petId == null) return;
    ref.read(petV2ServiceProvider).interact(petId, 'train');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '🃏 记忆翻牌',
          style: TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _gameStarted
          ? _buildGame()
          : _buildStartScreen(),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🃏', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          const Text(
            '记忆翻牌',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '翻开两张相同的卡片即可配对成功',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _initGame,
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
        ],
      ),
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        // HUD
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _hudItem('🎯', '$_moves 步'),
              _hudItem('✅', '$_matches/${_cards.length ~/ 2}'),
            ],
          ),
        ),
        // 卡片网格 (4x3)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.75,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                return _buildCard(index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(int index) {
    final card = _cards[index];
    final isRevealed = card.isFlipped || card.isMatched;

    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isRevealed
              ? (card.isMatched ? const Color(0xFFC8E6C9) : Colors.white)
              : const Color(0xFFFF9800),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: card.isMatched
                ? const Color(0xFF4CAF50)
                : const Color(0xFFFFE0B2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isRevealed
                ? Text(
                    card.emoji,
                    key: ValueKey(card.emoji),
                    style: const TextStyle(fontSize: 40),
                  )
                : const Text(
                    '❓',
                    key: ValueKey('back'),
                    style: TextStyle(fontSize: 30),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _hudItem(String icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// 记忆卡片数据
class _Card {
  final String emoji;
  bool isFlipped;
  bool isMatched;

  _Card({
    required this.emoji,
    this.isFlipped = false,
    this.isMatched = false,
  });
}
