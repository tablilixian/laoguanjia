# 物品系统 - 离线数据库优先方案深度分析报告

> 生成日期：2026-04-03
> 分析范围：完整物品系统（数据模型 / 本地数据库 / 仓库层 / 状态管理 / 同步引擎 / UI 层 / 数据库迁移）

---

## 一、系统架构总览

### 1.1 架构分层

```
┌─────────────────────────────────────────────────────────┐
│                    UI Layer (Pages)                      │
│  items_list_page | item_create_page | item_detail_page   │
│  item_stats_page | item_tags_page | item_locations_page  │
│  item_type_manage_page | item_ai_assistant_page          │
├─────────────────────────────────────────────────────────┤
│                 State Layer (Riverpod)                    │
│  offline_items_provider | paginated_items_provider       │
│  offline_item_detail_provider | offline_item_create_...  │
│  offline_item_stats_provider | offline_item_types_...    │
│  offline_locations_provider | offline_tags_provider      │
├─────────────────────────────────────────────────────────┤
│              Repository Layer (ItemRepository)            │
│  查询→本地DB | 写入→本地DB+标记syncPending | 同步→Supabase│
├─────────────────────────────────────────────────────────┤
│            Local DB Layer (Drift + SQLite)               │
│  AppDatabase | ItemsDao | LocationsDao | TagsDao         │
│  TypesDao | MembersDao | Extensions                      │
├─────────────────────────────────────────────────────────┤
│              Remote DB Layer (Supabase)                   │
│  household_items | item_locations | item_tags             │
│  item_type_configs | item_tag_relations                  │
└─────────────────────────────────────────────────────────┘
```

### 1.2 核心设计原则

- **离线优先（Offline-First）**：所有读写操作优先走本地 SQLite（Drift），网络恢复后自动同步到 Supabase
- **版本控制（Version Control）**：每条记录带 `version` 字段，用于冲突检测和增量同步
- **软删除（Soft Delete）**：通过 `deleted_at` 标记删除，确保同步时能正确传播删除操作
- **位图标签（Bitmap Tags）**：使用 `tags_mask` 整数位运算存储标签关系，避免关系表
- **双同步路径**：`ItemRepository.autoSync()` 和 `SyncEngine` 两套同步机制并存

---

## 二、数据模型层分析

### 2.1 核心模型

| 模型 | 文件 | 状态 |
|------|------|------|
| `HouseholdItem` | `data/models/household_item.dart` | ✅ 完整 |
| `ItemLocation` | `data/models/item_location.dart` | ✅ 完整 |
| `ItemTag` | `data/models/item_tag.dart` | ✅ 完整 |
| `ItemTypeConfig` | `data/models/item_type_config.dart` | ✅ 完整 |

### 2.2 HouseholdItem 字段完整性

| 字段 | 本地DB | 远程DB | Model | 序列化 | 状态 |
|------|--------|--------|-------|--------|------|
| id | ✅ | ✅ | ✅ | ✅ | ✅ |
| household_id | ✅ | ✅ | ✅ | ✅ | ✅ |
| name | ✅ | ✅ | ✅ | ✅ | ✅ |
| description | ✅ | ✅ | ✅ | ✅ | ✅ |
| item_type | ✅ | ✅ | ✅ | ✅ | ✅ |
| location_id | ✅ | ✅ | ✅ | ✅ | ✅ |
| owner_id | ✅ | ✅ | ✅ | ✅ | ✅ |
| quantity | ✅ | ✅ | ✅ | ✅ | ✅ |
| brand | ✅ | ✅ | ✅ | ✅ | ✅ |
| model | ✅ | ✅ | ✅ | ✅ | ✅ |
| purchase_date | ✅ | ✅ | ✅ | ✅ | ✅ |
| purchase_price | ✅ | ✅ | ✅ | ✅ | ✅ |
| warranty_expiry | ✅ | ✅ | ✅ | ✅ | ✅ |
| condition | ✅ | ✅ | ✅ | ✅ | ✅ |
| image_url | ✅ | ✅ | ✅ | ✅ | ✅ |
| thumbnail_url | ✅ | ✅ | ✅ | ✅ | ✅ |
| notes | ✅ | ✅ | ✅ | ✅ | ✅ |
| sync_status | ✅ | ✅ | ✅ | ✅ | ✅ |
| remote_id | ✅ | ✅ | ✅ | ✅ | ✅ |
| created_by | ✅ | ✅ | ✅ | ✅ | ✅ |
| created_at | ✅ | ✅ | ✅ | ✅ | ✅ |
| updated_at | ✅ | ✅ | ✅ | ✅ | ✅ |
| deleted_at | ✅ | ✅ | ✅ | ✅ | ✅ |
| version | ✅ | ✅ | ✅ | ✅ | ✅ |
| sync_pending | ✅ | N/A | 计算属性 | ✅ | ✅ |
| tags_mask | ✅ | ✅ | ✅ | ✅ | ✅ |
| slot_position | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |

### 2.3 发现的问题

#### 🔴 问题 1：`slot_position` 序列化不一致

**文件**：`household_item.dart` → `toMap()` 方法

```dart
// toMap() 中：
'slot_position': slotPosition,  // Map<String, dynamic>
```

**问题**：`toMap()` 输出的是 `Map`，但 `toRemoteJson()`（extension）中：
```dart
'slot_position': slotPosition,  // 也是 Map
```

而在本地 DB 存储时（`item_repository.dart`）：
```dart
slotPosition: Value(newItem.slotPosition?.toString()),  // 转为字符串
```

**影响**：`slotPosition` 在本地 DB 中以 `.toString()` 存储（如 `{index: 4}`），但读取时 `parseSlotPosition` 尝试解析这种非标准格式。虽然当前有容错逻辑，但这是脆弱的设计。

**建议**：统一使用 `jsonEncode/jsonDecode` 处理 `slotPosition`，而非 `.toString()`。

#### 🟡 问题 2：`ItemLocation.toRemoteJson()` 硬编码 `version: 1`

**文件**：`item_location.dart` 第 189 行

```dart
Map<String, dynamic> toRemoteJson() {
  return {
    // ... 其他字段
    'version': 1,  // ⚠️ 硬编码为 1
  };
}
```

**影响**：位置更新同步到远程时，版本号始终为 1，无法正确参与版本冲突检测。

**建议**：`ItemLocation` 模型应包含 `version` 字段，并在 `toRemoteJson()` 中使用实际值。

#### 🟡 问题 3：`ItemTag.toRemoteJson()` 硬编码 `version: 1`

**文件**：`item_tag.dart` 第 117 行

```dart
'version': 1,  // ⚠️ 硬编码
```

**影响**：同上，标签同步时版本号不正确。

#### 🟡 问题 4：`ItemTypeConfig` 缺少 `version` 和 `updatedAt` 字段

**文件**：`item_type_config.dart`

模型中缺少 `version` 和 `updatedAt` 字段，但远程 DB 表（migration 022）已添加这些字段。

**影响**：类型配置同步时无法正确参与版本冲突检测。`toRemoteJson()` 中也硬编码了 `'version': 1`。

---

## 三、本地数据库层分析（Drift）

### 3.1 表结构

| 本地表 | 对应远程表 | Schema版本 | 状态 |
|--------|-----------|-----------|------|
| `HouseholdItems` | `household_items` | v1 | ✅ |
| `ItemLocations` | `item_locations` | v1 | ✅ |
| `ItemTags` | `item_tags` | v1 | ✅ |
| `ItemTypeConfigs` | `item_type_configs` | v1 | ✅ |
| `Members` | `members` | v3 | ✅ |
| `Tasks` | `tasks` | v1 | ✅ |

**Schema Version = 3**，迁移逻辑正确。

### 3.2 DAO 层

| DAO | 文件 | 主要方法 | 状态 |
|-----|------|---------|------|
| `ItemsDao` | `daos/items_dao.dart` | 14+ 方法 | ✅ |
| `LocationsDao` | `daos/locations_dao.dart` | 待确认 | 需检查 |
| `TagsDao` | `daos/tags_dao.dart` | 待确认 | 需检查 |
| `TypesDao` | `daos/types_dao.dart` | 待确认 | 需检查 |
| `MembersDao` | `daos/members_dao.dart` | 待确认 | 需检查 |

### 3.3 ItemsDao 方法清单

| 方法 | 用途 | 状态 |
|------|------|------|
| `getAll()` | 获取所有物品 | ✅ |
| `getById()` | 按ID获取 | ✅ |
| `watchAll()` / `watchById()` | 流式监听 | ✅ |
| `insertItem()` | 插入 | ✅ |
| `updateItem()` | 更新 | ✅ |
| `deleteItem()` | 删除 | ✅ |
| `getSyncPending()` | 获取待同步 | ✅ |
| `markSynced()` | 标记已同步 | ✅ |
| `upsertItemFromRemote()` | 远程数据写入本地 | ✅ |
| `getByHousehold()` | 按家庭获取 | ✅ |
| `getByHouseholdPaginated()` | 分页查询 | ✅ |
| `getCountByHousehold()` | 计数 | ✅ |
| `getByLocation()` / `getByType()` / `getByOwner()` | 按维度查询 | ✅ |
| `searchSmart()` | 智能搜索 | ✅ |
| `softDeleteWithVersion()` | 软删除+版本号 | ✅ |
| `getOverviewStats()` | 概览统计 | ✅ |
| `getCountByType()` | 按类型统计 | ✅ |
| `getCountByOwner()` | 按归属人统计 | ✅ |
| `getCountByLocation()` | 按位置统计 | ✅ |
| `getByTag()` / `getByAnyTag()` / `getByAllTags()` | 位图标签查询 | ✅ |

### 3.4 发现的问题

#### 🟡 问题 5：`getByHouseholdPaginated()` 中存在重复的筛选条件

**文件**：`items_dao.dart` 第 175-196 行

```dart
if (itemType != null && itemType.isNotEmpty) {
  query.where((i) => i.itemType.equals(itemType));
}
if (locationIds != null && locationIds.isNotEmpty) {
  query.where((i) => i.locationId.isIn(locationIds));
} else if (locationId != null && locationId.isNotEmpty) {
  query.where((i) => i.locationId.equals(locationId));
}
if (ownerId != null && ownerId.isNotEmpty) {
  query.where((i) => i.ownerId.equals(ownerId));
}
// ⚠️ 以下重复了一次
if (itemType != null && itemType.isNotEmpty) {
  query.where((i) => i.itemType.equals(itemType));
}
if (locationId != null && locationId.isNotEmpty) {
  query.where((i) => i.locationId.equals(locationId));
}
if (ownerId != null && ownerId.isNotEmpty) {
  query.where((i) => i.ownerId.equals(ownerId));
}
```

**影响**：重复的 `where` 条件虽然不会导致错误（Drift 会合并），但代码冗余，影响可读性和维护性。

**建议**：删除第 188-196 行的重复代码块。

#### 🟡 问题 6：`ItemLocations` 表缺少 `deletedAt` 字段

**文件**：`tables/item_locations.dart`

位置表没有 `deletedAt` 字段，但 `deleteLocation()` 方法执行的是硬删除：

```dart
Future<void> deleteLocation(String id) async {
  await _localDb.locationsDao.deleteLocation(id);  // 硬删除
}
```

**影响**：
1. 位置被硬删除后，如果该位置下有物品，物品的 `location_id` 变为悬空引用
2. 多端同步时，一端删除位置，另一端无法感知（因为没有软删除标记传播）
3. 远程 DB 表也没有 `deleted_at` 字段（migration 017），但 sync 触发器（migration 024）会在 UPDATE 时递增 version

**建议**：为位置表添加软删除支持，或在删除位置时级联更新关联物品。

#### 🟡 问题 7：`ItemLocations` 表缺少 `deletedAt` 字段导致同步不完整

远程 `item_locations` 表在 migration 017 中没有 `deleted_at` 字段，但 migration 022 添加了 `version`。这意味着位置删除无法通过版本号机制正确同步。

---

## 四、仓库层分析（ItemRepository）

### 4.1 职责划分

| 职责 | 实现 | 状态 |
|------|------|------|
| 查询（读） | 全部走本地 DB | ✅ |
| 写入（CRUD） | 写入本地 DB + 标记 syncPending | ✅ |
| 同步（Sync） | `autoSync()` 方法 | ✅ |
| 远程回退 | 本地为空时拉取远程 | ✅ |
| 数据组装 | 位置路径、标签解析、成员映射 | ✅ |

### 4.2 同步流程

```
写操作（create/update/delete）
    ↓
写入本地 SQLite
    ↓
标记 syncPending=true, syncStatus=pending
    ↓
触发 _triggerAutoSync()
    ↓
autoSync(householdId)
    ↓
1. 同步 Locations（并行）
2. 同步 Tags（并行）
3. 同步 TypeConfigs（并行）
4. 同步 Items（依赖上述数据）
    ↓
对于每个 pending item:
  - 查询远程状态
  - 本地 version > 远程 version → 推送
  - 本地 version ≤ 远程 version → 拉取
  - 远程不存在 → 插入
  - 本地已删除 → 推送软删除
```

### 4.3 发现的问题

#### 🔴 问题 8：两套同步机制并存，可能冲突

**文件**：
- `ItemRepository.autoSync()` — 物品模块内置同步
- `SyncEngine.syncItems()` — 全局同步引擎

两套机制都实现了物品同步逻辑，但实现细节不同：

| 特性 | ItemRepository.autoSync() | SyncEngine.syncItems() |
|------|--------------------------|----------------------|
| 触发方式 | 写操作后自动触发 | 定时/手动触发 |
| 同步顺序 | 先 locations/tags/types，再 items | 先 push，再 pull，再 locations/tags/types |
| 冲突解决 | 基于 version 比较 | 基于 version + updatedAt 比较 |
| 多端同步 | `_pullRemoteItemChanges()` | `pullItems(localVersion)` |
| 错误处理 | 单物品失败不影响其他 | 收集 errors 列表 |

**影响**：
1. `SyncScheduler` 调用的是 `SyncEngine.syncTasks()`（只同步任务，不同步物品！）
2. 物品的自动同步依赖 `ItemRepository.autoSync()`，但这是由写操作触发的
3. 如果用户长时间不执行写操作，`SyncScheduler` 的 5 分钟定时同步不会同步物品

**建议**：
- 统一同步机制，让 `SyncScheduler` 也调用物品的同步
- 或者让 `SyncEngine.syncItems()` 被 `SyncScheduler.sync()` 调用

#### 🟡 问题 9：`_syncItems()` 中批量插入失败后未正确标记

**文件**：`item_repository.dart` 第 1234-1244 行

```dart
if (itemsToInsert.isNotEmpty) {
  try {
    await _client.from('household_items').insert(itemsToInsert);
    for (final item in itemsToInsert) {
      await _localDb.itemsDao.markSynced(item['id']);
    }
  } catch (e) {
    print('❌ [云端同步] 插入失败: $e');
    // ⚠️ 没有标记为 error 状态，下次还会重试
  }
}
```

**影响**：批量插入失败后，所有物品的 `syncPending` 仍为 `true`，下次同步会无限重试。如果失败原因是数据结构问题（如字段缺失），会造成死循环。

**建议**：插入失败时，将相关物品标记为 `syncStatus = error`，而非保持 `pending`。

#### 🟡 问题 10：`_syncTags()` 中 `tag_index` 未同步到远程

**文件**：`item_repository.dart` 第 1411-1423 行

```dart
final remoteData = {
  'id': tag.id,
  'household_id': tag.householdId,
  'name': tag.name,
  'color': tag.color,
  'icon': tag.icon,
  'category': tag.category,
  'applicable_types': applicableTypes,
  'tag_index': tag.tagIndex,  // ✅ 有包含
  // ...
};
```

实际上 `tag_index` 是包含了的，但 `toRemoteJson()` extension 中也包含了。不过 `_syncTagToLocal()` 中：

```dart
await _localDb.tagsDao.insertOrUpdateTag(
  db.ItemTagsCompanion(
    // ...
    tagIndex: Value(tag.tagIndex),
    // ...
  ),
);
```

**状态**：✅ 经过仔细检查，`tag_index` 的同步链路是完整的。

#### 🟡 问题 11：`initialize()` 增量同步未处理远程软删除

**文件**：`item_repository.dart` 第 1701-1731 行

```dart
Future<void> _fetchAndSyncRemoteItemsIncremental(String householdId) async {
  // ...
  .isFilter('deleted_at', null)  // ⚠️ 只拉取未删除的
  // ...
}
```

**影响**：如果远程有物品被其他设备软删除了，增量同步不会拉取这些删除记录，导致本地保留了已被删除的物品。

**建议**：增量同步应也检查远程的软删除记录，或者使用版本号机制（`_pullRemoteItemChanges` 已经做了部分工作）。

#### 🟡 问题 12：`_fetchRemoteTags()` 未查询 `updated_at` 和 `version`

**文件**：`item_repository.dart` 第 1633-1649 行

```dart
final response = await _client
    .from('item_tags')
    .select(
      'id, household_id, name, color, icon, category, applicable_types, created_at, tag_index',
    )
```

**影响**：缺少 `updated_at` 和 `version` 字段，导致：
1. `ItemTag.fromMap()` 中 `updatedAt` 回退到 `createdAt`（见 `item_tag.dart` 第 84-86 行）
2. 版本冲突检测可能不准确

**建议**：在 select 中添加 `updated_at, version, deleted_at`。

---

## 五、状态管理层分析（Riverpod Providers）

### 5.1 Provider 清单

| Provider | 类型 | 职责 | 状态 |
|----------|------|------|------|
| `offlineItemsProvider` | StateNotifier | 物品列表 CRUD + 同步 | ✅ |
| `paginatedItemsProvider` | StateNotifier | 分页物品列表 | ✅ |
| `offlineItemDetailProvider` | FutureProvider | 单个物品详情 | ✅ |
| `itemCreateProvider` | StateNotifier | 物品创建/编辑 | ✅ |
| `offlineItemStatsProvider` | FutureProvider | 物品统计 | ✅ |
| `itemTypesProvider` | FutureProvider | 类型列表 | ✅ |
| `offlineLocationsProvider` | StateNotifier | 位置 CRUD | ✅ |
| `offlineTagsProvider` | StateNotifier | 标签 CRUD | ✅ |
| `offlineItemRepositoryProvider` | Provider | Repository 单例 | ✅ |

### 5.2 发现的问题

#### 🟡 问题 13：`offlineItemsProvider` 的 `filteredItems` 与分页查询重复

**文件**：`offline_items_provider.dart` 第 71-97 行

`ItemsState.filteredItems` 在内存中执行过滤和排序，但 `paginatedItemsProvider` 已经通过 DB 层做了高效的分页过滤。

**影响**：两套过滤逻辑并存，可能导致不一致。`offlineItemsProvider` 加载所有物品到内存后过滤，而 `paginatedItemsProvider` 使用 DB 分页。

**建议**：明确分工——`offlineItemsProvider` 用于全量数据（小数据量场景），`paginatedItemsProvider` 用于列表展示。或者统一使用分页方案。

#### 🟡 问题 14：`batchSetTags()` 中重复读 DB

**文件**：`offline_items_provider.dart` 第 527-532 行

```dart
// setItemTags 内部已经处理了版本号递增和 syncPending 标记
await _repository.setItemTags(itemId, tagIds);

// 重新从本地数据库读取更新后的物品
final allItems = await _repository.getItems(householdId);
final updatedItem = allItems.firstWhere(...);
```

**影响**：每个物品执行 `batchSetTags` 时都会重新读取整个物品列表（O(n²) 复杂度）。批量设置 10 个物品 = 10 次全表扫描。

**建议**：`setItemTags` 方法应返回更新后的物品对象，避免重复查询。

---

## 六、同步引擎分析

### 6.1 SyncEngine vs ItemRepository 同步对比

| 维度 | SyncEngine | ItemRepository |
|------|-----------|----------------|
| 设计目标 | 全局统一同步 | 物品模块专用 |
| 调用方 | SyncScheduler | 写操作后自动触发 |
| 同步策略 | pull-push 分离 | 混合 push-pull |
| 冲突检测 | version + updatedAt | version 比较 |
| 全量同步 | ✅ `forceFullSyncItems()` | ❌ 无 |
| 进度回调 | ✅ | ❌ |
| 错误聚合 | ✅ `SyncResult.errors` | ❌ 仅 print |

### 6.2 SyncScheduler 问题

#### 🔴 问题 15：SyncScheduler 只同步 Tasks，不同步 Items

**文件**：`sync_scheduler.dart` 第 65-77 行

```dart
Future<void> sync() async {
  if (_isSyncing || !_initialized || _syncEngine == null) return;
  _isSyncing = true;
  try {
    await _syncEngine!.syncTasks();  // ⚠️ 只同步任务！
    _lastSyncTime = DateTime.now();
  } catch (e) {
    print('同步失败: $e');
  } finally {
    _isSyncing = false;
  }
}
```

**影响**：
1. 5 分钟定时同步不会同步物品数据
2. 网络恢复触发的同步也不会同步物品
3. 物品的后台同步完全依赖写操作触发的 `autoSync()`
4. 如果用户只读不写，物品数据永远不会后台同步

**建议**：在 `SyncScheduler.sync()` 中添加 `await _syncEngine!.syncItems()`。

---

## 七、数据库迁移分析

### 7.1 物品相关迁移清单

| 迁移文件 | 内容 | 状态 |
|---------|------|------|
| `017_create_household_items.sql` | 5张表 + 索引 + RLS + 预设数据 | ✅ |
| `018_add_test_data_household_items.sql` | 测试数据 | ✅ |
| `022_add_items_version_control.sql` | 添加 version + updated_at | ✅ |
| `023_update_items_sync_versions.sql` | sync_versions 记录 + 版本索引 | ✅ |
| `024_create_items_triggers.sql` | 版本号递增 + sync_versions 更新触发器 | ✅ |
| `025_cleanup_sync_fields.sql` | 清理同步字段 | 需检查 |
| `026_fix_item_tag_relations_rls.sql` | 修复标签关联 RLS | ✅ |
| `027_add_tag_index_field.sql` | 添加 tag_index 字段 | 需检查 |

### 7.2 发现的问题

#### 🟡 问题 16：`item_tag_relations` 表存在但未被使用

**文件**：`017_create_household_items.sql` 创建了 `item_tag_relations` 表，但实际代码中使用的是 `tags_mask` 位图方案。

**影响**：
1. 数据库中存在无用的表和 RLS 策略
2. `026_fix_item_tag_relations_rls.sql` 还在修复一个不使用的表的 RLS
3. 增加了维护负担

**建议**：如果确定使用位图方案，可以删除 `item_tag_relations` 表及相关迁移。

#### 🟡 问题 17：`item_locations` 远程表缺少 `deleted_at` 和 `version` 字段

**文件**：`017_create_household_items.sql` 创建的位置表没有 `deleted_at` 和 `version`。

虽然 migration 022 添加了 `version` 和 `updated_at`，但没有添加 `deleted_at`。

**影响**：位置删除无法通过同步机制传播到其他设备。

---

## 八、位图标签系统分析

### 8.1 TagsMaskHelper

**文件**：`data/utils/tags_mask_helper.dart`

| 方法 | 功能 | 状态 |
|------|------|------|
| `addTag()` | 添加标签 | ✅ |
| `removeTag()` | 移除标签 | ✅ |
| `hasTag()` | 检查标签 | ✅ |
| `getTagIds()` | 获取所有标签ID | ✅ |
| `createMask()` | 从ID列表生成mask | ✅ |
| `hasAnyTag()` | OR查询 | ✅ |
| `hasAllTags()` | AND查询 | ✅ |
| `updateMask()` | 替换标签 | ✅ |
| `getTagCount()` | 标签计数 | ✅ |

### 8.2 发现的问题

#### 🟡 问题 18：BigInt 转换可能丢失精度

**文件**：`tags_mask_helper.dart` 第 29-30 行

```dart
final shiftMask = BigInt.from(1) << tagId;
return currentMask | shiftMask.toInt();  // ⚠️ toInt() 可能溢出
```

**影响**：在 Dart 中，`int` 在 Web 平台是 53 位精度，在原生平台是 64 位。当 `tagId >= 53` 时，`BigInt.toInt()` 在 Web 平台会丢失精度。

**建议**：
1. 明确限制最多支持 31 个标签（安全范围）或 53 个标签（Web 安全）
2. 或者在 Web 平台使用 BigInt 存储 mask

#### 🟡 问题 19：`tagIndex` 上限未做校验

标签的 `tagIndex` 范围为 0-62（64 位），但创建标签时（`createTag` 方法）：

```dart
final tagIndex = await _localDb.tagsDao.getNextTagIndex(tag.householdId);
if (tagIndex == null) {
  throw Exception('标签数量已达上限（最多63个）');
}
```

**状态**：✅ 有校验。但删除标签后，`tagIndex` 是否会被回收？如果不会，用户删除标签后新建标签仍会消耗新的 index，最终达到上限。

**建议**：实现 tagIndex 回收机制，或在文档中明确说明。

---

## 九、UI 层分析

### 9.1 页面清单

| 页面 | 文件 | 功能 | 状态 |
|------|------|------|------|
| 物品列表 | `items_list_page.dart` | 列表展示 + 筛选 | ✅ |
| 创建物品 | `item_create_page.dart` | 创建表单 | ✅ |
| 物品详情 | `item_detail_page.dart` | 详情展示 + 编辑 | ✅ |
| 物品统计 | `item_stats_page.dart` | 统计图表 | ✅ |
| 标签管理 | `item_tags_page.dart` | 标签 CRUD | ✅ |
| 位置管理 | `item_locations_page.dart` | 位置 CRUD | ✅ |
| 类型管理 | `item_type_manage_page.dart` | 类型配置 | ✅ |
| AI 助手 | `item_ai_assistant_page.dart` | AI 辅助 | ✅ |

### 9.2 同步 UI 组件

| 组件 | 文件 | 功能 | 状态 |
|------|------|------|------|
| 离线横幅 | `offline_banner.dart` | 离线提示 | ✅ |
| 同步操作栏 | `sync_action_bar.dart` | 手动同步按钮 + 状态 | ✅ |
| 同步状态指示器 | `sync_status_indicator.dart` | 状态图标 | ✅ |
| 同步刷新指示器 | `sync_refresh_indicator.dart` | 下拉刷新 | ✅ |
| 同步状态徽章 | `sync_status_badge.dart` | 同步状态标签 | ✅ |
| 同步错误 Snackbar | `sync_error_snackbar.dart` | 错误提示 | ✅ |
| 同步错误边界 | `sync_error_boundary.dart` | 错误捕获 | ✅ |

---

## 十、总结与建议

### 10.1 完成度评估

| 模块 | 完成度 | 评价 |
|------|--------|------|
| 数据模型 | 90% | 核心字段完整，部分模型缺少 version |
| 本地数据库 | 95% | Drift 表结构完善，DAO 方法丰富 |
| 仓库层 | 85% | CRUD 完整，同步逻辑有冗余和边界情况 |
| 状态管理 | 90% | Provider 覆盖全面，有重复逻辑 |
| 同步引擎 | 75% | 双机制并存，SyncScheduler 未覆盖物品 |
| 数据库迁移 | 90% | 版本控制和触发器完善，有未使用表 |
| UI 层 | 95% | 页面和组件齐全 |
| 位图标签 | 85% | 工具类完整，有精度风险 |
| **总体** | **88%** | **离线优先方案基本可用，需修复关键问题** |

### 10.2 必须修复（🔴 高优先级）

| # | 问题 | 影响 | 修复难度 |
|---|------|------|---------|
| 1 | `SyncScheduler` 不同步物品 | 后台定时同步不生效，物品数据可能过期 | 低 |
| 2 | 两套同步机制并存 | 可能产生冲突和重复同步 | 中 |
| 3 | `slot_position` 序列化不一致 | 数据损坏风险 | 低 |
| 4 | 批量插入失败后未标记 error | 无限重试死循环 | 低 |
| 5 | 增量同步未处理远程软删除 | 多端数据不一致 | 中 |

### 10.3 建议优化（🟡 中优先级）

| # | 问题 | 影响 | 修复难度 |
|---|------|------|---------|
| 6 | `ItemLocation`/`ItemTag`/`ItemTypeConfig` 模型缺少 version | 版本冲突检测不准确 | 低 |
| 7 | `getByHouseholdPaginated()` 重复筛选条件 | 代码冗余 | 低 |
| 8 | 位置表缺少软删除 | 多端删除不一致 | 中 |
| 9 | `batchSetTags()` O(n²) 复杂度 | 批量操作性能差 | 低 |
| 10 | `_fetchRemoteTags()` 缺少 version/updated_at | 数据不完整 | 低 |
| 11 | `item_tag_relations` 表未使用 | 数据库维护负担 | 低 |
| 12 | BigInt 精度风险 | Web 平台标签可能出错 | 中 |
| 13 | tagIndex 回收机制缺失 | 标签上限可能提前到达 | 中 |
| 14 | `filteredItems` 与分页重复 | 内存浪费，逻辑不一致 | 低 |

### 10.4 架构建议

1. **统一同步机制**：将 `ItemRepository.autoSync()` 和 `SyncEngine.syncItems()` 合并为一个，由 `SyncScheduler` 统一调度
2. **完善模型字段**：为 `ItemLocation`、`ItemTag`、`ItemTypeConfig` 添加 `version` 和 `updatedAt` 字段
3. **位置软删除**：为位置表添加 `deleted_at` 支持
4. **错误状态管理**：同步失败时标记 `syncStatus = error`，而非保持 `pending`
5. **清理未使用代码**：移除 `item_tag_relations` 相关迁移和 RLS 策略
6. **添加集成测试**：当前有 `offline_item_repository_test.dart` 和 `offline_scenario_test.dart`，建议增加多端冲突场景测试

---

*报告结束*
