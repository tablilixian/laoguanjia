# 物品系统简洁重构方案

> 版本: v2.0 | 日期: 2026-03-27 | 状态: 草案

---

## 核心理念

**少就是多** - 删除不必要的抽象层

```
当前: 1000+ 行间接调用代码
目标: Repository 直接实现，无中间层
收益: 代码减半，认知负担减半
```

---

## 问题诊断

### 当前架构问题

```
┌─────────────────────────────────────────────────────────────┐
│  OfflineItemRepository (438行)                               │
│  ├── 本身几乎没有逻辑，只是转发调用                            │
│  ├── 每个方法都是: return _queryService.xxx()                 │
│  └── 门面模式在这里没有价值                                   │
├─────────────────────────────────────────────────────────────┤
│  ItemQueryService (587行)                                    │
│  ├── 查询方法: 直接调用 _localDb.itemsDao.xxx()              │
│  ├── 统计方法: 直接调用 _localDb.itemsDao.xxx()              │
│  └── 远程方法: 调用 _client.from('xxx').select()            │
├─────────────────────────────────────────────────────────────┤
│  ItemCommandService (438行)                                  │
│  ├── createItem: 生成 UUID + 调用 DAO.insert                 │
│  ├── updateItem: 调用 DAO.update                             │
│  └── deleteItem: 调用 DAO.softDelete                         │
├─────────────────────────────────────────────────────────────┤
│  ItemSyncService (491行)                                     │
│  └── 同步逻辑                                                │
└─────────────────────────────────────────────────────────────┘

问题:
1. Repository 只是门面，没有实际价值
2. Service 层的方法大多是 DAO 调用的简单包装
3. 调用链过长: Provider → Repository → Service → DAO
4. 文件太多，找代码困难
```

### 什么才是真正的业务逻辑？

| 真正的业务逻辑 | 当前位置 |
|---------------|---------|
| 构建位置层级路径 | `ItemRepository` (旧) |
| 批量创建物品 | `ItemRepository` (旧) |
| 版本冲突解决 | `ItemSyncService` |
| 自动触发同步 | `OfflineItemRepository` 构造函数 |

| 不是业务逻辑（应该删除） | 当前位置 |
|------------------------|---------|
| `getItems()` 转发调用 | `OfflineItemRepository` |
| `createItem()` 包装 DAO | `ItemCommandService` |
| `getItemOverview()` 包装 DAO | `ItemQueryService` |

---

## 目标架构

```
┌─────────────────────────────────────────────────────────────┐
│  Provider 层                                                 │
│  ├── offlineItemsProvider (状态 + 列表)                      │
│  └── paginatedItemsProvider (分页显示)                       │
├─────────────────────────────────────────────────────────────┤
│  Repository 层 (唯一)                                        │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  ItemRepository (600行左右)                             ││
│  │  ├── 查询: 直接调用 DAO                                  ││
│  │  ├── 写入: 调用 DAO + 标记 syncPending                   ││
│  │  ├── 同步: sync() 方法处理冲突                           ││
│  │  └── 业务: buildLocationPath(), createItemsBatch()      ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  DAO 层                                                      │
│  ├── ItemsDao (448行) - 保持不变                             │
│  ├── LocationsDao                                            │
│  ├── TagsDao                                                 │
│  └── TypesDao                                                │
├─────────────────────────────────────────────────────────────┤
│  本地数据库 (Drift/SQLite)                                   │
└─────────────────────────────────────────────────────────────┘
```

### 职责划分

| 层级 | 职责 | 原则 |
|------|------|------|
| Provider | 状态管理、UI 驱动 | 不包含业务逻辑 |
| Repository | 持久化、同步、业务逻辑 | 单一入口 |
| DAO | SQL 查询 | 纯数据访问 |

---

## 分阶段重构

### Phase 1: 合并 Repository (Week 1)

**目标**: 删除 `OfflineItemRepository`，统一到 `ItemRepository`

#### Step 1.1: 扩展 `ItemRepository`

```dart
// lib/data/repositories/item_repository.dart
class ItemRepository {
  final _client = SupabaseClientManager.client;
  final db.AppDatabase _localDb = getDatabase();
  
  // ========== 保留原有方法 ==========
  Future<List<HouseholdItem>> getItems(String householdId) { ... }
  Future<HouseholdItem?> getItemById(String id) { ... }
  Future<HouseholdItem> createItem(HouseholdItem item) { ... }
  // ...
  
  // ========== 新增离线支持 ==========
  
  /// 分页查询（从 OfflineItemRepository 迁移）
  Future<PaginatedItemsResult> getItemsPaginated(
    String householdId, {
    required int limit,
    required int offset,
    String? searchQuery,
    String? itemType,
    String? locationId,
    String? ownerId,
    String sortBy = 'updatedAt',
    bool sortAsc = false,
  }) async {
    // 直接调用 DAO，不经过 Service
    final items = await _localDb.itemsDao.getByHouseholdPaginated(
      householdId,
      limit: limit,
      offset: offset,
      // ...
    );
    final count = await _localDb.itemsDao.getCountByHousehold(householdId, ...);
    return PaginatedItemsResult(items: items, totalCount: count, hasMore: ...);
  }
  
  /// 同步方法（从 ItemSyncService 迁移核心逻辑）
  Future<SyncResult> sync(String householdId) async {
    final pendingItems = await _localDb.itemsDao.getSyncPending();
    // ... 冲突解决逻辑
  }
}
```

#### Step 1.2: 迁移调用点

| 文件 | 原调用 | 新调用 |
|------|--------|--------|
| `batch_add_page.dart` | `offlineItemRepositoryProvider` | `ItemRepository()` |
| `item_create_page.dart` | `offlineItemRepositoryProvider` | `ItemRepository()` |
| `offline_items_provider.dart` | `offlineItemRepositoryProvider` | `ItemRepository()` |

#### Step 1.3: 删除文件

```bash
# 删除 Service 层
rm lib/data/services/item_query_service.dart
rm lib/data/services/item_command_service.dart
rm lib/data/services/item_sync_service.dart

# 删除旧 Repository
rm lib/data/repositories/offline_item_repository.dart
```

#### Step 1.4: 验证

```bash
flutter analyze
flutter test
# 功能测试
```

---

### Phase 2: 统一 Provider (Week 2)

**目标**: 删除 `itemsProvider`，统一到 `offlineItemsProvider`

#### Step 2.1: 确认 `offlineItemsProvider` 覆盖所有功能

```dart
// 需要确认存在的方法
class ItemsNotifier {
  Future<void> createItem(HouseholdItem item);
  Future<void> updateItem(HouseholdItem item);
  Future<void> deleteItem(String itemId);
  Future<void> refresh();
  Future<void> sync();
  void setFilters(ItemFilters filters);
  void setSearchQuery(String query);
  void setItemTypeFilter(String? typeKey);
}
```

#### Step 2.2: 迁移调用点

```bash
# 查找 itemsProvider 使用
grep -r "itemsProvider" lib/ --include="*.dart" | grep -v "offline"
```

#### Step 2.3: 删除文件

```bash
rm lib/features/items/providers/items_provider.dart
```

---

### Phase 3: 简化 Provider 依赖 (Week 3)

**目标**: 让 `paginatedItemsProvider` 直接基于 `offlineItemsProvider` 派生

#### 当前问题

```dart
// 两个独立的数据源
offlineItemsProvider    // 有自己的 items 列表
paginatedItemsProvider  // 也有自己的 items 列表

// 需要手动同步
await ref.read(paginatedItemsProvider.notifier).refresh();
await ref.read(offlineItemsProvider.notifier).refresh();
```

#### 目标方案

```dart
// paginatedItemsProvider 从 offlineItemsProvider 派生
final paginatedItemsProvider = Provider<PaginatedView>((ref) {
  final itemsState = ref.watch(offlineItemsProvider);
  final page = ref.watch(_currentPageProvider);
  final pageSize = 20;
  
  // 直接切片，不需要独立数据源
  final start = page * pageSize;
  final end = start + pageSize;
  final pageItems = itemsState.filteredItems.sublist(
    start, 
    end.clamp(0, itemsState.filteredItems.length)
  );
  
  return PaginatedView(
    items: pageItems,
    totalCount: itemsState.filteredItems.length,
    hasMore: end < itemsState.filteredItems.length,
  );
});
```

#### 收益

- 删除 `PaginatedItemsNotifier` (350行)
- 不需要手动同步两个 Provider
- 数据自动同步

---

## 重构收益对比

### 代码量

| 模块 | 当前 | 目标 | 减少 |
|------|------|------|------|
| Repository | 438 + 798 = 1236行 | 600行 | -636行 |
| Service | 587 + 438 + 491 = 1516行 | 0行 | -1516行 |
| Provider | 350 + 225 = 575行 | 225行 | -350行 |
| **总计** | **3327行** | **825行** | **-2502行 (-75%)** |

### 文件数

| 类型 | 当前 | 目标 | 减少 |
|------|------|------|------|
| Repository | 2 | 1 | -1 |
| Service | 3 | 0 | -3 |
| Provider (items相关) | 3 | 2 | -1 |
| **总计** | **8** | **3** | **-5** |

### 调用链

```
当前: Provider → Repository → Service → DAO (4层)
目标: Provider → Repository → DAO (3层)
```

---

## 测试策略

### 单元测试重点

```dart
// Repository 直接测试
test('getItemsPaginated should return correct page', () async {
  final repo = ItemRepository();
  // 准备数据
  await repo.createItem(sampleItem1);
  await repo.createItem(sampleItem2);
  
  // 测试分页
  final result = await repo.getItemsPaginated(
    householdId,
    limit: 1,
    offset: 0,
  );
  
  expect(result.items.length, 1);
  expect(result.totalCount, 2);
  expect(result.hasMore, true);
});
```

### 集成测试清单

- [ ] 创建物品 → 本地保存 → 自动同步
- [ ] 批量录入 → 全部保存 → 列表显示
- [ ] 离线操作 → 上线 → 自动同步
- [ ] 冲突解决 → 版本号处理

---

## 风险与回滚

### 风险

| 风险 | 概率 | 影响 | 对策 |
|------|------|------|------|
| 遗漏边界情况 | 中 | 中 | 完善测试用例 |
| 同步逻辑引入 bug | 低 | 高 | 保留 Service 测试 |

### 回滚方案

```bash
# 每阶段打 tag
git tag v2-phase-1-start
git tag v2-phase-2-start
git tag v2-phase-3-start

# 回滚
git checkout v2-phase-1-start
```

---

## 实施清单

### Phase 1 完成后

- [ ] `ItemRepository` 包含所有查询、写入、同步方法
- [ ] 删除 `OfflineItemRepository`
- [ ] 删除 3 个 Service 文件
- [ ] 所有 Provider 调用 `ItemRepository`
- [ ] 测试全部通过

### Phase 2 完成后

- [ ] 删除 `itemsProvider`
- [ ] 所有页面使用 `offlineItemsProvider`
- [ ] 测试全部通过

### Phase 3 完成后

- [ ] `paginatedItemsProvider` 是纯派生，无独立数据源
- [ ] 删除 `PaginatedItemsNotifier`
- [ ] 列表自动同步，无需手动刷新
- [ ] 测试全部通过

---

## 变更记录

| 日期 | 版本 | 变更内容 |
|------|------|----------|
| 2026-03-27 | v2.0 | 简洁方案，删除中间层 |
