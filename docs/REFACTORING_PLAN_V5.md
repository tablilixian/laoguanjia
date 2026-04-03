# 物品系统 — 架构重构方案（终版）

> 目标：调用端零感知远端，全链路响应式，初始化流程统一，同步机制完备
> 生成日期：2026-04-03

---

## 一、架构总览

### 1.1 四层架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        Layer 4: UI Layer                         │
│  Pages: items_list | item_create | item_detail | item_stats      │
│         item_locations | item_tags | item_type_manage            │
│  职责：展示 + 用户交互，不关心数据来源和同步                        │
├─────────────────────────────────────────────────────────────────┤
│                    Layer 3: State Layer (Riverpod)                │
│  Providers: Items | Locations | Tags | Types | Stats | Paginated  │
│  职责：响应式绑定 Drift Stream，数据库变化自动推送到 UI             │
├─────────────────────────────────────────────────────────────────┤
│                    Layer 2: Repository Layer                      │
│  ItemRepository: 纯本地 CRUD + watch Stream                      │
│  职责：业务逻辑编排、数据组装、位图标签解析、位置路径构建            │
│  不暴露任何远端操作方法                                            │
├─────────────────────────────────────────────────────────────────┤
│              Layer 1: Infrastructure Layer                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │  Local DB (Drift)│  │  Sync Engine     │  │  App Lifecycle │ │
│  │  SQLite 持久化    │  │  版本控制+冲突解决 │  │  前台恢复同步   │ │
│  │  watch() 响应式   │  │  增量/全量/重置   │  │  定时同步调度   │ │
│  └──────────────────┘  └──────────────────┘  └────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    Remote: Supabase PostgreSQL                    │
│  household_items | item_locations | item_tags | item_type_configs│
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 核心原则

| 原则 | 说明 |
|------|------|
| **Local-First** | 所有读写优先走本地 SQLite，远端只作为同步目标 |
| **Reactive** | Provider 层使用 `watch()` Stream，数据库变化自动推送 UI |
| **Sync-Transparent** | 调用端不感知同步，同步由独立层自动维护 |
| **Single Init** | 初始化流程统一，无论冷启动/重置/恢复都走同一路径 |

---

## 二、数据模型与数据库

### 2.1 本地 Drift 表（6 张）

| 表名 | DAO | 字段数 | watch 方法 | 状态 |
|------|-----|--------|-----------|------|
| `HouseholdItems` | `ItemsDao` | 26 | `watchByHousehold()` | ✅ 已有 |
| `ItemLocations` | `LocationsDao` | 17 | `watchByHousehold()` | ✅ 已有 |
| `ItemTags` | `TagsDao` | 12 | `watchByHousehold()` | ✅ 已有 |
| `ItemTypeConfigs` | `TypesDao` | 10 | `watchByHousehold()` | ✅ 已有 |
| `Members` | `MembersDao` | 8 | 待添加 | ⚠️ |
| `Tasks` | `TasksDao` | 12 | 待添加 | ⚠️ |

### 2.2 同步字段约定（所有业务表统一）

| 字段 | 类型 | 用途 | 谁维护 |
|------|------|------|--------|
| `version` | `IntColumn` | 乐观锁版本号，每次 UPDATE 自动+1 | 远端触发器 + 本地手动 |
| `syncPending` | `BoolColumn` | 标记本地是否有待推送的变更 | 本地写入时设为 true |
| `deletedAt` | `DateTimeColumn` | 软删除时间戳 | 本地删除时设置 |

### 2.3 数据库变更

#### 新建：`supabase_migrations/028_item_locations_add_deleted_at.sql`

```sql
ALTER TABLE item_locations
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_locations_deleted_at ON item_locations(deleted_at);
```

#### 新建：`supabase_migrations/029_drop_item_tag_relations.sql`

```sql
DROP TABLE IF EXISTS item_tag_relations;
```

#### 修改：`lib/data/local_db/tables/item_locations.dart`

新增字段：
```dart
DateTimeColumn get deletedAt => dateTime().nullable()();
```

#### 修改：`lib/data/local_db/app_database.dart`

- `schemaVersion` 从 3 → 4
- `onUpgrade` 添加 v3→v4 迁移：`await m.addColumn(itemLocations, itemLocations.deletedAt);`

---

## 三、模块职责定义

### 3.1 各层职责边界（严格）

| 层 | 能做什么 | 不能做什么 |
|----|---------|-----------|
| **UI (Pages)** | 读 Provider state、调用 Notifier 方法、展示数据 | 不调用 Repository、不调用 autoSync、不直接访问数据库 |
| **State (Providers)** | 监听 Drift Stream、组装 UI state、响应 Notifier 操作 | 不直接操作远端、不触发同步 |
| **Repository** | 本地 CRUD、数据组装（位置路径/标签解析）、暴露 watch Stream | 不暴露远端操作方法、不触发同步 |
| **SyncEngine** | 版本比较、push/pull、冲突解决、全量/增量/重置 | 不暴露给 UI 层、不操作业务逻辑 |
| **SyncScheduler** | 定时触发、网络恢复触发、前台恢复触发 | 不实现具体同步逻辑，只调度 |

### 3.2 Repository 公开 API（重构后）

```dart
class ItemRepository {
  // ========== 查询（本地） ==========
  Future<List<HouseholdItem>> getItems(String householdId);
  Future<HouseholdItem?> getItem(String itemId);
  Future<PaginatedItemsResult> getItemsPaginated(...);
  Future<Map<String, int>> getAllLocationItemCounts(String householdId);
  Future<Map<String, dynamic>> getItemOverview(String householdId);
  Future<List<Map<String, dynamic>>> getItemCountByType(String householdId);
  Future<List<Map<String, dynamic>>> getItemCountByOwner(String householdId);
  Future<List<Map<String, dynamic>>> getItemCountByTag(String householdId);

  // ========== 响应式监听（新增） ==========
  Stream<List<ItemLocation>> watchLocations(String householdId);
  Stream<List<ItemTag>> watchTags(String householdId);
  Stream<List<ItemTypeConfig>> watchTypeConfigs(String householdId);
  Stream<List<HouseholdItem>> watchItems(String householdId);
  Stream<ItemLocation?> watchLocation(String locationId);
  Stream<ItemTag?> watchTag(String tagId);

  // ========== 写入（本地 + 标记同步） ==========
  Future<HouseholdItem> createItem(HouseholdItem item);
  Future<HouseholdItem> updateItem(HouseholdItem item);
  Future<void> deleteItem(String itemId);
  Future<void> batchDeleteItems(List<String> itemIds);
  Future<void> batchSetTags(String itemId, List<String> tagIds);

  Future<ItemLocation> createLocation(ItemLocation location);
  Future<ItemLocation> updateLocation(ItemLocation location);
  Future<void> deleteLocation(String locationId);

  Future<ItemTag> createTag(ItemTag tag);
  Future<ItemTag> updateTag(ItemTag tag);
  Future<void> deleteTag(String tagId);
  Future<ItemTag> restoreTag(ItemTag tag);

  Future<ItemTypeConfig> createTypeConfig(ItemTypeConfig type);
  Future<ItemTypeConfig> updateTypeConfig(ItemTypeConfig type);
  Future<void> deleteTypeConfig(String typeId);
  Future<void> deactivateTypeConfig(String typeId);

  // ========== 辅助 ==========
  Future<List<ItemLocation>> getLocations(String householdId);
  Future<List<ItemTag>> getTags(String householdId);
  Future<List<ItemTypeConfig>> getTypeConfigs(String householdId);
  Future<List<ItemTypeConfig>> getAllTypeConfigs(String householdId);
  Future<List<String>> getItemTagIds(String itemId);
  Future<void> updateItemTags(String itemId, List<String> tagIds);
  Future<int?> getNextTagIndex(String householdId);
  Future<ItemTag?> findDeletedTagByName(String householdId, String name);
  Future<void> syncMembersToLocal(String householdId);

  // ========== 初始化 ==========
  Future<void> initialize(String householdId);

  // ========== 删除（不再暴露） ==========
  // ❌ autoSync()           → 删除，由 SyncScheduler 统一调度
  // ❌ getItemTypes()        → 删除，用 getTypeConfigs()
  // ❌ getAllItemTypes()     → 删除，用 getAllTypeConfigs()
  // ❌ createItemType()      → 删除，用 createTypeConfig()
  // ❌ updateItemTypeConfig()→ 删除，用 updateTypeConfig()
  // ❌ deleteItemType()      → 删除，用 deleteTypeConfig()
  // ❌ deactivateItemType()  → 删除，用 deactivateTypeConfig()
  // ❌ getOccupiedSlots()    → 删除，改为本地查询
}
```

---

## 四、完整数据流

### 4.1 初始化流程

```
┌─────────────────────────────────────────────────────────────┐
│                     冷启动 / 登录成功                         │
│                          ↓                                   │
│                    WelcomePage                               │
│                          ↓                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ _startInitialization()                              │    │
│  │   ├─ _initAI()          (AI 服务)                    │    │
│  │   ├─ _initWeather()     (天气服务)                   │    │
│  │   ├─ _preloadProviders()(预加载存储)                  │    │
│  │   ├─ _initHousehold()   (刷新家庭信息)                │    │
│  │   ├─ _initItemData()    (物品数据初始化)              │    │
│  │   │     ↓                                           │    │
│  │   │  ItemRepository.initialize(householdId)          │    │
│  │   │     ├─ 检查本地是否有数据                         │    │
│  │   │     ├─ 本地为空 → 全量拉取远程 5 张表             │    │
│  │   │     └─ 本地有数据 → 增量同步 5 张表               │    │
│  │   └─ _initSync()        (启动同步调度器)              │    │
│  │         ├─ SyncScheduler.initialize()                 │    │
│  │         │   ├─ 5 分钟定时同步                         │    │
│  │         │   └─ 网络恢复监听                           │    │
│  │         └─ SyncScheduler.sync()  (首次立即同步)       │    │
│  └─────────────────────────────────────────────────────┘    │
│                          ↓                                   │
│                    context.go('/home')                       │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 App 从后台恢复

```
App 回到前台
    ↓
AppLifecycleObserver.didChangeAppLifecycleState(resumed)
    ↓
SyncScheduler.sync()
    ├─ SyncEngine.syncTasks()
    ├─ SyncEngine.syncItems()
    ├─ SyncEngine.syncLocations()
    ├─ SyncEngine.syncTags()
    └─ SyncEngine.syncTypes()
    ↓
Drift 数据库更新
    ↓
watch() Stream 推送
    ↓
Provider 自动重建
    ↓
UI 实时更新（无需手动 refresh）
```

### 4.3 增删改查流程

```
┌──────────────────────────────────────────────────────────┐
│  用户在 UI 上操作（例如：创建物品）                         │
│                          ↓                                │
│  Provider Notifier.createItem(item)                       │
│                          ↓                                │
│  ItemRepository.createItem(item)                          │
│    ├─ 生成 UUID, 设置 syncStatus=pending                  │
│    ├─ 写入本地 SQLite (ItemsDao.insertItem)               │
│    ├─ 设置 syncPending=true                               │
│    └─ 返回新物品对象                                       │
│                          ↓                                │
│  Notifier 更新 state（手动或 watch 自动推送）               │
│    → UI 立即看到新物品（无需等待同步）                       │
│                          ↓                                │
│  [异步] SyncScheduler 定时触发 或 写操作事件触发            │
│    ↓                                                      │
│  SyncEngine.syncItems()                                   │
│    ├─ push: 查找 syncPending=true 的记录                   │
│    ├─ 检查远端 version，决定 push/pull                    │
│    ├─ 推送成功 → markSynced(id)                           │
│    └─ 拉取更新 → upsertItemFromRemote()                   │
│                          ↓                                │
│  Drift 数据库更新 → watch Stream 推送 → UI 自动刷新        │
└──────────────────────────────────────────────────────────┘
```

### 4.4 定时同步

```
SyncScheduler.initialize()
    ↓
Timer.periodic(5 分钟)
    ↓
SyncScheduler.sync()
    ├─ SyncEngine.syncTasks()
    ├─ SyncEngine.syncItems()       ← 修复后新增
    │   ├─ pushItems()              推送本地待同步数据
    │   └─ pullItems(localVersion)  拉取远端新版本数据
    ├─ SyncEngine.syncLocations()   ← 修复后新增
    ├─ SyncEngine.syncTags()        ← 修复后新增
    └─ SyncEngine.syncTypes()       ← 修复后新增
    ↓
Drift 数据库更新 → watch Stream → UI 自动刷新
```

### 4.5 全量重置

```
设置页 → 确认重置
    ↓
SyncScheduler.resetAndSync()
    ├─ SyncEngine.resetLocalData()
    │   ├─ AppDatabase.resetDatabase()  (清空 6 张表)
    │   └─ setLocalVersion('tasks', 0)
    │   └─ setLocalVersion('household_items', 0)  ← 修复后新增
    │   └─ setLocalVersion('item_locations', 0)   ← 修复后新增
    │   └─ setLocalVersion('item_tags', 0)        ← 修复后新增
    │   └─ setLocalVersion('item_type_configs', 0)← 修复后新增
    └─ SyncEngine.forceFullSync()
        ├─ forceFullSyncItems()  (全量拉取物品)
        ├─ syncLocations()       (全量拉取位置)
        └─ syncTags()            (全量拉取标签)
        └─ syncTypes()           (全量拉取类型)
    ↓
context.go('/welcome')  ← 跳回欢迎页重新初始化
    ↓
WelcomePage._initItemData()
    → 检测到本地为空 → 全量拉取
    → 进入主页
```

---

## 五、UI 响应式刷新方案

### 5.1 当前问题

所有 Provider 都是一次性读取 + 手动 state 赋值：

```dart
// 当前写法 — 一次性读取
class LocationsNotifier extends StateNotifier<LocationsState> {
  LocationsNotifier(this._ref) : super(LocationsState()) {
    _loadLocations();  // ← 只执行一次
  }
  
  Future<void> _loadLocations() async {
    final locations = await _repository.getLocations(householdId);  // 一次性
    state = state.copyWith(locations: locations);  // 手动赋值
  }
}
```

同步完成后，Drift 数据库已更新，但 Provider state 不变 → **页面不刷新**。

### 5.2 目标方案：Stream 驱动

```dart
// 目标写法 — Stream 响应式
final locationsProvider = StreamProvider.autoDispose<LocationsState>((ref) {
  final householdId = ref.watch(householdProvider).currentHousehold?.id;
  if (householdId == null) return Stream.value(LocationsState());
  
  final repository = ref.watch(itemRepositoryProvider);
  
  return repository.watchLocations(householdId).map((locations) {
    // 每次数据库变化都会重新执行这里
    return LocationsState(locations: locations);
  });
});
```

### 5.3 各 Provider 改造方案

| Provider | 当前类型 | 改造后类型 | 数据源 | 改动量 |
|----------|---------|-----------|--------|--------|
| `locationsProvider` | `StateNotifier` | `StreamProvider` | `watchLocations()` | 中 |
| `tagsProvider` | `StateNotifier` | `StreamProvider` | `watchTags()` | 中 |
| `itemTypesProvider` | `FutureProvider` | `StreamProvider` | `watchTypeConfigs()` | 小 |
| `paginatedItemsProvider` | `StateNotifier` | `StateNotifier` + `ref.listen(watch)` | `watchItems()` | 中 |
| `offlineItemDetailProvider` | `FutureProvider` | `StreamProvider` | `watchItem()` | 小 |
| `offlineItemsProvider` | `StateNotifier` | `StreamProvider` | `watchItems()` | 中 |

### 5.4 需要新增的 Repository watch 方法

```dart
// item_repository.dart 新增
Stream<List<ItemLocation>> watchLocations(String householdId) =>
    _localDb.locationsDao.watchByHousehold(householdId);

Stream<List<ItemTag>> watchTags(String householdId) =>
    _localDb.tagsDao.watchByHousehold(householdId);

Stream<List<ItemTypeConfig>> watchTypeConfigs(String householdId) =>
    _localDb.typesDao.watchByHousehold(householdId);

Stream<List<HouseholdItem>> watchItems(String householdId) =>
    _localDb.itemsDao.watchByHousehold(householdId);

Stream<ItemLocation?> watchLocation(String locationId) =>
    _localDb.locationsDao.watchById(locationId);

Stream<ItemTag?> watchTag(String tagId) =>
    _localDb.tagsDao.watchById(tagId);
```

**这些 DAO 方法已存在**（`watchByHousehold`、`watchById`），只需在 Repository 层暴露即可。

---

## 六、完整文件变更清单

### 6.1 新建文件（4 个）

| 文件 | 说明 | 优先级 |
|------|------|--------|
| `supabase_migrations/028_item_locations_add_deleted_at.sql` | 位置表软删除 | P0 |
| `supabase_migrations/029_drop_item_tag_relations.sql` | 删除废弃表 | P0 |
| `lib/core/sync/app_lifecycle_sync.dart` | App 前台恢复同步 | P0 |
| `lib/core/providers/item_repository_provider.dart` | Repository 单例 Provider | P1 |

### 6.2 修改文件（18 个）

| 文件 | 变更内容 | 优先级 | 风险 |
|------|---------|--------|------|
| `lib/core/sync/sync_scheduler.dart` | sync() 加入物品/位置/标签/类型同步 | P0 | 低 |
| `lib/core/sync/sync_engine.dart` | resetLocalData() 重置所有表版本号 | P0 | 低 |
| `lib/core/sync/sync_engine.dart` | forceFullSync() 加入物品全量拉取 | P0 | 低 |
| `lib/data/repositories/item_repository.dart` | 删除 autoSync + 反向方法，新增 watch 方法 | P0 | 高 |
| `lib/data/local_db/tables/item_locations.dart` | 添加 deletedAt 列 | P0 | 低 |
| `lib/data/local_db/app_database.dart` | schemaVersion 3→4，添加迁移 | P0 | 低 |
| `lib/data/local_db/daos/locations_dao.dart` | deleteLocation 改为软删除 | P0 | 低 |
| `lib/data/models/item_location.dart` | 添加 deletedAt 字段 | P0 | 低 |
| `lib/data/local_db/item_extensions.dart` | 添加 deletedAt 映射 | P0 | 低 |
| `lib/features/items/providers/locations_provider.dart` | 改为 StreamProvider，删除 autoSync | P1 | 中 |
| `lib/features/items/providers/tags_provider.dart` | 改为 StreamProvider，删除 autoSync | P1 | 中 |
| `lib/features/items/providers/item_types_provider.dart` | 改为 StreamProvider | P1 | 低 |
| `lib/features/items/providers/offline_items_provider.dart` | 改为 StreamProvider，删除 _triggerAutoSync | P1 | 中 |
| `lib/features/items/providers/paginated_items_provider.dart` | 监听 watchItems 自动刷新 | P1 | 中 |
| `lib/features/items/providers/offline_item_detail_provider.dart` | 改为 StreamProvider | P1 | 低 |
| `lib/features/items/pages/items_list_page.dart` | 删除 autoSync 调用 | P1 | 低 |
| `lib/features/items/pages/item_type_manage_page.dart` | 适配新的类型操作方法 | P1 | 中 |
| `lib/features/settings/pages/settings_page.dart` | resetAndSync 后跳回 /welcome | P1 | 低 |

### 6.3 删除文件（2 个）

| 文件 | 原因 |
|------|------|
| `lib/features/items/providers/offline_locations_provider.dart` | 重复代码，无 UI 引用 |
| `lib/features/items/providers/offline_tags_provider.dart` | 重复代码，无 UI 引用 |

---

## 七、分阶段实施计划

### Phase 1：同步层修复（P0，可独立上线）

| # | 任务 | 文件 | 验证 |
|---|------|------|------|
| 1.1 | `SyncScheduler.sync()` 加入物品/位置/标签/类型同步 | `sync_scheduler.dart` | 5 分钟定时同步覆盖物品 |
| 1.2 | `SyncEngine.resetLocalData()` 重置所有表版本号 | `sync_engine.dart` | resetAndSync 后能全量拉取 |
| 1.3 | `SyncEngine.forceFullSync()` 加入物品全量拉取 | `sync_engine.dart` | 全量同步包含物品 |
| 1.4 | 新建 `app_lifecycle_sync.dart` | 新建文件 | App 恢复前台自动同步 |
| 1.5 | 注册 AppLifecycleObserver | `main.dart` 或 `welcome_page.dart` | 后台切回触发同步 |

### Phase 2：数据库变更（P0，与 Phase 1 并行）

| # | 任务 | 文件 | 验证 |
|---|------|------|------|
| 2.1 | 创建 migration 028（位置软删除） | SQL 文件 | 远端表有 deleted_at |
| 2.2 | 创建 migration 029（删除废弃表） | SQL 文件 | 远端无 item_tag_relations |
| 2.3 | 本地 Drift 表添加 deletedAt | `item_locations.dart` | 编译通过 |
| 2.4 | schemaVersion 3→4 + 迁移逻辑 | `app_database.dart` | 升级不丢数据 |
| 2.5 | LocationsDao.deleteLocation 改为软删除 | `locations_dao.dart` | 删除后 syncPending=true |
| 2.6 | ItemLocation 模型添加 deletedAt | `item_location.dart` | 序列化正确 |
| 2.7 | Extension 添加 deletedAt 映射 | `item_extensions.dart` | 转换正确 |

### Phase 3：Repository 重构（P0，核心）

| # | 任务 | 文件 | 验证 |
|---|------|------|------|
| 3.1 | 新增 watch 方法（6 个） | `item_repository.dart` | Stream 能推送数据变化 |
| 3.2 | 删除 `autoSync()` 方法 | `item_repository.dart` | 编译通过 |
| 3.3 | 删除反向远程方法（7 个） | `item_repository.dart` | 编译通过 |
| 3.4 | 适配调用方：`item_type_manage_page.dart` | 修改调用 | 类型 CRUD 正常 |

### Phase 4：Provider 响应式改造（P1）

| # | 任务 | 文件 | 验证 |
|---|------|------|------|
| 4.1 | `locationsProvider` → StreamProvider | `locations_provider.dart` | 同步后页面自动刷新 |
| 4.2 | `tagsProvider` → StreamProvider | `tags_provider.dart` | 同步后页面自动刷新 |
| 4.3 | `itemTypesProvider` → StreamProvider | `item_types_provider.dart` | 同步后页面自动刷新 |
| 4.4 | `offline_items_provider` → StreamProvider | `offline_items_provider.dart` | 同步后页面自动刷新 |
| 4.5 | `paginatedItemsProvider` 监听 watch | `paginated_items_provider.dart` | 同步后自动刷新 |
| 4.6 | `offlineItemDetailProvider` → StreamProvider | `offline_item_detail_provider.dart` | 同步后详情自动刷新 |
| 4.7 | 删除重复 Provider（2 个文件） | 删除文件 | 编译通过 |
| 4.8 | 清理所有 `autoSync()` 调用 | 6 个文件 | 编译通过 |

### Phase 5：初始化流程统一（P1）

| # | 任务 | 文件 | 验证 |
|---|------|------|------|
| 5.1 | `resetAndSync()` 后跳回 `/welcome` | `settings_page.dart` | 重置后重新初始化 |
| 5.2 | 消除 PaginatedItemsNotifier 重复初始化 | `paginated_items_provider.dart` | 不重复拉取数据 |
| 5.3 | `SessionManager` 完善清理逻辑 | `session_manager.dart` | 退出登录无数据残留 |

---

## 八、验证清单

### 8.1 初始化

- [ ] 冷启动 → WelcomePage → 全量拉取 → 主页显示数据
- [ ] 本地已有数据 → WelcomePage → 增量同步 → 主页显示最新数据
- [ ] App 从后台恢复 → 自动触发同步 → 远端变更拉取到本地
- [ ] 网络断开 → 操作数据 → 网络恢复 → 自动同步

### 8.2 增删改查

- [ ] 创建物品 → UI 立即显示 → 同步到远端
- [ ] 修改物品 → UI 立即更新 → 同步到远端
- [ ] 删除物品 → UI 立即消失 → 软删除同步到远端
- [ ] 离线创建物品 → 恢复网络 → 自动同步

### 8.3 同步

- [ ] 5 分钟定时同步覆盖物品/位置/标签/类型
- [ ] 网络恢复触发同步覆盖物品/位置/标签/类型
- [ ] App 前台恢复触发同步
- [ ] 多端操作：A 端修改 → B 端 5 分钟内自动更新
- [ ] 版本冲突：A/B 同时修改 → 后修改者胜出（基于 updatedAt）

### 8.4 UI 刷新

- [ ] 位置管理页：远端变更 → 页面自动刷新（无需下拉）
- [ ] 标签管理页：远端变更 → 页面自动刷新
- [ ] 类型管理页：远端变更 → 页面自动刷新
- [ ] 物品列表页：远端变更 → 页面自动刷新
- [ ] 物品详情页：远端变更 → 页面自动刷新
- [ ] 物品统计页：远端变更 → 页面自动刷新

### 8.5 重置与恢复

- [ ] 设置页全量重置 → 跳回 WelcomePage → 重新初始化
- [ ] 重置后本地数据清空 → 远端数据完整拉回
- [ ] 退出登录 → 所有本地数据清除 → 无数据残留

### 8.6 数据库

- [ ] `item_tag_relations` 表已删除，不影响任何功能
- [ ] 位置软删除后，关联物品 location_id 正确处理
- [ ] Drift schema 升级不丢已有数据
- [ ] 所有表版本号正确维护

---

## 九、风险评估

| 变更 | 风险 | 缓解措施 |
|------|------|---------|
| SyncScheduler 加入物品同步 | 低 | SyncEngine.syncItems() 已有完整实现 |
| Repository 删除 autoSync | 高 | 需确保所有调用方已清理 + SyncScheduler 已生效 |
| Repository 删除反向方法 | 高 | 逐一确认调用方并适配 |
| Provider 改为 StreamProvider | 中 | 逐步替换，每个改完验证 |
| 位置软删除 | 低 | 只影响删除行为，查询需加 `deletedAt.isNull` 条件 |
| schemaVersion 升级 | 低 | Drift 迁移是增量式的，不会丢数据 |
| App 前台恢复同步 | 低 | 独立模块，不影响现有逻辑 |

---

## 十、关键设计决策记录

| 决策 | 选择 | 理由 |
|------|------|------|
| 同步触发方式 | SyncScheduler 统一调度 | 避免散落在 15 处，集中管理 |
| App 前台恢复 | AppLifecycleObserver | 全局监听，不依赖特定页面 |
| Provider 响应式 | StreamProvider | Drift 原生支持 watch()，零额外开销 |
| 重置后跳转 | 跳回 WelcomePage | 初始化流程统一，避免状态不一致 |
| 位置软删除 | 添加 deletedAt 字段 | 多端同步需要传播删除操作 |
| 删除 item_tag_relations | 直接 DROP TABLE | 代码零引用，位图方案已完全替代 |
| 冲突解决策略 | updatedAt 后写者胜 | 简单、可预测，适合家庭场景 |

---

*文档结束*
