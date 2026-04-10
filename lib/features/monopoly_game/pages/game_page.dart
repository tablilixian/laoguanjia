// 地产大亨 - 游戏主页面
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/storage_service.dart';
import '../models/models.dart';
import '../constants/board_config.dart';
import '../constants/board_layout_config.dart';
import '../providers/game_provider.dart';
import '../services/save_service.dart';
import '../widgets/board/game_board.dart';
import '../widgets/dice/dice_widget.dart';
import '../widgets/dialogs/buy_dialog.dart';
import '../widgets/dialogs/build_dialog.dart';
import 'load_game_page.dart';
import 'game_setup_page.dart';

class MonopolyGamePage extends ConsumerStatefulWidget {
  const MonopolyGamePage({super.key});

  @override
  ConsumerState<MonopolyGamePage> createState() => _MonopolyGamePageState();
}

class _MonopolyGamePageState extends ConsumerState<MonopolyGamePage> {
  BoardLayoutConfig _currentLayout = BoardLayoutPresets.standard;
  
  @override
  void initState() {
    super.initState();
    // 初始化游戏
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadSavedLayout();
      // 先尝试加载存档
      final gameNotifier = ref.read(gameProvider.notifier);
      await gameNotifier.loadSavedGame();
      // 检查是否有存档
      final gameState = ref.read(gameProvider);
      if (gameState.players.isNotEmpty) {
        // 有存档，导航到加载游戏页面
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoadGamePage()),
        );
      } else {
        // 没有存档，导航到游戏设置页面
        _navigateToSetupPage();
      }
    });
  }

  /// 导航到游戏设置页面
  void _navigateToSetupPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GameSetupPage()),
    );
  }

  // 显示加载游戏对话框
  void _showLoadGameDialog(BuildContext context, GameNotifier gameNotifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现存档'),
        content: const Text('检测到有未完成的游戏，你是要继续上一局还是开始新游戏？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 继续上一局，不需要做任何操作
            },
            child: const Text('继续游戏'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 开始新游戏，导航到游戏设置页面
              _navigateToSetupPage();
            },
            child: const Text('新游戏'),
          ),
        ],
      ),
    );
  }

  // 加载保存的布局
  Future<void> _loadSavedLayout() async {
    final storage = await StorageService.getInstance();
    final layoutName = await storage.getString('board_layout');
    if (layoutName != null) {
      final layout = BoardLayoutPresets.getByName(layoutName);
      if (layout != null) {
        setState(() {
          _currentLayout = layout;
        });
      }
    }
  }

  // 保存布局
  Future<void> _saveLayout(BoardLayoutConfig layout) async {
    final storage = await StorageService.getInstance();
    await storage.setString('board_layout', layout.name);
  }

  // 监听游戏状态变化，自动触发AI行动
  void _watchGameState(GameState previous, GameState next) {
    // 当玩家列表为空时，不执行任何操作
    if (next.players.isEmpty) return;
    
    // 当玩家是AI或真人开启了自动操作时，视为AI回合
    final isAITurn = !next.currentPlayer.isHuman || next.currentPlayer.isAutoPlay;
    final isPhaseReady = next.phase == GamePhase.playerTurnStart || 
                         next.phase == GamePhase.playerAction;
    
    // 只在以下情况触发AI行动：
    // 1. 当前玩家是AI或真人开启了自动操作
    // 2. 游戏阶段是 playerTurnStart 或 playerAction
    // 3. 游戏未结束
    // 4. 状态确实发生了变化（避免重复触发）
    if (isAITurn && isPhaseReady && !next.isGameOver) {
      // 检查是否是状态变化触发的（避免重复触发）
      final isStateChanged = previous.phase != next.phase || 
                             previous.currentPlayerIndex != next.currentPlayerIndex ||
                             previous.currentPlayer.isAutoPlay != next.currentPlayer.isAutoPlay;
      
      if (isStateChanged) {
        // AI回合，延迟执行
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ref.read(gameProvider.notifier).performAIAction();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final isPlayerTurn = ref.watch(isPlayerTurnProvider);
    
    // 游戏未初始化时显示加载界面
    if (gameState.players.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('地产大亨'),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在初始化游戏...'),
            ],
          ),
        ),
      );
    }
    
    // 监听状态变化触发 AI
    ref.listen(gameProvider, (previous, next) {
      if (previous != null) {
        _watchGameState(previous, next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('地产大亨'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await ref.read(gameProvider.notifier).saveGame();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('游戏已保存')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showGameRulesDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => _showOperationRecordsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 游戏信息栏
          _buildInfoBar(gameState),
          // 棋盘区域（使用Stack将骰子和玩家信息叠加在棋盘中间）
          Expanded(
            child: Container(
              child: Stack(
                children: [
                  GameBoard(layoutConfig: _currentLayout),
                  // 中间层：骰子区域（居中显示）
                  if (gameState.phase == GamePhase.diceRolling || 
                      gameState.lastDice1 != null)
                    Center(
                      child: _buildDiceArea(gameState),
                    ),
                  // 顶层：玩家信息（棋盘上方1/4位置，居中显示）
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: const Alignment(0, -0.5),
                      child: _buildPlayerInfo(gameState),
                    ),
                  ),
                  // 游戏结束显示胜利界面
                  if (gameState.phase == GamePhase.gameOver)
                    Center(
                      child: _buildGameOverOverlay(gameState),
                    ),
                ],
              ),
            ),
          ),
          // 操作按钮
          _buildActionButtons(gameState, isPlayerTurn),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay(GameState gameState) {
    final winner = gameState.players.firstWhere((p) => p.id == gameState.winnerId);
    final isPlayerWin = winner.isHuman;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPlayerWin ? Icons.emoji_events : Icons.sentiment_dissatisfied,
            size: 80,
            color: isPlayerWin ? Colors.amber : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            isPlayerWin ? '恭喜你获胜！' : '游戏结束',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '胜利者: ${winner.name}',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              ref.read(gameProvider.notifier).initGame(const GameSettings());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('再来一局', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceArea(GameState gameState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gameState.phase == GamePhase.diceRolling)
            const DiceWidget(
              dice1: 1,
              dice2: 1,
              isRolling: true,
              size: 60,
            )
          else if (gameState.lastDice1 != null && gameState.lastDice2 != null)
            DiceResultWidget(
              dice1: gameState.lastDice1!,
              dice2: gameState.lastDice2!,
              isDoubles: gameState.isDoubles,
              size: 60,
            ),
          const SizedBox(height: 8),
          Text(
            '点数: ${(gameState.lastDice1 ?? 0) + (gameState.lastDice2 ?? 0)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (gameState.isDoubles && gameState.lastDice1 != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '对子！',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoBar(GameState gameState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '第 ${gameState.turnNumber} 回合',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '当前: ${gameState.currentPlayer.name}',
            style: TextStyle(
              color: gameState.currentPlayer.tokenColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(_getPhaseText(gameState.phase)),
        ],
      ),
    );
  }

  String _getPhaseText(GamePhase phase) {
    switch (phase) {
      case GamePhase.init:
        return '初始化';
      case GamePhase.playerTurnStart:
        return '等待掷骰';
      case GamePhase.diceRolling:
        return '掷骰中...';
      case GamePhase.playerMoving:
        return '移动中...';
      case GamePhase.eventProcessing:
        return '处理事件...';
      case GamePhase.playerAction:
        return '请选择操作';
      case GamePhase.turnEnd:
        return '回合结束';
      case GamePhase.gameOver:
        return '游戏结束!';
    }
  }

  Widget _buildPlayerInfo(GameState gameState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: gameState.players.asMap().entries.map((entry) {
        final index = entry.key;
        final player = entry.value;
        final isActive = index == gameState.currentPlayerIndex;
        
        return Container(
          width: 90,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade50 : Colors.white.withValues(alpha: 0.9),
            border: Border.all(
              color: isActive ? Colors.blue : Colors.grey.shade300,
              width: isActive ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
              if (isActive)
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: player.tokenColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      player.name,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '\$${player.cash}',
                style: TextStyle(
                  color: player.cash < 100 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (player.isBankrupt)
                const Text(
                  '破产',
                  style: TextStyle(color: Colors.red, fontSize: 9),
                )
              else if (player.isInJail)
                const Text(
                  '在监狱',
                  style: TextStyle(color: Colors.orange, fontSize: 9),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(GameState gameState, bool isPlayerTurn) {
    final player = gameState.currentPlayer;
    final position = player.position;
    final property = gameState.properties.firstWhere((p) => p.cellIndex == position);
    final cell = boardCells[position];
    
    // 检查是否显示购买或建造按钮
    final canBuy = isPlayerTurn && 
        gameState.phase == GamePhase.playerAction && 
        cell.isPurchasable && 
        property.ownerId == null;
    
    final canBuild = isPlayerTurn && 
        gameState.phase == GamePhase.playerAction && 
        cell.type == CellType.property && 
        property.ownerId == player.id;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 购买按钮
          if (canBuy)
            ElevatedButton.icon(
              onPressed: () => showBuyPropertyDialog(context, position),
              icon: const Icon(Icons.shopping_cart, size: 14),
              label: Text('购买 \$${cell.price}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          
          // 建造按钮
          if (canBuild)
            ElevatedButton.icon(
              onPressed: () => showBuildHouseDialog(context, position),
              icon: const Icon(Icons.home, size: 14),
              label: const Text('建造'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          
          // 掷骰子按钮
          ElevatedButton.icon(
            onPressed: isPlayerTurn && gameState.phase == GamePhase.playerTurnStart
                ? () => ref.read(gameProvider.notifier).rollDice()
                : null,
            icon: const Icon(Icons.casino, size: 14),
            label: const Text('掷骰子'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          
          // 自动操作开关
          if (gameState.players.isNotEmpty && gameState.currentPlayer.isHuman)
            Row(
              children: [
                const Text('自动', style: TextStyle(fontSize: 12)),
                Switch(
                  value: gameState.currentPlayer.isAutoPlay,
                  onChanged: (value) {
                    final gameNotifier = ref.read(gameProvider.notifier);
                    final currentPlayer = gameNotifier.state.currentPlayer;
                    final updatedPlayer = currentPlayer.copyWith(isAutoPlay: value);
                    final updatedPlayers = gameNotifier.state.players.map((p) {
                      if (p.id == currentPlayer.id) {
                        return updatedPlayer;
                      }
                      return p;
                    }).toList();
                    gameNotifier.state = gameNotifier.state.copyWith(players: updatedPlayers);
                  },
                ),
              ],
            ),
          
          // 结束回合按钮
          ElevatedButton.icon(
            onPressed: isPlayerTurn && (gameState.phase == GamePhase.playerAction || 
                                          gameState.phase == GamePhase.playerTurnStart)
                ? () => ref.read(gameProvider.notifier).endTurn()
                : null,
            icon: const Icon(Icons.skip_next, size: 14),
            label: const Text('结束'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('游戏设置'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('新游戏'),
                  leading: const Icon(Icons.refresh),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(gameProvider.notifier).initGame(const GameSettings());
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '棋盘布局',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                ...BoardLayoutPresets.all.map((layout) {
                  return RadioListTile<BoardLayoutConfig>(
                    title: Text(layout.name),
                    subtitle: Text(
                      layout.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: layout,
                    groupValue: _currentLayout,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _currentLayout = value;
                        });
                        this.setState(() {
                          _currentLayout = value;
                          // 保存布局
                          _saveLayout(value);
                        });
                      }
                    },
                  );
                }),

                const Divider(),
                SwitchListTile(
                  title: const Text('自动保存'),
                  subtitle: const Text('在每回合结束时自动保存游戏进度'),
                  value: ref.read(gameProvider).settings.autoSaveEnabled,
                  onChanged: (value) {
                    final gameNotifier = ref.read(gameProvider.notifier);
                    final newSettings = gameNotifier.state.settings.copyWith(autoSaveEnabled: value);
                    gameNotifier.state = gameNotifier.state.copyWith(settings: newSettings);
                    setState(() {});
                  },
                ),

                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '游戏速度',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${ref.read(gameProvider).settings.speedMultiplier.toStringAsFixed(1)}x',
                            style: const TextStyle(fontSize: 14, color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: ref.read(gameProvider).settings.speedMultiplier,
                        min: 0.5,
                        max: 5.0,
                        divisions: 9,
                        label: '${ref.read(gameProvider).settings.speedMultiplier.toStringAsFixed(1)}x',
                        onChanged: (value) {
                          final gameNotifier = ref.read(gameProvider.notifier);
                          final newSettings = gameNotifier.state.settings.copyWith(speedMultiplier: value);
                          gameNotifier.state = gameNotifier.state.copyWith(settings: newSettings);
                          setState(() {});
                        },
                      ),
                      const Text(
                        '提示：速度越高，游戏动画和AI思考越快',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                const Divider(),
                ListTile(
                  title: const Text('清理本地数据'),
                  leading: const Icon(Icons.delete_sweep),
                  onTap: () async {
                    // 显示确认对话框
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认清理'),
                        content: const Text('确定要清理所有本地游戏数据吗？这将删除游戏存档、设置和布局配置。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () async {
                              // 清理所有本地数据
                              final storage = await StorageService.getInstance();
                              await storage.remove('game_setup');
                              await storage.remove('board_layout');
                              await SaveService.deleteSave();
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('monopoly_game_settings');
                              
                              // 重置游戏状态为初始状态
                              ref.read(gameProvider.notifier).resetGame();
                              
                              // 关闭设置对话框并跳转到游戏设置页面
                              if (mounted) {
                                // 先显示清理成功提示
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('本地数据已清理，正在跳转到游戏设置页面')),
                                );
                                // 关闭设置对话框
                                Navigator.pop(context);
                                // 立即跳转到游戏设置页面
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const GameSetupPage()),
                                );
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('清理'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('返回'),
                  leading: const Icon(Icons.arrow_back),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showGameRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('游戏玩法说明'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRuleSection('游戏目标', [
                '成为最后的幸存者，让其他玩家破产',
                '通过购买地产、建造房屋和收取租金来积累财富',
                '策略性地管理资金和地产，成为地产大亨'
              ]),
              _buildRuleSection('基本玩法', [
                '每位玩家初始拥有 1500 现金',
                '按回合顺序进行游戏，每回合先掷骰子',
                '根据骰子点数移动棋子到相应位置',
                '处理所在位置的事件（购买、支付租金等）',
                '可以选择购买地产、建造房屋或结束回合'
              ]),
              _buildRuleSection('地产系统', [
                '地产分为普通地产、高铁站和公用事业',
                '购买地产需要支付相应价格',
                '拥有完整色组后可以建造房屋',
                '每栋房屋增加租金收入',
                '5栋房屋可升级为酒店，获得更高租金'
              ]),
              _buildRuleSection('监狱系统', [
                '掷出3次对子会被送进监狱',
                '停在"前往派出所"格子会被送进监狱',
                '在监狱中可以：',
                '  - 掷骰子尝试离开（需要掷出对子）',
                '  - 支付50元保释金',
                '  - 使用出狱卡',
                '最多在监狱中停留3回合，之后必须离开'
              ]),
              _buildRuleSection('卡牌系统', [
                '机会卡：随机事件，可能带来好运或厄运',
                '公益卡：社区福利，可能获得资金或特殊效果',
                '卡牌效果包括：前进、后退、获得资金、支付费用、入狱等'
              ]),
              _buildRuleSection('特殊格子', [
                '起点（祖国华诞）：经过时获得200元',
                '人民广场：休息区，无特殊效果',
                '个人所得税：支付200元',
                '消费税：支付100元'
              ]),
              _buildRuleSection('破产规则', [
                '当玩家现金不足以支付债务时会破产',
                '破产玩家的所有地产将被收回',
                '最后一位非破产玩家获胜'
              ]),
              _buildRuleSection('AI玩家', [
                '电脑玩家会根据难度和性格自动进行游戏',
                '简单模式：AI决策较为保守',
                '困难模式：AI会更积极地购买和建造'
              ]),
              _buildRuleSection('操作提示', [
                '点击"掷骰子"开始你的回合',
                '停在无主地产时可以选择购买',
                '停在自己的地产时可以选择建造房屋',
                '点击"结束回合"结束当前回合',
                '使用右上角的保存按钮保存游戏进度'
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleSection(String title, List<String> rules) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rules.map((rule) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• $rule'),
            )).toList(),
          ),
        ],
      ),
    );
  }

  void _showOperationRecordsDialog(BuildContext context) {
    final logRecords = AppLogger.getLogRecords();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.maxFinite,
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '操作记录',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '共 ${logRecords.length} 条记录',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: logRecords.isEmpty
                    ? const Center(
                        child: Text('暂无操作记录'),
                      )
                    : ListView.builder(
                        reverse: true, // 最新的记录在最下面
                        itemCount: logRecords.length,
                        itemBuilder: (context, index) {
                          final record = logRecords[logRecords.length - 1 - index];
                          return _buildLogItem(record);
                        },
                      ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      AppLogger.clearLogRecords();
                      Navigator.pop(context);
                      // 重新打开对话框以显示清空后的状态
                      _showOperationRecordsDialog(context);
                    },
                    child: const Text('清空记录'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem(LogRecord record) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: record.level == LogLevel.error
              ? Colors.red.shade50
              : record.level == LogLevel.warning
                  ? Colors.yellow.shade50
                  : Colors.grey.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  record.levelEmoji,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  record.formattedTime,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${record.levelName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: record.level == LogLevel.error
                        ? Colors.red
                        : record.level == LogLevel.warning
                            ? Colors.orange
                            : record.level == LogLevel.info
                                ? Colors.blue
                                : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${record.tag}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              record.message,
              style: const TextStyle(fontSize: 14),
            ),
            if (record.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Error: ${record.error}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


}
