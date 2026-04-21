// 地产大亨 - 游戏状态管理 (Riverpod)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/logger.dart';
import '../models/models.dart';
import '../constants/board_config.dart';
import '../constants/game_constants.dart';
import '../constants/themes/theme_provider.dart';
import '../constants/themes/base_cards.dart';
import '../services/dice_service.dart';
import '../services/rent_calculator.dart';
import '../services/card_service.dart';
import '../services/ai_service.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../pages/game_setup_page.dart';
import '../widgets/feedback/operation_log_board.dart';

/// 游戏状态Notifier
class GameNotifier extends StateNotifier<GameState> {
  final Logger _logger = Logger('GameNotifier');
  
  GameNotifier() : super(_createInitialState());

  /// 计算调整后的延迟时间（根据游戏速度倍数）
  Duration _adjustedDelay(int milliseconds) {
    final adjustedMs = (milliseconds / state.settings.speedMultiplier).round();
    return Duration(milliseconds: adjustedMs);
  }

  static GameState _createInitialState() {
    // 使用当前缓存主题的卡牌模板生成初始卡牌
    // 注意：这是初始占位状态，实际游戏开始时会在 initGameWithSetup 中重新生成
    final theme = currentCachedTheme;
    return GameState(
      players: [],
      phase: GamePhase.init,
      properties: _createInitialProperties(),
      chanceCards: buildChanceCards(theme),
      communityChestCards: buildCommunityChestCards(theme),
      settings: const GameSettings(),
    );
  }

  static List<PropertyState> _createInitialProperties() {
    return List.generate(
      GameConstants.boardCellCount,
      (index) => PropertyState(cellIndex: index),
    );
  }

  /// 根据游戏设置初始化游戏
  void initGameWithSetup(GameSetup setup) {
    // 清除旧的日志记录
    AppLogger.clearLogRecords();
    OperationLogManager.instance.clear();
    
    final players = <Player>[];
    
    // 根据设置创建玩家
    for (int i = 0; i < setup.playerCount; i++) {
      final config = setup.playerConfigs[i];
      players.add(Player(
        id: const Uuid().v4(),
        name: config.name,
        tokenColor: Color(playerTokenColors[i % playerTokenColors.length]),
        cash: GameConstants.startingCash,
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
      musicEnabled: false,
      autoSaveEnabled: true,
    );

    // 同步音效服务状态
    SoundService.setEnabled(true);

    // 使用当前主题的卡牌模板生成卡牌，并进行洗牌
    final theme = currentCachedTheme;
    final chanceCards = buildChanceCards(theme);
    final communityChestCards = buildCommunityChestCards(theme);
    
    state = GameState(
      players: players,
      currentPlayerIndex: 0,
      turnNumber: 1,
      phase: GamePhase.playerTurnStart,
      properties: _createInitialProperties(),
      chanceCards: CardService.shuffleCards(chanceCards),
      communityChestCards: CardService.shuffleCards(communityChestCards),
      settings: settings,
      setup: setup.toJson(),
    );
    
    _logger.info('根据游戏设置初始化完成，玩家数量: ${setup.playerCount}');
    _logger.info('=== 游戏开始 ===');
    GameLogger.gameStart(
      playerNames: players.map((p) => p.name).toList(),
      turnNumber: 1,
    );
    _logger.info('=== 第 1 回合开始 ===');
    GameLogger.turnStart(
      playerId: players[0].id,
      playerName: players[0].name,
      playerColor: players[0].tokenColor.toARGB32(),
      turnNumber: 1,
    );
  }

  GameSetup? getGameSetup() {
    final setupJson = state.setup;
    if (setupJson == null) return null;
    return GameSetup.fromJson(setupJson);
  }

  /// 加载游戏
  Future<void> loadSavedGame() async {
    final savedState = await SaveService.loadGame();
    if (savedState != null) {
      // 使用当前主题的卡牌模板重新生成卡牌（因为fromJson时设置为空列表）
      final theme = currentCachedTheme;
      final chanceCards = buildChanceCards(theme);
      final communityChestCards = buildCommunityChestCards(theme);
      
      state = savedState.copyWith(
        chanceCards: CardService.shuffleCards(chanceCards),
        communityChestCards: CardService.shuffleCards(communityChestCards),
      );
      _logger.info('游戏加载成功');
      GameLogger.info('游戏加载成功');
    }
  }

  /// 掷骰子
  void rollDice() {
    if (state.phase != GamePhase.playerTurnStart) return;

    _performRollDice();
  }

  /// 执行掷骰子操作
  void _performRollDice() {
    final (dice1, dice2, total) = DiceService.rollBoth();
    final isDoubles = DiceService.isDoubles(dice1, dice2);
    final player = state.currentPlayer;
    
    _logger.info('${player.name} 掷骰子: $dice1 + $dice2 = $total${isDoubles ? ' (对子!)' : ''}');
    GameLogger.diceRoll(
      dice1: dice1,
      dice2: dice2,
      isDoubles: isDoubles,
      playerId: player.id,
      playerName: player.name,
      playerColor: player.tokenColor.toARGB32(),
      turnNumber: state.turnNumber,
    );

    state = state.copyWith(
      phase: GamePhase.diceRolling,
      lastDice1: dice1,
      lastDice2: dice2,
      isDoubles: isDoubles,
      consecutiveDoubles: isDoubles ? state.consecutiveDoubles + 1 : 0,
    );
    SoundService.playDiceRoll();

    if (isDoubles) {
      Future.delayed(const Duration(milliseconds: 500), () {
        SoundService.playDoubles();
      });
    }

    // 延迟后进入移动阶段
    Future.delayed(_adjustedDelay(GameConstants.diceRollDelay), () {
      _processMovement(total, isDoubles);
    });
  }

  /// 处理玩家移动
  void _processMovement(int steps, bool isDoubles) {
    final player = state.currentPlayer;
    int newPosition = (player.position + steps) % GameConstants.boardCellCount;
    bool passedGo = player.position + steps >= GameConstants.boardCellCount;
    
    if (player.isInJail) {
      _logger.info('${player.name} 在监狱中掷出了 ${isDoubles ? '对子，离开监狱' : '非对子，继续待在监狱'}');
      GameLogger.jailDiceRoll(
        dice1: state.lastDice1 ?? 0,
        dice2: state.lastDice2 ?? 0,
        isDoubles: isDoubles,
        isReleased: false,
        remainingTurns: player.jailTurns - 1,
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
        turnNumber: state.turnNumber,
      );
    }

    // 检查是否进入监狱
    if (state.consecutiveDoubles >= GameConstants.maxConsecutiveDoubles) {
      _logger.info('${player.name} 连续3次对子，被送进监狱');
      GameLogger.info('${player.name} 连续3次对子，被送进监狱',
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
      );
      _sendToJail();
      return;
    }

    // 如果在监狱中且不是双三，离开监狱
    if (player.isInJail) {
      if (!isDoubles) {
        // 在监狱中度过一回合
        _logger.info('${player.name} 在监狱中掷出了非对子，继续待在监狱');
        _handleJailTurn();
        return;
      }
      // 离开监狱
      _logger.info('${player.name} 在监狱中掷出了对子，离开监狱');
      _handleJailBreak();
      newPosition = (jailIndex + steps) % GameConstants.boardCellCount;
    }
    
    _logger.info('${player.name} 从位置 ${player.position}(${boardCells[player.position].name}) 移动 $steps 步到位置 $newPosition(${boardCells[newPosition].name})${passedGo ? '，经过起点' : ''}');
    GameLogger.playerMove(
      fromPosition: player.position,
      toPosition: newPosition,
      steps: steps,
      passedGo: passedGo,
      playerId: player.id,
      playerName: player.name,
      playerColor: player.tokenColor.toARGB32(),
      turnNumber: state.turnNumber,
    );

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
    Future.delayed(_adjustedDelay(GameConstants.playerMoveDelay), () {
      _processCellEvent(newPosition, passedGo, isDoubles);
    });
  }

  /// 处理格子事件
  void _processCellEvent(int position, bool passedGo, bool isDoubles) {
    final cell = boardCells[position];
    final player = state.currentPlayer;
    
    _logger.debug('${player.name} 到达位置 $position: ${cell.name} (${cell.type.toString().split('.').last})');

    // 处理经过起点 - 无论到达什么格子，只要经过起点就获得200元
    // 必须在处理任何格子事件之前执行，确保玩家总是能获得经过起点的奖励
    if (passedGo) {
      _updatePlayerCash(player.id, GameConstants.passGoReward);
      _logger.info('${player.name} 经过起点，获得 \$${GameConstants.passGoReward}');
      GameLogger.passGo(
        reward: GameConstants.passGoReward,
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
        turnNumber: state.turnNumber,
      );
      SoundService.playPassGo();
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
        GameLogger.info('${player.name} 抽到机会卡',
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
        );
        _handleChanceCard();
        return;
      case CellType.communityChest:
        _logger.info('${player.name} 抽到社区福利卡');
        GameLogger.info('${player.name} 抽到社区福利卡',
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
        );
        _handleCommunityChestCard();
        return;
      case CellType.incomeTax:
        _logger.info('${player.name} 遇到所得税');
        GameLogger.payTax(
          isIncomeTax: true,
          amount: GameConstants.incomeTax,
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
          turnNumber: state.turnNumber,
        );
        _handleIncomeTax(player);
        return;
      case CellType.luxuryTax:
        _logger.info('${player.name} 遇到奢侈品税');
        GameLogger.payTax(
          isIncomeTax: false,
          amount: GameConstants.luxuryTax,
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
          turnNumber: state.turnNumber,
        );
        _handleLuxuryTax(player);
        return;
      case CellType.goToJail:
        _logger.info('${player.name} 被送进监狱');
        GameLogger.goToJail(
          reason: '到达监狱格子',
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
          turnNumber: state.turnNumber,
        );
        _sendToJail();
        return;
      case CellType.freeParking:
        _logger.debug('${player.name} 停在免费停车');
        GameLogger.info('${player.name} 停在免费停车',
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
        );
        break;
      case CellType.jail:
        _logger.info('${player.name} 被送进监狱');
        GameLogger.goToJail(
          reason: '到达监狱格子',
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
          turnNumber: state.turnNumber,
        );
        _sendToJail();
        return;
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
          GameLogger.payRent(
            propertyName: cell.name,
            amount: rentResult.amount,
            payerId: player.id,
            payerName: player.name,
            payerColor: player.tokenColor.toARGB32(),
            receiverId: owner.id,
            receiverName: owner.name,
            turnNumber: state.turnNumber,
          );
          _payRent(property.ownerId!, rentResult.amount);
        }
      } else {
        _logger.debug('${player.name} 停在 ${cell.name}，但该地产已抵押，无需支付租金');
        GameLogger.info('${player.name} 停在 ${cell.name}，但该地产已抵押，无需支付租金',
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
        );
      }
    } else if (property.ownerId == null) {
      // 可以购买
      _logger.info('${player.name} 可以购买 ${cell.name}，价格: ${cell.price}');
      GameLogger.info('${player.name} 可以购买 ${cell.name}，价格: ${cell.price}',
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
      );
    } else {
      _logger.debug('${player.name} 停在自己的地产 ${cell.name}');
      GameLogger.info('${player.name} 停在自己的地产 ${cell.name}',
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
      );
    }
    
    // 无论何种情况，处理完地产事件后进入行动阶段
    state = state.copyWith(phase: GamePhase.playerAction);
  }

  /// 购买地产
  void buyProperty(int position) {
    final cell = boardCells[position];
    final price = cell.price ?? 0;
    final player = state.currentPlayer;

    debugPrint('[DEBUG buyProperty] 开始购买');
    debugPrint('[DEBUG buyProperty] position: $position, player.id: ${player.id}, player.name: ${player.name}');

    if (player.cash < price) {
      _logger.warning('${player.name} 现金不足，无法购买 ${cell.name} (需要 $price，只有 ${player.cash})');
      GameLogger.cashInsufficient(
        reason: '购买 ${cell.name}',
        needed: price,
        available: player.cash,
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
        turnNumber: state.turnNumber,
      );
      return;
    }

    _logger.info('${player.name} 购买 ${cell.name}，花费 $price');
    GameLogger.propertyPurchase(
      propertyName: cell.name,
      price: price,
      playerId: player.id,
      playerName: player.name,
      playerColor: player.tokenColor.toARGB32(),
      turnNumber: state.turnNumber,
    );

    // 扣款
    _updatePlayerCash(player.id, -price);
    debugPrint('[DEBUG buyProperty] 扣款后，player.cash: ${state.currentPlayer.cash}');

    // 更新地产状态
    debugPrint('[DEBUG buyProperty] state.properties.length: ${state.properties.length}');
    final targetProperty = state.properties.firstWhere((p) => p.cellIndex == position);
    debugPrint('[DEBUG buyProperty] 购买前 targetProperty.ownerId: ${targetProperty.ownerId}');

    final newProperties = state.properties.map((p) {
      if (p.cellIndex == position) {
        return p.copyWith(ownerId: player.id);
      }
      return p;
    }).toList();

    final newPropertyAfter = newProperties.firstWhere((p) => p.cellIndex == position);
    debugPrint('[DEBUG buyProperty] 更新后 newPropertyAfter.ownerId: ${newPropertyAfter.ownerId}');

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
    debugPrint('[DEBUG buyProperty] state 更新后，properties[position].ownerId: ${state.properties.firstWhere((p) => p.cellIndex == position).ownerId}');
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
    if (player.cash >= GameConstants.incomeTax) {
      _updatePlayerCash(player.id, -GameConstants.incomeTax);
      GameLogger.payTax(
        isIncomeTax: true,
        amount: GameConstants.incomeTax,
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
        turnNumber: state.turnNumber,
      );
    } else {
      _handleBankruptcy(player.id, null, player.cash);
    }
    state = state.copyWith(phase: GamePhase.playerAction);
  }

  /// 处理奢侈品税
  void _handleLuxuryTax(Player player) {
    if (player.cash >= GameConstants.luxuryTax) {
      _updatePlayerCash(player.id, -GameConstants.luxuryTax);
      GameLogger.payTax(
        isIncomeTax: false,
        amount: GameConstants.luxuryTax,
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
        turnNumber: state.turnNumber,
      );
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
    GameLogger.info('${player.name} 抽到${isChance ? '机会' : '命运'}卡: ${card.title}',
      playerId: player.id,
      playerName: player.name,
      playerColor: player.tokenColor.toARGB32(),
    );
    _logger.info('${player.name} 卡牌效果: ${_getCardEffectDescription(card, result)}');
    GameLogger.drawCard(
      isChance: isChance,
      cardTitle: card.title,
      cardDescription: _getCardEffectDescription(card, result),
      amount: result.collect ? result.amount : (result.pay ? -result.amount : null),
      playerId: player.id,
      playerName: player.name,
      playerColor: player.tokenColor.toARGB32(),
      turnNumber: state.turnNumber,
    );

    OperationLogManager.instance.logDrawCard(
      playerName: player.name,
      playerColor: player.tokenColor,
      cardTitle: card.title,
      cardDescription: card.description,
      amount: result.collect ? result.amount : (result.pay ? -result.amount : null),
      turnNumber: state.turnNumber,
    );

    // 处理资金变化
    if (result.collect || result.pay) {
      _updatePlayerCash(player.id, result.amount);
    }

    // 处理支付给每个玩家（董事会主席）
    if (result.payEachPlayer) {
      int totalPayment = 0;
      for (final p in state.players) {
        if (p.id != player.id && !p.isBankrupt) {
          totalPayment += result.amount;
        }
      }
      
      if (totalPayment > 0) {
        if (player.cash >= totalPayment) {
          _updatePlayerCash(player.id, -totalPayment);
          for (final p in state.players) {
            if (p.id != player.id && !p.isBankrupt) {
              _updatePlayerCash(p.id, result.amount);
            }
          }
          _logger.info('${player.name} 向每位玩家支付 \$${result.amount}，共支付 \$$totalPayment');
          GameLogger.payEachPlayer(
            amountPerPlayer: result.amount,
            playerCount: state.players.where((p) => p.id != player.id && !p.isBankrupt).length,
            totalAmount: totalPayment,
            playerId: player.id,
            playerName: player.name,
            playerColor: player.tokenColor.toARGB32(),
            turnNumber: state.turnNumber,
          );
        } else {
          _handleBankruptcy(player.id, null, player.cash);
          return;
        }
      }
    }

    // 处理从每个玩家获得（生日礼物）
    if (result.collectFromEachPlayer) {
      int totalCollection = 0;
      for (final p in state.players) {
        if (p.id != player.id && !p.isBankrupt) {
          if (p.cash >= result.amount) {
            _updatePlayerCash(p.id, -result.amount);
            totalCollection += result.amount;
          }
        }
      }
      
      if (totalCollection > 0) {
        _updatePlayerCash(player.id, totalCollection);
        _logger.info('${player.name} 从每位玩家获得 \$${result.amount}，共获得 \$$totalCollection');
        GameLogger.collectFromEachPlayer(
          amountPerPlayer: result.amount,
          playerCount: totalCollection ~/ result.amount,
          totalAmount: totalCollection,
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
          turnNumber: state.turnNumber,
        );
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

    // 处理按房屋支付
    if (result.payPerHouse) {
      int totalCost = 0;
      int houseCount = 0;
      int hotelCount = 0;
      
      for (final property in state.properties) {
        if (property.ownerId == player.id) {
          if (property.houses >= 5) {
            hotelCount++;
          } else {
            houseCount += property.houses;
          }
        }
      }
      
      // 计算费用：每栋房屋25，每家酒店100（机会卡）或每栋房屋40，每家酒店115（社区福利卡）
      final houseCost = result.houseCost ?? GameConstants.chanceHouseRepair;
      final hotelCost = isChance ? GameConstants.chanceHotelRepair : GameConstants.communityChestHotelRepair;
      totalCost = houseCount * houseCost + hotelCount * hotelCost;
      
      if (totalCost > 0) {
        _logger.info('${player.name} 支付房屋维修费用: \$${totalCost} (房屋: $houseCount, 酒店: $hotelCount)');
        GameLogger.houseRepair(
          amount: totalCost,
          houseCount: houseCount,
          hotelCount: hotelCount,
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
          turnNumber: state.turnNumber,
        );
        if (player.cash >= totalCost) {
          _updatePlayerCash(player.id, -totalCost);
        } else {
          _handleBankruptcy(player.id, null, player.cash);
          return;
        }
      }
    }

    // 处理前往监狱
    if (result.goToJail) {
      _sendToJail();
      return;
    }

    // 处理位置变化
    int newPosition = result.newPosition;
    if (newPosition >= 0 && newPosition < GameConstants.boardCellCount) {
      // 只有当位置发生变化时才更新位置和处理事件
      if (newPosition != player.position) {
        _updatePlayerPosition(player.id, newPosition);
        
        if (result.passGo) {
          _logger.info('${player.name} 经过起点，获得 \$${GameConstants.passGoReward}');
          GameLogger.passGo(
            reward: GameConstants.passGoReward,
            playerId: player.id,
            playerName: player.name,
            playerColor: player.tokenColor.toARGB32(),
            turnNumber: state.turnNumber,
          );
          _updatePlayerCash(player.id, GameConstants.passGoReward);
        }

        // 延迟处理新位置事件
        Future.delayed(_adjustedDelay(GameConstants.playerMoveDelay), () {
          if (boardCells[newPosition].isPurchasable) {
            _handlePropertyEvent(newPosition);
          } else {
            state = state.copyWith(phase: GamePhase.playerAction);
          }
        });
      } else {
        // 位置未变化，直接进入行动阶段
        state = state.copyWith(phase: GamePhase.playerAction);
      }
    } else {
      state = state.copyWith(phase: GamePhase.playerAction);
    }
  }

  /// 发送玩家到监狱
  void _sendToJail() {
    final player = state.currentPlayer;
    final newPlayers = state.players.map((p) {
      if (p.id == player.id) {
        return p.copyWith(position: jailIndex, status: PlayerStatus.inJail, jailTurns: GameConstants.maxJailTurns);
      }
      return p;
    }).toList();

    state = state.copyWith(
      players: newPlayers,
      phase: GamePhase.turnEnd,
    );
    SoundService.play(SoundEffect.jail);
    GameLogger.goToJail(
      reason: '连续3次对子',
      playerId: player.id,
      playerName: player.name,
      playerColor: player.tokenColor.toARGB32(),
      turnNumber: state.turnNumber,
    );
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
      _endTurn(); // 玩家待满3回合被释放后，需要结束回合
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
    if (player.cash >= GameConstants.bailAmount) {
      _updatePlayerCash(player.id, -GameConstants.bailAmount);
      _logger.info('${player.name} 支付保释金 \$${GameConstants.bailAmount} 离开监狱');
      GameLogger.releaseFromJail(
        reason: '支付保释金',
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
        turnNumber: state.turnNumber,
      );
      _handleJailBreak();
    } else {
      _logger.warning('${player.name} 现金不足，无法支付保释金');
      GameLogger.cashInsufficient(
        reason: '支付保释金',
        needed: GameConstants.bailAmount,
        available: player.cash,
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
        turnNumber: state.turnNumber,
      );
      // 现金不足时，不能支付保释金，需要选择其他方式（掷骰子或使用越狱卡）
      // 不调用_handleJailBreak()，让玩家留在监狱中
      return;
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
      _logger.info('${player.name} 使用越狱卡离开监狱');
      GameLogger.releaseFromJail(
        reason: '使用越狱卡',
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
        turnNumber: state.turnNumber,
      );
      state = state.copyWith(players: newPlayers);
      _handleJailBreak();
    }
  }

  /// 切换到监狱决策阶段
  void transitionToJailDecision() {
    if (state.phase != GamePhase.playerTurnStart) return;
    if (!state.currentPlayer.isInJail) return;

    state = state.copyWith(phase: GamePhase.jailDecision);
  }

  /// 处理监狱决策
  /// [decision]: 0 = 掷骰子尝试离开, 1 = 使用越狱卡, 2 = 支付保释金
  void handleJailDecision(int decision) {
    if (state.phase != GamePhase.jailDecision) return;

    final player = state.currentPlayer;

    switch (decision) {
      case 0:
        _logger.info('${player.name} 选择掷骰子尝试离开监狱');
        GameLogger.info('${player.name} 选择掷骰子尝试离开监狱',
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
        );
        _performRollDice();
        break;
      case 1:
        if (player.hasGetOutOfJailFree) {
          useJailCard();
          _performRollDice();
        } else {
          _logger.warning('${player.name} 没有越狱卡，无法使用');
          GameLogger.warning('${player.name} 没有越狱卡，无法使用',
            playerId: player.id,
            playerName: player.name,
            playerColor: player.tokenColor.toARGB32(),
          );
          return;
        }
        break;
      case 2:
        if (player.cash >= GameConstants.bailAmount) {
          payBail();
          _performRollDice();
        } else {
          _logger.warning('${player.name} 现金不足，无法支付保释金');
          GameLogger.cashInsufficient(
            reason: '支付保释金',
            needed: GameConstants.bailAmount,
            available: player.cash,
            playerId: player.id,
            playerName: player.name,
            playerColor: player.tokenColor.toARGB32(),
            turnNumber: state.turnNumber,
          );
          return;
        }
        break;
    }
  }

  /// AI在监狱中的决策
  void _handleAIActionInJail(AIPersonality personality) {
    final player = state.currentPlayer;
    final jailTurns = player.jailTurns;

    if (player.hasGetOutOfJailFree) {
      _logger.info('${player.name} (AI) 使用越狱卡离开监狱');
      GameLogger.info('${player.name} (AI) 使用越狱卡离开监狱',
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
      );
      handleJailDecision(1);
      return;
    }

    // 如果是最后一回合，必须支付保释金
    if (jailTurns <= 1) {
      if (player.cash >= GameConstants.bailAmount) {
        _logger.info('${player.name} (AI) 最后一回合，支付保释金离开监狱');
        GameLogger.info('${player.name} (AI) 最后一回合，支付保释金离开监狱',
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
        );
        handleJailDecision(2);
      } else {
        _logger.info('${player.name} (AI) 现金不足，只能掷骰子尝试离开');
        GameLogger.info('${player.name} (AI) 现金不足，只能掷骰子尝试离开',
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
        );
        handleJailDecision(0);
      }
      return;
    }

    // 根据个性选择策略
    switch (personality) {
      case AIPersonality.aggressive:
        if (player.cash >= GameConstants.bailAmount) {
          _logger.info('${player.name} (AI-aggressive) 选择支付保释金离开监狱');
          GameLogger.info('${player.name} (AI-aggressive) 选择支付保释金离开监狱',
            playerId: player.id,
            playerName: player.name,
            playerColor: player.tokenColor.toARGB32(),
          );
          handleJailDecision(2);
        } else {
          _logger.info('${player.name} (AI) 现金不足，掷骰子尝试离开');
          GameLogger.info('${player.name} (AI) 现金不足，掷骰子尝试离开',
            playerId: player.id,
            playerName: player.name,
            playerColor: player.tokenColor.toARGB32(),
          );
          handleJailDecision(0);
        }
        break;
      case AIPersonality.conservative:
        _logger.info('${player.name} (AI-conservative) 选择掷骰子尝试离开监狱');
        GameLogger.info('${player.name} (AI-conservative) 选择掷骰子尝试离开监狱',
          playerId: player.id,
          playerName: player.name,
          playerColor: player.tokenColor.toARGB32(),
        );
        handleJailDecision(0);
        break;
      case AIPersonality.random:
        final choice = DateTime.now().millisecond % 3;
        if (choice == 1 && player.hasGetOutOfJailFree) {
          _logger.info('${player.name} (AI-random) 随机选择使用越狱卡');
          GameLogger.info('${player.name} (AI-random) 随机选择使用越狱卡',
            playerId: player.id,
            playerName: player.name,
            playerColor: player.tokenColor.toARGB32(),
          );
          handleJailDecision(1);
        } else if (choice == 2 && player.cash >= GameConstants.bailAmount) {
          _logger.info('${player.name} (AI-random) 随机选择支付保释金');
          GameLogger.info('${player.name} (AI-random) 随机选择支付保释金',
            playerId: player.id,
            playerName: player.name,
            playerColor: player.tokenColor.toARGB32(),
          );
          handleJailDecision(2);
        } else {
          _logger.info('${player.name} (AI-random) 随机选择掷骰子');
          GameLogger.info('${player.name} (AI-random) 随机选择掷骰子',
            playerId: player.id,
            playerName: player.name,
            playerColor: player.tokenColor.toARGB32(),
          );
          handleJailDecision(0);
        }
        break;
    }
  }

  /// 建造房屋
  void buildHouse(int propertyIndex) {
    final property = state.properties.firstWhere((p) => p.cellIndex == propertyIndex);
    final cell = boardCells[propertyIndex];
    final player = state.currentPlayer;
    
    if (property.ownerId != player.id) {
      _logger.warning('${player.name} 试图在非自己的地产上建造房屋');
      GameLogger.warning('${player.name} 试图在非自己的地产上建造房屋',
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
      );
      return;
    }
    
    if (property.houses >= 5) {
      _logger.warning('${player.name} 试图在已有酒店的地产上建造房屋');
      GameLogger.warning('${player.name} 试图在已有酒店的地产上建造房屋',
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
      );
      return; // 已经有酒店
    }

    final price = RentCalculator.getHousePrice(propertyIndex);
    if (player.cash < price) {
      _logger.warning('${player.name} 现金不足，无法建造房屋 (需要 $price，只有 ${player.cash})');
      GameLogger.cashInsufficient(
        reason: '建造房屋',
        needed: price,
        available: player.cash,
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
        turnNumber: state.turnNumber,
      );
      return;
    }

    // 检查是否可以建造
    if (!RentCalculator.canBuildHouse(
      player.id,
      boardCells[propertyIndex].color!,
      state.properties,
    )) {
      _logger.warning('${player.name} 无法在 ${cell.name} 建造房屋，不符合建造条件');
      GameLogger.warning('${player.name} 无法在 ${cell.name} 建造房屋，不符合建造条件',
        playerId: player.id,
        playerName: player.name,
        playerColor: player.tokenColor.toARGB32(),
      );
      return;
    }

    _logger.info('${player.name} 在 ${cell.name} 建造房屋，花费 $price');
    GameLogger.buildHouse(
      propertyName: cell.name,
      housesBefore: state.properties.firstWhere((p) => p.cellIndex == propertyIndex).houses,
      housesAfter: state.properties.firstWhere((p) => p.cellIndex == propertyIndex).houses + 1,
      cost: price,
      playerId: player.id,
      playerName: player.name,
      playerColor: player.tokenColor.toARGB32(),
      turnNumber: state.turnNumber,
    );

    _updatePlayerCash(player.id, -price);

    final newProperties = state.properties.map((p) {
      if (p.cellIndex == propertyIndex) {
        final newHouses = p.houses + 1;
        if (newHouses >= 5) {
          _logger.info('${player.name} 在 ${cell.name} 建造了酒店');
          GameLogger.buildHouse(
            propertyName: cell.name,
            housesBefore: newHouses - 1,
            housesAfter: newHouses,
            cost: price,
            playerId: player.id,
            playerName: player.name,
            playerColor: player.tokenColor.toARGB32(),
            turnNumber: state.turnNumber,
          );
        } else {
          _logger.info('${player.name} 在 ${cell.name} 建造了第 $newHouses 栋房屋');
          GameLogger.buildHouse(
            propertyName: cell.name,
            housesBefore: newHouses - 1,
            housesAfter: newHouses,
            cost: price,
            playerId: player.id,
            playerName: player.name,
            playerColor: player.tokenColor.toARGB32(),
            turnNumber: state.turnNumber,
          );
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
    if (property.ownerId == null || property.ownerId != state.currentPlayer.id) return;
    if (property.isMortgaged) return;
    if (property.houses > 0) return; // 有房屋不能抵押

    final value = RentCalculator.getMortgageValue(propertyIndex);
    if (value <= 0) {
      _logger.warning('无法抵押 ${boardCells[propertyIndex].name}，抵押价值无效');
      GameLogger.warning('无法抵押 ${boardCells[propertyIndex].name}，抵押价值无效',
        playerId: state.currentPlayer.id,
        playerName: state.currentPlayer.name,
        playerColor: state.currentPlayer.tokenColor.toARGB32(),
      );
      return;
    }

    final cell = boardCells[propertyIndex];
    _updatePlayerCash(state.currentPlayer.id, value);
    _logger.info('${state.currentPlayer.name} 抵押 ${cell.name} 获得 \$$value');
    GameLogger.mortgage(
      propertyName: cell.name,
      amount: value,
      playerId: state.currentPlayer.id,
      playerName: state.currentPlayer.name,
      playerColor: state.currentPlayer.tokenColor.toARGB32(),
      turnNumber: state.turnNumber,
    );

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
    if (property.ownerId == null || property.ownerId != state.currentPlayer.id) return;
    if (!property.isMortgaged) return;

    final value = RentCalculator.getRedeemValue(propertyIndex);
    if (value <= 0 || state.currentPlayer.cash < value) return;

    final cell = boardCells[propertyIndex];
    _updatePlayerCash(state.currentPlayer.id, -value);
    _logger.info('${state.currentPlayer.name} 赎回 ${cell.name} 支付 \$$value');
    GameLogger.redeem(
      propertyName: cell.name,
      amount: value,
      playerId: state.currentPlayer.id,
      playerName: state.currentPlayer.name,
      playerColor: state.currentPlayer.tokenColor.toARGB32(),
      turnNumber: state.turnNumber,
    );

    final newProperties = state.properties.map((p) {
      if (p.cellIndex == propertyIndex) {
        return p.copyWith(isMortgaged: false);
      }
      return p;
    }).toList();

    state = state.copyWith(properties: newProperties);
  }

  /// 切换自动游戏模式
  void toggleAutoPlay(String playerId) {
    final newPlayers = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(isAutoPlay: !p.isAutoPlay);
      }
      return p;
    }).toList();

    state = state.copyWith(players: newPlayers);
    
    final player = state.players.firstWhere((p) => p.id == playerId);
    _logger.info('${player.name} ${player.isAutoPlay ? "开启" : "关闭"}自动游戏模式');
    GameLogger.info('${player.name} ${player.isAutoPlay ? "开启" : "关闭"}自动游戏模式',
      playerId: player.id,
      playerName: player.name,
      playerColor: player.tokenColor.toARGB32(),
    );
  }

  /// 结束回合
  void _endTurn() {
    final currentPlayer = state.currentPlayer;
    
    // 检查是否应该再掷骰子（对子且连续次数<3）
    if (state.isDoubles && state.consecutiveDoubles < GameConstants.maxConsecutiveDoubles) {
      _logger.info('${currentPlayer.name} 掷出对子，可以再掷一次！(连续${state.consecutiveDoubles}次)');
      GameLogger.info('${currentPlayer.name} 掷出对子，可以再掷一次！(连续${state.consecutiveDoubles}次)',
        playerId: currentPlayer.id,
        playerName: currentPlayer.name,
        playerColor: currentPlayer.tokenColor.toARGB32(),
      );
      
      // 不结束回合，回到掷骰子阶段
      state = state.copyWith(
        phase: GamePhase.playerTurnStart,
        // 保持 isDoubles 和 consecutiveDoubles 不变
      );
      return; // 不切换玩家
    }
    
    _logger.info('${currentPlayer.name} 回合结束');
    GameLogger.turnEnd(
      playerId: currentPlayer.id,
      playerName: currentPlayer.name,
      playerColor: currentPlayer.tokenColor.toARGB32(),
      turnNumber: state.turnNumber,
    );
    
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
      GameLogger.info('${state.players[nextIndex].name} 已破产，跳过',
        playerId: state.players[nextIndex].id,
        playerName: state.players[nextIndex].name,
        playerColor: state.players[nextIndex].tokenColor.toARGB32(),
      );
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
    GameLogger.turnStart(
      playerId: nextPlayer.id,
      playerName: nextPlayer.name,
      playerColor: nextPlayer.tokenColor.toARGB32(),
      turnNumber: newTurnNumber,
    );
    
    if (isNewTurn) {
      _logger.info('=== 第 $newTurnNumber 回合开始 ===');
      GameLogger.turnStart(
        playerId: nextPlayer.id,
        playerName: nextPlayer.name,
        playerColor: nextPlayer.tokenColor.toARGB32(),
        turnNumber: newTurnNumber,
      );
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
      GameLogger.info('游戏已自动保存',
        playerId: state.currentPlayer.id,
        playerName: state.currentPlayer.name,
        playerColor: state.currentPlayer.tokenColor.toARGB32(),
      );
    } catch (e) {
      _logger.error('自动保存失败: $e');
      GameLogger.critical('自动保存失败: $e',
        playerId: state.currentPlayer.id,
        playerName: state.currentPlayer.name,
        playerColor: state.currentPlayer.tokenColor.toARGB32(),
      );
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
    final player = state.players.firstWhere((p) => p.id == playerId);
    final newPlayers = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(status: PlayerStatus.bankrupt, cash: 0);
      }
      return p;
    }).toList();

    if (player.isHuman) {
      SoundService.playLose();
    }

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
    // 当玩家是真人且未开启自动操作时，不执行AI操作
    if (state.currentPlayer.isHuman && !state.currentPlayer.isAutoPlay) return;

    final player = state.currentPlayer;
    final settings = state.settings;
    final personality = settings.aiPersonas.isNotEmpty 
        ? settings.aiPersonas[state.currentPlayerIndex % settings.aiPersonas.length]
        : AIPersonality.conservative;

    // 检查是否在监狱需要做决策
    if (state.phase == GamePhase.jailDecision) {
      await Future.delayed(_adjustedDelay(GameConstants.playerMoveDelay));
      _handleAIActionInJail(personality);
      return;
    }

    // 检查是否需要掷骰子
    if (state.phase == GamePhase.playerTurnStart) {
      // 等待一小段时间模拟思考
      await Future.delayed(_adjustedDelay(settings.difficulty == AIDifficulty.easy ? GameConstants.easyAIDelay : GameConstants.hardAIDelay));
      
      // AI自动掷骰子
      rollDice();
      return; // 掷骰子后会触发后续流程
    }

    // 等待一小段时间模拟思考
    await Future.delayed(_adjustedDelay(settings.difficulty == AIDifficulty.easy ? GameConstants.aiBuildDelay : GameConstants.aiBuyDelay));

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
        await Future.delayed(_adjustedDelay(GameConstants.playerMoveDelay));
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
      await Future.delayed(_adjustedDelay(GameConstants.aiBuyDelay));
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
      case CardEffectType.birthday:
        return '生日礼物，从每个玩家获得 \$${effect.value}';
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
      isAutoPlay: false,
    );
  }
  return state.currentPlayer;
});

/// 是否为玩家回合
final isPlayerTurnProvider = Provider<bool>((ref) {
  final state = ref.watch(gameProvider);
  if (state.players.isEmpty) return false;
  // 当玩家是真人且未开启自动操作时，显示玩家操作界面
  return state.currentPlayer.isHuman && !state.currentPlayer.isAutoPlay && state.phase != GamePhase.gameOver;
});
