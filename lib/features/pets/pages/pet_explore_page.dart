import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_personality.dart';
import 'package:home_manager/data/models/exploration_diary.dart';
import 'package:home_manager/data/repositories/pet_ai_repository.dart';
import 'package:home_manager/core/services/exploration_service.dart';
import 'package:home_manager/core/providers/tts_settings_provider.dart';
import 'package:home_manager/data/ai/tts_provider.dart';

class PetExplorePage extends ConsumerStatefulWidget {
  final String petId;
  final Pet? pet;

  const PetExplorePage({
    super.key,
    required this.petId,
    this.pet,
  });

  @override
  ConsumerState<PetExplorePage> createState() => _PetExplorePageState();
}

class _PetExplorePageState extends ConsumerState<PetExplorePage> {
  final ExplorationService _explorationService = ExplorationService();
  final PetAIRepository _aiRepository = PetAIRepository();

  bool _isLoading = true;
  bool _isExploring = false;
  String _currentContent = '';
  String? _errorMessage;
  Pet? _pet;
  PetPersonality? _personality;

  @override
  void initState() {
    super.initState();
    _loadPetData();
  }

  Future<void> _loadPetData() async {
    try {
      _pet = widget.pet;
      if (_pet == null) {
        // 如果没有传入 pet，需要重新加载
        // 这里简化处理，假设 widget.pet 总是有值
      }
      
      _personality = await _aiRepository.getPersonality(widget.petId);
      
      // 如果没有性格，创建一个默认性格
      if (_personality == null) {
        _personality = _createDefaultPersonality(widget.petId);
      }
      
      setState(() {
        _isLoading = false;
      });

      // 检查是否可以探索
      if (_pet != null) {
        final checkResult = await _explorationService.checkCanExplore(_pet!);
        if (!checkResult.canExplore) {
          setState(() {
            _errorMessage = checkResult.reason;
            _isLoading = false;
          });
          return;
        }

        // 开始探索
        _startExploration();
      } else {
        setState(() {
          _errorMessage = '无法加载宠物信息';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  PetPersonality _createDefaultPersonality(String petId) {
    return PetPersonality(
      id: '',
      petId: petId,
      openness: 0.5,
      agreeableness: 0.5,
      extraversion: 0.5,
      conscientiousness: 0.5,
      neuroticism: 0.5,
      traits: ['好奇', '活泼'],
      habits: ['喜欢探索'],
      fears: [],
      speechStyle: 'normal',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _startExploration() async {
    if (_pet == null || _personality == null) return;

    setState(() {
      _isExploring = true;
      _currentContent = '';
      _errorMessage = null;
    });

    // 获取 TTS 设置
    final ttsSettings = ref.read(ttsSettingsProvider);
    String _lastSpokenText = '';
    
    // 停止之前的 TTS
    ref.read(ttsProvider.notifier).stop();

    try {
      await for (final event in _explorationService.generateDiaryStream(
        pet: _pet!,
        personality: _personality!,
      )) {
        switch (event.type) {
          case ExplorationStreamEventType.started:
            setState(() {
              _currentContent = '正在准备出发...\n';
            });
            break;
          case ExplorationStreamEventType.contentUpdate:
            setState(() {
              _currentContent = event.content ?? '';
            });
            
            // TTS 语音播报：新增加的内容
            if (ttsSettings.enabled && event.content != null) {
              final newContent = event.content!;
              if (newContent.length > _lastSpokenText.length) {
                final newText = newContent.substring(_lastSpokenText.length);
                // 只播报新增加的内容
                if (newText.length > 10) {
                  ref.read(ttsProvider.notifier).speak(newText);
                  _lastSpokenText = newContent;
                }
              }
            }
            break;
          case ExplorationStreamEventType.completed:
            // 停止 TTS
            ref.read(ttsProvider.notifier).stop();
            if (event.diary != null) {
              if (mounted) {
                // 探索完成，跳转到详情页
                context.pushReplacement(
                  '/home/pets/${widget.petId}/explore/${event.diary!.id}',
                  extra: {'pet': _pet, 'diary': event.diary},
                );
              }
            }
            break;
          case ExplorationStreamEventType.error:
            ref.read(ttsProvider.notifier).stop();
            setState(() {
              _errorMessage = event.error;
              _isExploring = false;
            });
            break;
          case ExplorationStreamEventType.parsingFailed:
            // 解析失败但继续显示内容
            break;
        }
      }
    } catch (e) {
      ref.read(ttsProvider.notifier).stop();
      setState(() {
        _errorMessage = '探索失败: $e';
        _isExploring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ttsSettings = ref.watch(ttsSettingsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_pet != null ? '${_pet!.name}的探索' : '探索世界'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              ttsSettings.enabled ? Icons.volume_up : Icons.volume_off,
              color: ttsSettings.enabled ? Colors.green : null,
            ),
            onPressed: _toggleTTS,
            tooltip: ttsSettings.enabled ? '关闭语音' : '开启语音',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  void _toggleTTS() {
    ref.read(ttsSettingsProvider.notifier).toggle();
    final ttsSettings = ref.read(ttsSettingsProvider);
    if (ttsSettings.enabled) {
      ref.read(ttsProvider.notifier).speak('语音已开启');
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('准备探索中...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && !_isExploring) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 宠物状态卡片
          if (_pet != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        _getPetEmoji(_pet!.type),
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pet!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '正在探索世界...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isExploring)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // 探索动画和内容
          if (_isExploring || _currentContent.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 动画指示器
                  if (_isExploring)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          _buildPulsingDot(),
                          const SizedBox(width: 8),
                          Text(
                            _getExplorationStatus(_currentContent),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 内容展示
                  Text(
                    _currentContent,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(value),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted && _isExploring) {
          setState(() {});
        }
      },
    );
  }

  String _getExplorationStatus(String content) {
    if (content.isEmpty || content == '正在准备出发...\n') {
      return '准备出发...';
    }
    
    // 根据内容判断进度
    final stopMatches = RegExp(r'第[一二三四五六七八九十\d]+站').allMatches(content);
    final count = stopMatches.length;
    
    if (count == 0) return '发现第一个地点...';
    if (count < 3) return '继续探索中...';
    if (count < 6) return '发现更多有趣的地方...';
    return '准备回家...';
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
}
