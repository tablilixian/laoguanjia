import 'dart:math';
import 'package:flutter/material.dart';

/// 随机选择器页面 - 从多个选项中随机选择一个
/// 
/// 输入选项列表，点击开始后随机抽取一个结果
class RandomPickerPage extends StatefulWidget {
  const RandomPickerPage({super.key});

  @override
  State<RandomPickerPage> createState() => _RandomPickerPageState();
}

class _RandomPickerPageState extends State<RandomPickerPage> {
  // 选项列表
  final List<String> _options = ['选项一', '选项二', '选项三'];
  
  // 输入框控制器
  final _controller = TextEditingController();
  
  // 当前结果
  String? _result;
  
  // 是否正在抽取中
  bool _isPicking = false;
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  /// 添加新选项
  void _addOption() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    if (_options.contains(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选项已存在')),
      );
      return;
    }
    
    setState(() {
      _options.add(text);
      _controller.clear();
    });
  }
  
  /// 移除选项
  void _removeOption(int index) {
    setState(() {
      _options.removeAt(index);
      // 如果移除后没有结果了，清空结果
      if (_result != null && !_options.contains(_result)) {
        _result = null;
      }
    });
  }
  
  /// 开始抽取
  void _pick() {
    if (_options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加选项')),
      );
      return;
    }
    
    setState(() {
      _isPicking = true;
      _result = null;
    });
    
    // 动画效果
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      
      final random = Random();
      final result = _options[random.nextInt(_options.length)];
      
      setState(() {
        _result = result;
        _isPicking = false;
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
          '随机选择',
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
              // 选项输入区域
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '输入选项',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _addOption(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _addOption,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E57C2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 选项列表
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _options.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    final isResult = option == _result;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isResult
                            ? const Color(0xFF7E57C2).withValues(alpha: 0.1)
                            : null,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(15),
                          right: Radius.circular(15),
                        ),
                      ),
                      child: Row(
                        children: [
                          // 序号
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isResult
                                  ? const Color(0xFF7E57C2)
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isResult
                                    ? Colors.white
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // 选项文字
                          Expanded(
                            child: Text(
                              option,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: isResult
                                    ? FontWeight.w600
                                    : null,
                                color: isResult
                                    ? const Color(0xFF7E57C2)
                                    : null,
                              ),
                            ),
                          ),
                          
                          // 如果是结果，显示对勾
                          if (isResult)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF7E57C2),
                            ),
                          
                          // 删除按钮
                          IconButton(
                            onPressed: () => _removeOption(index),
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              const Spacer(),
              
              // 结果显示
              if (_result != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7E57C2), Color(0xFF5E35B1)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '🎉',
                        style: TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _result!,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // 开始按钮
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isPicking ? null : _pick,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E57C2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isPicking ? '🎲 抽取中...' : '🎲  开始抽取',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}