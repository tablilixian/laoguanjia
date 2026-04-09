// 地产大亨 - 游戏主页面
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../constants/board_config.dart';
import '../providers/game_provider.dart';
import '../widgets/board/game_board.dart';
import '../widgets/dice/dice_widget.dart';
import '../widgets/dialogs/buy_dialog.dart';
import '../widgets/dialogs/build_dialog.dart';

class MonopolyGamePage extends ConsumerStatefulWidget {
  const MonopolyGamePage({super.key});

  @override
  ConsumerState<MonopolyGamePage> createState() => _MonopolyGamePageState();
}

class _MonopolyGamePageState extends ConsumerState<MonopolyGamePage> {
  @override
  void initState() {
    super.initState();
    // 初始化游戏
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameProvider.notifier).initGame(const GameSettings());
    });
  }

  // 监听游戏状态变化，自动触发AI行动
  void _watchGameState(GameState state) {
    final isPlayerTurn = state.currentPlayer.name != '你';
    final isPhaseReady = state.phase == GamePhase.playerTurnStart || 
                         state.phase == GamePhase.playerAction;
    
    if (isPlayerTurn && isPhaseReady && !state.isGameOver) {
      // AI回合，延迟执行
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.read(gameProvider.notifier).performAIAction();
        }
      });
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
      _watchGameState(next);
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
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 游戏信息栏
          _buildInfoBar(gameState),
          // 棋盘
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: const GameBoard(),
            ),
          ),
          // 骰子显示区域
          if (gameState.phase == GamePhase.diceRolling || 
              gameState.lastDice1 != null)
            _buildDiceArea(gameState),
          // 玩家信息
          _buildPlayerInfo(gameState),
          // 游戏结束显示胜利界面
          if (gameState.phase == GamePhase.gameOver)
            _buildGameOverOverlay(gameState),
          // 操作按钮
          _buildActionButtons(gameState, isPlayerTurn),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay(GameState gameState) {
    final winner = gameState.players.firstWhere((p) => p.id == gameState.winnerId);
    final isPlayerWin = winner.name == '你';
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black54,
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '胜利者: ${winner.name}',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(gameProvider.notifier).initGame(const GameSettings());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('再来一局'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceArea(GameState gameState) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          if (gameState.phase == GamePhase.diceRolling)
            const DiceWidget(
              dice1: 1,
              dice2: 1,
              isRolling: true,
              size: 50,
            )
          else if (gameState.lastDice1 != null && gameState.lastDice2 != null)
            DiceResultWidget(
              dice1: gameState.lastDice1!,
              dice2: gameState.lastDice2!,
              isDoubles: gameState.isDoubles,
              size: 50,
            ),
          const SizedBox(height: 4),
          Text(
            '点数: ${(gameState.lastDice1 ?? 0) + (gameState.lastDice2 ?? 0)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
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
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: gameState.players.length,
        itemBuilder: (context, index) {
          final player = gameState.players[index];
          final isActive = index == gameState.currentPlayerIndex;
          
          return Container(
            width: 100,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? Colors.blue.shade50 : Colors.grey.shade100,
              border: Border.all(
                color: isActive ? Colors.blue : Colors.grey.shade300,
                width: isActive ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: player.tokenColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        player.name,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${player.cash}',
                  style: TextStyle(
                    color: player.cash < 100 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (player.isBankrupt)
                  const Text(
                    '破产',
                    style: TextStyle(color: Colors.red, fontSize: 10),
                  )
                else if (player.isInJail)
                  const Text(
                    '在监狱',
                    style: TextStyle(color: Colors.orange, fontSize: 10),
                  ),
              ],
            ),
          );
        },
      ),
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
              icon: const Icon(Icons.shopping_cart),
              label: Text('购买 \$${cell.price}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          
          // 建造按钮
          if (canBuild)
            ElevatedButton.icon(
              onPressed: () => showBuildHouseDialog(context, position),
              icon: const Icon(Icons.home),
              label: const Text('建造/管理'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          
          // 掷骰子按钮
          ElevatedButton.icon(
            onPressed: isPlayerTurn && gameState.phase == GamePhase.playerTurnStart
                ? () => ref.read(gameProvider.notifier).rollDice()
                : null,
            icon: const Icon(Icons.casino),
            label: const Text('掷骰子'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          
          // 结束回合按钮
          ElevatedButton.icon(
            onPressed: isPlayerTurn && (gameState.phase == GamePhase.playerAction || 
                                          gameState.phase == GamePhase.playerTurnStart)
                ? () => ref.read(gameProvider.notifier).endTurn()
                : null,
            icon: const Icon(Icons.skip_next),
            label: const Text('结束回合'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            ListTile(
              title: const Text('返回'),
              leading: const Icon(Icons.arrow_back),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
