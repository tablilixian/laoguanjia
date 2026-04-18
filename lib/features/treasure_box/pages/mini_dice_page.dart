import 'dart:math';
import 'package:flutter/material.dart';

/// 掷骰子页面 - 简单的1-6随机骰子
/// 
/// 点击开始按钮后，骰子会进行旋转动画然后随机停下显示结果
class MiniDicePage extends StatefulWidget {
  const MiniDicePage({super.key});

  @override
  State<MiniDicePage> createState() => _MiniDicePageState();
}

class _MiniDicePageState extends State<MiniDicePage>
    with SingleTickerProviderStateMixin {
  // 当前骰子点数 (1-6)
  int _currentValue = 1;
  
  // 是否正在动画中
  bool _isRolling = false;
  
  // 历史记录
  final List<int> _history = [];
  
  // 动画控制器
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  /// 开始掷骰子
  void _rollDice() {
    if (_isRolling) return;
    
    setState(() {
      _isRolling = true;
    });
    
    // 生成随机结果
    final random = Random();
    final result = random.nextInt(6) + 1;
    
    // 旋转动画
    _controller.reset();
    _rotationAnimation = Tween<double>(begin: 0, end: result.toDouble()).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _controller.forward().then((_) {
      setState(() {
        _currentValue = result;
        _isRolling = false;
        _history.insert(0, result);
        // 只保留最近10条记录
        if (_history.length > 10) {
          _history.removeLast();
        }
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '掷骰子',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              
              // 骰子显示区域
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final value = _isRolling
                      ? (_rotationAnimation.value.ceil() % 6)
                      : _currentValue;
                  return _DiceWidget(value: value);
                },
              ),
              
              const SizedBox(height: 32),
              
              // 点数显示
              Text(
                _isRolling ? 'rolling...' : '点数：$_currentValue',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _isRolling
                      ? theme.colorScheme.onSurfaceVariant
                      : const Color(0xFFFF7043),
                ),
              ),
              
              const Spacer(),
              
              // 开始按钮
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isRolling ? null : _rollDice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7043),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isRolling ? '等待结果...' : '🎲  开始',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 历史记录
              if (_history.isNotEmpty) ...[
                Text(
                  '历史记录',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: _history
                      .map((v) => _DiceMiniWidget(value: v))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 骰子大 widget
class _DiceWidget extends StatelessWidget {
  final int value;
  
  const _DiceWidget({required this.value});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7043).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getDiceChar(value),
          style: const TextStyle(fontSize: 96),
        ),
      ),
    );
  }
  
  String _getDiceChar(int v) {
    return ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'][v - 1];
  }
}

/// 历史记录中的小骰子
class _DiceMiniWidget extends StatelessWidget {
  final int value;
  
  const _DiceMiniWidget({required this.value});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7043).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'][value - 1],
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}