// 地产大亨 - 游戏状态管理 (Riverpod)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/logger.dart';
import '../models/models.dart';
import '../constants/board_config.dart';
import '../services/dice_service.dart';
import '../services/rent_calculator.dart';
import '../services/card_service.dart';
import '../services/ai_service.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../pages/game_setup_page.dart';

/// 游戏状态Notifier
class GameNotifier extends StateNotifier<GameState> {
  final Logger _logger = Logger('GameNotifier');
  
  GameNotifier() : super(_createInitialState());

  static GameState _createInitialState() {
    return GameState(
      players: [],
      phase: GamePhase.init,
      properties: _createInitialProperties(),
      chanceCards: List.from(chanceCards),
      communityChestCards: List.from(communityChestCards),
      settings: const GameSettings(),
    );
  }

  static List<PropertyState> _createInitialProperties() {
    return List.generate(
      40,
      (index) => PropertyState(cellIndex: index),
    );
  }

  /// 初始化新游戏
  void initGame(GameSettings settings) {
    // 清除旧的日志记录
    AppLogger.clearLogRecords();
    
    final playerCount = settings.playerCount;
    final players = <Player>[];
    
    // 创建人类玩家
    players.add(Player(
      id: const Uuid().v4(),
      name: '你',
      tokenColor: Color(playerTokenColors[0]),
      cash: 1500,
      isHuman: true,
    ));

    // 创建AI玩家
    for (int i = 1; i < playerCount; i++) {
      players.add(Player(
        id: const Uuid().v4(),
        name: '电脑$i',
        tokenColor: Color(playerTokenColors[i % playerTokenColors.length]),
        cash: 1500,
        isHuman: false,
      ));
    }

    state = GameState(
      players: players,
      currentPlayerIndex: 0,
      turnNumber: 1,
      phase: GamePhase.playerTurnStart,
      properties: _createInitialProperties(),
      chanceCards: CardService.shuffleCards(List.from(chanceCards)),
      communityChestCards: CardService.shuffleCards(List.from(communityChestCards)),
      settings: settings,
    );
    
    _logger.info('=== 游戏开始 ===');
    _logger.info('=== 第 1 回合开始 ===');
  }

  /// 根据游戏设置初始化游戏
  void initGameWithSetup(GameSetup setup) {
    // 清除旧的日志记录
    AppLogger.clearLogRecords();
    
    final players = <Player>[];
    
    // 根据设置创建玩家
    for (int i = 0; i < setup.playerCount; i++) {
      final config = setup.playerConfigs[i];
      players.add(Player(
        id: const Uuid().v4(),
        name: config.name,
        tokenColor: Color(playerTokenColors[i % playerTokenColors.length]),
        cash: 1500,
        isHuman: config.isHuman,
      ));
    }

    // 创建游戏设置
    final aiConfigs = setup.playerConfigs.where((config) => !config.isHuman).toList();
    final settings = GameSettings(
      playerCount: setup.playerCount,
      difficulty: aiConfigs.isNotEmpty ? aiConfigs.first.difficulty : AIDifficulty.easy,
      aiPersonas: aiConfigs.map((config) => config.personality).toList(),
      soundEnabled: true,
      musicEnabled: true,
      autoSaveEnabled: true,
    );

    state = GameState(
      players: players,
      currentPlayerIndex: 0,
      turnNumber: 1,
      phase: GamePhase.playerTurnStart,
      properties: _createInitialProperties(),
      chanceCards: CardService.shuffleCards(List.from(chanceCards)),
      communityChestCards: CardService.shuffleCards(List.from(communityChestCards)),
      settings: settings,
    );
    
    _logger.info('根据游戏设置初始化完成，玩家数量: ${setup.playerCount}');
    _logger.info('=== 游戏开始 ===');
    _logger.info('=== 第 1 回合开始 ===');
  }

  /// 加载游戏
  Future<void> loadSavedGame() async {
    final savedState = await SaveService.loadGame();
    if (savedState != null) {
      state = savedState;
    }
  }

  /// 掷骰子
  void rollDice() {
    if (state.phase != GamePhase.playerTurnStart) return;

    final (dice1, dice2, total) = DiceService.rollBoth();
    final isDoubles = DiceService.isDoubles(dice1, dice2);
    final player = state.currentPlayer;
    
    _logger.info('${player.name} 掷骰子: $dice1 + $dice2 = $total${isDoubles ? ' (对子!)' : ''}');

    state = state.copyWith(
      phase: GamePhase.diceRolling,
      lastDice1: dice1,
      lastDice2: dice2,
      isDoubles: isDoubles,
      consecutiveDoubles: isDoubles ? state.consecutiveDoubles + 1 : 0,
    );

    // 延迟后进入移动阶段
    Future.delayed(const Duration(milliseconds: 800), () {
      _processMovement(total, isDoubles);
    });
  }

  /// 处理玩家移动
  void _processMovement(int steps, bool isDoubles) {
    final player = state.currentPlayer;
    int newPosition = (player.position + steps) % 40;
    bool passedGo = player.position + steps >= 40;
    
    if (player.isInJail) {
      _logger.info('${player.name} 在监狱中掷出了 ${isDoubles ? '对子，离开监狱' : '非对子，继续待在监狱'}');
    }

    // 检查是否进入监狱
    if (state.consecutiveDoubles >= 3) {
      _logger.info('${player.name} 连续3次对子，被送进监狱');
      _sendToJail();
      return;
    }

    // 如果在监狱中且不是双三，离开监狱
    if (player.isInJail) {
      if (!isDoubles) {
        // 在监狱中度过一回合
        _handleJailTurn();
        return;
      }
      // 离开监狱
      _handleJailBreak();
      newPosition = (jailIndex + steps) % 40;
    }
    
    _logger.info('${player.name} 从位置 ${player.position}(${boardCells[player.position].name}) 移动 $steps 步到位置 $newPosition(${boardCells[newPosition].name})${passedGo ? '，经过起点' : ''}');

    state = state.copyWith(
      phase: GamePhase.playerMoving,
      players: state.players.map((p) {
        if (p.id == player.id) {
          return p.copyWith(position: newPosition);
        }
        return p;
      }).toList(),
    );

    // 延迟后处理事件
    Future.delayed(const Duration(milliseconds: 500), () {
      _processCellEvent(newPosition, passedGo, isDoubles);
    });
  }

  /// 处理格子事件
  void _processCellEvent(int position, bool passedGo, bool isDoubles) {
    final cell = boardCells[position];
    final player = state.currentPlayer;
    
    _logger.debug('${player.name} 到达位置 $position: ${cell.name} (${cell.type.toString().split('.').last})');

    // 处理经过起点
    int moneyChange = 0;
    if (passedGo) {
      moneyChange += 200;
      _logger.info('${player.name} 经过起点，获得 \$200');
    }

    switch (cell.type) {
      case CellType.go:
        // 已经在移动阶段处理了
        break;
      case CellType.property:
      case CellType.railroad:
      case CellType.utility:
        _handlePropertyEvent(position);
        return; // 购买/租金在异步中处理
      case CellType.chance:
        _logger.info('${player.name} 抽到机会卡');
        _handleChanceCard();
        return;
      case CellType.communityChest:
        _logger.info('${player.name} 抽到社区福利卡');
        _handleCommunityChestCard();
        return;
      case CellType.incomeTax:
        _logger.info('${player.name} 遇到所得税');
        _handleIncomeTax(player);
        return;
      case CellType.luxuryTax:
        _logger.info('${player.name} 遇到奢侈品税');
        _handleLuxuryTax(player);
        return;
      case CellType.goToJail:
        _logger.info('${player.name} 被送进监狱');
        _sendToJail();
        return;
      case CellType.freeParking:
        _logger.debug('${player.name} 停在免费停车');
        break;
      case CellType.jail:
        _logger.debug('${player.name} 访问监狱');
        break;
    }

    // 应用资金变化
    if (moneyChange > 0) {
      _updatePlayerCash(player.id, moneyChange);
    }

    // 进入行动选择阶段
    state = state.copyWith(phase: GamePhase.playerAction);
  }

  /// 处理地产事件（购买或租金）
  void _handlePropertyEvent(int position) {
    final cell = boardCells[position];
    final property = state.properties.firstWhere((p) => p.cellIndex == position);
    final player = state.currentPlayer;

    // 已有拥有者，检查是否需要付租金
    if (property.ownerId != null && property.ownerId != state.currentPlayer.id) {
      if (!property.isMortgaged) {
        final rentResult = RentCalculator.calculateRent(
          cellIndex: position,
          properties: state.properties,
          players: state.players,
          diceTotal: (state.lastDice1 ?? 0) + (state.lastDice2 ?? 0),
        );

        if (rentResult.amount > 0) {
          final owner = state.players.firstWhere((p) => p.id == property.ownerId);
          _logger.info('${player.name} 向 ${owner.name} 支付 ${rentResult.amount} 租金');
          _payRent(property.ownerId!, rentResult.amount);
          state = state.copyWith(phase: GamePhase.playerAction);
        }
      } else {
        _logger.debug('${player.name} 停在 ${cell.name}，但该地产已抵押，无需支付租金');
        state = state.copyWith(phase: GamePhase.playerAction);
      }
    } else if (property.ownerId == null) {
      // 可以购买
      _logger.info('${player.name} 可以购买 ${cell.name}，价格: ${cell.price}');
      state = state.copyWith(phase: GamePhase.playerAction);
    } else {
      _logger.debug('${player.name} 停在自己的地产 ${cell.name}');
      state = state.copyWith(phase: GamePhase.playerAction);
    }
  }

  /// 购买地产
  void buyProperty(int position) {
    final cell = boardCells[position];
    final price = cell.price ?? 0;
    final player = state.currentPlayer;

    if (player.cash < price) {
      _logger.warning('${player.name} 现金不足，无法购买 ${cell.name} (需要 $price，只有 ${player.cash})');
      return;
    }

    _logger.info('${player.name} 购买 ${cell.name}，花费 $price');

    // 扣款
    _updatePlayerCash(player.id, -price);

    // 更新地产状态
    final newProperties = state.properties.map((p) {
      if (p.cellIndex == position) {
        return p.copyWith(ownerId: player.id);
      }
      return p;
    }).toList();

    // 更新玩家拥有的地产列表
    final newPlayers = state.players.map((p) {
      if (p.id == player.id) {
        return p.copyWith(ownedProperties: [...p.ownedProperties, position]);
      }
      return p;
    }).toList();

    state = state.copyWith(
      properties: newProperties,
      players: newPlayers,
    );
    SoundService.playBuy();
  }

  /// 拒绝购买，进入拍卖
  void rejectPurchase() {
    // TODO: 拍卖逻辑
    state = state.copyWith(phase: GamePhase.playerAction);
  }

  /// 支付租金
  void _payRent(String ownerId, int amount) {
    final player = state.currentPlayer;
    SoundService.playRent();
    if (player.cash < amount) {
      // 破产处理
      _handleBankruptcy(player.id, ownerId, amount);
      return;
    }

    _updatePlayerCash(player.id, -amount);
    _updatePlayerCash(ownerId, amount);
  }

  /// 处理所得税
  void _handleIncomeTax(Player player) {
    // 简单处理：固定200元
    if (player.cash >= 200) {
      _updatePlayerCash(player.id, -200);
    } else {
      _handleBankruptcy(player.id, null, player.cash);
    }
    state = state.copyWith(phase: GamePhase.playerAction);
  }

  /// 处理奢侈品税
  void _handleLuxuryTax(Player player) {
    if (player.cash >= 100) {
      _updatePlayerCash(player.id, -100);
    } else {
      _handleBankruptcy(player.id, null, player.cash);
    }
    state = state.copyWith(phase: GamePhase.playerAction);
  }

  /// 处理机会卡
  void _handleChanceCard() {
    final cards = state.chanceCards;
    final index = state.chanceCardIndex;
    final (card, nextIndex, _) = CardService.drawCard(cards, index);

    state = state.copyWith(chanceCardIndex: nextIndex);
    SoundService.playCard();
    _executeCardEffect(card, isChance: true);
  }

  /// 处理社区福利卡
  void _handleCommunityChestCard() {
    final cards = state.communityChestCards;
    final index = state.communityChestCardIndex;
    final (card, nextIndex, _) = CardService.drawCard(cards, index);

    state = state.copyWith(communityChestCardIndex: nextIndex);
    SoundService.playCard();
    _executeCardEffect(card, isChance: false);
  }

  /// 执行卡牌效果
  void _executeCardEffect(GameCard card, {required bool isChance}) {
    final result = CardService.executeCardEffect(card, state.currentPlayer.position);
    final player = state.currentPlayer;
    
    _logger.info('${player.name} 抽到${isChance ? '机会' : '命运'}卡: ${card.title}');
    _logger.info('${player.name} 卡牌效果: ${_getCardEffectDescription(card, result)}');

    // 处理资金变化
    if (result.collect || result.pay) {
      _updatePlayerCash(player.id, result.amount);
    }

    // 处理每个玩家付款
    if (result.payEachPlayer) {
      for (final p in state.players) {
        if (p.id != player.id && !p.isBankrupt) {
          _updatePlayerCash(p.id, result.amount);
          _updatePlayerCash(player.id, result.amount);
        }
      }
    }

    // 处理出狱卡
    if (result.getOutOfJailCard) {
      final newPlayers = state.players.map((p) {
        if (p.id == player.id) {
          return p.copyWith(hasGetOutOfJailFree: true);
        }
        return p;
      }).toList();
      state = state.copyWith(players: newPlayers);
    }

    // 处理前往监狱
    if (result.goToJail) {
      _sendToJail();
      return;
    }

    // 处理位置变化
    int newPosition = result.newPosition;
    if (newPosition >= 0 && newPosition < 40) {
      _updatePlayerPosition(player.id, newPosition);
      
      // 处理经过起点
      if (result.passGo && newPosition < player.position) {
        _updatePlayerCash(player.id, 200);
      }

      // 延迟处理新位置事件
      Future.delayed(const Duration(milliseconds: 500), () {
        if (boardCells[newPosition].isPurchasable) {
          _handlePropertyEvent(newPosition);
        } else {
          state = state.copyWith(phase: GamePhase.playerAction);
        }
      });
    } else {
      state = state.copyWith(phase: GamePhase.playerAction);
    }
  }

  /// 发送玩家到监狱
  void _sendToJail() {
    final player = state.currentPlayer;
    final newPlayers = state.players.map((p) {
      if (p.id == player.id) {
        return p.copyWith(position: jailIndex, status: PlayerStatus.inJail, jailTurns: 3);
      }
      return p;
    }).toList();

    state = state.copyWith(
      players: newPlayers,
      phase: GamePhase.turnEnd,
    );
    SoundService.play(SoundEffect.jail);
    _endTurn(); // 添加这一行，确保送进监狱后结束回合
  }

  /// 处理监狱回合
  void _handleJailTurn() {
    final player = state.currentPlayer;
    final newJailTurns = player.jailTurns - 1;
    final newPlayers = state.players.map((p) {
      if (p.id == player.id) {
        return p.copyWith(jailTurns: newJailTurns);
      }
      return p;
    }).toList();

    state = state.copyWith(players: newPlayers);

    // 检查是否需要释放
    if (newJailTurns <= 0) {
      _handleJailBreak();
    } else {
      _endTurn();
    }
  }

  /// 处理离开监狱
  void _handleJailBreak() {
    final player = state.currentPlayer;
    final newPlayers = state.players.map((p) {
      if (p.id == player.id) {
        return p.copyWith(status: PlayerStatus.active, jailTurns: 0);
      }
      return p;
    }).toList();

    state = state.copyWith(players: newPlayers);
    // 不直接结束回合，让流程继续执行移动和事件处理
  }

  /// 支付保释金
  void payBail() {
    final player = state.currentPlayer;
    if (player.cash >= 50) {
      _updatePlayerCash(player.id, -50);
      _handleJailBreak();
    }
  }

  /// 使用出狱卡
  void useJailCard() {
    final player = state.currentPlayer;
    if (player.hasGetOutOfJailFree) {
      final newPlayers = state.players.map((p) {
        if (p.id == player.id) {
          return p.copyWith(hasGetOutOfJailFree: false);
        }
        return p;
      }).toList();
      state = state.copyWith(players: newPlayers);
      _handleJailBreak();
    }
  }

  /// 建造房屋
  void buildHouse(int propertyIndex) {
    final property = state.properties.firstWhere((p) => p.cellIndex == propertyIndex);
    final cell = boardCells[propertyIndex];
    final player = state.currentPlayer;
    
    if (property.ownerId != player.id) {
      _logger.warning('${player.name} 试图在非自己的地产上建造房屋');
      return;
    }
    
    if (property.houses >= 5) {
      _logger.warning('${player.name} 试图在已有酒店的地产上建造房屋');
      return; // 已经有酒店
    }

    final price = RentCalculator.getHousePrice(propertyIndex);
    if (player.cash < price) {
      _logger.warning('${player.name} 现金不足，无法建造房屋 (需要 $price，只有 ${player.cash})');
      return;
    }

    // 检查是否可以建造
    if (!RentCalculator.canBuildHouse(
      player.id,
      boardCells[propertyIndex].color!,
      state.properties,
    )) {
      _logger.warning('${player.name} 无法在 ${cell.name} 建造房屋，不符合建造条件');
      return;
    }

    _logger.info('${player.name} 在 ${cell.name} 建造房屋，花费 $price');

    _updatePlayerCash(player.id, -price);

    final newProperties = state.properties.map((p) {
      if (p.cellIndex == propertyIndex) {
        final newHouses = p.houses + 1;
        if (newHouses >= 5) {
          _logger.info('${player.name} 在 ${cell.name} 建造了酒店');
        } else {
          _logger.info('${player.name} 在 ${cell.name} 建造了第 $newHouses 栋房屋');
        }
        return p.copyWith(houses: newHouses);
      }
      return p;
    }).toList();

    state = state.copyWith(properties: newProperties);
    SoundService.playBuild();
  }

  /// 抵押地产
  void mortgageProperty(int propertyIndex) {
    final property = state.properties.firstWhere((p) => p.cellIndex == propertyIndex);
    if (property.ownerId != state.currentPlayer.id) return;
    if (property.isMortgaged) return;
    if (property.houses > 0) return; // 有房屋不能抵押

    final value = RentCalculator.getMortgageValue(propertyIndex);
    _updatePlayerCash(state.currentPlayer.id, value);

    final newProperties = state.properties.map((p) {
      if (p.cellIndex == propertyIndex) {
        return p.copyWith(isMortgaged: true);
      }
      return p;
    }).toList();

    state = state.copyWith(properties: newProperties);
  }

  /// 赎回抵押
  void redeemMortgage(int propertyIndex) {
    final property = state.properties.firstWhere((p) => p.cellIndex == propertyIndex);
    if (property.ownerId != state.currentPlayer.id) return;
    if (!property.isMortgaged) return;

    final value = RentCalculator.getRedeemValue(propertyIndex);
    if (state.currentPlayer.cash < value) return;

    _updatePlayerCash(state.currentPlayer.id, -value);

    final newProperties = state.properties.map((p) {
      if (p.cellIndex == propertyIndex) {
        return p.copyWith(isMortgaged: false);
      }
      return p;
    }).toList();

    state = state.copyWith(properties: newProperties);
  }

  /// 结束回合
  void _endTurn() {
    final currentPlayer = state.currentPlayer;
    
    _logger.info('${currentPlayer.name} 回合结束');
    
    // 检查是否有玩家破产
    _checkBankruptcy();

    // 检查游戏是否结束
    if (_checkGameOver()) return;

    // 切换到下一位玩家
    int nextIndex = (state.currentPlayerIndex + 1) % state.players.length;
    int newTurnNumber = state.turnNumber;
    bool isNewTurn = false;
    
    if (nextIndex == 0) {
      newTurnNumber = state.turnNumber + 1;
      isNewTurn = true;
    }

    // 检查下一位玩家是否破产
    while (state.players[nextIndex].isBankrupt) {
      _logger.debug('${state.players[nextIndex].name} 已破产，跳过');
      nextIndex = (nextIndex + 1) % state.players.length;
      if (nextIndex == 0 && !isNewTurn) {
        newTurnNumber = state.turnNumber + 1;
        isNewTurn = true;
      }
      if (state.players.where((p) => !p.isBankrupt).length <= 1) {
        _finishGame();
        return;
      }
    }
    
    final nextPlayer = state.players[nextIndex];
    _logger.info('轮到 ${nextPlayer.name}');
    
    if (isNewTurn) {
      _logger.info('=== 第 $newTurnNumber 回合开始 ===');
    }

    state = state.copyWith(
      currentPlayerIndex: nextIndex,
      turnNumber: newTurnNumber,
      phase: GamePhase.playerTurnStart,
      isDoubles: false,
      consecutiveDoubles: 0,
    );

    // 自动保存游戏
    if (state.settings.autoSaveEnabled) {
      _autoSave();
    }
  }

  /// 自动保存游戏
  Future<void> _autoSave() async {
    try {
      await SaveService.saveGame(state);
      _logger.debug('游戏已自动保存');
    } catch (e) {
      _logger.error('自动保存失败: $e');
    }
  }

  /// 检查破产
  void _checkBankruptcy() {
    for (final player in state.players) {
      if (player.cash < 0) {
        _handleBankruptcy(player.id, null, -player.cash);
      }
    }
  }

  /// 处理破产
  void _handleBankruptcy(String playerId, String? creditorId, int debt) {
    final newPlayers = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(status: PlayerStatus.bankrupt, cash: 0);
      }
      return p;
    }).toList();

    // 资产转移给债主
    if (creditorId != null) {
      final newProperties = state.properties.map((p) {
        if (p.ownerId == playerId) {
          return p.copyWith(ownerId: creditorId);
        }
        return p;
      }).toList();
      state = state.copyWith(properties: newProperties);
    }

    state = state.copyWith(players: newPlayers);
  }

  /// 检查游戏结束
  bool _checkGameOver() {
    final activePlayers = state.players.where((p) => !p.isBankrupt).toList();
    if (activePlayers.length <= 1) {
      _finishGame();
      return true;
    }
    return false;
  }

  /// 结束游戏
  void _finishGame() {
    final activePlayers = state.players.where((p) => !p.isBankrupt).toList();
    if (activePlayers.isNotEmpty) {
      state = state.copyWith(
        phase: GamePhase.gameOver,
        winnerId: activePlayers.first.id,
      );
      // 播放音效
      if (activePlayers.first.isHuman) {
        SoundService.playWin();
      }
    }
  }

  /// 更新玩家现金
  void _updatePlayerCash(String playerId, int amount) {
    final newPlayers = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(cash: p.cash + amount);
      }
      return p;
    }).toList();
    state = state.copyWith(players: newPlayers);
  }

  /// 更新玩家位置
  void _updatePlayerPosition(String playerId, int position) {
    final newPlayers = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(position: position);
      }
      return p;
    }).toList();
    state = state.copyWith(players: newPlayers);
  }

  /// 玩家点击结束回合按钮
  void endTurn() {
    if (state.phase == GamePhase.playerAction) {
      _endTurn();
    }
  }

  /// 手动保存游戏
  Future<void> saveGame() async {
    await SaveService.saveGame(state);
  }

  /// AI自动行动
  Future<void> performAIAction() async {
    if (state.currentPlayer.isHuman) return;

    final player = state.currentPlayer;
    final settings = state.settings;
    final personality = settings.aiPersonas.isNotEmpty 
        ? settings.aiPersonas[state.currentPlayerIndex % settings.aiPersonas.length]
        : AIPersonality.conservative;

    // 检查是否需要掷骰子
    if (state.phase == GamePhase.playerTurnStart) {
      // 等待一小段时间模拟思考
      await Future.delayed(Duration(milliseconds: settings.difficulty == AIDifficulty.easy ? 1500 : 500));
      
      // AI自动掷骰子
      rollDice();
      return; // 掷骰子后会触发后续流程
    }

    // 等待一小段时间模拟思考
    await Future.delayed(Duration(milliseconds: settings.difficulty == AIDifficulty.easy ? 1000 : 300));

    // AI决策
    final position = player.position;
    final property = state.properties.firstWhere((p) => p.cellIndex == position);
    final cell = boardCells[position];

    // 检查是否需要购买
    if (property.ownerId == null && cell.isPurchasable) {
      final decision = AIService.decideBuyProperty(
        player: player,
        propertyIndex: position,
        properties: state.properties,
        difficulty: settings.difficulty,
        personality: personality,
      );

      if (decision.action == AIAction.buy) {
        buyProperty(position);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // AI建造决策
    final buildDecision = AIService.decideBuildHouse(
      player: player,
      properties: state.properties,
      difficulty: settings.difficulty,
      personality: personality,
    );

    if (buildDecision.action == AIAction.build && buildDecision.targetIndex != null) {
      buildHouse(buildDecision.targetIndex!);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // 结束回合
    _endTurn();
  }

  /// 重置游戏
  void resetGame() {
    state = _createInitialState();
  }

  /// 获取卡牌效果描述
  String _getCardEffectDescription(GameCard card, CardEffectResult result) {
    final effect = card.effect;
    
    switch (effect.type) {
      case CardEffectType.advanceTo:
        return '前进到 ${effect.target ?? '起点'}';
      case CardEffectType.advanceToNearestRailroad:
        return '前进到最近的火车站';
      case CardEffectType.advanceToNearestUtility:
        return '前进到最近的公用事业';
      case CardEffectType.goToJail:
        return '前往监狱';
      case CardEffectType.collect:
        return '获得 \$${effect.value}';
      case CardEffectType.pay:
        return '支付 \$${effect.value}';
      case CardEffectType.payPerHouse:
        return '按房屋支付，每栋 \$${effect.value}';
      case CardEffectType.goBack:
        return '后退 ${effect.value} 步';
      case CardEffectType.getOutOfJailFree:
        return '获得出狱卡';
      case CardEffectType.electionChairman:
        return '选举主席，支付给每个玩家 \$${effect.value}';
    }
  }
}

/// 游戏状态Provider
final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier();
});

/// 当前玩家Provider
final currentPlayerProvider = Provider<Player>((ref) {
  final state = ref.watch(gameProvider);
  if (state.players.isEmpty) {
    // 当玩家列表为空时，返回一个默认的玩家对象
    return Player(
      id: '',
      name: '',
      tokenColor: Colors.grey,
      isHuman: false,
    );
  }
  return state.currentPlayer;
});

/// 是否为玩家回合
final isPlayerTurnProvider = Provider<bool>((ref) {
  final state = ref.watch(gameProvider);
  if (state.players.isEmpty) return false;
  return state.currentPlayer.isHuman && state.phase != GamePhase.gameOver;
});
