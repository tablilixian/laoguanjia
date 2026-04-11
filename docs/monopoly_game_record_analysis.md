# 地产大亨游戏记录系统分析

> **状态：** 🔴 待开发  
> **创建日期：** 2026-04-11  
> **目标：** 达到"能够复原整个游戏流程"的记录完善程度

---

## 一、当前记录系统分析

### 1.1 现有记录内容

#### 1.1.1 游戏状态快照 (GameState)

**保存位置：** `SaveService.saveGame()`

**保存内容：**
```dart
class GameState {
  final List<Player> players;              // 玩家列表
  final int currentPlayerIndex;            // 当前玩家索引
  final int turnNumber;                    // 回合数
  final GamePhase phase;                   // 游戏阶段
  final List<PropertyState> properties;    // 地产状态
  final List<GameCard> chanceCards;        // 命运卡牌堆
  final List<GameCard> communityChestCards; // 公益卡牌堆
  final int chanceCardIndex;               // 命运卡索引
  final int communityChestCardIndex;       // 公益卡索引
  final int? lastDice1;                    // 上次骰子1
  final int? lastDice2;                    // 上次骰子2
  final bool isDoubles;                    // 是否对子
  final int consecutiveDoubles;            // 连续对子次数
  final String? winnerId;                  // 胜利者ID
  final GameSettings settings;             // 游戏设置
}
```

**问题：**
- ❌ 只保存当前状态，无法回溯历史
- ❌ 无法知道状态是如何变化的
- ❌ 无法复现游戏过程

---

#### 1.1.2 日志记录 (LogRecord)

**保存位置：** `SaveService.saveGame()` 中的日志保存

**保存内容：**
```dart
class LogRecord {
  final DateTime timestamp;  // 时间戳
  final String tag;          // 标签
  final LogLevel level;      // 日志级别
  final String message;      // 日志消息
}
```

**当前日志示例：**
```
✅ [Game] 玩家1 掷骰子: 3 + 4 = 7
✅ [Game] 玩家1 从位置 0(起点) 移动 7 步到位置 7(命运卡)
✅ [Game] 玩家1 抽到命运卡: 前进到起点
✅ [Game] 玩家1 移动到位置 0(起点)，获得 200 元
```

**问题：**
- ⚠️ 日志格式不统一，难以解析
- ⚠️ 缺少关键信息（如交易、拍卖等）
- ⚠️ 无法自动复原游戏状态

---

### 1.2 现有记录的局限性

| 局限性 | 说明 | 影响 |
|--------|------|------|
| 无法回溯历史 | 只保存当前状态快照 | ❌ 无法查看历史状态 |
| 无法复现过程 | 缺少操作序列记录 | ❌ 无法重放游戏 |
| 无法统计分析 | 缺少结构化数据 | ❌ 无法生成统计报告 |
| 无法验证公平性 | 缺少随机种子记录 | ❌ 无法验证游戏公平性 |

---

## 二、目标记录系统设计

### 2.1 完整的游戏记录模型

#### 2.1.1 游戏记录模型 (GameRecord)

```dart
/// 游戏记录模型
class GameRecord {
  final String gameId;                      // 游戏ID
  final DateTime startTime;                 // 开始时间
  final DateTime? endTime;                  // 结束时间
  final GameSetup setup;                    // 游戏设置
  final GameResult? result;                 // 游戏结果
  final List<TurnRecord> turns;             // 回合记录列表
  final GameStatistics statistics;          // 游戏统计
  final int randomSeed;                     // 随机种子（用于复现）
}

/// 游戏结果模型
class GameResult {
  final String winnerId;                    // 胜利者ID
  final int totalTurns;                     // 总回合数
  final Duration duration;                  // 游戏时长
  final List<PlayerResult> playerResults;   // 玩家结果
}

/// 玩家结果模型
class PlayerResult {
  final String playerId;
  final String playerName;
  final int finalRanking;                   // 最终排名
  final int finalCash;                      // 最终现金
  final int totalAssets;                    // 总资产
  final int propertiesOwned;                // 拥有地产数
  final int housesBuilt;                    // 建造房屋数
  final int timesInJail;                    // 进监狱次数
  final int timesBankrupt;                  // 破产次数（0或1）
}
```

---

#### 2.1.2 回合记录模型 (TurnRecord)

```dart
/// 回合记录模型
class TurnRecord {
  final int turnNumber;                     // 回合数
  final String playerId;                    // 玩家ID
  final DateTime startTime;                 // 开始时间
  final DateTime endTime;                   // 结束时间
  final List<ActionRecord> actions;         // 操作记录列表
  final PlayerStateSnapshot startState;     // 回合开始状态快照
  final PlayerStateSnapshot endState;       // 回合结束状态快照
}

/// 玩家状态快照
class PlayerStateSnapshot {
  final int position;                       // 位置
  final int cash;                           // 现金
  final PlayerStatus status;                // 状态
  final List<int> propertyIndices;          // 拥有的地产索引
  final int jailTurns;                      // 监狱回合数
  final bool hasGetOutOfJailFree;           // 是否有出狱卡
}
```

---

#### 2.1.3 操作记录模型 (ActionRecord)

```dart
/// 操作类型枚举
enum ActionType {
  rollDice,           // 掷骰子
  move,               // 移动
  buyProperty,        // 购买地产
  payRent,            // 支付租金
  buildHouse,         // 建造房屋
  sellHouse,          // 出售房屋
  mortgageProperty,   // 抵押地产
  redeemProperty,     // 赎回地产
  drawCard,           // 抽卡
  goToJail,           // 进监狱
  getOutOfJail,       // 出狱
  payTax,             // 支付税款
  bankrupt,           // 破产
  auction,            // 拍卖
  trade,              // 交易
}

/// 操作记录模型
class ActionRecord {
  final String actionId;                    // 操作ID
  final ActionType type;                    // 操作类型
  final DateTime timestamp;                 // 时间戳
  final String playerId;                    // 执行玩家ID
  final Map<String, dynamic> details;       // 操作详情
  final ActionResult result;                // 操作结果
}

/// 操作结果模型
class ActionResult {
  final bool success;                       // 是否成功
  final String? errorMessage;               // 错误信息
  final Map<String, dynamic> changes;       // 状态变化
}

/// 掷骰子操作详情
class RollDiceDetails {
  final int dice1;                          // 骰子1
  final int dice2;                          // 骰子2
  final bool isDoubles;                     // 是否对子
  final int consecutiveDoubles;             // 连续对子次数
}

/// 购买地产操作详情
class BuyPropertyDetails {
  final int propertyIndex;                  // 地产索引
  final String propertyName;                // 地产名称
  final int price;                          // 购买价格
  final int playerCashBefore;               // 购买前现金
  final int playerCashAfter;                // 购买后现金
}

/// 支付租金操作详情
class PayRentDetails {
  final int propertyIndex;                  // 地产索引
  final String propertyName;                // 地产名称
  final String ownerId;                     // 地产拥有者ID
  final int rentAmount;                     // 租金金额
  final int houses;                         // 房屋数量
  final bool isMortgaged;                   // 是否抵押
}

/// 建造房屋操作详情
class BuildHouseDetails {
  final int propertyIndex;                  // 地产索引
  final String propertyName;                // 地产名称
  final int housesBefore;                   // 建造前房屋数
  final int housesAfter;                    // 建造后房屋数
  final int cost;                           // 建造成本
}

/// 抽卡操作详情
class DrawCardDetails {
  final CardType cardType;                  // 卡牌类型
  final String cardName;                    // 卡牌名称
  final String cardDescription;             // 卡牌描述
  final CardEffect effect;                  // 卡牌效果
}
```

---

#### 2.1.4 游戏统计模型 (GameStatistics)

```dart
/// 游戏统计模型
class GameStatistics {
  final int totalTurns;                     // 总回合数
  final Duration duration;                  // 游戏时长
  final int totalDiceRolls;                 // 总掷骰次数
  final int totalDoubles;                   // 总对子次数
  final int totalPropertiesBought;          // 总购买地产次数
  final int totalHousesBuilt;               // 总建造房屋次数
  final int totalRentPaid;                  // 总支付租金
  final int totalTaxPaid;                   // 总支付税款
  final int totalTimesInJail;               // 总进监狱次数
  final int totalCardsDrawn;                // 总抽卡次数
  final Map<String, PlayerStatistics> playerStats; // 玩家统计
}

/// 玩家统计模型
class PlayerStatistics {
  final String playerId;
  final int diceRolls;                      // 掷骰次数
  final int doubles;                        // 对子次数
  final int propertiesBought;               // 购买地产数
  final int housesBuilt;                    // 建造房屋数
  final int rentCollected;                  // 收取租金总额
  final int rentPaid;                       // 支付租金总额
  final int taxPaid;                        // 支付税款总额
  final int timesInJail;                    // 进监狱次数
  final int cardsDrawn;                     // 抽卡次数
  final int timesAroundBoard;               // 绕棋盘次数
  final int maxCash;                        // 最高现金
  final int minCash;                        // 最低现金
}
```

---

## 三、实现方案

### 3.1 需要新增的文件

#### 3.1.1 数据模型文件

**新建文件：** `lib/features/monopoly_game/models/game_record.dart`

```dart
// 游戏记录相关数据模型
// 包含 GameRecord, TurnRecord, ActionRecord 等
```

---

#### 3.1.2 记录服务文件

**新建文件：** `lib/features/monopoly_game/services/game_record_service.dart`

```dart
/// 游戏记录服务
class GameRecordService {
  /// 开始新游戏记录
  static GameRecord startNewGame(GameSetup setup, int randomSeed);
  
  /// 记录回合开始
  static void startTurn(GameRecord record, String playerId);
  
  /// 记录操作
  static void recordAction(GameRecord record, ActionRecord action);
  
  /// 记录回合结束
  static void endTurn(GameRecord record, PlayerStateSnapshot endState);
  
  /// 结束游戏记录
  static GameResult endGame(GameRecord record, String winnerId);
  
  /// 保存游戏记录
  static Future<bool> saveGameRecord(GameRecord record);
  
  /// 加载游戏记录
  static Future<GameRecord?> loadGameRecord(String gameId);
  
  /// 获取所有游戏记录
  static Future<List<GameRecord>> getAllGameRecords();
  
  /// 删除游戏记录
  static Future<bool> deleteGameRecord(String gameId);
  
  /// 导出游戏记录为JSON
  static String exportToJson(GameRecord record);
  
  /// 从JSON导入游戏记录
  static GameRecord importFromJson(String json);
  
  /// 生成游戏统计报告
  static GameStatistics generateStatistics(GameRecord record);
}
```

---

#### 3.1.3 游戏回放服务文件

**新建文件：** `lib/features/monopoly_game/services/game_replay_service.dart`

```dart
/// 游戏回放服务
class GameReplayService {
  /// 从游戏记录复原游戏状态
  static GameState reconstructGameState(GameRecord record, int turnNumber);
  
  /// 重放游戏到指定回合
  static GameState replayToTurn(GameRecord record, int turnNumber);
  
  /// 获取指定回合的操作列表
  static List<ActionRecord> getTurnActions(GameRecord record, int turnNumber);
  
  /// 验证游戏记录完整性
  static bool validateGameRecord(GameRecord record);
  
  /// 生成游戏回放报告
  static String generateReplayReport(GameRecord record);
}
```

---

### 3.2 需要修改的文件

#### 3.2.1 修改游戏提供者

**修改文件：** `lib/features/monopoly_game/providers/game_provider.dart`

**需要添加：**
```dart
class GameNotifier extends StateNotifier<GameState> {
  GameRecord? _currentRecord;  // 当前游戏记录
  
  /// 初始化游戏时创建记录
  void initGame(List<PlayerConfig> playerConfigs, GameSettings settings) {
    // ... 原有逻辑
    
    // 创建游戏记录
    final randomSeed = DateTime.now().millisecondsSinceEpoch;
    _currentRecord = GameRecordService.startNewGame(
      GameSetup(playerConfigs: playerConfigs, playerCount: playerConfigs.length),
      randomSeed,
    );
  }
  
  /// 记录操作
  void _recordAction(ActionType type, Map<String, dynamic> details) {
    if (_currentRecord == null) return;
    
    final action = ActionRecord(
      actionId: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      timestamp: DateTime.now(),
      playerId: state.currentPlayer.id,
      details: details,
      result: ActionResult(success: true, changes: {}),
    );
    
    GameRecordService.recordAction(_currentRecord!, action);
  }
  
  /// 掷骰子时记录
  void rollDice() {
    // ... 原有逻辑
    
    // 记录操作
    _recordAction(ActionType.rollDice, {
      'dice1': dice1,
      'dice2': dice2,
      'isDoubles': isDoubles,
      'consecutiveDoubles': state.consecutiveDoubles,
    });
  }
  
  /// 购买地产时记录
  void buyProperty() {
    // ... 原有逻辑
    
    // 记录操作
    _recordAction(ActionType.buyProperty, {
      'propertyIndex': currentPosition,
      'propertyName': boardCells[currentPosition].name,
      'price': property.price,
      'playerCashBefore': player.cash + property.price,
      'playerCashAfter': player.cash,
    });
  }
  
  // ... 其他操作类似
}
```

---

#### 3.2.2 修改存档服务

**修改文件：** `lib/features/monopoly_game/services/save_service.dart`

**需要添加：**
```dart
class SaveService {
  static const String _gameRecordsKey = 'monopoly_game_records';
  
  /// 保存游戏记录
  static Future<bool> saveGameRecord(GameRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取现有记录列表
      final recordsJson = prefs.getString(_gameRecordsKey);
      final records = recordsJson != null 
          ? jsonDecode(recordsJson) as List 
          : [];
      
      // 添加新记录
      records.add(record.toJson());
      
      // 保存
      final newRecordsJson = jsonEncode(records);
      return await prefs.setString(_gameRecordsKey, newRecordsJson);
    } catch (e) {
      AppLogger.error('保存游戏记录失败: $e');
      return false;
    }
  }
  
  /// 获取所有游戏记录
  static Future<List<GameRecord>> getAllGameRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getString(_gameRecordsKey);
      
      if (recordsJson == null) return [];
      
      final records = jsonDecode(recordsJson) as List;
      return records
          .map((r) => GameRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('加载游戏记录失败: $e');
      return [];
    }
  }
}
```

---

### 3.3 需要新增的UI页面

#### 3.3.1 游戏记录列表页面

**新建文件：** `lib/features/monopoly_game/pages/game_records_page.dart`

**功能：**
- 显示所有游戏记录
- 按日期排序
- 显示游戏结果摘要
- 点击查看详情

---

#### 3.3.2 游戏记录详情页面

**新建文件：** `lib/features/monopoly_game/pages/game_record_detail_page.dart`

**功能：**
- 显示游戏基本信息
- 显示回合列表
- 显示操作详情
- 支持回放到指定回合
- 导出游戏记录

---

#### 3.3.3 游戏统计页面

**新建文件：** `lib/features/monopoly_game/pages/game_statistics_page.dart`

**功能：**
- 显示游戏统计图表
- 玩家表现对比
- 历史数据分析

---

## 四、实现优先级

### 4.1 高优先级（核心功能）

| 序号 | 功能 | 工作量 | 优先级 | 说明 |
|------|------|--------|--------|------|
| 1 | 创建游戏记录模型 | 2天 | 🔴 高 | 基础数据结构 |
| 2 | 实现记录服务 | 3天 | 🔴 高 | 核心记录功能 |
| 3 | 修改游戏提供者 | 2天 | 🔴 高 | 集成记录功能 |
| 4 | 实现游戏结果保存 | 1天 | 🔴 高 | 保存最终结果 |

**总工作量：** 8天

---

### 4.2 中优先级（增强功能）

| 序号 | 功能 | 工作量 | 优先级 | 说明 |
|------|------|--------|--------|------|
| 5 | 游戏记录列表页面 | 2天 | 🟡 中 | 查看历史记录 |
| 6 | 游戏记录详情页面 | 2天 | 🟡 中 | 查看详细信息 |
| 7 | 游戏统计功能 | 3天 | 🟡 中 | 数据分析 |
| 8 | 导出/导入功能 | 1天 | 🟡 中 | 数据备份 |

**总工作量：** 8天

---

### 4.3 低优先级（高级功能）

| 序号 | 功能 | 工作量 | 优先级 | 说明 |
|------|------|--------|--------|------|
| 9 | 游戏回放功能 | 5天 | 🟢 低 | 复原游戏流程 |
| 10 | 游戏统计图表 | 3天 | 🟢 低 | 可视化展示 |
| 11 | 游戏记录搜索 | 2天 | 🟢 低 | 快速查找 |
| 12 | 游戏记录分享 | 1天 | 🟢 低 | 社交功能 |

**总工作量：** 11天

---

## 五、实现步骤

### 5.1 第一阶段：核心记录功能（8天）

**目标：** 实现基本的游戏记录功能

**步骤：**
1. 创建游戏记录数据模型（2天）
   - GameRecord
   - TurnRecord
   - ActionRecord
   - GameResult
   - GameStatistics

2. 实现游戏记录服务（3天）
   - startNewGame()
   - recordAction()
   - endGame()
   - saveGameRecord()
   - loadGameRecord()

3. 修改游戏提供者（2天）
   - 集成记录功能
   - 在每个操作处添加记录
   - 保存游戏结果

4. 测试和优化（1天）
   - 单元测试
   - 集成测试
   - 性能优化

---

### 5.2 第二阶段：UI展示功能（8天）

**目标：** 实现游戏记录的查看和展示

**步骤：**
1. 游戏记录列表页面（2天）
   - 显示所有记录
   - 排序和筛选
   - 删除记录

2. 游戏记录详情页面（2天）
   - 显示基本信息
   - 显示回合列表
   - 显示操作详情

3. 游戏统计功能（3天）
   - 计算统计数据
   - 生成统计报告
   - 显示统计图表

4. 导出/导入功能（1天）
   - JSON导出
   - JSON导入
   - 文件分享

---

### 5.3 第三阶段：高级功能（11天）

**目标：** 实现游戏回放和高级分析

**步骤：**
1. 游戏回放功能（5天）
   - 状态复原
   - 回放到指定回合
   - 回放控制（播放、暂停、快进）

2. 游戏统计图表（3天）
   - 数据可视化
   - 图表库集成
   - 交互式图表

3. 游戏记录搜索（2天）
   - 按日期搜索
   - 按玩家搜索
   - 按结果搜索

4. 游戏记录分享（1天）
   - 生成分享链接
   - 社交媒体分享
   - 二维码分享

---

## 六、技术要点

### 6.1 数据存储方案

**方案1：SharedPreferences（当前方案）**
- ✅ 简单易用
- ✅ 适合少量数据
- ❌ 不适合大量历史记录
- ❌ 无法存储大量游戏记录

**方案2：SQLite数据库（推荐）**
- ✅ 适合大量数据
- ✅ 支持复杂查询
- ✅ 数据结构化存储
- ❌ 需要额外的数据库管理

**方案3：文件存储**
- ✅ 适合大量数据
- ✅ 易于备份和迁移
- ✅ 支持导出和分享
- ❌ 查询性能较低

**推荐方案：** SQLite + 文件存储混合方案
- SQLite存储索引和元数据
- 文件存储详细记录（JSON格式）

---

### 6.2 性能优化

**问题：** 游戏记录可能非常大，影响性能

**解决方案：**
1. 分页加载：只加载当前页的记录
2. 延迟加载：需要时才加载详细信息
3. 压缩存储：使用gzip压缩JSON数据
4. 索引优化：为常用查询字段创建索引

---

### 6.3 数据完整性

**问题：** 如何确保游戏记录的完整性和正确性

**解决方案：**
1. 数据校验：保存前验证数据完整性
2. 哈希校验：为每条记录计算哈希值
3. 版本控制：记录数据模型版本号
4. 备份机制：定期备份游戏记录

---

## 七、验收标准

### 7.1 功能验收标准

| 功能 | 验收标准 | 测试方法 |
|------|----------|----------|
| 游戏记录保存 | ✅ 能够保存完整的游戏记录 | 完成一局游戏，检查记录 |
| 游戏记录加载 | ✅ 能够加载历史游戏记录 | 加载并显示历史记录 |
| 游戏回放 | ✅ 能够回放到任意回合 | 回放到指定回合并验证状态 |
| 统计分析 | ✅ 能够生成准确的统计报告 | 对比手动计算结果 |
| 数据导出 | ✅ 能够导出为JSON格式 | 导出并验证JSON内容 |
| 数据导入 | ✅ 能够从JSON导入记录 | 导入并验证记录完整性 |

---

### 7.2 性能验收标准

| 指标 | 标准 | 测试方法 |
|------|------|----------|
| 记录保存时间 | < 100ms | 测量保存时间 |
| 记录加载时间 | < 200ms | 测量加载时间 |
| 回放响应时间 | < 50ms | 测量回放响应 |
| 内存占用 | < 50MB | 监控内存使用 |
| 存储空间 | < 10MB/局 | 测量文件大小 |

---

## 八、总结

### 8.1 当前状态

**记录完善程度：** 30%

**主要问题：**
- ❌ 缺少结构化的游戏记录
- ❌ 无法回溯历史状态
- ❌ 无法复现游戏过程
- ❌ 缺少统计分析功能

---

### 8.2 目标状态

**记录完善程度：** 100%

**实现效果：**
- ✅ 完整的游戏记录（每个操作都有记录）
- ✅ 可回溯的历史状态（可以回到任意时刻）
- ✅ 可复现的游戏过程（可以重放整个游戏）
- ✅ 详细的统计分析（各种统计数据和图表）

---

### 8.3 工作量估算

**总工作量：** 27天

**分阶段工作量：**
- 第一阶段（核心功能）：8天
- 第二阶段（UI展示）：8天
- 第三阶段（高级功能）：11天

**建议实施策略：**
1. 先实现核心记录功能（第一阶段）
2. 根据用户反馈决定是否继续
3. 逐步完善高级功能

---

**文档版本：** v1.0  
**创建日期：** 2026-04-11  
**维护人员：** 开发团队
