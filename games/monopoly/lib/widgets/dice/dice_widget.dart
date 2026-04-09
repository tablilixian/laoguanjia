// 地产大亨 - 骰子动画组件
import 'dart:math';
import 'package:flutter/material.dart';

class DiceWidget extends StatefulWidget {
  final int? dice1;
  final int? dice2;
  final bool isRolling;
  final VoidCallback? onRollComplete;
  final double size;

  const DiceWidget({
    super.key,
    this.dice1,
    this.dice2,
    this.isRolling = false,
    this.onRollComplete,
    this.size = 60,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> with TickerProviderStateMixin {
  late AnimationController _rollController;
  late Animation<double> _rotationAnimation;
  final Random _random = Random();
  int _displayDice1 = 1;
  int _displayDice2 = 1;

  @override
  void initState() {
    super.initState();
    _rollController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rollController, curve: Curves.easeInOut),
    );
    
    _rollController.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.onRollComplete != null) {
        widget.onRollComplete!();
      }
    });
  }

  @override
  void didUpdateWidget(DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRolling && !oldWidget.isRolling) {
      _startRolling();
    } else if (widget.dice1 != null && widget.dice2 != null) {
      _displayDice1 = widget.dice1!;
      _displayDice2 = widget.dice2!;
    }
  }

  void _startRolling() async {
    for (int i = 0; i < 6; i++) {
      if (!mounted || !_rollController.isAnimating) break;
      setState(() {
        _displayDice1 = _random.nextInt(6) + 1;
        _displayDice2 = _random.nextInt(6) + 1;
      });
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (mounted) {
      setState(() {
        _displayDice1 = widget.dice1 ?? 1;
        _displayDice2 = widget.dice2 ?? 1;
      });
    }
  }

  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDice(_displayDice1),
        const SizedBox(width: 16),
        _buildDice(_displayDice2),
      ],
    );
  }

  Widget _buildDice(int value) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        final rotation = widget.isRolling 
            ? _rotationAnimation.value * 2 * pi * (1 + _random.nextDouble())
            : 0.0;
        
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(rotation)
            ..rotateY(rotation * 0.5),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                value.toString(),
                style: TextStyle(
                  fontSize: widget.size * 0.5,
                  fontWeight: FontWeight.bold,
                  color: _getDiceColor(value),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getDiceColor(int value) {
    if (value <= 2) return Colors.red;
    if (value <= 4) return Colors.black;
    return Colors.blue;
  }
}

/// 骰子结果显示组件（用于显示最终结果）
class DiceResultWidget extends StatelessWidget {
  final int dice1;
  final int dice2;
  final bool isDoubles;
  final double size;

  const DiceResultWidget({
    super.key,
    required this.dice1,
    required this.dice2,
    this.isDoubles = false,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStaticDice(dice1),
            const SizedBox(width: 16),
            _buildStaticDice(dice2),
          ],
        ),
        if (isDoubles)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '双三！再掷一次',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStaticDice(int value) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          value.toString(),
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
            color: _getDiceColor(value),
          ),
        ),
      ),
    );
  }

  Color _getDiceColor(int value) {
    if (value <= 2) return Colors.red;
    if (value <= 4) return Colors.black;
    return Colors.blue;
  }
}