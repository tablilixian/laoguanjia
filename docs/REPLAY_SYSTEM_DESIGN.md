# 地产大亨 - 游戏回放系统设计文档

> **状态：** 📋 设计中
> **创建日期：** 2026-04-15
> **版本：** v1.0

---

## 一、设计目标

| 目标 | 描述 | 优先级 |
|------|------|--------|
| **游戏回放** | 完整重现游戏过程，支持播放/暂停/定位 | 🔴 高 |
| **存档增强** | 将现有存档升级为支持回放的格式 | 🔴 高 |
| **操作录制** | 记录所有玩家操作，用于分析验证 | 🟡 中 |
| **统计分析** | 基于记录生成游戏统计报告 | 🟢 低 |

---

## 二、设计原则

### 2.1 核心思想：命令模式 + 状态快照

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           回放系统核心架构                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐     ┌──────────────────┐     ┌─────────────────────┐     │
│  │  初始状态     │────▶│   命令序列        │────▶│   最终状态           │     │
│  │  (Snapshot)  │     │  (GameAction[])  │     │  (GameState)        │     │
│  └─────────────┘     └──────────────────┘     └─────────────────────┘     │
│         │                      │                        ▲                 │
│         │                      │                        │                 │
│         ▼                      ▼                        │                 │
│  ┌─────────────┐     ┌──────────────────┐     ┌─────────────────────┐     │
│  │  加载存档    │     │   重放命令        │     │   正常游戏流程        │     │
│  │  Restore    │     │   Replay         │     │   Forward           │     │
│  └─────────────┘     └──────────────────┘     └─────────────────────┘     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 回放与正常游戏的区别

| 方面 | 正常游戏 | 游戏回放 |
|------|----------|----------|
| 骰子结果 | 实时随机生成 | 从记录读取 |
| AI决策 | 重新计算 | 从记录读取 |
| 卡牌顺序 | 预先洗牌 | 从记录读取 |
| 操作来源 | 玩家/AI触发 | 命令序列驱动 |

---

## 三、数据结构设计

### 3.1 整体结构

```dart
/// 游戏记录完整结构
class GameReplayRecord {
  final String gameId;                    // 唯一标识
  final int version = 1;                 // 格式版本
  final GameSetup setup;                 // 游戏初始配置
  final GameReplaySnapshot initialSnapshot; // 初始状态快照
  final List<GameAction> actions;        // 所有操作记录
  final GameReplaySnapshot? finalSnapshot;  // 最终状态快照（可选）
  final ReplayMetadata metadata;          // 元数据
}

/// 游戏初始配置
class GameSetup {
  final List<PlayerConfig> playerConfigs;
  final GameSettings settings;
  // ... 现有 GameSetup 字段
}

/// 初始状态快照
class GameReplaySnapshot {
  final Map<String, PlayerSnapshot> players;   // 玩家状态快照
  final List<PropertySnapshot> properties;     // 地产状态快照
  final List<CardSnapshot> chanceCards;        // 机会卡顺序
  final List<CardSnapshot> communityChestCards; // 公益卡顺序
  final int chanceCardIndex;                  // 当前抽到的卡牌位置
  final int communityChestCardIndex;
  final int randomSeed;                        // 随机种子
}

/// 玩家状态快照
class PlayerSnapshot {
  final String id;
  final String name;
  final int tokenColor;           // ARGB int
  final int position;
  final int cash;
  final int status;               // PlayerStatus.index
  final int jailTurns;
  final bool hasGetOutOfJailFree;
  final List<int> ownedProperties;
  final bool isHuman;
}

/// 地产状态快照
class PropertySnapshot {
  final int cellIndex;
  final String? ownerId;
  final int houses;               // 0-4=房屋, 5=酒店
  final bool isMortgaged;
}

/// 卡牌快照
class CardSnapshot {
  final int index;                // 在牌堆中的位置
  final String title;
  final CardEffectType effectType;
  final Map<String, dynamic> effectParams;
}

/// 元数据
class ReplayMetadata {
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? totalDuration;
  final int totalTurns;
  final String? winnerId;
  final String? winnerName;
}
```

### 3.2 操作记录 (GameAction)

```dart
/// 游戏操作基类
abstract class GameAction {
  final String id;                 // UUID
  final int turnNumber;            // 回合号
  final String playerId;           // 玩家ID
  final DateTime timestamp;        // 时间戳
  final GamePhase phaseBefore;     // 执行前的游戏阶段
  final GamePhase phaseAfter;      // 执行后的游戏阶段

  /// 将操作应用到游戏状态（用于重放）
  void applyTo(GameNotifier notifier);

  /// 序列化
  Map<String, dynamic> toJson();

  /// 反序列化
  static GameAction fromJson(Map<String, dynamic> json);
}
```

#### 3.2.1 掷骰子操作

```dart
class RollDiceAction extends GameAction {
  final int dice1;
  final int dice2;
  final bool isDoubles;
  final int consecutiveDoubles;

  void applyTo(GameNotifier notifier) {
    // 直接修改 state 中的骰子相关字段
    // 然后触发后续移动流程
    notifier.replayRollDice(dice1, dice2, isDoubles, consecutiveDoubles);
  }
}
```

#### 3.2.2 移动操作

```dart
class MoveAction extends GameAction {
  final int fromPosition;
  final int toPosition;
  final int steps;
  final bool passedGo;             // 是否经过起点
  final int? passGoReward;         // 经过起点获得的金额

  void applyTo(GameNotifier notifier) {
    notifier.replayMove(fromPosition, toPosition, steps, passedGo, passGoReward);
  }
}
```

#### 3.2.3 购买地产操作

```dart
class BuyPropertyAction extends GameAction {
  final int propertyIndex;
  final int price;
  final bool wasPurchased;         // 是否成功购买（false=放弃/流拍）

  void applyTo(GameNotifier notifier) {
    if (wasPurchased) {
      notifier.replayBuyProperty(propertyIndex);
    } else {
      notifier.replayRejectPurchase(propertyIndex);
    }
  }
}
```

#### 3.2.4 支付租金操作

```dart
class PayRentAction extends GameAction {
  final int propertyIndex;
  final String ownerId;
  final int amount;
  final bool wasBankrupt;          // 是否因此破产

  void applyTo(GameNotifier notifier) {
    notifier.replayPayRent(propertyIndex, ownerId, amount, wasBankrupt);
  }
}
```

#### 3.2.5 建造房屋操作

```dart
class BuildHouseAction extends GameAction {
  final int propertyIndex;
  final int housesBefore;
  final int housesAfter;
  final int cost;

  void applyTo(GameNotifier notifier) {
    notifier.replayBuildHouse(propertyIndex, housesAfter);
  }
}
```

#### 3.2.6 抵押/赎回操作

```dart
class MortgageAction extends GameAction {
  final int propertyIndex;
  final int amount;                // 抵押获得/赎回支付的金额
  final bool isMortgage;           // true=抵押, false=赎回

  void applyTo(GameNotifier notifier) {
    if (isMortgage) {
      notifier.replayMortgage(propertyIndex);
    } else {
      notifier.replayRedeem(propertyIndex);
    }
  }
}
```

#### 3.2.7 抽卡操作

```dart
class DrawCardAction extends GameAction {
  final bool isChance;             // true=机会卡, false=公益卡
  final String cardTitle;
  final CardEffectType effectType;
  final Map<String, dynamic> effectResult; // 卡牌效果执行结果
  final int? positionChange;        // 位置变化
  final int? cashChange;           // 现金变化

  void applyTo(GameNotifier notifier) {
    notifier.replayDrawCard(isChance, effectType, effectResult);
  }
}
```

#### 3.2.8 监狱相关操作

```dart
class JailDecisionAction extends GameAction {
  final int decision;              // 0=掷骰子, 1=用卡, 2=付保释金
  final bool success;              // 是否成功离开监狱

  void applyTo(GameNotifier notifier) {
    notifier.replayJailDecision(decision, success);
  }
}

class GoToJailAction extends GameAction {
  final String reason;             // 进监狱原因（踩到格子/连续对子）

  void applyTo(GameNotifier notifier) {
    notifier.replayGoToJail();
  }
}
```

#### 3.2.9 税务操作

```dart
class TaxAction extends GameAction {
  final bool isIncomeTax;          // true=所得税, false=奢侈品税
  final int amount;
  final bool wasBankrupt;

  void applyTo(GameNotifier notifier) {
    notifier.replayPayTax(isIncomeTax, amount, wasBankrupt);
  }
}
```

#### 3.2.10 回合相关操作

```dart
class TurnStartAction extends GameAction {
  final String playerName;
  final int turnNumber;

  void applyTo(GameNotifier notifier) {
    notifier.replayTurnStart(playerName, turnNumber);
  }
}

class TurnEndAction extends GameAction {
  final bool isLastInRound;        // 是否是本轮最后一人

  void applyTo(GameNotifier notifier) {
    notifier.replayTurnEnd(isLastInRound);
  }
}
```

#### 3.2.11 破产/游戏结束操作

```dart
class BankruptcyAction extends GameAction {
  final String playerId;
  final String? creditorId;        // 资产转给谁
  final int debtAmount;
  final List<int> transferredProperties; // 转移的地产

  void applyTo(GameNotifier notifier) {
    notifier.replayBankruptcy(playerId, creditorId);
  }
}

class GameOverAction extends GameAction {
  final String winnerId;
  final String winnerName;
  final List<PlayerFinalResult> results;

  void applyTo(GameNotifier notifier) {
    notifier.replayGameOver(winnerId);
  }
}
```

---

## 四、序列化设计

### 4.1 整体JSON结构

```json
{
  "gameId": "550e8400-e29b-41d4-a716-446655440000",
  "version": 1,
  "setup": {
    "playerConfigs": [...],
    "settings": {...}
  },
  "initialSnapshot": {
    "players": {
      "player_1": {
        "id": "player_1",
        "name": "玩家1",
        "tokenColor": 4293467748,
        "position": 0,
        "cash": 1500,
        "status": 0,
        "jailTurns": 0,
        "hasGetOutOfJailFree": false,
        "ownedProperties": [],
        "isHuman": true
      }
    },
    "properties": [...],
    "chanceCards": [...],
    "communityChestCards": [...],
    "chanceCardIndex": 0,
    "communityChestCardIndex": 0,
    "randomSeed": 1234567890
  },
  "actions": [
    {
      "type": "turnStart",
      "id": "action_001",
      "turnNumber": 1,
      "playerId": "player_1",
      "timestamp": "2026-04-15T10:00:00.000Z",
      "phaseBefore": 1,
      "phaseAfter": 1,
      "data": {
        "playerName": "玩家1",
        "turnNumber": 1
      }
    },
    {
      "type": "rollDice",
      "id": "action_002",
      "turnNumber": 1,
      "playerId": "player_1",
      "timestamp": "2026-04-15T10:00:01.000Z",
      "phaseBefore": 1,
      "phaseAfter": 2,
      "data": {
        "dice1": 4,
        "dice2": 3,
        "isDoubles": false,
        "consecutiveDoubles": 0
      }
    },
    {
      "type": "move",
      "id": "action_003",
      "turnNumber": 1,
      "playerId": "player_1",
      "timestamp": "2026-04-15T10:00:02.000Z",
      "phaseBefore": 2,
      "phaseAfter": 3,
      "data": {
        "fromPosition": 0,
        "toPosition": 7,
        "steps": 7,
        "passedGo": false,
        "passGoReward": null
      }
    }
  ],
  "finalSnapshot": {...},
  "metadata": {
    "startTime": "2026-04-15T10:00:00.000Z",
    "endTime": "2026-04-15T10:45:00.000Z",
    "totalDuration": 2700000,
    "totalTurns": 25,
    "winnerId": "player_1",
    "winnerName": "玩家1"
  }
}
```

### 4.2 操作类型枚举

```dart
/// JSON中使用的操作类型字符串
enum GameActionType {
  // 回合流程
  turnStart('turnStart'),
  turnEnd('turnEnd'),

  // 骰子与移动
  rollDice('rollDice'),
  move('move'),
  passGo('passGo'),

  // 地产操作
  buyProperty('buyProperty'),
  rejectPurchase('rejectPurchase'),
  payRent('payRent'),
  buildHouse('buildHouse'),
  mortgage('mortgage'),
  redeem('redeem'),

  // 卡片
  drawCard('drawCard'),

  // 监狱
  jailDecision('jailDecision'),
  goToJail('goToJail'),

  // 税务
  payTax('payTax'),

  // 玩家状态
  bankruptcy('bankruptcy'),
  gameOver('gameOver'),

  // AI决策
  aiDecision('aiDecision'),

  // 系统
  gameStart('gameStart');
}
```

---

## 五、保存与加载机制

### 5.1 存储方案

| 存储位置 | 用途 | 容量 | 说明 |
|----------|------|------|------|
| `SharedPreferences` | 游戏存档 | ~100KB | 现有存档机制 |
| `ReplayService.listReplays()` | 回放列表 | 元数据 | 仅保存基本信息 |
| `ReplayService.getReplay(id)` | 回放详情 | 按需加载 | 按ID访问 |

### 5.2 文件组织

```
SharedPreferences
├── monopoly_game_save           # 当前游戏存档
├── monopoly_game_replays_index  # 回放索引列表
├── monopoly_game_replay_{id}   # 单个回放数据
└── monopoly_game_settings     # 游戏设置
```

### 5.3 回放服务接口

```dart
/// 回放服务
class ReplayService {
  /// 保存回放（游戏结束时自动调用）
  static Future<bool> saveReplay(GameReplayRecord record);

  /// 加载回放列表（元数据，不含完整actions）
  static Future<List<ReplayMetadata>> listReplays();

  /// 加载完整回放
  static Future<GameReplayRecord?> getReplay(String gameId);

  /// 删除回放
  static Future<bool> deleteReplay(String gameId);

  /// 导出回放为JSON文件
  static Future<String?> exportReplay(String gameId);

  /// 从JSON导入回放
  static Future<bool> importReplay(String jsonString);
}
```

### 5.4 自动保存策略

```dart
/// 游戏结束时自动保存回放
void _finishGame() {
  // ... 现有逻辑

  // 创建回放记录
  final replay = GameReplayRecord(
    gameId: state.setup?['gameId'] ?? Uuid().v4(),
    setup: getGameSetup(),
    initialSnapshot: _createSnapshot(),
    actions: _actionRecorder.actions,
    finalSnapshot: _createSnapshot(),
    metadata: ReplayMetadata(
      startTime: _gameStartTime,
      endTime: DateTime.now(),
      totalDuration: DateTime.now().difference(_gameStartTime),
      totalTurns: state.turnNumber,
      winnerId: winner?.id,
      winnerName: winner?.name,
    ),
  );

  // 保存回放
  ReplayService.saveReplay(replay);
}
```

---

## 六、回放引擎设计

### 6.1 回放状态机

```dart
/// 回放状态
enum ReplayPhase {
  idle,        // 空闲
  loading,     // 加载中
  ready,       // 就绪
  playing,     // 播放中
  paused,      // 已暂停
  seeking,     // 定位中
  finished,    // 回放完成
  error,       // 错误
}

/// 回放速度
enum ReplaySpeed {
  x0.5(0.5),
  x1(1.0),
  x2(2.0),
  x4(4.0);

  final double value;
}
```

### 6.2 回放控制器

```dart
/// 回放控制器
class ReplayController extends ChangeNotifier {
  ReplayPhase _phase = ReplayPhase.idle;
  ReplaySpeed _speed = ReplaySpeed.x1;
  int _currentActionIndex = 0;
  int _currentTurn = 1;
  double _progress = 0.0;  // 0.0 - 1.0

  GameReplayRecord? _record;
  GameNotifier? _gameNotifier;

  /// 加载回放
  Future<void> loadReplay(String gameId);

  /// 播放
  void play();

  /// 暂停
  void pause();

  /// 停止
  void stop();

  /// 定位到指定回合
  void seekToTurn(int turnNumber);

  /// 定位到指定进度
  void seekToProgress(double progress);

  /// 步进到下一个操作
  Future<void> stepForward();

  /// 步退到上一个操作
  Future<void> stepBackward();

  /// 设置播放速度
  void setSpeed(ReplaySpeed speed);

  /// 重置到初始状态
  Future<void> reset();
}
```

### 6.3 重放方法扩展 (GameNotifier)

```dart
extension GameNotifierReplay on GameNotifier {
  /// 重放掷骰子（不重新随机）
  void replayRollDice(int dice1, int dice2, bool isDoubles, int consecutiveDoubles) {
    state = state.copyWith(
      phase: GamePhase.diceRolling,
      lastDice1: dice1,
      lastDice2: dice2,
      isDoubles: isDoubles,
      consecutiveDoubles: consecutiveDoubles,
    );
    // 触发后续移动流程
    _processMovement(dice1 + dice2, isDoubles);
  }

  /// 重放移动
  void replayMove(int from, int to, int steps, bool passedGo, int? reward) {
    // 更新玩家位置
    final newPlayers = state.players.map((p) {
      if (p.id == state.currentPlayer.id) {
        return p.copyWith(position: to);
      }
      return p;
    }).toList();

    state = state.copyWith(
      phase: GamePhase.playerMoving,
      players: newPlayers,
    );

    // 处理经过起点奖励
    if (passedGo && reward != null) {
      _updatePlayerCash(state.currentPlayer.id, reward);
    }
  }

  /// 重放购买地产
  void replayBuyProperty(int propertyIndex) {
    // 直接调用现有购买逻辑
    buyProperty(propertyIndex);
  }

  /// ... 其他重放方法
}
```

---

## 七、UI设计

### 7.1 回放入口

```
游戏结束页面
├── 显示结算面板
│   ├── 🏆 获胜者
│   ├── 📊 本局数据
│   └── 💰 最终资产排名
├── [再来一局] 按钮
├── [回放本局] 按钮    ← 新增
└── [返回主页] 按钮
```

### 7.2 回放列表页面

```
┌─────────────────────────────────────────────────────────────┐
│  ◀ 返回                    回放列表                    🔍搜索 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ 🏆 玩家1 获胜                                          │ │
│  │ 📅 2026-04-15 10:45                                    │ │
│  │ 👥 4人局  |  🎲 25回合  |  ⏱️ 45分钟                    │ │
│  │                                                         │ │
│  │                               [▶ 回放]  [🗑 删除]        │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ 🏆 玩家2 获胜                                          │ │
│  │ 📅 2026-04-14 15:30                                    │ │
│  │ 👥 3人局  |  🎲 18回合  |  ⏱️ 32分钟                    │ │
│  │                                                         │ │
│  │                               [▶ 回放]  [🗑 删除]        │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 7.3 回放播放页面

```
┌─────────────────────────────────────────────────────────────┐
│  ◀ 返回              回放: 玩家1 vs 玩家2              ⚙️设置 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │                    游戏棋盘 (只读)                     │ │
│  │                                                       │ │
│  │     [地产格子...]                                      │ │
│  │                                                       │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  🎲 回合 5: 红队 (玩家1) 掷出 4+3=7                    │ │
│  │     从(民生路)移动7步到(股市大厦)                       │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [⏮] [⏯] [⏭]    ━━━━━━━━●━━━━━━━━━━    5/25  [x1.0 ▼]   │
│                                                             │
│  回合: [1 ▼]  玩家: [全部 ▼]  类型: [全部 ▼]                │
└─────────────────────────────────────────────────────────────┘
```

### 7.4 回放控制栏

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ◀◀  │  ▶/⏸  │  ▶▶  │   ━━━━━━●━━━━━━   │  12/25  │  x1.0  │
│  后退 │ 播放/  │ 前进 │      进度条       │ 回合进度 │  速度  │
│ 一步  │ 暂停   │ 一步 │                  │          │       │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  筛选: [全部] [骰子] [购买] [建造] [租金] [卡牌] [其他]       │
└─────────────────────────────────────────────────────────────┘
```

### 7.5 操作详情面板

```
┌─────────────────────────────────────────────────────────────┐
│  📋 操作记录                                    [收起▲]     │
├─────────────────────────────────────────────────────────────┤
│  ▶ 回合 5                                                    │
│    ├─ 🎲 掷骰子: 4+3=7                                       │
│    ├─ 🚶 移动: 民生路 → 股市大厦                              │
│    └─ 💰 购买: 股市大厦 ($500)                               │
│  ▶ 回合 6                                                    │
│    ├─ 🎲 掷骰子: 2+2=4 (对子!)                              │
│    ├─ 🚶 移动: 股市大厦 → 购物中心                            │
│    └─ 💸 支付租金: $120 → 玩家2                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 八、对现有代码的调整

### 8.1 新增文件

| 文件路径 | 描述 |
|----------|------|
| `models/game_replay.dart` | 回放相关数据模型 |
| `services/replay_service.dart` | 回放服务（保存/加载） |
| `providers/replay_controller.dart` | 回放控制器Provider |
| `pages/replay_list_page.dart` | 回放列表页面 |
| `pages/replay_player_page.dart` | 回放播放页面 |
| `widgets/replay_controls.dart` | 回放控制组件 |
| `widgets/replay_action_list.dart` | 回放操作列表组件 |

### 8.2 修改文件

| 文件 | 修改内容 |
|------|----------|
| `providers/game_provider.dart` | 添加 `replayXxx()` 方法，添加 `_actionRecorder` |
| `services/save_service.dart` | 整合回放服务，添加回放索引管理 |
| `models/models.dart` | 导出 game_replay.dart |
| `pages/game_page.dart` | 添加回放按钮入口 |
| `pages/game_over_page.dart` | 游戏结束时自动保存回放 |

### 8.3 GameNotifier 需添加的方法

```dart
// === 回放支持方法 ===

/// 记录操作（游戏过程中调用）
void recordAction(GameAction action);

/// 重放相关方法
void replayRollDice(int dice1, int dice2, bool isDoubles, int consecutiveDoubles);
void replayMove(int from, int to, int steps, bool passedGo, int? reward);
void replayBuyProperty(int propertyIndex);
void replayRejectPurchase(int propertyIndex);
void replayPayRent(int propertyIndex, String ownerId, int amount, bool wasBankrupt);
void replayBuildHouse(int propertyIndex, int housesAfter);
void replayMortgage(int propertyIndex);
void replayRedeem(int propertyIndex);
void replayDrawCard(bool isChance, CardEffectType effectType, Map<String, dynamic> result);
void replayJailDecision(int decision, bool success);
void replayGoToJail();
void replayPayTax(bool isIncomeTax, int amount, bool wasBankrupt);
void replayBankruptcy(String playerId, String? creditorId);
void replayGameOver(String winnerId);
void replayTurnEnd(bool isLastInRound);
```

### 8.4 随机种子管理

```dart
/// 在 GameNotifier 中添加
int? _randomSeed;

/// 初始化游戏时生成种子
void initGameWithSetup(GameSetup setup) {
  // ... 现有逻辑

  // 生成或使用指定的随机种子
  _randomSeed = DateTime.now().millisecondsSinceEpoch;
}

/// 获取随机种子（用于保存）
int get randomSeed => _randomSeed;

/// 设置随机种子（用于重放）
void setRandomSeed(int seed) {
  _randomSeed = seed;
  // 初始化随机数生成器
  _random = Random(seed);
}
```

---

## 九、实现计划

### Phase 1: 基础架构 (核心)

| 任务 | 工作内容 | 优先级 |
|------|----------|--------|
| T1.1 | 创建 `models/game_replay.dart` 数据模型 | 🔴 高 |
| T1.2 | 创建 `ReplayService` 服务类 | 🔴 高 |
| T1.3 | 在 `GameNotifier` 添加操作录制逻辑 | 🔴 高 |
| T1.4 | 在 `GameNotifier` 添加重放方法 | 🔴 高 |
| T1.5 | 游戏结束时自动保存回放 | 🔴 高 |

### Phase 2: 回放UI (交互)

| 任务 | 工作内容 | 优先级 |
|------|----------|--------|
| T2.1 | 创建 `ReplayController` Provider | 🟡 中 |
| T2.2 | 创建 `ReplayControls` 组件 | 🟡 中 |
| T2.3 | 创建 `ReplayPlayerPage` 页面 | 🟡 中 |
| T2.4 | 创建 `ReplayListPage` 页面 | 🟡 中 |
| T2.5 | 添加回放入口（游戏结束页面） | 🟡 中 |

### Phase 3: 增强功能 (可选)

| 任务 | 工作内容 | 优先级 |
|------|----------|--------|
| T3.1 | 回放导出/导入 | 🟢 低 |
| T3.2 | 回放筛选（按回合/玩家/操作类型） | 🟢 低 |
| T3.3 | 关键帧快速定位 | 🟢 低 |
| T3.4 | 游戏统计分析报告 | 🟢 低 |

---

## 十、测试验证

### 10.1 功能测试

```dart
test('回放完整性验证', () async {
  // 1. 开始新游戏
  final game = GameNotifier();
  game.initGameWithSetup(setup);

  // 2. 模拟几个回合
  for (int i = 0; i < 5; i++) {
    game.rollDice();
    await Future.delayed(Duration(milliseconds: 500));
    game.endTurn();
  }

  // 3. 获取记录
  final record = game.getReplayRecord();

  // 4. 创建新游戏并重放
  final replayGame = GameNotifier();
  await replayGame.replayFromRecord(record);

  // 5. 验证状态一致
  expect(replayGame.state.turnNumber, equals(5));
  expect(replayGame.state.currentPlayerIndex, equals(0));
});
```

### 10.2 边界情况

| 场景 | 预期行为 |
|------|----------|
| 回放文件损坏 | 显示错误提示，不崩溃 |
| 回放过程中退出 | 下次可继续从断点播放 |
| 超长游戏（100+回合） | 支持分页加载操作记录 |

---

## 十一、FAQ

**Q: 为什么需要记录初始快照？只用操作序列不行吗？**

A: 因为有些状态变化没有直接操作（如：经过起点自动获得$200），需要快照来确保所有状态的准确性。另外，快照也简化了"定位到指定回合"的实现。

**Q: 为什么不直接保存完整的 GameState 序列？**

A: 完整状态序列会非常大（一局100回合可能几十MB）。使用初始快照+操作序列的方式，存档大小通常在10-50KB左右。

**Q: AI决策需要记录吗？**

A: 需要。因为AI决策可能依赖随机性，重新计算可能产生不同结果。记录后可以确保回放与原始游戏完全一致。

---

## 附录

### A. 文件结构

```
lib/features/monopoly_game/
├── models/
│   ├── models.dart                    # 现有模型
│   └── game_replay.dart               # 新增：回放模型
├── services/
│   ├── save_service.dart              # 修改：整合回放服务
│   └── replay_service.dart            # 新增：回放服务
├── providers/
│   ├── game_provider.dart             # 修改：添加录制和重放
│   └── replay_controller.dart          # 新增：回放控制器
├── pages/
│   ├── replay_list_page.dart          # 新增：回放列表
│   └── replay_player_page.dart         # 新增：回放播放
└── widgets/
    ├── replay_controls.dart            # 新增：播放控制
    └── replay_action_list.dart         # 新增：操作列表
```

### B. 依赖关系

```
GameReplayRecord
    ├── GameSetup
    ├── GameReplaySnapshot
    │     ├── Map<PlayerSnapshot>
    │     ├── List<PropertySnapshot>
    │     └── List<CardSnapshot>
    ├── List<GameAction>
    │     ├── RollDiceAction
    │     ├── MoveAction
    │     ├── BuyPropertyAction
    │     └── ...
    └── ReplayMetadata
```
