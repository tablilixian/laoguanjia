# 物品系统架构收紧 — 完整修改方案

> 目标：调用端对远端零感知，所有增删改查仅操作本地 DB，同步由独立层自动维护

---

## 一、当前问题全景图

### 1.1 同步触发散落在 15 处

| 文件 | 触发点 | 方式 |
|------|--------|------|
| `offline_items_provider.dart` | createItem / updateItem / deleteItem / batchXxx | `await _repository.autoSync()` |
| `offline_locations_provider.dart` | createLocation / updateLocation / deleteLocation | `await _repository.autoSync()` |
| `locations_provider.dart` | createLocation / updateLocation / deleteLocation | `await _repository.autoSync()` |
| `offline_tags_provider.dart` | createTag / updateTag / deleteTag | `_repository.autoSync()`（无 await） |
| `tags_provider.dart` | createTag / updateTag / deleteTag / restoreTag | `await _repository.autoSync()` |
| `items_list_page.dart` | 删除物品后 | `await repository.autoSync()` |

### 1.2 两套 Provider 并存（重复代码）

| 实体 | Provider A（使用中） | Provider B（未使用） |
|------|---------------------|---------------------|
| 位置 | `locationsProvider` ← UI 全部引用这个 | `offlineLocationsProvider` ← 无人引用 |
| 标签 | `tagsProvider` ← UI 全部引用这个 | `offlineTagsProvider` ← 无人引用 |

**结论**：`offline_*` 前缀的 providers 是旧版，实际 UI 用的都是无前缀版本。两套代码逻辑几乎相同，可以安全删除 `offline_locations_provider.dart` 和 `offline_tags_provider.dart`。

### 1.3 SyncScheduler 不同步物品

```dart
// sync_scheduler.dart L65-77
Future<void> sync() async {
  await _syncEngine!.syncTasks();  // ← 只同步任务！
}
```

5 分钟定时同步、网络恢复触发同步，全部只同步 tasks，物品完全不管。

### 1.4 Repository 存在"反向"远程方法

| 方法 | 方向 | 应该改为 |
|------|------|---------|
| `createItemType()` | 写远程→同步本地 | 写本地→同步远程 |
| `updateItemTypeConfig()` | 写远程→同步本地 | 写本地→同步远程 |
| `deleteItemType()` | 删远程→删本地 | 删本地→同步远程 |
| `deactivateItemType()` | 直接改远程 | 改本地→同步远程 |
| `getOccupiedSlots()` | 直接查远程 | 查本地 |
| `getItemTypes()` | 直接查远程 | 查本地 |
| `getAllItemTypes()` | 直接查远程 | 查本地 |

---

## 二、目标架构

```
┌──────────────────────────────────────────────────────┐
│                   UI Layer (Pages)                    │
│  只读/写 Provider，不感知同步，不调用 autoSync()       │
├──────────────────────────────────────────────────────┤
│              State Layer (Riverpod)                    │
│  ┌─────────────┐  ┌──────────┐  ┌─────────────────┐  │
│  │itemsProvider│  │locations │  │     tags        │  │
│  │paginated    │  │provider  │  │   provider      │  │
│  └──────┬──────┘  └────┬─────┘  └────────┬────────┘  │
│         │              │                 │            │
│         └──────────────┼─────────────────┘            │
│                        ↓                              │
│              ItemRepository（纯本地操作）               │
│  create/update/delete/get → 全部读写本地 SQLite        │
├──────────────────────────────────────────────────────┤
│              SyncWorker（独立同步层）                    │
│  ┌──────────────────────────────────────────────┐    │
│  │ SyncScheduler（定时 + 网络恢复触发）           │    │
│  │   ↓                                          │    │
│  │ SyncEngine（统一同步引擎）                     │    │
│  │   ├─ syncTasks()                             │    │
│  │   ├─ syncItems()  ← 新增                      │    │
│  │   ├─ syncLocations()                         │    │
│  │   ├─ syncTags()                              │    │
│  │   └─ syncTypeConfigs()                       │    │
│  └──────────────────────────────────────────────┘    │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │ Supabase Realtime Listener（新增）            │    │
│  │   监听远端变更 → 写入本地 DB                    │    │
│  └──────────────────────────────────────────────┘    │
├──────────────────────────────────────────────────────┤
│         Local DB (Drift/SQLite)    Remote (Supabase)  │
└──────────────────────────────────────────────────────┘
```

**核心原则**：
1. UI 层和 Provider 层不调用 `autoSync()`
2. Repository 层只暴露本地 CRUD 方法
3. 同步由 `SyncWorker` 独立层负责（定时 + 事件驱动 + Realtime）

---

## 三、数据库变更

### 3.1 远端 Supabase 表调整

#### 迁移文件：`028_item_locations_add_deleted_at.sql`（新建）

```sql
-- 为 item_locations 添加软删除支持
ALTER TABLE item_locations
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_locations_deleted_at ON item_locations(deleted_at);

-- 更新时间触发器已存在（017 迁移中已创建），version 触发器已存在（024 迁移中已创建）
```

**原因**：位置表目前没有 `deleted_at`，删除位置无法同步到其他设备。

#### 迁移文件：`029_drop_item_tag_relations.sql`（新建）

```sql
-- 删除已弃用的标签关联表
DROP TABLE IF EXISTS item_tag_relations;
```

**原因**：已迁移到位图方案（`tags_mask`），该表无任何代码引用。

### 3.2 本地 Drift 表调整

#### 修改：`lib/data/local_db/tables/item_locations.dart`

```dart
// 新增字段
DateTimeColumn get deletedAt => dateTime().nullable()();
```

#### 修改：`lib/data/local_db/app_database.dart`

```dart
// schemaVersion 从 3 提升到 4
@override
int get schemaVersion => 4;

@override
MigrationStrategy get migration => MigrationStrategy(
  // ... 现有逻辑 ...
  onUpgrade: (Migrator m, int from, int to) async {
    // ... 现有 v1→v2, v2→v3 ...
    if (from < 4) {
      await m.addColumn(itemLocations, itemLocations.deletedAt);
    }
  },
);
```

### 3.3 数据库变更影响文件清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `supabase_migrations/028_item_locations_add_deleted_at.sql` | 新建 | 远端添加 deleted_at |
| `supabase_migrations/029_drop_item_tag_relations.sql` | 新建 | 远端删除废弃表 |
| `lib/data/local_db/tables/item_locations.dart` | 修改 | 添加 deletedAt 列 |
| `lib/data/local_db/app_database.dart` | 修改 | schemaVersion 3→4 |
| `lib/data/local_db/daos/locations_dao.dart` | 修改 | 删除改为软删除 |
| `lib/data/repositories/item_repository.dart` | 修改 | deleteLocation 改为软删除 |
| `lib/data/models/item_location.dart` | 修改 | 添加 deletedAt 字段 |
| `lib/data/local_db/item_extensions.dart` | 修改 | 添加 deletedAt 映射 |

---

## 四、代码变更清单

### Phase 1：统一同步层（核心）

#### 4.1 修改 `SyncScheduler` — 加入物品同步

**文件**：`lib/core/sync/sync_scheduler.dart`

```dart
// 修改 sync() 方法
Future<void> sync() async {
  if (_isSyncing || !_initialized || _syncEngine == null) return;
  _isSyncing = true;
  try {
    await _syncEngine!.syncTasks();
    await _syncEngine!.syncItems();      // ← 新增
    await _syncEngine!.syncLocations();  // ← 新增
    await _syncEngine!.syncTags();       // ← 新增
    await _syncEngine!.syncTypes();      // ← 新增
    _lastSyncTime = DateTime.now();
  } catch (e) {
    print('同步失败: $e');
  } finally {
    _isSyncing = false;
  }
}
```

**影响**：5 分钟定时同步和网络恢复触发同步现在覆盖物品全模块。

#### 4.2 合并同步逻辑 — 让 SyncEngine 成为唯一同步入口

**文件**：`lib/core/sync/sync_engine.dart`

当前 `SyncEngine` 已有 `syncItems()`, `syncLocations()`, `syncTags()`, `syncTypes()` 方法，但 `ItemRepository.autoSync()` 有一套独立的同步逻辑。

**方案**：保留 `SyncEngine` 作为唯一同步引擎，`ItemRepository` 不再暴露 `autoSync()`。

具体做法：
1. 将 `ItemRepository.autoSync()` 中的 `_syncItems()` 逻辑（包含多端同步 `_pullRemoteItemChanges`）迁移到 `SyncEngine.syncItems()` 中
2. `ItemRepository` 删除 `autoSync()`、`_syncItems()`、`_syncLocations()`、`_syncTags()`、`_syncTypeConfigs()` 方法
3. 所有同步由 `SyncEngine` 统一处理

#### 4.3 写操作后自动触发同步 — 事件驱动

**方案 A（推荐）**：Repository 内部发布事件

```dart
// 在 ItemRepository 中
final StreamController<String> _syncTriggerController = 
    StreamController<String>.broadcast();

Stream<String> get onSyncTrigger => _syncTriggerController.stream;

// 每次写操作后触发
Future<HouseholdItem> createItem(HouseholdItem item) async {
  // ... 写入本地 ...
  _syncTriggerController.add(householdId);  // ← 发布事件
  return newItem;
}
```

```dart
// SyncWorker 监听事件
class SyncWorker {
  void initialize() {
    final repository = ItemRepository();
    repository.onSyncTrigger.listen((householdId) {
      _enqueueSync(householdId);  // 入队，防抖后执行
    });
  }
}
```

**方案 B（简单）**：Provider 层保留 autoSync 调用，但改为 fire-and-forget

保持当前 Provider 中 `autoSync()` 调用不变，但：
1. 去掉所有 `await`，改为 fire-and-forget
2. 添加防抖（500ms 内多次触发只执行一次）

**推荐方案 B**，改动量小，风险低。方案 A 更优雅但需要重构 Repository。

### Phase 2：清理 Repository 反向方法

#### 4.4 删除/改造反向远程方法

**文件**：`lib/data/repositories/item_repository.dart`

| 方法 | 操作 | 原因 |
|------|------|------|
| `getItemTypes()` | 改为查本地 | 已有 `getTypeConfigs()` 走本地 |
| `getAllItemTypes()` | 改为查本地 | 同上 |
| `createItemType()` | 删除 | 应使用 `createTypeConfig()`（写本地→同步） |
| `updateItemTypeConfig()` | 删除 | 应使用 `updateTypeConfig()`（写本地→同步） |
| `deleteItemType()` | 删除 | 应使用 `deleteTypeConfig()`（写本地→同步） |
| `deactivateItemType()` | 改为本地操作 | 修改本地 isActive → 标记 syncPending |
| `getOccupiedSlots()` | 改为查本地 | 本地 DB 已有 slot_position |

**调用方适配**：

| 调用方 | 当前调用 | 改为 |
|--------|---------|------|
| `item_type_manage_page.dart` | `createItemType()` | `createTypeConfig()` |
| `item_type_manage_page.dart` | `updateItemTypeConfig()` | `updateTypeConfig()` |
| `item_type_manage_page.dart` | `deleteItemType()` | `deleteTypeConfig()` |
| `item_type_manage_page.dart` | `deactivateItemType()` | 本地更新 + syncPending |

### Phase 3：清理重复 Provider

#### 4.5 删除未使用的 Provider

| 文件 | 操作 | 原因 |
|------|------|------|
| `lib/features/items/providers/offline_locations_provider.dart` | 删除 | 无 UI 引用，逻辑与 `locations_provider.dart` 重复 |
| `lib/features/items/providers/offline_tags_provider.dart` | 删除 | 无 UI 引用，逻辑与 `tags_provider.dart` 重复 |

#### 4.6 清理 Provider 中的 autoSync 调用

**文件**：`lib/features/items/providers/locations_provider.dart`

删除 `createLocation`、`updateLocation`、`deleteLocation` 中的 `autoSync()` 调用块（3 处）。

**文件**：`lib/features/items/providers/tags_provider.dart`

删除 `createTag`、`updateTag`、`deleteTag`、`restoreTag` 中的 `autoSync()` 调用块（4 处）。

**文件**：`lib/features/items/providers/offline_items_provider.dart`

删除 `_triggerAutoSync()` 方法及其所有调用点。改为由 `SyncScheduler` 定时同步 + Realtime 推送。

**文件**：`lib/features/items/pages/items_list_page.dart`

删除第 486 行的 `await repository.autoSync(householdId)`。

### Phase 4：添加 Supabase Realtime 订阅（可选增强）

#### 4.7 Realtime Listener

**文件**：新建 `lib/core/sync/item_realtime_listener.dart`

```dart
class ItemRealtimeListener {
  void start(String householdId) {
    // 监听 household_items 变更
    _client
        .from('household_items')
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .listen((items) {
          for (final item in items) {
            _localDb.itemsDao.upsertItemFromRemote(item);
          }
        });
    
    // 同样监听 locations、tags、type_configs
  }
}
```

**优先级**：P1（非阻塞，可后续迭代）。当前版本靠定时同步已够用。

---

## 五、完整文件变更清单

### 新建文件（3 个）

| 文件 | 说明 |
|------|------|
| `supabase_migrations/028_item_locations_add_deleted_at.sql` | 位置表软删除 |
| `supabase_migrations/029_drop_item_tag_relations.sql` | 删除废弃表 |
| `lib/core/sync/item_realtime_listener.dart` | Realtime 订阅（可选） |

### 修改文件（14 个）

| 文件 | 变更内容 | 风险等级 |
|------|---------|---------|
| `lib/core/sync/sync_scheduler.dart` | sync() 加入物品同步 | 低 |
| `lib/core/sync/sync_engine.dart` | 合并 ItemRepository 的同步逻辑 | 中 |
| `lib/data/repositories/item_repository.dart` | 删除 autoSync + 反向方法 | 高 |
| `lib/data/local_db/tables/item_locations.dart` | 添加 deletedAt | 低 |
| `lib/data/local_db/app_database.dart` | schemaVersion 3→4 | 低 |
| `lib/data/local_db/daos/locations_dao.dart` | 删除改软删除 | 低 |
| `lib/data/models/item_location.dart` | 添加 deletedAt 字段 | 低 |
| `lib/data/local_db/item_extensions.dart` | 添加 deletedAt 映射 | 低 |
| `lib/features/items/providers/locations_provider.dart` | 删除 autoSync 调用 | 低 |
| `lib/features/items/providers/tags_provider.dart` | 删除 autoSync 调用 | 低 |
| `lib/features/items/providers/offline_items_provider.dart` | 删除 _triggerAutoSync | 中 |
| `lib/features/items/pages/items_list_page.dart` | 删除 autoSync 调用 | 低 |
| `lib/features/items/pages/item_type_manage_page.dart` | 适配新的类型操作方法 | 中 |
| `lib/features/items/providers/item_types_provider.dart` | 确保走本地查询 | 低 |

### 删除文件（2 个）

| 文件 | 原因 |
|------|------|
| `lib/features/items/providers/offline_locations_provider.dart` | 重复代码，无引用 |
| `lib/features/items/providers/offline_tags_provider.dart` | 重复代码，无引用 |

---

## 六、实施顺序与依赖

```
Phase 1（同步层统一）
  ├─ 1.1 修改 SyncScheduler.sync() 加入物品同步    ← 独立，可先做
  └─ 1.2 合并 SyncEngine 与 ItemRepository 同步逻辑 ← 依赖 1.1

Phase 2（数据库变更）
  ├─ 2.1 创建 migration 028（位置软删除）            ← 独立
  ├─ 2.2 创建 migration 029（删除废弃表）            ← 独立
  ├─ 2.3 修改本地 Drift 表 + schemaVersion           ← 依赖 2.1
  └─ 2.4 修改 DAO 和 Model                           ← 依赖 2.3

Phase 3（清理反向方法 + 重复代码）
  ├─ 3.1 删除/改造 Repository 反向方法               ← 依赖 1.2
  ├─ 3.2 适配调用方（item_type_manage_page）          ← 依赖 3.1
  ├─ 3.3 删除重复 Provider                           ← 独立
  └─ 3.4 清理 Provider 中 autoSync 调用               ← 依赖 1.1

Phase 4（可选增强）
  └─ 4.1 添加 Supabase Realtime 订阅                 ← 依赖 Phase 1-3 全部完成
```

**建议分 3 个 PR 提交**：
- PR 1：Phase 1 + Phase 2（同步层统一 + 数据库变更）
- PR 2：Phase 3（清理反向方法 + 重复代码）
- PR 3：Phase 4（Realtime 订阅）

---

## 七、风险评估

| 变更 | 风险 | 缓解措施 |
|------|------|---------|
| SyncScheduler 加入物品同步 | 低 | 现有 SyncEngine.syncItems() 已测试过 |
| 合并同步逻辑 | 中 | ItemRepository._syncItems() 有额外的多端同步逻辑，需迁移到 SyncEngine |
| 删除 Repository 反向方法 | 高 | 需确认所有调用方已适配 |
| 位置软删除 | 低 | 只影响删除行为，不影响查询 |
| 删除重复 Provider | 低 | 已确认无 UI 引用 |
| 清理 autoSync 调用 | 中 | 需确保 SyncScheduler 定时同步已生效 |

---

## 八、验证清单

- [ ] `flutter analyze` 无 error
- [ ] 创建物品 → 本地立即可见 → 5 分钟内同步到远端
- [ ] 修改物品 → 本地立即更新 → 5 分钟内同步到远端
- [ ] 删除物品 → 本地立即消失 → 软删除同步到远端
- [ ] 离线操作 → 恢复网络后自动同步
- [ ] 多端操作 → A 端修改，B 端 5 分钟内可见
- [ ] 位置 CRUD → 同步正常
- [ ] 标签 CRUD → 同步正常
- [ ] 类型配置 CRUD → 同步正常
- [ ] `item_tag_relations` 表已删除，不影响任何功能
- [ ] 位置软删除后，关联物品的 location_id 正确处理
