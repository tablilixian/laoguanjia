# 游戏记录存储空间估算

> **状态：** 🔴 待开发  
> **估算日期：** 2026-04-11  
> **场景：** 3个玩家，100局游戏，JSON格式

---

## 一、单局游戏记录大小估算

### 1.1 游戏基本信息（约500字节）

```json
{
  "gameId": "game_20260411_1234567890",
  "startTime": "2026-04-11T10:00:00.000Z",
  "endTime": "2026-04-11T11:30:00.000Z",
  "setup": {
    "playerCount": 3,
    "playerConfigs": [
      {"name": "玩家1", "isHuman": true, "difficulty": "easy", "personality": "conservative"},
      {"name": "电脑1", "isHuman": false, "difficulty": "easy", "personality": "conservative"},
      {"name": "电脑2", "isHuman": false, "difficulty": "medium", "personality": "aggressive"}
    ]
  },
  "result": {
    "winnerId": "player_1",
    "totalTurns": 50,
    "duration": "1:30:00"
  },
  "randomSeed": 1234567890
}
```

**大小估算：** 约500字节

---

### 1.2 回合记录（假设平均50回合）

#### 单个回合记录示例

```json
{
  "turnNumber": 1,
  "playerId": "player_1",
  "startTime": "2026-04-11T10:00:05.000Z",
  "endTime": "2026-04-11T10:00:15.000Z",
  "startState": {
    "position": 0,
    "cash": 1500,
    "status": "active",
    "propertyIndices": [],
    "jailTurns": 0,
    "hasGetOutOfJailFree": false
  },
  "endState": {
    "position": 7,
    "cash": 1500,
    "status": "active",
    "propertyIndices": [],
    "jailTurns": 0,
    "hasGetOutOfJailFree": false
  },
  "actions": []
}
```

**单个回合记录大小：** 约400字节（不含操作）

**50回合总计：** 400字节 × 50 = 20KB

---

### 1.3 操作记录（假设平均每回合5个操作）

#### 操作记录示例

**掷骰子操作：**
```json
{
  "actionId": "action_1",
  "type": "rollDice",
  "timestamp": "2026-04-11T10:00:06.000Z",
  "playerId": "player_1",
  "details": {
    "dice1": 3,
    "dice2": 4,
    "isDoubles": false,
    "consecutiveDoubles": 0
  },
  "result": {
    "success": true,
    "changes": {}
  }
}
```
**大小：** 约200字节

**移动操作：**
```json
{
  "actionId": "action_2",
  "type": "move",
  "timestamp": "2026-04-11T10:00:07.000Z",
  "playerId": "player_1",
  "details": {
    "fromPosition": 0,
    "toPosition": 7,
    "steps": 7,
    "passedGo": false
  },
  "result": {
    "success": true,
    "changes": {}
  }
}
```
**大小：** 约250字节

**购买地产操作：**
```json
{
  "actionId": "action_3",
  "type": "buyProperty",
  "timestamp": "2026-04-11T10:00:10.000Z",
  "playerId": "player_1",
  "details": {
    "propertyIndex": 1,
    "propertyName": "拉萨",
    "price": 60,
    "playerCashBefore": 1500,
    "playerCashAfter": 1440
  },
  "result": {
    "success": true,
    "changes": {
      "playerCash": -60,
      "propertyOwner": "player_1"
    }
  }
}
```
**大小：** 约300字节

**支付租金操作：**
```json
{
  "actionId": "action_4",
  "type": "payRent",
  "timestamp": "2026-04-11T10:05:12.000Z",
  "playerId": "player_2",
  "details": {
    "propertyIndex": 1,
    "propertyName": "拉萨",
    "ownerId": "player_1",
    "rentAmount": 2,
    "houses": 0,
    "isMortgaged": false
  },
  "result": {
    "success": true,
    "changes": {
      "player2Cash": -2,
      "player1Cash": +2
    }
  }
}
```
**大小：** 约350字节

**建造房屋操作：**
```json
{
  "actionId": "action_5",
  "type": "buildHouse",
  "timestamp": "2026-04-11T10:10:20.000Z",
  "playerId": "player_1",
  "details": {
    "propertyIndex": 1,
    "propertyName": "拉萨",
    "housesBefore": 0,
    "housesAfter": 1,
    "cost": 50
  },
  "result": {
    "success": true,
    "changes": {
      "playerCash": -50,
      "houses": +1
    }
  }
}
```
**大小：** 约300字节

**抽卡操作：**
```json
{
  "actionId": "action_6",
  "type": "drawCard",
  "timestamp": "2026-04-11T10:15:30.000Z",
  "playerId": "player_1",
  "details": {
    "cardType": "chance",
    "cardName": "前进到起点",
    "cardDescription": "前进到起点，获得200元",
    "effect": {
      "type": "moveTo",
      "position": 0,
      "collectMoney": 200
    }
  },
  "result": {
    "success": true,
    "changes": {
      "playerPosition": 0,
      "playerCash": +200
    }
  }
}
```
**大小：** 约400字节

**平均操作记录大小：** 约300字节

**操作数量估算：**
- 50回合
- 每回合平均5个操作（掷骰子、移动、购买/支付租金、建造、抽卡等）
- 总操作数：50 × 5 = 250个操作

**操作记录总计：** 300字节 × 250 = 75KB

---

### 1.4 统计信息（约1KB）

```json
{
  "statistics": {
    "totalTurns": 50,
    "duration": "1:30:00",
    "totalDiceRolls": 150,
    "totalDoubles": 15,
    "totalPropertiesBought": 20,
    "totalHousesBuilt": 30,
    "totalRentPaid": 500,
    "totalTaxPaid": 300,
    "totalTimesInJail": 5,
    "totalCardsDrawn": 15,
    "playerStats": {
      "player_1": {
        "diceRolls": 50,
        "doubles": 5,
        "propertiesBought": 8,
        "housesBuilt": 15,
        "rentCollected": 300,
        "rentPaid": 100,
        "taxPaid": 100,
        "timesInJail": 2,
        "cardsDrawn": 5,
        "timesAroundBoard": 3,
        "maxCash": 2000,
        "minCash": 500
      },
      "player_2": { ... },
      "player_3": { ... }
    }
  }
}
```

**大小估算：** 约1KB

---

### 1.5 单局游戏记录总大小

| 组成部分 | 大小 |
|---------|------|
| 游戏基本信息 | 0.5KB |
| 回合记录 | 20KB |
| 操作记录 | 75KB |
| 统计信息 | 1KB |
| **总计** | **约96.5KB** |

**取整估算：** 约100KB/局

---

## 二、100局游戏总存储空间

### 2.1 未压缩情况

**单局游戏：** 约100KB  
**100局游戏：** 100KB × 100 = **10MB**

---

### 2.2 压缩后情况

**JSON压缩率：** 通常可压缩到原大小的20-30%

**使用gzip压缩：**
- 压缩率：约25%
- 压缩后大小：10MB × 0.25 = **2.5MB**

---

### 2.3 优化后情况

#### 优化方案1：精简字段名

**原始：**
```json
{
  "actionId": "action_1",
  "type": "rollDice",
  "timestamp": "2026-04-11T10:00:06.000Z",
  "playerId": "player_1",
  "details": {
    "dice1": 3,
    "dice2": 4,
    "isDoubles": false
  }
}
```

**精简后：**
```json
{
  "id": "a1",
  "t": "roll",
  "ts": "2026-04-11T10:00:06Z",
  "p": "p1",
  "d": {
    "d1": 3,
    "d2": 4,
    "db": false
  }
}
```

**优化效果：** 减少约40%大小  
**优化后大小：** 10MB × 0.6 = **6MB**

---

#### 优化方案2：二进制格式

**使用MessagePack或Protobuf：**
- 比JSON更紧凑
- 解析速度更快
- 压缩率更高

**优化效果：** 减少约60%大小  
**优化后大小：** 10MB × 0.4 = **4MB**

---

#### 优化方案3：增量存储

**只存储状态变化：**
- 不存储完整的状态快照
- 只存储每次操作的变化量

**优化效果：** 减少约50%大小  
**优化后大小：** 10MB × 0.5 = **5MB**

---

### 2.4 最佳优化方案

**组合优化：精简字段 + 压缩**

**优化后大小：** 6MB × 0.25 = **1.5MB**

---

## 三、不同场景下的存储需求

### 3.1 按玩家数量

| 玩家数 | 单局大小 | 100局大小 | 压缩后 |
|--------|---------|-----------|--------|
| 2人 | 80KB | 8MB | 2MB |
| 3人 | 100KB | 10MB | 2.5MB |
| 4人 | 120KB | 12MB | 3MB |

---

### 3.2 按游戏局数

| 局数 | 未压缩 | 压缩后 | 优化后 |
|------|--------|--------|--------|
| 10局 | 1MB | 250KB | 150KB |
| 50局 | 5MB | 1.25MB | 750KB |
| 100局 | 10MB | 2.5MB | 1.5MB |
| 500局 | 50MB | 12.5MB | 7.5MB |
| 1000局 | 100MB | 25MB | 15MB |

---

### 3.3 按游戏时长

**假设：**
- 平均每局游戏50回合
- 平均每回合5个操作
- 平均每局游戏时长1.5小时

| 游戏时长 | 回合数 | 单局大小 |
|---------|--------|---------|
| 30分钟 | 20回合 | 40KB |
| 1小时 | 35回合 | 70KB |
| 1.5小时 | 50回合 | 100KB |
| 2小时 | 70回合 | 140KB |
| 3小时 | 100回合 | 200KB |

---

## 四、存储空间对比

### 4.1 与其他数据对比

| 数据类型 | 大小 |
|---------|------|
| 一张照片 | 2-5MB |
| 一首歌曲 | 3-5MB |
| 一段视频（1分钟） | 10-20MB |
| **100局游戏记录（未压缩）** | **10MB** |
| **100局游戏记录（压缩）** | **2.5MB** |
| **100局游戏记录（优化）** | **1.5MB** |

---

### 4.2 手机存储容量对比

| 手机容量 | 可存储游戏局数（优化后） |
|---------|------------------------|
| 16GB | 约100万局 |
| 32GB | 约200万局 |
| 64GB | 约400万局 |
| 128GB | 约800万局 |

---

## 五、存储方案建议

### 5.1 推荐方案

**方案：JSON + gzip压缩**

**优点：**
- ✅ 易于实现和维护
- ✅ 跨平台兼容性好
- ✅ 压缩效果明显（75%压缩率）
- ✅ 可读性好（解压后可读）

**实现：**
```dart
import 'dart:convert';
import 'dart:io';
import 'package:gzip/gzip.dart';

// 保存游戏记录
Future<void> saveGameRecord(GameRecord record) async {
  final json = jsonEncode(record.toJson());
  final compressed = gzip.encode(utf8.encode(json));
  
  final file = File('game_records/${record.gameId}.json.gz');
  await file.writeAsBytes(compressed);
}

// 加载游戏记录
Future<GameRecord> loadGameRecord(String gameId) async {
  final file = File('game_records/$gameId.json.gz');
  final compressed = await file.readAsBytes();
  final json = utf8.decode(gzip.decode(compressed));
  
  return GameRecord.fromJson(jsonDecode(json));
}
```

---

### 5.2 存储策略

#### 策略1：本地存储（推荐）

**适用场景：** 单机游戏，不需要云同步

**实现：**
- 使用文件系统存储
- 每局游戏一个文件
- 文件名：`game_YYYYMMDD_HHMMSS.json.gz`
- 定期清理旧记录（保留最近100局）

**存储位置：**
- Android: `/data/data/包名/files/game_records/`
- iOS: `Documents/game_records/`

---

#### 策略2：SQLite数据库

**适用场景：** 需要查询和统计

**实现：**
- 创建游戏记录表
- 创建操作记录表
- 创建索引加速查询

**优点：**
- ✅ 支持复杂查询
- ✅ 数据结构化
- ✅ 易于管理

**缺点：**
- ❌ 实现复杂度高
- ❌ 数据库文件可能较大

---

#### 策略3：云存储

**适用场景：** 需要多设备同步

**实现：**
- 使用Firebase或自建服务器
- 上传游戏记录到云端
- 支持多设备同步

**优点：**
- ✅ 数据安全
- ✅ 多设备同步
- ✅ 易于分享

**缺点：**
- ❌ 需要网络
- ❌ 服务器成本
- ❌ 隐私问题

---

## 六、总结

### 6.1 存储空间需求

**3个玩家，100局游戏：**
- 未压缩：约10MB
- gzip压缩：约2.5MB
- 优化后：约1.5MB

**结论：** 存储空间需求很小，完全可以接受

---

### 6.2 推荐方案

**最佳方案：** JSON + gzip压缩 + 本地文件存储

**理由：**
- ✅ 实现简单
- ✅ 存储效率高
- ✅ 易于维护
- ✅ 性能良好

---

### 6.3 实施建议

1. **第一阶段：** 实现基本的JSON存储
2. **第二阶段：** 添加gzip压缩
3. **第三阶段：** 实现自动清理旧记录

---

**文档版本：** v1.0  
**创建日期：** 2026-04-11  
**维护人员：** 开发团队
