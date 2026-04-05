import 'package:flutter/material.dart';

/// 宠物头像组件，带呼吸动画和心情徽章
class PetAvatarWidget extends StatefulWidget {
  final String type;
  final String? mood;
  final double size;

  const PetAvatarWidget({
    super.key,
    required this.type,
    this.mood,
    this.size = 80,
  });

  @override
  State<PetAvatarWidget> createState() => _PetAvatarWidgetState();
}

class _PetAvatarWidgetState extends State<PetAvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getEmoji() {
    switch (widget.type.toLowerCase()) {
      case 'cat':
        return '🐱';
      case 'dog':
        return '🐶';
      case 'rabbit':
        return '🐰';
      case 'hamster':
        return '🐹';
      case 'bird':
      case 'parrot':
        return '🐦';
      case 'fish':
        return '🐟';
      case 'turtle':
        return '🐢';
      case 'lizard':
        return '🦎';
      case 'snake':
        return '🐍';
      case 'horse':
        return '🐴';
      case 'cow':
        return '🐮';
      case 'pig':
        return '🐷';
      case 'sheep':
        return '🐑';
      case 'goat':
        return '🐐';
      case 'chicken':
        return '🐔';
      case 'duck':
        return '🦆';
      case 'frog':
        return '🐸';
      case 'hedgehog':
        return '🦔';
      case 'ferret':
        return '🦫';
      case 'guinea_pig':
        return '🐹';
      case 'chinchilla':
        return '🐭';
      default:
        return '🐾';
    }
  }

  String _getMoodEmoji() {
    if (widget.mood == null) return '';
    switch (widget.mood!.toLowerCase()) {
      case 'happy':
      case 'joy':
        return '😊';
      case 'sad':
      case 'sadness':
        return '😢';
      case 'angry':
        return '😠';
      case 'neutral':
        return '😐';
      case 'excited':
        return '🤩';
      case 'hungry':
        return '🤤';
      case 'tired':
        return '😴';
      case 'sick':
        return '🤒';
      case 'love':
        return '🥰';
      default:
        return '🙂';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.scale(
                scale: _animation.value,
                child: child,
              );
            },
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF5E6), Color(0xFFFFE0B2)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _getEmoji(),
                  style: TextStyle(fontSize: widget.size * 0.5),
                ),
              ),
            ),
          ),
          if (widget.mood != null && widget.mood!.isNotEmpty)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                ),
                child: Text(
                  _getMoodEmoji(),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
