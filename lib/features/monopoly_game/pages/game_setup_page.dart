import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/storage_service.dart';
import '../models/models.dart';
import '../providers/game_provider.dart';
import '../constants/themes/theme_provider.dart';
import '../constants/themes/board_theme.dart';

/// 游戏设置页面
class GameSetupPage extends ConsumerStatefulWidget {
  const GameSetupPage({super.key});

  @override
  ConsumerState<GameSetupPage> createState() => _GameSetupPageState();
}

class _GameSetupPageState extends ConsumerState<GameSetupPage> {
  // 游戏设置
  int _playerCount = 2;
  List<PlayerConfig> _playerConfigs = [
    PlayerConfig(name: '你', isHuman: true),
    PlayerConfig(name: '电脑1', isHuman: false, difficulty: AIDifficulty.easy, personality: AIPersonality.conservative),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedSetup();
  }

  /// 加载保存的游戏设置
  Future<void> _loadSavedSetup() async {
    try {
      final storage = await StorageService.getInstance();
      final savedSetup = await storage.getString('game_setup');
      if (savedSetup != null) {
        final setupData = GameSetup.fromJson(jsonDecode(savedSetup));
        setState(() {
          _playerCount = setupData.playerCount;
          _playerConfigs = setupData.playerConfigs;
        });
      }
    } catch (e) {
      print('加载游戏设置失败: $e');
    }
  }

  /// 保存游戏设置
  Future<void> _saveSetup() async {
    try {
      final storage = await StorageService.getInstance();
      final setup = GameSetup(
        playerCount: _playerCount,
        playerConfigs: _playerConfigs,
      );
      await storage.setString('game_setup', jsonEncode(setup.toJson()));
    } catch (e) {
      print('保存游戏设置失败: $e');
    }
  }

  /// 更新玩家数量
  void _updatePlayerCount(int count) {
    setState(() {
      _playerCount = count;
      // 调整玩家配置列表
      if (_playerConfigs.length < count) {
        // 添加新玩家
        for (int i = _playerConfigs.length; i < count; i++) {
          _playerConfigs.add(
            PlayerConfig(
              name: '电脑${i}',
              isHuman: false,
              difficulty: AIDifficulty.easy,
              personality: AIPersonality.conservative,
            ),
          );
        }
      } else if (_playerConfigs.length > count) {
        // 移除多余的玩家
        _playerConfigs = _playerConfigs.sublist(0, count);
      }
      _saveSetup();
    });
  }

  /// 更新玩家配置
  void _updatePlayerConfig(int index, PlayerConfig config) {
    setState(() {
      _playerConfigs[index] = config;
      _saveSetup();
    });
  }

  /// 开始游戏
  void _startGame() {
    final gameNotifier = ref.read(gameProvider.notifier);
    // 初始化游戏
    gameNotifier.initGameWithSetup(
      GameSetup(
        playerCount: _playerCount,
        playerConfigs: _playerConfigs,
      ),
    );
    // 返回游戏页面
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏设置'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // 返回到app的home页面
            context.go('/home');
          },
        ),
      ),
body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主题选择（移动端友好）
          _buildThemeSection(),
          const SizedBox(height: 24),
          // 游戏人数设置
            _buildPlayerCountSection(),
            const SizedBox(height: 24),
            // 玩家配置（可滚动）
            _buildPlayerConfigsSection(),
            // 开始游戏按钮
            Center(
              child: ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('开始游戏'),
              ),
            ),
            const SizedBox(height: 16), // 底部留出空间
          ],
        ),
      ),
    );
  }

  /// 构建主题选择部分（移动端友好）
  Widget _buildThemeSection() {
    final themes = ref.watch(availableThemesProvider);
    final selectedThemeId = ref.watch(selectedThemeIdProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择地图',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // 主题选择按钮组（横向排列，更适合移动端）
        Row(
          children: themes.map((theme) {
            final isSelected = theme.info.id == selectedThemeId;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ThemeButton(
                  theme: theme,
                  isSelected: isSelected,
                  onTap: () {
                    ref.read(selectedThemeIdProvider.notifier).setTheme(theme.info.id);
                  },
                ),
              ),
            );
          }).toList(),
        ),
        // 显示当前选择的主题描述
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            ref.watch(currentThemeProvider).info.description,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建游戏人数设置部分
  Widget _buildPlayerCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '游戏人数',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 2; i <= 4; i++)
              Expanded(
                child: RadioListTile<int>(
                  title: Text('${i}人'),
                  value: i,
                  groupValue: _playerCount,
                  onChanged: (value) {
                    if (value != null) {
                      _updatePlayerCount(value);
                    }
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 构建玩家配置部分
  Widget _buildPlayerConfigsSection() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '玩家配置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._playerConfigs.asMap().entries.map((entry) {
              int index = entry.key;
              PlayerConfig config = entry.value;
              return _buildPlayerConfigCard(index, config);
            }).toList(),
            const SizedBox(height: 32), // 底部留出空间
          ],
        ),
      ),
    );
  }

  /// 构建玩家配置卡片
  Widget _buildPlayerConfigCard(int index, PlayerConfig config) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '玩家 ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: config.isHuman,
                  onChanged: (value) {
                    _updatePlayerConfig(
                      index,
                      config.copyWith(isHuman: value),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 玩家类型
            Row(
              children: [
                const Text('类型: '),
                Text(config.isHuman ? '真人' : '机器人'),
              ],
            ),
            const SizedBox(height: 12),
            // 名字输入
            TextField(
              controller: TextEditingController(text: config.name)..selection = TextSelection.collapsed(offset: config.name.length),
              decoration: const InputDecoration(
                labelText: '名字',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _updatePlayerConfig(
                  index,
                  config.copyWith(name: value),
                );
              },
            ),
            const SizedBox(height: 12),
            // 机器人设置
            if (!config.isHuman)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '机器人设置',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 难度设置
                  Row(
                    children: [
                      const Text('难度: '),
                      DropdownButton<AIDifficulty>(
                        value: config.difficulty,
                        onChanged: (value) {
                          if (value != null) {
                            _updatePlayerConfig(
                              index,
                              config.copyWith(difficulty: value),
                            );
                          }
                        },
                        items: AIDifficulty.values.map((difficulty) {
                          return DropdownMenuItem<AIDifficulty>(
                            value: difficulty,
                            child: Text(difficulty == AIDifficulty.easy ? '简单' : '困难'),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 性格设置
                  Row(
                    children: [
                      const Text('性格: '),
                      DropdownButton<AIPersonality>(
                        value: config.personality,
                        onChanged: (value) {
                          if (value != null) {
                            _updatePlayerConfig(
                              index,
                              config.copyWith(personality: value),
                            );
                          }
                        },
                        items: AIPersonality.values.map((personality) {
                          String name;
                          switch (personality) {
                            case AIPersonality.aggressive:
                              name = '激进型';
                              break;
                            case AIPersonality.conservative:
                              name = '保守型';
                              break;
                            case AIPersonality.random:
                              name = '随机型';
                              break;
                          }
                          return DropdownMenuItem<AIPersonality>(
                            value: personality,
                            child: Text(name),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 游戏设置模型
class GameSetup {
  final int playerCount;
  final List<PlayerConfig> playerConfigs;

  GameSetup({
    required this.playerCount,
    required this.playerConfigs,
  });

  Map<String, dynamic> toJson() {
    return {
      'playerCount': playerCount,
      'playerConfigs': playerConfigs.map((config) => config.toJson()).toList(),
    };
  }

  factory GameSetup.fromJson(Map<String, dynamic> json) {
    return GameSetup(
      playerCount: json['playerCount'] ?? 2,
      playerConfigs: (json['playerConfigs'] as List? ?? [])
          .map((config) => PlayerConfig.fromJson(config))
          .toList(),
    );
  }
}

/// 玩家配置模型
class PlayerConfig {
  final String name;
  final bool isHuman;
  final AIDifficulty difficulty;
  final AIPersonality personality;

  PlayerConfig({
    required this.name,
    required this.isHuman,
    this.difficulty = AIDifficulty.easy,
    this.personality = AIPersonality.conservative,
  });

  PlayerConfig copyWith({
    String? name,
    bool? isHuman,
    AIDifficulty? difficulty,
    AIPersonality? personality,
  }) {
    return PlayerConfig(
      name: name ?? this.name,
      isHuman: isHuman ?? this.isHuman,
      difficulty: difficulty ?? this.difficulty,
      personality: personality ?? this.personality,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isHuman': isHuman,
      'difficulty': difficulty.index,
      'personality': personality.index,
    };
  }

  factory PlayerConfig.fromJson(Map<String, dynamic> json) {
    return PlayerConfig(
      name: json['name'] ?? '玩家',
      isHuman: json['isHuman'] ?? true,
      difficulty: AIDifficulty.values[json['difficulty'] ?? 0],
      personality: AIPersonality.values[json['personality'] ?? 0],
    );
  }
}

/// 主题选择按钮组件
class _ThemeButton extends StatelessWidget {
  final BoardTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getThemeIcon(),
                size: 28,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                theme.info.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getThemeIcon() {
    switch (theme.info.type) {
      case BoardThemeType.chinaCities:
        return Icons.location_city;
      case BoardThemeType.international:
        return Icons.public;
    }
  }
}
