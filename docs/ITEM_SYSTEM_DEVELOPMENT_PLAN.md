# 物品系统优化开发计划

> 版本：v1.0
> 创建日期：2026-03-25
> 目标：在保证本地和云端数据一致的前提下，提升用户体验（离线可用、快速响应）

---

## 一、现状分析与痛点

### 1.1 离线脆弱性 🔴 严重

**问题描述**：
`offline_item_repository.dart` 中的 `getLocations`、`getTags`、`getTypeConfigs`、`getItem` 等方法在本地无数据时会尝试从远程拉取。如果用户首次启动 App 时没有网络，或远程请求超时，这些方法会直接抛出异常，导致 UI 界面崩溃。

**受影响的方法**：
- `getLocations(householdId)` - 位置列表加载失败
- `getTags(householdId)` - 标签列表加载失败  
- `getTypeConfigs(householdId)` - 类型配置加载失败
- `getItem(id)` - 物品详情加载失败

**预期行为**：
- 远程失败时，应该返回本地缓存数据（即使为空）
- 绝不抛出异常给 UI 层
- 显示合适的空状态或错误提示

### 1.2 性能瓶颈 🟠 高危

**问题 1：统计功能内存计算**
```dart
// 当前实现（Bad）
Future<Map<String, dynamic>> getItemOverview(String householdId) async {
  final items = await _localDb.itemsDao.getByHousehold(householdId); // 加载所有数据
  final activeItems = items.where((i) => i.deletedAt == null).toList();
  // ... 遍历计数
}
```
- 加载 1000 条数据到内存只是为了计数
- 内存占用高，速度慢

**问题 2：列表无分页**
- `getItems()` 一次性返回所有数据
- 数据量大时渲染卡顿

**问题 3：搜索大小写敏感**
- `items_dao.dart` 的 `search` 方法使用 `contains`，默认大小写敏感
- 用户输入 "iphone" 搜不到 "iPhone"

### 1.3 同步效率 🟠 中高危

**N+1 请求问题**：
```dart
// 当前实现（Bad）
for (final itemId in itemsToPull) {
  final remoteItem = await _fetchRemoteItem(itemId); // 每个物品一个请求
}
```

**全量同步**：
- 每次同步拉取所有数据，而非增量同步
- 流量消耗大，速度慢

---

## 二、开发计划

### 第一阶段：基础加固与性能优化 (Sprint 1)

#### 任务 1.1：修复离线崩溃问题 ⚡ 紧急

**目标**：确保所有远程请求失败时都能优雅降级

**修改文件**：
- `lib/data/repositories/offline_item_repository.dart`

**具体修改**：

```dart
// 1. 修改 getLocations 方法
Future<List<ItemLocation>> getLocations(String householdId) async {
  try {
    final localLocations = await _localDb.locationsDao.getByHousehold(householdId);
    if (localLocations.isNotEmpty) {
      return localLocations.map((l) => l.toItemLocationModel()).toList();
    }
  } catch (e) {
    print('🔴 [OfflineItemRepository] 获取本地位置失败: $e');
  }

  // 添加 try-catch 包裹远程请求
  try {
    final remoteLocations = await _fetchRemoteLocations(householdId);
    for (final location in remoteLocations) {
      await _syncLocationToLocal(location);
    }
    return remoteLocations;
  } catch (e) {
    print('🔴 [OfflineItemRepository] 获取远程位置失败，返回空列表: $e');
    return []; // 降级返回空列表
  }
}

// 2. 修改 getTags 方法（类似结构）
// 3. 修改 getTypeConfigs 方法（类似结构）
// 4. 修改 getItem 方法
```

**验收标准**：
- [ ] 飞行模式下首次启动 App，不崩溃
- [ ] 位置/标签/类型列表显示为空，但可正常操作
- [ ] 物品详情加载失败时显示"离线模式"提示

---

#### 任务 1.2：统计功能 SQL 化 ⚡ 高优先级

**目标**：将统计计算从内存遍历改为 SQL 聚合查询

**修改文件**：
- `lib/data/local_db/daos/items_dao.dart` - 添加统计查询方法
- `lib/data/repositories/offline_item_repository.dart` - 调用新的 DAO 方法

**具体修改**：

```dart
// items_dao.dart 添加方法

/// 获取物品总览统计（SQL 聚合）
Future<ItemOverviewStats> getOverviewStats(String householdId) async {
  // 总数
  final totalQuery = selectOnly(householdItems)
    ..addColumns([countAll()])
    ..where(householdItems.householdId.equals(householdId))
    ..where(householdItems.deletedAt.isNull());
  final total = await totalQuery.map((row) => row.read(countAll())!).getSingle();

  // 本月新增
  final thisMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final newThisMonthQuery = selectOnly(householdItems)
    ..addColumns([countAll()])
    ..where(householdItems.householdId.equals(householdId))
    ..where(householdItems.deletedAt.isNull())
    ..where(householdItems.createdAt.isBiggerThanValue(thisMonth));
  final newThisMonth = await newThisMonthQuery.map((row) => row.read(countAll())!).getSingle();

  // 需关注（保修 30 天内到期）
  final thirtyDaysLater = DateTime.now().add(const Duration(days: 30));
  final attentionQuery = selectOnly(householdItems)
    ..addColumns([countAll()])
    ..where(householdItems.householdId.equals(householdId))
    ..where(householdItems.deletedAt.isNull())
    ..where(householdItems.warrantyExpiry.isSmallerOrEqualValue(thirtyDaysLater));
  final attentionNeeded = await attentionQuery.map((row) => row.read(countAll())!).getSingle();

  return ItemOverviewStats(
    total: total,
    newThisMonth: newThisMonth,
    attentionNeeded: attentionNeeded,
  );
}

/// 按类型统计（SQL GROUP BY）
Future<List<TypeCount>> getCountByType(String householdId) async {
  final query = selectOnly(householdItems)
    ..addColumns([householdItems.itemType, countAll()])
    ..where(householdItems.householdId.equals(householdId))
    ..where(householdItems.deletedAt.isNull())
    ..groupBy([householdItems.itemType])
    ..orderBy([OrderingTerm.desc(countAll())]);
  
  return query.map((row) => TypeCount(
    typeKey: row.read(householdItems.itemType)!,
    count: row.read(countAll())!,
  )).get();
}

/// 按归属人统计（SQL GROUP BY）
Future<List<OwnerCount>> getCountByOwner(String householdId) async {
  final query = selectOnly(householdItems)
    ..addColumns([householdItems.ownerId, countAll()])
    ..where(householdItems.householdId.equals(householdId))
    ..where(householdItems.deletedAt.isNull())
    ..groupBy([householdItems.ownerId])
    ..orderBy([OrderingTerm.desc(countAll())]);
  
  return query.map((row) => OwnerCount(
    ownerId: row.read(householdItems.ownerId),
    count: row.read(countAll())!,
  )).get();
}
```

**验收标准**：
- [ ] 统计查询不加载完整物品数据到内存
- [ ] 1000+ 物品时统计响应 < 100ms
- [ ] 统计结果准确性与原实现一致

---

#### 任务 1.3：列表分页支持

**目标**：`getItems` 支持分页加载

**修改文件**：
- `lib/data/local_db/daos/items_dao.dart`
- `lib/data/repositories/offline_item_repository.dart`
- `lib/features/items/providers/offline_items_provider.dart`

**具体修改**：

```dart
// items_dao.dart

/// 分页获取物品
Future<List<HouseholdItem>> getByHouseholdPaginated(
  String householdId, {
  required int limit,
  required int offset,
  String? searchQuery,
  String? itemType,
  String? locationId,
  String? ownerId,
}) {
  final query = select(householdItems)
    ..where((i) => i.householdId.equals(householdId) & i.deletedAt.isNull());
  
  if (searchQuery != null && searchQuery.isNotEmpty) {
    query.where((i) => i.name.contains(searchQuery));
  }
  if (itemType != null) {
    query.where((i) => i.itemType.equals(itemType));
  }
  if (locationId != null) {
    query.where((i) => i.locationId.equals(locationId));
  }
  if (ownerId != null) {
    query.where((i) => i.ownerId.equals(ownerId));
  }
  
  query.limit(limit, offset: offset);
  return query.get();
}

/// 获取筛选后的总数
Future<int> getCountByHousehold(
  String householdId, {
  String? searchQuery,
  String? itemType,
  String? locationId,
  String? ownerId,
}) {
  final query = selectOnly(householdItems)
    ..addColumns([countAll()])
    ..where(householdItems.householdId.equals(householdId))
    ..where(householdItems.deletedAt.isNull());
  
  // 添加筛选条件...
  
  return query.map((row) => row.read(countAll())!).getSingle();
}
```

**验收标准**：
- [ ] 首次加载只显示前 20 条
- [ ] 滚动到底部自动加载更多
- [ ] 加载指示器显示"加载中..."
- [ ] 无更多数据时显示"已加载全部"

---

#### 任务 1.4：搜索优化

**目标**：修复大小写敏感，支持多字段搜索

**修改文件**：
- `lib/data/local_db/tables/household_items.dart` - 添加索引
- `lib/data/local_db/daos/items_dao.dart` - 修改搜索方法

**具体修改**：

```dart
// items_dao.dart

/// 智能搜索（大小写不敏感，多字段）
Future<List<HouseholdItem>> searchSmart(String householdId, String query) {
  final lowerQuery = query.toLowerCase();
  
  return (select(householdItems)
    ..where((i) => 
      i.householdId.equals(householdId) &
      i.deletedAt.isNull() &
      (
        i.name.lower().contains(lowerQuery) |
        i.brand.lower().contains(lowerQuery) |
        i.model.lower().contains(lowerQuery) |
        i.notes.lower().contains(lowerQuery)
      )
    ))
    ..limit(50) // 搜索结果限制
    .get();
}
```

**验收标准**：
- [ ] 输入 "iphone" 能搜到 "iPhone"
- [ ] 输入品牌名能搜到对应物品
- [ ] 搜索响应 < 50ms

---

### 第二阶段：同步机制升级 (Sprint 2)

#### 任务 2.1：增量同步

**目标**：只拉取自上次同步后的更新

**修改**：
- 添加 `last_synced_at` 字段到本地配置表
- `_fetchRemoteItems` 添加 `WHERE updated_at > last_synced_at` 条件

#### 任务 2.2：批量拉取

**目标**：解决 N+1 问题

**修改**：
- `autoSync` 中的 `itemsToPull` 改为批量拉取
- 使用 Supabase 的 `in` 查询一次获取多个物品

#### 任务 2.3：后台同步

**目标**：App 进入后台时也能同步

**修改**：
- 集成 `flutter_workmanager`
- 注册后台同步任务

---

### 第三阶段：架构重构 (Sprint 3)

#### 任务 3.1：Repository 拆分

**目标**：将 1200 行的 `offline_item_repository.dart` 拆分为多个 Service

**新文件结构**：
```
lib/data/services/
├── item_query_service.dart      # 只读操作：List, Search, Stats
├── item_command_service.dart    # 写操作：Create, Update, Delete
└── item_sync_service.dart       # 同步逻辑
```

**职责划分**：

**ItemQueryService**：
- `getItems()` - 获取物品列表（分页）
- `getItem()` - 获取单个物品
- `searchItems()` - 搜索物品
- `getItemOverview()` - 统计概览
- `getItemCountByType()` - 按类型统计
- `getItemCountByOwner()` - 按归属人统计
- `getLocations()` - 获取位置列表
- `getTags()` - 获取标签列表
- `getTypeConfigs()` - 获取类型配置

**ItemCommandService**：
- `createItem()` - 创建物品
- `updateItem()` - 更新物品
- `deleteItem()` - 删除物品
- `setItemTags()` - 设置物品标签
- `createLocation()` - 创建位置
- `updateLocation()` - 更新位置
- `deleteLocation()` - 删除位置
- `createTag()` - 创建标签
- `updateTag()` - 更新标签
- `deleteTag()` - 删除标签

**ItemSyncService**：
- `sync()` - 执行同步
- `pullUpdates()` - 拉取更新
- `pushChanges()` - 推送变更
- `resolveConflict()` - 解决冲突

---

## 三、数据模型补充

### 3.1 统计结果模型

```dart
// lib/data/models/item_stats.dart

class ItemOverviewStats {
  final int total;
  final int newThisMonth;
  final int attentionNeeded;

  const ItemOverviewStats({
    required this.total,
    required this.newThisMonth,
    required this.attentionNeeded,
  });
}

class TypeCount {
  final String typeKey;
  final int count;

  const TypeCount({required this.typeKey, required this.count});
}

class OwnerCount {
  final String? ownerId;
  final int count;

  const OwnerCount({this.ownerId, required this.count});
}
```

---

## 四、测试计划

### 4.1 单元测试

- [ ] `ItemQueryService` - 统计方法返回正确结果
- [ ] `ItemQueryService` - 分页逻辑正确
- [ ] `ItemQueryService` - 搜索大小写不敏感
- [ ] `ItemCommandService` - CRUD 操作正确
- [ ] `ItemSyncService` - 离线降级不抛异常

### 4.2 集成测试

- [ ] 飞行模式下完整流程测试
- [ ] 离线创建 -> 上线同步 -> 数据一致

### 4.3 性能测试

- [ ] 1000 条数据统计响应时间
- [ ] 列表滚动流畅度
- [ ] 搜索响应时间

---

## 五、风险与依赖

### 5.1 技术风险

- **SQL 聚合查询兼容性**：Drift 的 `countAll()` 等函数可能在不同平台有差异
  - 缓解：充分测试 iOS/Android 两端
- **分页状态管理**：Provider 状态可能变复杂
  - 缓解：使用 `PagedNotifier` 或类似模式

### 5.2 依赖

- Drift: 已有
- flutter_workmanager: 后台同步需要新增

---

## 六、验收标准

### 第一阶段完成标准

- [ ] 飞行模式下 App 正常启动和基本操作
- [ ] 统计功能响应时间 < 100ms（1000 条数据）
- [ ] 列表支持分页加载
- [ ] 搜索大小写不敏感
- [ ] 代码结构清晰，单个文件不超过 400 行

### 最终完成标准

- [ ] 所有单元测试通过
- [ ] 集成测试通过
- [ ] 性能测试达标
- [ ] 代码审查通过

---

## 七、时间线

| 阶段 | 任务 | 预计时间 | 状态 |
|------|------|----------|------|
| Sprint 1 | 修复离线崩溃 | 0.5 天 | 待开始 |
| Sprint 1 | 统计 SQL 化 | 1 天 | 待开始 |
| Sprint 1 | 列表分页 | 1 天 | 待开始 |
| Sprint 1 | 搜索优化 | 0.5 天 | 待开始 |
| Sprint 2 | 增量同步 | 1 天 | 待开始 |
| Sprint 2 | 批量拉取 | 0.5 天 | 待开始 |
| Sprint 2 | 后台同步 | 1 天 | 待开始 |
| Sprint 3 | Repository 拆分 | 1 天 | 待开始 |
| Sprint 3 | Provider 适配 | 1 天 | 待开始 |
| Sprint 3 | 测试与修复 | 1 天 | 待开始 |

**总计**：约 8.5 天

---

*文档结束*
