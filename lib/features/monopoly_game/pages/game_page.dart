// 地产大亨 - 游戏主页面
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/storage_service.dart';
import '../models/models.dart';
import '../constants/board_config.dart';
import '../constants/board_layout_config.dart';
import '../constants/game_constants.dart';
import '../providers/game_provider.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../widgets/board/game_board.dart';
import '../widgets/dice/dice_widget.dart';
import '../widgets/dialogs/buy_dialog.dart';
import '../widgets/dialogs/build_dialog.dart';
import '../widgets/panels/player_detail_panel.dart';
import '../widgets/feedback/toast_manager.dart';
import '../widgets/feedback/game_toast.dart';
import '../widgets/feedback/operation_log_board.dart';
import 'load_game_page.dart';
import 'game_setup_page.dart';

/// Toast管理器Provider
final toastManagerProvider = Provider<ToastManager>((ref) {
  return ToastManager.instance;
});

class MonopolyGamePage extends ConsumerStatefulWidget {
  const MonopolyGamePage({super.key});

  @override
  ConsumerState<MonopolyGamePage> createState() => _MonopolyGamePageState();
}

class _MonopolyGamePageState extends ConsumerState<MonopolyGamePage> {
  BoardLayoutConfig _currentLayout = BoardLayoutPresets.standard;
  bool _showDetailPanel = false; // 控制详情面板显示
  String? _selectedPlayerId; // 当前查看的玩家ID
  GameState? _lastGameState; // 用于检测状态变化

  @override
  void initState() {
    super.initState();
    _lastGameState = null;
    SoundService.init();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadSavedLayout();
      final gameNotifier = ref.read(gameProvider.notifier);
      await gameNotifier.loadSavedGame();
      final gameState = ref.read(gameProvider);
      if (gameState.players.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoadGamePage()),
        );
      } else {
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
    final isAITurn =
        !next.currentPlayer.isHuman || next.currentPlayer.isAutoPlay;
    final isPhaseReady =
        next.phase == GamePhase.playerTurnStart ||
        next.phase == GamePhase.playerAction ||
        next.phase == GamePhase.jailDecision;

    // 只在以下情况触发AI行动：
    // 1. 当前玩家是AI或真人开启了自动操作
    // 2. 游戏阶段是 playerTurnStart 或 playerAction 或 jailDecision
    // 3. 游戏未结束
    // 4. 状态确实发生了变化（避免重复触发）
    if (isAITurn && isPhaseReady && !next.isGameOver) {
      // 检查是否是状态变化触发的（避免重复触发）
      final isStateChanged =
          previous.phase != next.phase ||
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

    // 监听 jailDecision 阶段变化，显示监狱选项对话框（仅真人玩家）
    if (next.phase == GamePhase.jailDecision && previous.phase != GamePhase.jailDecision) {
      if (next.currentPlayer.isHuman && !next.currentPlayer.isAutoPlay) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showJailDecisionDialog(context, ref);
          }
        });
      }
    }

    // 监听 playerTurnStart 阶段变化，如果玩家在监狱且是真人，自动切换到监狱决策阶段
    if (next.phase == GamePhase.playerTurnStart && 
        previous.phase != GamePhase.playerTurnStart &&
        next.currentPlayer.isInJail &&
        next.currentPlayer.isHuman && 
        !next.currentPlayer.isAutoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(gameProvider.notifier).transitionToJailDecision();
        }
      });
    }
  }

  /// 处理游戏反馈（根据状态变化显示Toast）
  void _processGameFeedback(GameState previous, GameState current) {
    debugPrint('[DEBUG _processGameFeedback] 开始处理反馈');
    debugPrint('[DEBUG _processGameFeedback] turn: ${previous.turnNumber} -> ${current.turnNumber}');
    debugPrint('[DEBUG _processGameFeedback] phase: ${previous.phase} -> ${current.phase}');
    debugPrint('[DEBUG _processGameFeedback] position: ${previous.currentPlayer.position} -> ${current.currentPlayer.position}');
    debugPrint('[DEBUG _processGameFeedback] currentPlayerIndex: ${previous.currentPlayerIndex} -> ${current.currentPlayerIndex}');
    debugPrint('[DEBUG _processGameFeedback] 当前玩家: ${current.currentPlayer.name}, isHuman: ${current.currentPlayer.isHuman}, id: ${current.currentPlayer.id}');

    final toast = ToastManager.instance;
    final logManager = OperationLogManager.instance;
    final currentPlayer = current.currentPlayer;
    final currentPos = currentPlayer.position;

    // 使用id找到之前状态的同一个玩家，而不是依赖currentPlayerIndex
    final prevPlayer = previous.players.firstWhere(
      (p) => p.id == currentPlayer.id,
      orElse: () => previous.currentPlayer,
    );

    debugPrint('[DEBUG _processGameFeedback] 位置: $currentPos');
    debugPrint('[DEBUG _processGameFeedback] prevPlayer.cash: ${prevPlayer.cash}, currentPlayer.cash: ${currentPlayer.cash}');

    // 打印 previous 和 current 中该位置的 property ownerId
    final prevPropertyAtPos = previous.properties.firstWhere((p) => p.cellIndex == currentPos, orElse: () => previous.properties.first);
    final currentPropertyAtPos = current.properties.firstWhere((p) => p.cellIndex == currentPos, orElse: () => current.properties.first);
    debugPrint('[DEBUG _processGameFeedback] previous.properties[$currentPos].ownerId: ${prevPropertyAtPos.ownerId}');
    debugPrint('[DEBUG _processGameFeedback] current.properties[$currentPos].ownerId: ${currentPropertyAtPos.ownerId}');

    // 跳过AI玩家或非当前玩家回合的反馈
    if (!current.currentPlayer.isHuman) {
      debugPrint('[DEBUG] 跳过：非人类玩家');
      return;
    }
    debugPrint('[DEBUG] 继续：是人类玩家');

    //检测移动，如果当前phase是playerMoving
    if (current.phase == GamePhase.playerMoving) {
      if (currentPos != previous.currentPlayer.position) {
        debugPrint('[DEBUG] 检测到移动');
        // 检查是否经过起点
      if (_checkPassedStart(previous, current)) {
        debugPrint('[DEBUG] 经过起点');
        toast.showPassStart(reward: GameConstants.passGoReward);
        logManager.logPassStart(
          playerName: currentPlayer.name,
          playerColor: currentPlayer.tokenColor,
          turnNumber: current.turnNumber,
        );
      }

        logManager.logMove(
          playerName: currentPlayer.name,
          playerColor: currentPlayer.tokenColor,
          fromPosition: previous.currentPlayer.position,
          toPosition: currentPos,
          steps: currentPos - previous.currentPlayer.position,
          turnNumber: current.turnNumber,
        );
      } else {
        debugPrint('[DEBUG] 未检测到移动');
      }

      

      return;
    }

    if (current.phase == GamePhase.diceRolling) {
      debugPrint('[DEBUG] 检测到玩家回合开始');
      return;
    }


    // 检测骰子结果
    if (current.lastDice1 != null &&
        current.lastDice2 != null &&
        (previous.lastDice1 != current.lastDice1 ||
            previous.lastDice2 != current.lastDice2)) {
      debugPrint('[DEBUG] 检测到骰子变化');
      final prevPos = previous.players
          .firstWhere(
            (p) => p.id == current.currentPlayer.id,
            orElse: () => current.currentPlayer,
          )
          .position;
      logManager.logRollDice(
        playerName: currentPlayer.name,
        playerColor: currentPlayer.tokenColor,
        dice1: current.lastDice1!,
        dice2: current.lastDice2!,
        turnNumber: current.turnNumber,
      );

      
    }

    // 检测资金变化
    // 检查当前玩家的资金是否发生变化（通过id匹配，不依赖currentPlayerIndex）
    if (prevPlayer.cash != currentPlayer.cash) {
      debugPrint('[DEBUG] 资金发生变化: ${prevPlayer.cash} -> ${currentPlayer.cash}');
      final diff = currentPlayer.cash - prevPlayer.cash;
      debugPrint('[DEBUG] diff: $diff');
      if (diff != 0) {
        // 检查是否是租金
        if (_isRentPayment(previous, current)) {
          debugPrint('[DEBUG] 判断为：租金支付');
          final rentAmount = diff.abs();
          final pos = current.currentPlayer.position;
          final property = previous.properties.firstWhere((p) => p.cellIndex == pos);
          final owner = previous.players.firstWhere((p) => p.id == property.ownerId);
          toast.showMoneyExpense(reason: '支付租金', amount: rentAmount);
          logManager.logPayRent(
            playerName: currentPlayer.name,
            playerColor: currentPlayer.tokenColor,
            propertyName: _getPropertyName(pos),
            ownerName: owner.name,
            amount: rentAmount,
            turnNumber: current.turnNumber,
          );
        }
        // 检查是否是购买
        else if (_isPropertyPurchase(previous, current)) {
          debugPrint('[DEBUG] 判断为：购买地产');
          final price = diff.abs();
          toast.showBuySuccess(
            propertyName: _getPropertyName(current.currentPlayer.position),
            price: price,
          );
          logManager.logBuyProperty(
            playerName: currentPlayer.name,
            playerColor: currentPlayer.tokenColor,
            propertyName: _getPropertyName(current.currentPlayer.position),
            price: price,
            turnNumber: current.turnNumber,
          );
        }
        // 检查是否是卡牌
        else if (_isCardEffect(previous, current)) {
          debugPrint('[DEBUG] 判断为：卡牌效果');
          toast.showCard(
            cardTitle: _getCardTitle(previous, current),
            description: _getCardDescription(previous, current),
            amount: diff > 0 ? diff : null,
          );
          logManager.logDrawCard(
            playerName: currentPlayer.name,
            playerColor: currentPlayer.tokenColor,
            cardTitle: _getCardTitle(previous, current),
            cardDescription: _getCardDescription(previous, current),
            amount: diff > 0 ? diff : (diff < 0 ? diff : null),
            turnNumber: current.turnNumber,
          );
        }
        // 检查是否是税务（只有资金减少才是税务支出，资金增加时跳过）
        else if (_isTaxPayment(previous, current) && diff < 0) {
          debugPrint('[DEBUG] 判断为：税务');
          final taxAmount = diff.abs();
          toast.showMoneyExpense(
            reason: _getTaxReason(previous, current),
            amount: taxAmount,
          );
          logManager.logTax(
            playerName: currentPlayer.name,
            playerColor: currentPlayer.tokenColor,
            taxType: _getTaxReason(previous, current),
            amount: taxAmount,
            turnNumber: current.turnNumber,
          );
        } else if (diff > 0) {
          debugPrint('[DEBUG] 资金增加但未匹配任何类型（可能是经过起点奖励）');
        } else {
          debugPrint('[DEBUG] 资金变化但未匹配任何类型！');
        }
      }
    } else {
      debugPrint('[DEBUG] 资金未变化');
    }

    // 检测对子
    if (current.isDoubles) {
      debugPrint('[DEBUG] 检测到对子');
      toast.showDoubles(consecutiveCount: current.consecutiveDoubles);
      logManager.logDoubles(
        playerName: currentPlayer.name,
        playerColor: currentPlayer.tokenColor,
        consecutiveCount: current.consecutiveDoubles,
        turnNumber: current.turnNumber,
      );
    }

    // 检测入狱
    if (current.currentPlayer.isInJail && !prevPlayer.isInJail) {
      toast.showGoToJail();
      logManager.logJail(
        playerName: currentPlayer.name,
        playerColor: currentPlayer.tokenColor,
        turnNumber: current.turnNumber,
      );
    }
  }

  /// 基于 GamePhase 的游戏反馈处理（switch 版本）
  void _processGameFeedbackByPhase(GameState previous, GameState current) {
    final toast = ToastManager.instance;
    final logManager = OperationLogManager.instance;
    final currentPhase = current.phase;
    final currentPlayer = current.currentPlayer;
    final prevPlayer = previous.players.firstWhere(
      (p) => p.id == currentPlayer.id,
      orElse: () => currentPlayer,
    );

    //机器人不显示Toast
    if (!currentPlayer.isHuman) {
      return;
    }

    switch (currentPhase) {
      case GamePhase.init:
        debugPrint('[DEBUG _processGameFeedbackByPhase] init 阶段');
        final playerNames = current.players.map((p) => p.name).toList();
        toast.showSuccess(title: '游戏开始', subtitle: '共 ${playerNames.length} 位玩家');
        logManager.logGameStart(
          playerNames: playerNames,
          turnNumber: current.turnNumber,
        );
        break;

      case GamePhase.playerTurnStart:
        debugPrint('[DEBUG _processGameFeedbackByPhase] playerTurnStart 阶段');
        if (currentPlayer.isHuman) {
          // toast.showInfo(title: '回合开始', subtitle: '${currentPlayer.name} 的回合');
          logManager.logTurnStart(
            playerName: currentPlayer.name,
            playerColor: currentPlayer.tokenColor,
            turnNumber: current.turnNumber,
          );
        }
        break;

      case GamePhase.jailDecision:
        // debugPrint('[DEBUG _processGameFeedbackByPhase] jailDecision 阶段');
        if (currentPlayer.isHuman) {
          // toast.showWarning(title: '监狱决策', subtitle: '选择离开方式');
        }
        break;

      case GamePhase.diceRolling:
        debugPrint('[DEBUG _processGameFeedbackByPhase] diceRolling 阶段');
        if (current.lastDice1 != null &&
            current.lastDice2 != null &&
            (previous.lastDice1 != current.lastDice1 ||
                previous.lastDice2 != current.lastDice2)) {
          debugPrint('[DEBUG] 掷骰子结果: ${current.lastDice1} + ${current.lastDice2}');
          // toast.showSpecial(
          //   title: '🎲 掷骰子',
          //   subtitle: '${current.lastDice1} + ${current.lastDice2}',
          // );
          logManager.logRollDice(
            playerName: currentPlayer.name,
            playerColor: currentPlayer.tokenColor,
            dice1: current.lastDice1!,
            dice2: current.lastDice2!,
            turnNumber: current.turnNumber,
          );
          
          // 检测对子
          if (current.isDoubles) {
            debugPrint('[DEBUG] 检测到对子');
            toast.showDoubles(consecutiveCount: current.consecutiveDoubles);
            logManager.logDoubles(
              playerName: currentPlayer.name,
              playerColor: currentPlayer.tokenColor,
              consecutiveCount: current.consecutiveDoubles,
              turnNumber: current.turnNumber,
            );
          }
        }
        break;

      case GamePhase.playerMoving:
        debugPrint('[DEBUG _processGameFeedbackByPhase] playerMoving 阶段');
        final currentPos = currentPlayer.position;
        final prevPos = previous.currentPlayer.position;
        if (currentPos != prevPos) {
          debugPrint('[DEBUG] 检测到移动: $prevPos -> $currentPos');
          // toast.showInfo(
          //   title: '移动',
          //   subtitle: '从 ${_getPropertyName(prevPos)} 到 ${_getPropertyName(currentPos)}',
          // );
          logManager.logMove(
            playerName: currentPlayer.name,
            playerColor: currentPlayer.tokenColor,
            fromPosition: prevPos,
            toPosition: currentPos,
            steps: currentPos - prevPos,
            turnNumber: current.turnNumber,
          );
          if (_checkPassedStart(previous, current)) {
            debugPrint('[DEBUG] 经过起点');
            toast.showPassStart(reward: GameConstants.passGoReward);
            logManager.logPassStart(
              playerName: currentPlayer.name,
              playerColor: currentPlayer.tokenColor,
              turnNumber: current.turnNumber,
            );
          }
        }
        break;

      case GamePhase.eventProcessing:
        debugPrint('[DEBUG _processGameFeedbackByPhase] eventProcessing 阶段');
        final pos = currentPlayer.position;
        final prevProperty = previous.properties.firstWhere((p) => p.cellIndex == pos);
        final currentProperty = current.properties.firstWhere((p) => p.cellIndex == pos);
        
        // 检查是否是租金支付
        if (prevProperty.ownerId != null && 
            prevProperty.ownerId != currentPlayer.id &&
            currentProperty.ownerId == prevProperty.ownerId) {
          final diff = currentPlayer.cash - prevPlayer.cash;
          if (diff < 0) {
            toast.showMoneyExpense(
              reason: '支付租金',
              amount: diff.abs(),
            );
          }
        }
        // 检查是否是购买
        else if (prevProperty.ownerId == null && 
                 currentProperty.ownerId == currentPlayer.id) {
          final diff = currentPlayer.cash - prevPlayer.cash;
          if (diff < 0) {
            toast.showBuySuccess(
              propertyName: _getPropertyName(pos),
              price: diff.abs(),
            );
          }
        }
        // 检查是否是卡牌
        else if (chanceIndices.contains(pos) || communityChestIndices.contains(pos)) {
          final diff = currentPlayer.cash - prevPlayer.cash;
          if (diff != 0) {
            toast.showCard(
              cardTitle: chanceIndices.contains(pos) ? '🎴 机会卡' : '🎴 公益卡',
              description: diff > 0 ? '获得 $diff 元' : '支付 ${diff.abs()} 元',
              amount: diff > 0 ? diff : null,
            );
          }
        }
        // 检查是否是税务
        else if (pos == incomeTaxIndex || pos == luxuryTaxIndex) {
          final diff = currentPlayer.cash - prevPlayer.cash;
          if (diff < 0) {
            toast.showMoneyExpense(
              reason: pos == incomeTaxIndex ? '个人所得税' : '消费税',
              amount: diff.abs(),
            );
          }
        }
        break;

      case GamePhase.playerAction:
        debugPrint('[DEBUG _processGameFeedbackByPhase] playerAction 阶段');
        final pos = currentPlayer.position;
        if (pos >= 0 && pos < 40) {
          final prevProperty = previous.properties.firstWhere((p) => p.cellIndex == pos);
          final currentProperty = current.properties.firstWhere((p) => p.cellIndex == pos);
          if (prevProperty.ownerId == null && currentProperty.ownerId == currentPlayer.id) {
            final cell = boardCells[pos];
            if (cell.price != null) {
              debugPrint('[DEBUG] 购买地产: ${cell.name}, 价格: ${cell.price}');
              toast.showBuySuccess(
                propertyName: cell.name,
                price: cell.price!,
              );
              logManager.logBuyProperty(
                playerName: currentPlayer.name,
                playerColor: currentPlayer.tokenColor,
                propertyName: cell.name,
                price: cell.price!,
                turnNumber: current.turnNumber,
              );
            }
          }
        }
        break;

      case GamePhase.turnEnd:
        debugPrint('[DEBUG _processGameFeedbackByPhase] turnEnd 阶段');
        break;

      case GamePhase.gameOver:
        debugPrint('[DEBUG _processGameFeedbackByPhase] gameOver 阶段');
        break;
    }

    // 检测入狱
    if (current.currentPlayer.isInJail && !prevPlayer.isInJail) {
      debugPrint('[DEBUG] 检测到入狱');
      toast.showGoToJail();
      logManager.logJail(
        playerName: currentPlayer.name,
        playerColor: currentPlayer.tokenColor,
        turnNumber: current.turnNumber,
      );
    }
  }

  /// 获取玩家位置变化
  int _getPositionChange(GameState previous, GameState next) {
    final prevPlayer = previous.players.firstWhere(
      (p) => p.id == next.currentPlayer.id,
      orElse: () => next.currentPlayer,
    );
    return next.currentPlayer.position - prevPlayer.position;
  }

  /// 检查是否经过起点
  bool _checkPassedStart(GameState previous, GameState next) {
    final prevPos = previous.players
        .firstWhere(
          (p) => p.id == next.currentPlayer.id,
          orElse: () => next.currentPlayer,
        )
        .position;
    final newPos = next.currentPlayer.position;
    return newPos < prevPos; // 位置变小区40说明经过了起点
  }

  /// 是否是租金支付
  /// 判断条件：
  /// 1. 格子是可购买的地产
  /// 2. 之前有所有者且不是当前玩家
  /// 3. 当前资金减少（支付了租金）
  bool _isRentPayment(GameState previous, GameState current) {
    final pos = current.currentPlayer.position;
    if (pos < 0 || pos >= 40) return false;
    final cell = boardCells[pos];
    if (!cell.isPurchasable) return false;

    // 检查之前的状态：必须有所有者且不是当前玩家
    final prevProperty = previous.properties.firstWhere((p) => p.cellIndex == pos);
    if (prevProperty.ownerId == null || prevProperty.ownerId == current.currentPlayer.id) {
      return false;
    }

    return true;
  }

  /// 是否是购买地产
  /// 判断条件：
  /// 1. 格子是可购买的地产
  /// 2. 之前没有所有者
  /// 3. 现在有所有者且是当前玩家
  /// 4. 当前资金减少（支付了购买费用）
  bool _isPropertyPurchase(GameState previous, GameState current) {
    final pos = current.currentPlayer.position;
    debugPrint('[DEBUG _isPropertyPurchase] pos: $pos');
    if (pos < 0 || pos >= 40) {
      debugPrint('[DEBUG _isPropertyPurchase] 位置超出范围');
      return false;
    }
    final cell = boardCells[pos];
    debugPrint('[DEBUG _isPropertyPurchase] cell: ${cell.name}, isPurchasable: ${cell.isPurchasable}');
    if (!cell.isPurchasable) {
      debugPrint('[DEBUG _isPropertyPurchase] 格子不可购买');
      return false;
    }

    // 检查之前的状态：必须没有所有者
    final prevProperty = previous.properties.firstWhere((p) => p.cellIndex == pos);
    debugPrint('[DEBUG _isPropertyPurchase] prevProperty.ownerId: ${prevProperty.ownerId}');
    if (prevProperty.ownerId != null) {
      debugPrint('[DEBUG _isPropertyPurchase] 之前已有所有者');
      return false;
    }

    // 检查现在的状态：必须有所有者且是当前玩家
    final currentProperty = current.properties.firstWhere((p) => p.cellIndex == pos);
    debugPrint('[DEBUG _isPropertyPurchase] currentProperty.ownerId: ${currentProperty.ownerId}, currentPlayer.id: ${current.currentPlayer.id}');
    if (currentProperty.ownerId != current.currentPlayer.id) {
      debugPrint('[DEBUG _isPropertyPurchase] 所有者不是当前玩家');
      return false;
    }

    debugPrint('[DEBUG _isPropertyPurchase] 返回 true');
    return true;
  }

  /// 是否是卡牌效果
  bool _isCardEffect(GameState previous, GameState current) {
    final pos = current.currentPlayer.position;
    return chanceIndices.contains(pos) || communityChestIndices.contains(pos);
  }

  /// 获取卡牌标题
  String _getCardTitle(GameState previous, GameState current) {
    final pos = current.currentPlayer.position;
    final isChance = chanceIndices.contains(pos);
    return isChance ? '🎴 机会卡' : '🎴 公益卡';
  }

  /// 获取卡牌描述
  String _getCardDescription(GameState previous, GameState current) {
    final cards = chanceIndices.contains(current.currentPlayer.position)
        ? current.chanceCards
        : current.communityChestCards;
    if (cards.isEmpty) return '';
    final index = chanceIndices.contains(current.currentPlayer.position)
        ? current.chanceCardIndex
        : current.communityChestCardIndex;
    final safeIndex = index > 0 ? index - 1 : 0;
    if (safeIndex < cards.length) {
      return cards[safeIndex].description;
    }
    return '';
  }

  /// 是否是税务
  bool _isTaxPayment(GameState previous, GameState current) {
    final pos = current.currentPlayer.position;
    return pos == incomeTaxIndex || pos == luxuryTaxIndex;
  }

  /// 获取税务原因
  String _getTaxReason(GameState previous, GameState current) {
    final pos = current.currentPlayer.position;
    return pos == incomeTaxIndex ? '个人所得税' : '消费税';
  }

  /// 获取地产名称
  String _getPropertyName(int position) {
    if (position < 0 || position >= 40) return '';
    return boardCells[position].name;
  }

  /// 构建Toast显示区域
  Widget _buildToastArea() {
    final toast = ref.read(toastManagerProvider);
    return ListenableBuilder(
      listenable: toast,
      builder: (context, child) {
        final toasts = toast.toasts;
        if (toasts.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: toasts.map((t) {
            return GameToastWidget(
              key: ValueKey(t.id),
              toast: t,
              onDismiss: () => toast.dismiss(t.id),
            );
          }).toList(),
        );
      },
    );
  }

  /// 构建操作记录看板
  Widget _buildOperationLogBoard() {
    final logManager = ref.read(operationLogManagerProvider);
    return OperationLogBoard(manager: logManager);
  }

  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final isPlayerTurn = ref.watch(isPlayerTurnProvider);

    // 游戏未初始化时显示加载界面
    if (gameState.players.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('地产大亨'), centerTitle: true),
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

    // 监听状态变化触发 AI 和显示反馈
    ref.listen(gameProvider, (previous, next) {
      if (previous != null) {
        _watchGameState(previous, next);
        // _processGameFeedback(previous, next);
        _processGameFeedbackByPhase(previous, next);
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('游戏已保存')));
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
      body: Stack(
        children: [
          // 游戏主界面
          Column(
            children: [
              // 游戏信息栏
              _buildInfoBar(gameState),
              // 棋盘区域（使用Stack将骰子和玩家信息叠加在棋盘中间）
              Expanded(
                child: Container(
                  child: Stack(
                    children: [
                      GameBoard(layoutConfig: _currentLayout),
                      // 操作记录看板（在棋盘内部）
                      Positioned.fill(
                        child: Align(
                          alignment: FractionalOffset(0.5, 0.15),
                          child: FractionallySizedBox(
                            widthFactor: 0.7,
                            child: SizedBox(
                              height: 150,
                              child: _buildOperationLogBoard(),
                            ),
                          ),
                        ),
                      ),
                      // 中间层：骰子区域（居中显示）
                      if (gameState.phase == GamePhase.diceRolling ||
                          gameState.lastDice1 != null)
                        Align(
                          alignment: const Alignment(0, 0.1),
                          child: _buildDiceArea(gameState),
                        ),
                      // 顶层：玩家信息（棋盘上方位置，居中显示）
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: const Alignment(0, 0.7),
                          child: _buildPlayerInfo(gameState),
                        ),
                      ),
                      // Toast显示层（顶部）
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 56,
                        left: 0,
                        right: 0,
                        child: _buildToastArea(),
                      ),
                      // 游戏结束显示胜利界面
                      if (gameState.phase == GamePhase.gameOver)
                        Center(child: _buildGameOverOverlay(gameState)),
                    ],
                  ),
                ),
              ),
              // 操作按钮
              _buildActionButtons(gameState, isPlayerTurn),
            ],
          ),
          // 玩家详情面板（带滑进滑出动效）
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _showDetailPanel ? 0 : -280,
            top: 0,
            bottom: 0,
            child: PlayerDetailPanel(
              playerId: _selectedPlayerId,
              onClose: () {
                setState(() {
                  _showDetailPanel = false;
                });
              },
            ),
          ),
          // 点击空白区域收起面板
          if (_showDetailPanel)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width - 280,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showDetailPanel = false;
                  });
                },
                child: Container(color: Colors.transparent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay(GameState gameState) {
    final winner = gameState.players.firstWhere(
      (p) => p.id == gameState.winnerId,
    );
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '胜利者: ${winner.name}',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final setup = ref.read(gameProvider.notifier).getGameSetup();
              if (setup != null) {
                ref.read(gameProvider.notifier).initGameWithSetup(setup);
              }
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
            const DiceWidget(dice1: 1, dice2: 1, isRolling: true, size: 60)
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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

  Widget _buildDoublesIndicator(GameState gameState) {
    if (!gameState.isDoubles) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.casino, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            '对子！再掷一次！',
            style: TextStyle(
              color: Colors.orange.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${gameState.consecutiveDoubles}/3',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
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
      case GamePhase.jailDecision:
        return '监狱选择';
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

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPlayerId = player.id;
              _showDetailPanel = true;
            });
          },
          child: Container(
            width: 90,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                top: BorderSide(
                  color: player.tokenColor,
                  width: isActive ? 3 : 2,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                if (isActive)
                  BoxShadow(
                    color: player.tokenColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: player.tokenColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          player.name[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        player.name,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 11,
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: player.cash < GameConstants.lowCashWarningThreshold ? Colors.red : Colors.green,
                  ),
                ),
                if (player.isBankrupt)
                  Text('破产', style: TextStyle(color: Colors.red, fontSize: 9))
                else if (player.isInJail)
                  Text(
                    '在监狱',
                    style: TextStyle(color: Colors.orange, fontSize: 9),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(GameState gameState, bool isPlayerTurn) {
    final player = gameState.currentPlayer;
    final position = player.position;
    final property = gameState.properties.firstWhere(
      (p) => p.cellIndex == position,
    );
    final cell = boardCells[position];

    // 检查是否显示购买或建造按钮
    final canBuy =
        isPlayerTurn &&
        gameState.phase == GamePhase.playerAction &&
        cell.isPurchasable &&
        property.ownerId == null;

    final canBuild =
        isPlayerTurn &&
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),

          // 掷骰子按钮
          ElevatedButton.icon(
            onPressed:
                isPlayerTurn && gameState.phase == GamePhase.playerTurnStart
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

          // 结束回合按钮
          ElevatedButton.icon(
            onPressed:
                isPlayerTurn &&
                    (gameState.phase == GamePhase.playerAction ||
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

  void _showJailDecisionDialog(BuildContext context, WidgetRef ref) {
    final gameState = ref.read(gameProvider);
    final player = gameState.currentPlayer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.gavel, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text('${player.name} 在监狱中')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您现在在监狱中，还剩 ${player.jailTurns} 回合'),
            const SizedBox(height: 16),
            const Text('请选择离开监狱的方式:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildJailOption(
              icon: Icons.casino,
              title: '掷骰子',
              subtitle: '掷出对子即可离开监狱',
              enabled: true,
              onTap: () {
                Navigator.pop(dialogContext);
                ref.read(gameProvider.notifier).handleJailDecision(0);
              },
            ),
            const SizedBox(height: 8),
            _buildJailOption(
              icon: Icons.credit_card,
              title: '使用越狱卡',
              subtitle: player.hasGetOutOfJailFree ? '使用一张越狱卡立即离开' : '没有越狱卡',
              enabled: player.hasGetOutOfJailFree,
              onTap: player.hasGetOutOfJailFree
                  ? () {
                      Navigator.pop(dialogContext);
                      ref.read(gameProvider.notifier).handleJailDecision(1);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            _buildJailOption(
              icon: Icons.money,
              title: '支付保释金',
              subtitle: player.cash >= GameConstants.bailAmount ? '支付 \$${GameConstants.bailAmount} 立即离开' : '现金不足 (\$${player.cash})',
              enabled: player.cash >= GameConstants.bailAmount,
              onTap: player.cash >= GameConstants.bailAmount
                  ? () {
                      Navigator.pop(dialogContext);
                      ref.read(gameProvider.notifier).handleJailDecision(2);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJailOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? Colors.grey.shade300 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
          color: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? Colors.blue : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: enabled ? Colors.black : Colors.grey,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              const Icon(Icons.chevron_right, color: Colors.grey)
            else
              const Icon(Icons.block, color: Colors.grey),
          ],
        ),
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
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('新游戏'),
                      leading: const Icon(Icons.refresh),
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          final storage = await StorageService.getInstance();
                          final savedSetup = await storage.getString('game_setup');
                          if (savedSetup != null) {
                            final setup = GameSetup.fromJson(jsonDecode(savedSetup));
                            ref.read(gameProvider.notifier).initGameWithSetup(setup);
                          } else {
                            final defaultSetup = GameSetup(
                              playerCount: 2,
                              playerConfigs: [
                                PlayerConfig(name: '你', isHuman: true),
                                PlayerConfig(name: '电脑1', isHuman: false),
                              ],
                            );
                            ref.read(gameProvider.notifier).initGameWithSetup(defaultSetup);
                          }
                        } catch (e) {
                          final defaultSetup = GameSetup(
                            playerCount: 2,
                            playerConfigs: [
                              PlayerConfig(name: '你', isHuman: true),
                              PlayerConfig(name: '电脑1', isHuman: false),
                            ],
                          );
                          ref.read(gameProvider.notifier).initGameWithSetup(defaultSetup);
                        }
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
                        final newSettings = gameNotifier.state.settings.copyWith(
                          autoSaveEnabled: value,
                        );
                        gameNotifier.state = gameNotifier.state.copyWith(
                          settings: newSettings,
                        );
                        setState(() {});
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('音效'),
                      subtitle: const Text('游戏音效和反馈声'),
                      secondary: const Icon(Icons.volume_up),
                      value: ref.read(gameProvider).settings.soundEnabled,
                      onChanged: (value) {
                        final gameNotifier = ref.read(gameProvider.notifier);
                        final newSettings = gameNotifier.state.settings.copyWith(
                          soundEnabled: value,
                        );
                        gameNotifier.state = gameNotifier.state.copyWith(
                          settings: newSettings,
                        );
                        SoundService.setEnabled(value);
                        setState(() {});
                      },
                    ),
                    SwitchListTile(
                      title: const Text('背景音乐'),
                      subtitle: const Text('游戏背景音乐（暂不可用）'),
                      secondary: const Icon(Icons.music_note),
                      value: ref.read(gameProvider).settings.musicEnabled,
                      onChanged: null,
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '游戏速度',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${ref.read(gameProvider).settings.speedMultiplier.toStringAsFixed(1)}x',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                ),
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
                                  final storage = await StorageService.getInstance();
                                  await storage.remove('game_setup');
                                  await storage.remove('board_layout');
                                  await SaveService.deleteSave();
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.remove('monopoly_game_settings');
                                  ref.read(gameProvider.notifier).resetGame();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('本地数据已清理，正在跳转到游戏设置页面')),
                                    );
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const GameSetupPage()),
                                    );
                                  }
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
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
              ),
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
                '策略性地管理资金和地产，成为地产大亨',
              ]),
              _buildRuleSection('基本玩法', [
                '每位玩家初始拥有 ${GameConstants.startingCash} 现金',
                '按回合顺序进行游戏，每回合先掷骰子',
                '根据骰子点数移动棋子到相应位置',
                '处理所在位置的事件（购买、支付租金等）',
                '可以选择购买地产、建造房屋或结束回合',
              ]),
              _buildRuleSection('地产系统', [
                '地产分为普通地产、高铁站和公用事业',
                '购买地产需要支付相应价格',
                '拥有完整色组后可以建造房屋',
                '每栋房屋增加租金收入',
                '5栋房屋可升级为酒店，获得更高租金',
              ]),
              _buildRuleSection('监狱系统', [
                '掷出3次对子会被送进监狱',
                '停在"前往派出所"格子会被送进监狱',
                '在监狱中可以：',
                '  - 掷骰子尝试离开（需要掷出对子）',
                '  - 支付${GameConstants.bailAmount}元保释金',
                '  - 使用出狱卡',
                '最多在监狱中停留${GameConstants.maxJailTurns}回合，之后必须离开',
              ]),
              _buildRuleSection('卡牌系统', [
                '机会卡：随机事件，可能带来好运或厄运',
                '公益卡：社区福利，可能获得资金或特殊效果',
                '卡牌效果包括：前进、后退、获得资金、支付费用、入狱等',
              ]),
              _buildRuleSection('特殊格子', [
                '起点（祖国华诞）：经过时获得${GameConstants.passGoReward}元',
                '人民广场：休息区，无特殊效果',
                '个人所得税：支付${GameConstants.incomeTax}元',
                '消费税：支付${GameConstants.luxuryTax}元',
              ]),
              _buildRuleSection('破产规则', [
                '当玩家现金不足以支付债务时会破产',
                '破产玩家的所有地产将被收回',
                '最后一位非破产玩家获胜',
              ]),
              _buildRuleSection('AI玩家', [
                '电脑玩家会根据难度和性格自动进行游戏',
                '简单模式：AI决策较为保守',
                '困难模式：AI会更积极地购买和建造',
              ]),
              _buildRuleSection('操作提示', [
                '点击"掷骰子"开始你的回合',
                '停在无主地产时可以选择购买',
                '停在自己的地产时可以选择建造房屋',
                '点击"结束回合"结束当前回合',
                '使用右上角的保存按钮保存游戏进度',
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
            children: rules
                .map(
                  (rule) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $rule'),
                  ),
                )
                .toList(),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    '共 ${logRecords.length} 条记录',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: logRecords.isEmpty
                    ? const Center(child: Text('暂无操作记录'))
                    : ListView.builder(
                        reverse: true, // 最新的记录在最下面
                        itemCount: logRecords.length,
                        itemBuilder: (context, index) {
                          final record =
                              logRecords[logRecords.length - 1 - index];
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
                Text(record.levelEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  record.formattedTime,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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
            Text(record.message, style: const TextStyle(fontSize: 14)),
            if (record.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Error: ${record.error}',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
