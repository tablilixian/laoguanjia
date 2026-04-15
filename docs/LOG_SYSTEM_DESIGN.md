# 地产大亨 - 游戏日志系统设计文档

> **状态：** 📋 设计中
> **创建日期：** 2026-04-15
> **版本：** v1.0

---

## 一、需求分析

### 1.1 现状问题

当前游戏中存在**三套并存的日志/记录系统**，数据分散，维护成本高：

| 系统 | 用途 | 持久化 | 显示方式 | 局限性 |
|------|------|--------|----------|--------|
| **AppLogger** | 系统调试日志 | ✅ 最多1000条 | 仅代码层面 | 无分级显示、不可配置 |
| **ToastManager** | 瞬时UI通知 | ❌ 无 | 屏幕顶部弹出 | 不持久、无法回放 |
| **OperationLogManager** | 游戏操作记录 | ✅ 最多10条 | 侧边栏面板 | 条目少、格式固定 |

### 1.2 用户需求

1. **统一管理** - 把散落的各种日志，进行统一管理
2. **分级显示** - 支持不同级别的日志显示
3. **记录操作** - 把玩家的各种操作进行记录
4. **序列化** - 方便进行回放和效果验证

---

## 二、设计目标与原则

### 2.1 核心原则：单一入口

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           单一入口原则                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  【游戏代码中只调用 GameLogger】                                              │
│                                                                             │
│    GameLogger.info(...)          ← 游戏中唯一的日志调用入口                   │
│         │                                                                     │
│         └──▶ GameLogManager ──▶ 分发给各个 Handler                           │
│                                ├── ConsoleHandler                            │
│                                ├── FileHandler                              │
│                                └── ToastHandler                             │
│                                                                             │
│  【辅助方法全部封装在 GameLogger 内部】                                      │
│                                                                             │
│    GameLogger.diceRoll(dice1: 4, dice2: 3)  ← 封装好的便捷方法               │
│    GameLogger.propertyPurchase(propertyName: "股市大厦", price: 500)          │
│    GameLogger.payRent(amount: 120, from: "红队", to: "蓝队")                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 逐步替换策略

| 阶段 | 内容 | 优先级 |
|------|------|--------|
| **Phase 1** | 创建 `GameLogger` + 数据模型 + `GameLogManager` | 🔴 高 |
| **Phase 2** | 在 `GameNotifier` 中逐步替换现有日志调用 | 🔴 高 |
| **Phase 3** | 集成持久化（保存/恢复日志） | 🔴 高 |
| **Phase 4** | 替换 `AppLogger`、`ToastManager`、`OperationLogManager` | 🟡 中 |

### 2.3 设计目标

| 目标 | 描述 | 优先级 |
|------|------|--------|
| **统一日志格式** | 统一的数据结构，覆盖所有日志场景 | 🔴 高 |
| **日志分级** | 支持 debug/info/warning/important/critical 多级别 | 🔴 高 |
| **灵活显示** | 支持过滤、搜索、分组显示 | 🟡 中 |
| **持久化支持** | 可配置保存策略，方便回放和验证 | 🔴 高 |
| **性能友好** | 异步写入，不阻塞游戏主流程 | 🔴 高 |

### 3.1 核心思想：统一、分层、可配置

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           日志系统核心架构                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        游戏日志入口层                                  │   │
│  │                                                                      │   │
│  │   GameLogger.info("玩家购买地产")                                    │   │
│  │   GameLogger.debug("骰子结果: 4+3=7")                               │   │
│  │   GameLogger.important("玩家破产!")                                 │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                      │
│                                      ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        日志处理器层                                  │   │
│  │                                                                      │   │
│  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                │   │
│  │   │ ConsoleHandler│  │ FileHandler │  │ ToastHandler │               │   │
│  │   │  (控制台)    │  │  (文件)      │  │  (UI通知)    │                │   │
│  │   └─────────────┘  └─────────────┘  └─────────────┘                │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                      │
│                                      ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        日志存储层                                    │   │
│  │                                                                      │   │
│  │   ┌─────────────────────────────────────────────────────────────┐   │   │
│  │   │                    GameLogArchive                           │   │   │
│  │   │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐   │   │   │
│  │   │  │ 日志条目1  │ │ 日志条目2  │ │ 日志条目3  │ │ 日志条目N  │   │   │   │
│  │   │  └───────────┘ └───────────┘ └───────────┘ └───────────┘   │   │   │
│  │   └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 与回放系统的关系

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         日志系统与回放系统的关系                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐                    ┌─────────────────┐                │
│  │    日志系统      │                    │    回放系统      │                │
│  │  GameLogger     │                    │  GameReplay     │                │
│  └────────┬────────┘                    └────────┬────────┘                │
│           │                                      │                          │
│           │  日志条目序列                          │  操作命令序列             │
│           │  GameLogEntry[]                       │  GameAction[]           │
│           │                                      │                          │
│           ▼                                      ▼                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      共同的持久化层                                   │   │
│  │                   ReplayArchive / LogArchive                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  日志系统记录「发生了什么」                                                    │
│  回放系统记录「如何复现」                                                     │
│  两者可以共享底层存储，但服务于不同目的                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 四、数据结构设计

### 4.1 日志级别 (GameLogLevel)

```dart
/// 游戏日志级别
enum GameLogLevel {
  /// 调试级 - 详细信息（骰子数值、移动轨迹）
  debug(0, '调试', '🔵'),

  /// 信息级 - 关键游戏事件（购买、租金、卡牌）
  info(1, '信息', '✅'),

  /// 警告级 - 需要注意的情况（现金不足、连续对子）
  warning(2, '警告', '⚠️'),

  /// 重要级 - 游戏转折点（破产、建成房屋、入狱）
  important(3, '重要', '🔶'),

  /// 最高级 - 游戏结果（胜利、失败）
  critical(4, '重要', '🔴');

  final int level;
  final String label;
  final String emoji;

  bool shouldDisplayThan(GameLogLevel other) => this.level >= other.level;
}
```

### 4.2 日志类型 (GameLogType)

```dart
/// 游戏日志类型
enum GameLogType {
  // 骰子相关
  diceRoll,

  // 移动相关
  playerMove,
  passGo,

  // 地产相关
  propertyPurchase,
  propertyAuction,
  propertyBuild,
  propertyMortgage,
  propertyRedeem,

  // 租金相关
  payRent,
  collectRent,

  // 卡片相关
  chanceCard,
  communityChestCard,

  // 税务相关
  incomeTax,
  luxuryTax,
  houseRepair,

  // 玩家状态
  playerBankruptcy,
  playerEliminated,
  playerJailed,
  playerReleased,
  playerBankrupt,

  // 交易相关
  payToPlayer,
  receiveFromPlayer,

  // 游戏流程
  gameStart,
  turnStart,
  turnEnd,
  gameEnd,

  // AI相关
  aiDecision,

  // 系统相关
  systemMessage,
  error,
}
```

### 4.3 日志条目 (GameLogEntry)

```dart
/// 游戏日志条目
class GameLogEntry {
  final String id;                     // UUID
  final int turnNumber;                // 回合号（0=游戏开始前）
  final String? playerId;              // 玩家ID（null=系统）
  final String? playerName;            // 玩家名称（快照）
  final int? playerColor;              // 玩家颜色（ARGB int，快照）
  final GameLogLevel level;            // 日志级别
  final GameLogType type;              // 日志类型
  final String title;                  // 标题（简短）
  final String description;            // 详细描述
  final int? amount;                   // 金额变化（可为负）
  final String? propertyName;          // 相关地产名称
  final String? targetPlayerId;       // 目标玩家ID（用于交易）
  final String? targetPlayerName;     // 目标玩家名称（快照）
  final Map<String, dynamic>? metadata; // 扩展数据
  final DateTime timestamp;

  /// 序列化
  Map<String, dynamic> toJson() => {...};

  /// 反序列化
  static GameLogEntry fromJson(Map<String, dynamic> json) => {...};
}
```

### 4.4 日志配置 (GameLogConfig)

```dart
/// 日志配置
class GameLogConfig {
  final GameLogLevel minLevel;              // 最小显示级别
  final Set<GameLogType> enabledTypes;       // 启用的日志类型（空=全部）
  final Set<GameLogType> disabledTypes;      // 禁用的日志类型
  final bool enableConsole;                 // 输出到控制台
  final bool enableFile;                    // 保存到文件
  final bool enableToast;                   // 显示Toast
  final int maxEntries;                     // 最大内存条目数
  final int maxFileEntries;                 // 最大文件条目数
}
```

### 4.5 日志处理器接口

```dart
/// 日志处理器接口
abstract class GameLogHandler {
  /// 处理日志
  void handle(GameLogEntry entry);

  /// 刷新（将缓冲区写入文件等）
  Future<void> flush();

  /// 关闭
  Future<void> close();
}

/// 控制台处理器
class ConsoleGameLogHandler implements GameLogHandler {
  // 输出到 debugPrint / print
}

/// 文件处理器
class FileGameLogHandler implements GameLogHandler {
  // 异步写入文件
  // 支持日志轮转（按日期/大小）
}

/// Toast处理器
class ToastGameLogHandler implements GameLogHandler {
  // 根据 level 和 type 决定是否显示Toast
  // 集成现有 ToastManager
}
```

---

## 五、API设计

### 5.1 简洁入口：GameLogger

```dart
/// 游戏日志器
class GameLogger {
  /// 记录调试日志
  static void debug(
    String message, {
    GameLogType? type,
    String? playerId,
    String? playerName,
    int? playerColor,
  }) => _log(GameLogLevel.debug, message, type: type, ...);

  /// 记录信息日志
  static void info(
    String message, {
    GameLogType? type,
    String? playerId,
    String? playerName,
    int? playerColor,
  }) => _log(GameLogLevel.info, message, type: type, ...);

  /// 记录警告日志
  static void warning(
    String message, {
    GameLogType? type,
    String? playerId,
    String? playerName,
    int? playerColor,
  }) => _log(GameLogLevel.warning, message, type: type, ...);

  /// 记录重要日志
  static void important(
    String message, {
    GameLogType? type,
    String? playerId,
    String? playerName,
    int? playerColor,
  }) => _log(GameLogLevel.important, message, type: type, ...);

  /// 记录关键日志
  static void critical(
    String message, {
    GameLogType? type,
    String? playerId,
    String? playerName,
    int? playerColor,
  }) => _log(GameLogLevel.critical, message, type: type, ...);

  /// 带金额变化的便捷方法
  static void money(
    int amount, {
    required String reason,
    required String playerId,
    required String playerName,
    required int playerColor,
    GameLogLevel level = GameLogLevel.info,
  }) => _log(level, reason, type: GameLogType.systemMessage,
      playerId: playerId, playerName: playerName, playerColor: playerColor,
      metadata: {'amount': amount});

  /// 内部日志方法
  static void _log(GameLogLevel level, String message, {
    GameLogType? type,
    String? playerId,
    String? playerName,
    int? playerColor,
    Map<String, dynamic>? metadata,
  }) {
    // 创建日志条目
    final entry = GameLogEntry(
      id: Uuid().v4(),
      turnNumber: _currentTurnNumber,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
      level: level,
      type: type ?? GameLogType.systemMessage,
      title: _extractTitle(message),
      description: message,
      metadata: metadata,
      timestamp: DateTime.now(),
    );

    // 分发给各个处理器
    for (final handler in _handlers) {
      handler.handle(entry);
    }
  }
}
```

### 5.2 便捷工厂方法

```dart
extension GameLoggerConvenience on GameLogger {
  /// 记录掷骰子
  static void diceRoll({
    required int dice1,
    required int dice2,
    required bool isDoubles,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    final total = dice1 + dice2;
    final message = isDoubles
        ? '掷出对子: $dice1 + $dice2 = $total'
        : '掷骰子: $dice1 + $dice2 = $total';

    GameLogger.info(message,
      type: GameLogType.diceRoll,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
      metadata: {'dice1': dice1, 'dice2': dice2, 'isDoubles': isDoubles});
  }

  /// 记录玩家移动
  static void playerMove({
    required int fromPosition,
    required int toPosition,
    required int steps,
    required bool passedGo,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    final fromCell = boardCells[fromPosition];
    final toCell = boardCells[toPosition];
    final message = '从(${fromCell.name})移动${steps}步到(${toCell.name})';

    GameLogger.info(message,
      type: GameLogType.playerMove,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
      metadata: {'from': fromPosition, 'to': toPosition, 'steps': steps, 'passedGo': passedGo});
  }

  /// 记录购买地产
  static void propertyPurchase({
    required String propertyName,
    required int price,
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    GameLogger.important('购买 $propertyName，花费 \$$price',
      type: GameLogType.propertyPurchase,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
      metadata: {'price': price});

    // 同时记录资金变化
    GameLogger.money(-price,
      reason: '购买 $propertyName',
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor);
  }

  /// 记录支付租金
  static void payRent({
    required String propertyName,
    required int amount,
    required String payerId,
    required String payerName,
    required int payerColor,
    required String receiverId,
    required String receiverName,
    required int receiverColor,
    required int turnNumber,
  }) {
    GameLogger.important('向 $receiverName 支付租金 \$$amount（$propertyName）',
      type: GameLogType.payRent,
      playerId: payerId,
      playerName: payerName,
      playerColor: payerColor,
      targetPlayerId: receiverId,
      targetPlayerName: receiverName,
      metadata: {'amount': amount});

    GameLogger.money(-amount,
      reason: '支付 $propertyName 租金',
      playerId: payerId,
      playerName: payerName,
      playerColor: payerColor,
      level: GameLogLevel.warning);
  }

  /// 记录玩家破产
  static void playerBankrupt({
    required String playerId,
    required String playerName,
    required int playerColor,
    required String? creditorId,
    required String? creditorName,
    required int turnNumber,
  }) {
    final message = creditorName != null
        ? '破产，资产转移给 $creditorName'
        : '破产，退出游戏';

    GameLogger.critical(message,
      type: GameLogType.playerBankruptcy,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
      metadata: creditorId != null ? {'creditorId': creditorId} : null);
  }

  /// 记录游戏开始
  static void gameStart({
    required List<String> playerNames,
    required int turnNumber,
  }) {
    final players = playerNames.join('、');
    GameLogger.important('游戏开始！玩家: $players',
      type: GameLogType.gameStart,
      metadata: {'players': playerNames});
  }

  /// 记录回合开始
  static void turnStart({
    required String playerId,
    required String playerName,
    required int playerColor,
    required int turnNumber,
  }) {
    GameLogger.info('第 $turnNumber 回合开始',
      type: GameLogType.turnStart,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor);
  }

  /// 记录游戏结束
  static void gameOver({
    required String winnerId,
    required String winnerName,
    required int winnerColor,
    required int turnNumber,
    required List<Map<String, dynamic>> finalResults,
  }) {
    GameLogger.critical('$winnerName 赢得游戏！',
      type: GameLogType.gameOver,
      playerId: winnerId,
      playerName: winnerName,
      playerColor: winnerColor,
      metadata: {'results': finalResults});
  }
}
```

---

## 六、日志管理器 (GameLogManager)

### 6.1 核心类

```dart
/// 游戏日志管理器
class GameLogManager extends ChangeNotifier {
  static GameLogManager? _instance;
  static GameLogManager get instance => _instance ??= GameLogManager._();

  GameLogManager._();

  final List<GameLogEntry> _entries = [];
  final List<GameLogHandler> _handlers = [];
  GameLogConfig _config = GameLogConfig.defaultConfig();

  int _currentTurnNumber = 0;
  String? _currentPlayerId;
  String? _currentPlayerName;
  int? _currentPlayerColor;

  /// 当前日志条目（只读）
  List<GameLogEntry> get entries => List.unmodifiable(_entries);

  /// 当前回合号
  int get currentTurnNumber => _currentTurnNumber;

  /// 设置当前回合信息（游戏流程中自动调用）
  void setCurrentTurn(int turnNumber, {
    String? playerId,
    String? playerName,
    int? playerColor,
  }) {
    _currentTurnNumber = turnNumber;
    _currentPlayerId = playerId;
    _currentPlayerName = playerName;
    _currentPlayerColor = playerColor;
  }

  /// 添加处理器
  void addHandler(GameLogHandler handler) {
    _handlers.add(handler);
  }

  /// 移除处理器
  void removeHandler(GameLogHandler handler) {
    _handlers.remove(handler);
  }

  /// 更新配置
  void updateConfig(GameLogConfig config) {
    _config = config;
    notifyListeners();
  }

  /// 记录日志
  void log(GameLogEntry entry) {
    // 根据配置过滤
    if (entry.level.level < _config.minLevel.level) return;
    if (_config.enabledTypes.isNotEmpty && !_config.enabledTypes.contains(entry.type)) return;
    if (_config.disabledTypes.contains(entry.type)) return;

    // 添加到内存
    _entries.add(entry);

    // 保持最大条目限制
    while (_entries.length > _config.maxEntries) {
      _entries.removeAt(0);
    }

    // 分发给处理器
    for (final handler in _handlers) {
      handler.handle(entry);
    }

    notifyListeners();
  }

  /// 清空日志
  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// 获取过滤后的日志
  List<GameLogEntry> getFiltered({
    GameLogLevel? minLevel,
    GameLogType? type,
    String? playerId,
    int? turnNumber,
    String? searchQuery,
  }) {
    return _entries.where((entry) {
      if (minLevel != null && entry.level.level < minLevel.level) return false;
      if (type != null && entry.type != type) return false;
      if (playerId != null && entry.playerId != playerId) return false;
      if (turnNumber != null && entry.turnNumber != turnNumber) return false;
      if (searchQuery != null && !entry.description.contains(searchQuery)) return false;
      return true;
    }).toList();
  }

  /// 按回合分组
  Map<int, List<GameLogEntry>> getGroupedByTurn() {
    final Map<int, List<GameLogEntry>> grouped = {};
    for (final entry in _entries) {
      grouped.putIfAbsent(entry.turnNumber, () => []).add(entry);
    }
    return grouped;
  }

  /// 导出为JSON
  List<Map<String, dynamic>> exportToJson() {
    return _entries.map((e) => e.toJson()).toList();
  }

  /// 从JSON导入
  void importFromJson(List<Map<String, dynamic>> jsonList) {
    _entries.clear();
    for (final json in jsonList) {
      _entries.add(GameLogEntry.fromJson(json));
    }
    notifyListeners();
  }
}
```

---

## 七、与现有系统集成

### 7.1 迁移现有日志系统

| 现有系统 | 迁移方式 | 优先级 |
|----------|----------|--------|
| `AppLogger` | 替换为 `GameLogger`，保留接口兼容性 | 🔴 高 |
| `ToastManager` | 作为 `GameLogHandler` 集成，不替换UI | 🔴 高 |
| `OperationLogManager` | 废弃，功能合并到 `GameLogManager` | 🟡 中 |

### 7.2 Toast处理器的实现

```dart
/// Toast日志处理器
class ToastGameLogHandler implements GameLogHandler {
  final ToastManager _toastManager;

  ToastGameLogHandler(this._toastManager);

  @override
  void handle(GameLogEntry entry) {
    // 根据日志类型和级别决定是否显示Toast
    if (entry.level.level < GameLogLevel.important.level) {
      return; // debug/info 不显示Toast
    }

    GameToastType toastType;
    switch (entry.type) {
      case GameLogType.payRent:
      case GameLogType.incomeTax:
      case GameLogType.luxuryTax:
      case GameLogType.houseRepair:
      case GameLogType.payToPlayer:
        toastType = GameToastType.moneyExpense;
        break;
      case GameLogType.collectRent:
      case GameLogType.receiveFromPlayer:
        toastType = GameToastType.moneyIncome;
        break;
      case GameLogType.chanceCard:
      case GameLogType.communityChestCard:
        toastType = GameToastType.card;
        break;
      case GameLogType.playerBankruptcy:
        toastType = GameToastType.error;
        break;
      default:
        toastType = GameToastType.info;
    }

    _toastManager.show(
      type: toastType,
      title: entry.title,
      subtitle: entry.description,
      amount: entry.amount,
    );
  }
}
```

### 7.3 游戏流程中的集成点

```dart
/// 在 GameNotifier 中
class GameNotifier extends StateNotifier<GameState> {
  void rollDice() {
    // ... 现有逻辑 ...

    // 记录日志
    GameLogger.diceRoll(
      dice1: dice1,
      dice2: dice2,
      isDoubles: isDoubles,
      playerId: player.id,
      playerName: player.name,
      playerColor: player.tokenColor.toARGB32(),
      turnNumber: state.turnNumber,
    );
  }

  void buyProperty(int position) {
    // ... 现有逻辑 ...

    // 记录日志
    GameLogger.propertyPurchase(
      propertyName: boardCells[position].name,
      price: price,
      playerId: player.id,
      playerName: player.name,
      playerColor: player.tokenColor.toARGB32(),
      turnNumber: state.turnNumber,
    );
  }

  void _endTurn() {
    // ... 现有逻辑 ...

    // 记录回合结束
    GameLogger.info('${currentPlayer.name} 回合结束',
      type: GameLogType.turnEnd,
      playerId: currentPlayer.id,
      playerName: currentPlayer.name,
      playerColor: currentPlayer.tokenColor.toARGB32());
  }
}
```

---

## 八、UI设计

### 8.1 日志面板组件

```
┌─────────────────────────────────────────────────────────────┐
│  📋 游戏日志                              [🔍] [⚙️] [📤]    │
├─────────────────────────────────────────────────────────────┤
│  级别: [全部▼]  类型: [全部▼]  玩家: [全部▼]               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🔴 第3回合  红队  破产，资产转移给 蓝队               │   │
│  │    2026-04-15 10:32:15                              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🔶 第3回合  红队  购买 股市大厦，花费 $500            │   │
│  │    2026-04-15 10:31:50                              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ✅ 第2回合  蓝队  收取租金 $120（购物中心）           │   │
│  │    2026-04-15 10:30:22                              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ⚠️ 第2回合  红队  现金不足！无法购买 购物中心        │   │
│  │    2026-04-15 10:30:18                              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 日志设置对话框

```
┌─────────────────────────────────────────────────────────────┐
│  ⚙️ 日志设置                                           [X] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  显示级别                                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ● 全部  ○ 信息及以上  ○ 警告及以上  ○ 仅重要        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  显示类型                                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [✓] 骰子    [✓] 移动    [✓] 购买    [✓] 租金        │   │
│  │ [✓] 卡片    [✓] 税务    [✓] 建造    [ ] 调试        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  其他选项                                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [✓] 显示Toast通知                                   │   │
│  │ [✓] 保存到文件                                       │   │
│  │ [ ] 输出到控制台                                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  最大记录数: [100 ▼]                                        │
│                                                             │
│                        [恢复默认]  [确定]                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 九、持久化设计

### 9.1 日志存档结构

```dart
/// 日志存档
class GameLogArchive {
  final String gameId;
  final DateTime startTime;
  final DateTime? endTime;
  final GameSetup setup;                      // 游戏配置
  final List<GameLogEntry> entries;          // 日志条目
  final GameLogConfig config;               // 当年的配置
}
```

### 9.2 自动保存机制（每回合保存）

日志系统采用**每回合自动保存**策略，与游戏的 `autoSave` 机制整合，确保任何时候退出都能恢复到接近当前进度的状态。

#### 9.2.1 保存时机

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           自动保存时机                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  每回合结束时 (_endTurn):                                                   │
│                                                                             │
│  1. GameNotifier._endTurn() 被调用                                          │
│  2. 执行现有 autoSave 逻辑 ──▶ SaveService.saveGame(state)                   │
│  3. 同时保存日志到同一次存档                                                  │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         SaveService.saveGame()                        │   │
│  │                                                                      │   │
│  │   ① 保存 GameState 快照 (现有逻辑)                                    │   │
│  │         └── monopoly_game_save                                      │   │
│  │                                                                      │   │
│  │   ② 保存日志 (新增)                                                  │   │
│  │         └── monopoly_game_log_{gameId}                              │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 9.2.2 存储结构

```
SharedPreferences
├── monopoly_game_save              # 当前游戏存档 (GameState)
├── monopoly_game_log_{gameId}     # 每局游戏的日志 ← 新增，与存档绑定
├── monopoly_game_settings        # 游戏设置
└── ...
```

#### 9.2.3 SaveService 修改

```dart
/// 保存游戏（修改版）
static Future<bool> saveGame(GameState state) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // 1. 保存 GameState（现有逻辑）
    final gameData = state.toJson();
    final json = jsonEncode(gameData);
    await prefs.setString(_saveKey, json);

    // 2. 保存日志（新增）
    final gameId = _getGameId(state);
    final logEntries = GameLogManager.instance.exportToJson();
    await prefs.setString('${_logsKey}_$gameId', jsonEncode(logEntries));

    AppLogger.debug('游戏已保存（第 ${state.turnNumber} 回合）- 包含 ${logEntries.length} 条日志');

    return true;
  } catch (e) {
    AppLogger.error('保存游戏失败: $e');
    return false;
  }
}

/// 加载游戏（修改版）
static Future<GameState?> loadGame() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_saveKey);
    if (json == null) return null;

    final data = jsonDecode(json) as Map<String, dynamic>;
    final gameId = data['setup']?['gameId'] ?? 'default';
    final gameState = GameState.fromJson(data);

    // 恢复日志（新增）
    final logsJson = prefs.getString('${_logsKey}_$gameId');
    if (logsJson != null) {
      final logs = jsonDecode(logsJson) as List;
      GameLogManager.instance.importFromJson(logs.cast<Map<String, dynamic>>());
      AppLogger.info('游戏已恢复（第 ${gameState.turnNumber} 回合）- 恢复 ${logs.length} 条日志');
    }

    return gameState;
  } catch (e) {
    AppLogger.error('加载游戏失败: $e');
    return null;
  }
}

/// 获取游戏ID
static String _getGameId(GameState state) {
  final setup = state.setup;
  if (setup != null && setup['gameId'] != null) {
    return setup['gameId'];
  }
  return 'default';
}
```

#### 9.2.4 游戏生命周期中的日志管理

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       日志生命周期管理                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  【新游戏开始】                                                             │
│  initGameWithSetup()                                                        │
│       │                                                                     │
│       └──▶ GameLogManager.instance.clear()  ← 清空旧日志                     │
│       │                                                                     │
│       └──▶ GameLogger.gameStart(...)  ← 记录游戏开始                         │
│                                                                             │
│  【每回合进行中】                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  rollDice()          ──▶ GameLogger.diceRoll(...)                    │   │
│  │  buyProperty()       ──▶ GameLogger.propertyPurchase(...)             │   │
│  │  payRent()           ──▶ GameLogger.payRent(...)                      │   │
│  │  ...                                                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│       │                                                                     │
│  【回合结束】                                                               │
│  _endTurn()                                                                 │
│       │                                                                     │
│       └──▶ GameLogger.turnEnd(...)  ← 记录回合结束                         │
│       │                                                                     │
│       └──▶ SaveService.saveGame(state)  ← 同时保存状态和日志                 │
│                                                                             │
│  【游戏结束】                                                               │
│  _finishGame()                                                              │
│       │                                                                     │
│       └──▶ GameLogger.gameOver(...)  ← 记录游戏结束                         │
│       │                                                                     │
│       └──▶ SaveService.saveGame(state)  ← 保存最终状态和日志                 │
│                                                                             │
│  【加载存档继续游戏】                                                       │
│  loadGame()                                                                 │
│       │                                                                     │
│       ├──▶ 恢复 GameState                                                  │
│       │                                                                     │
│       └──▶ GameLogManager.importFromJson(...)  ← 恢复日志                   │
│                │                                                           │
│                └──▶ 用户继续游戏 ──▶ 日志自动追加                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 9.2.5 关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| **保存粒度** | 每回合结束时保存 | 平衡实时性和性能 |
| **日志位置** | 按 gameId 隔离存储 | 支持多局游戏同时存在 |
| **加载行为** | 恢复日志并继续追加 | 用户体验自然 |
| **日志上限** | 每局最多 1000 条 | 防止单局过大 |

#### 9.2.6 异常恢复场景

| 场景 | 恢复结果 |
|------|----------|
| 正常退出后重新打开 | 恢复到上一次保存的回合 |
| app 崩溃后重新打开 | 恢复到上一次保存的回合 |
| 手动删除存档 | 日志一并删除 |
| 游戏结束时 | 保存最终完整日志 |

---

## 十一、与回放系统的数据共享

> **重要决策：日志系统与回放系统完全独立，不共享数据。**

### 11.1 独立存储策略

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           独立存储结构                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  SharedPreferences / 文件系统                                               │
│  │                                                                          │
│  ├── monopoly_game_save              # 当前游戏存档 (GameState)              │
│  │                                                                          │
│  ├── monopoly_game_log_{gameId}     # 日志存档（完整日志条目）← 日志系统     │
│  │                                                                          │
│  └── monopoly_game_replay_{gameId}  # 回放存档（初始快照 + 操作序列）← 回放系统
│                                                                             │
│  两者通过 gameId 关联，但数据完全独立。                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 11.2 各系统职责清晰

| 系统 | 职责 | 数据类型 |
|------|------|----------|
| **日志系统** | 记录「发生了什么」 | `GameLogEntry[]` - 描述式 |
| **回放系统** | 记录「如何复现」 | `GameAction[]` + 初始快照 - 命令式 |

### 11.3 整合点：SaveService

两个系统在 SaveService 中整合，但数据分开存储：

```dart
/// 游戏记录服务（整合回放和日志）
class GameRecordService {
  /// 保存完整游戏记录（包含回放和日志）
  static Future<bool> saveCompleteRecord({
    required String gameId,
    required GameSetup setup,
    required GameReplaySnapshot initialSnapshot,
    required List<GameAction> actions,
    required List<GameLogEntry> logs,
    required ReplayMetadata metadata,
  }) async {
    // 1. 保存回放
    await ReplayService.saveReplay(GameReplayRecord(...));

    // 2. 保存日志（注意：这里不再保存，因为每回合已自动保存）
    // await GameLogService.saveLogArchive(...);

    return true;
  }

  /// 加载完整游戏记录
  static Future<GameCompleteRecord?> loadCompleteRecord(String gameId) async {
    // 加载回放
    final replay = await ReplayService.getReplay(gameId);

    // 日志已随存档保存，加载 GameState 时自动恢复
    // 无需单独加载

    if (replay == null) return null;

    return GameCompleteRecord(
      replay: replay,
      // 日志从 GameLogManager 获取
    );
  }
}
```

---

## 十二、实现计划

> **优先级：日志系统优先于回放系统**

### Phase 1: 核心日志系统 ✅ 已完成

| 任务 | 工作内容 | 状态 |
|------|----------|------|
| T1.1 | 创建 `models/game_log.dart` 数据模型 | ✅ 已完成 |
| T1.2 | 创建 `GameLogger` 日志入口类 | ✅ 已完成 |
| T1.3 | 创建 `GameLogManager` 管理器 | ✅ 已完成 |
| T1.4 | 创建 `ConsoleGameLogHandler` | ✅ 已完成 |
| T1.5 | 迁移 `AppLogger` 调用到 `GameLogger` | � 进行中 |

**已创建的文件：**
- `lib/features/monopoly_game/models/game_log.dart` - GameLogEntry、GameLogLevel、GameLogType
- `lib/features/monopoly_game/models/game_log_manager.dart` - GameLogManager、GameLogConfig、GameLogHandler
- `lib/features/monopoly_game/models/game_logger.dart` - GameLogger 入口类（含50+便捷方法）

**已替换的日志调用（game_provider.dart）：**
- `GameLogger.diceRoll()` - 普通掷骰
- `GameLogger.jailDiceRoll()` - 监狱掷骰
- `GameLogger.consecutiveDoublesWarning()` - 连续对子警告
- `GameLogger.playerMove()` - 玩家移动
- `GameLogger.passGo()` - 经过起点
- `GameLogger.doublesBonus()` - 对子奖励
- `GameLogger.drawCard()` - 抽卡
- `GameLogger.clear()` - 清除日志
- `GameLogger.propertyPurchase()` - 购买地产
- `GameLogger.payRent()` - 支付租金
- `GameLogger.buildHouse()` - 建造房屋
- `GameLogger.mortgage()` - 抵押地产
- `GameLogger.redeem()` - 赎回地产
- `GameLogger.payTax()` - 税款（所得税/奢侈品税）
- `GameLogger.houseRepair()` - 房屋维修
- `GameLogger.payEachPlayer()` - 向每位玩家支付
- `GameLogger.collectFromEachPlayer()` - 从每位玩家获得
- `GameLogger.goToJail()` - 进入监狱
- `GameLogger.releaseFromJail()` - 离开监狱（保释金/越狱卡）
- `GameLogger.turnStart()` - 回合开始
- `GameLogger.turnEnd()` - 回合结束

**待替换的日志调用（game_provider.dart）：**
- 剩余 `_logger.info/warning/error` 调用（~30处）
- 游戏开始/结束日志
- AI决策详细日志

### Phase 2: 持久化集成

| 任务 | 工作内容 | 优先级 |
|------|----------|--------|
| T2.1 | 修改 `SaveService.saveGame()` 保存日志 | 🔴 高 |
| T2.2 | 修改 `SaveService.loadGame()` 恢复日志 | 🔴 高 |
| T2.3 | 集成到 `GameNotifier._endTurn()` | 🔴 高 |
| T2.4 | 集成到 `GameNotifier.initGameWithSetup()` | 🔴 高 |

### Phase 3: 处理器与UI

| 任务 | 工作内容 | 优先级 |
|------|----------|--------|
| T3.1 | 创建 `ToastGameLogHandler`（可选） | 🟡 中 |
| T3.2 | 创建 `GameLogPanel` 组件 | � 中 |
| T3.3 | 收敛 `ToastManager` 入口 | � 中 |

### Phase 4: 回放系统（后续）

> 回放系统实现计划见 [REPLAY_SYSTEM_DESIGN.md](./REPLAY_SYSTEM_DESIGN.md)

---

## 十三、FAQ

**Q: 为什么需要单独的日志系统？回放系统的操作记录不够用吗？**

A: 回放系统的 `GameAction` 是**命令式**的，用于精确复现游戏过程。而日志系统是**描述式**的，用于记录「发生了什么」，两者服务目的不同。日志更灵活，可以记录任何信息；命令必须可执行可重放。

**Q: 为什么不直接扩展现有的 `OperationLogManager`？**

A: `OperationLogManager` 设计为内存暂存，最多10条，且数据结构固定。主要问题是条目少且不可配置。新的日志系统会保留其接口风格的便捷方法，但底层完全重新设计。

**Q: Toast 和日志系统如何共存？**

A: Toast 是一种**显示通道**，日志系统是一种**记录系统**。理想的流程是：
- 游戏逻辑产生日志 → 存入日志系统 → 分发给处理器
- ToastHandler 收到日志 → 根据规则决定是否显示 Toast

这样同一份日志数据可以同时显示在面板、保存到文件、显示Toast。

---

## 附录

### A. 文件结构

```
lib/features/monopoly_game/
├── models/
│   ├── models.dart                    # 现有模型
│   └── game_log.dart                  # 新增：日志模型
├── services/
│   ├── game_log_service.dart          # 新增：日志服务
│   ├── game_record_service.dart       # 新增：整合服务
│   └── save_service.dart              # 修改：使用新日志系统
├── providers/
│   ├── game_provider.dart             # 修改：集成日志
│   └── game_log_provider.dart         # 新增：日志Provider
└── widgets/
    ├── game_log_panel.dart            # 新增：日志面板
    ├── game_log_settings_dialog.dart  # 新增：设置对话框
    └── feedback/
        ├── toast_manager.dart          # 修改：实现日志处理器接口
        └── game_toast.dart             # 现有
```

### B. 现有系统迁移对照

| 现有API | 新API | 说明 |
|---------|-------|------|
| `AppLogger.info(msg)` | `GameLogger.info(msg)` | 接口兼容 |
| `AppLogger.getLogRecords()` | `GameLogManager.instance.entries` | 统一访问 |
| `ToastManager.instance.showXxx()` | `GameLogger.important(msg)` | 推荐用日志替代 |
| `OperationLogManager.instance.logXxx()` | `GameLogger.xxx(...)` | 便捷方法替代 |
