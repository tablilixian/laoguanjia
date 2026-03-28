# 物品系统优化方案 v3.0

> 版本: v3.0 | 日期: 2026-03-27 | 状态: 待审批

---

## 一、问题诊断

### 当前架构问题

```
┌─────────────────────────────────────────────────────────────────────┐
│  Service 层现状                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  ItemQueryService (587行)                                           │
│  ├── 核心价值: 数据组装、远程回退 (150行, 26%)                        │
│  └── 样板代码: DAO 包装、Companion 构建 (437行, 74%)                 │
├─────────────────────────────────────────────────────────────────────┤
│  ItemCommandService (438行)                                         │
│  ├── 核心价值: UUID生成、版本管理、位图操作 (75行, 17%)               │
│  └── 样板代码: DAO 调用、回调触发 (363行, 83%)                       │
├─────────────────────────────────────────────────────────────────────┤
│  ItemSyncService (491行)                                            │
│  ├── 核心价值: 冲突解决、增量同步策略 (120行, 24%)                    │
│  └── 样板代码: 日志、状态管理 (371行, 76%)                           │
├─────────────────────────────────────────────────────────────────────┤
│  OfflineItemRepository (438行)                                      │
│  └── 纯门面: 每个方法只是 return _service.xxx()                      │
└─────────────────────────────────────────────────────────────────────┘

总计: 1954行
核心价值: 345行 (18%)
样板代码: 1609行 (82%)
```

### 问题本质

| 问题 | 说明 |
|------|------|
| **过度抽象** | 门面层只是转发调用，没有增加价值 |
| **样板膨胀** | 82% 代码是 DAO 包装，没有业务逻辑 |
| **调用链过长** | Provider → Repository → Service → DAO (4层) |
| **文件分散** | 4 个文件，找代码困难 |

---

## 二、优化目标

### 核心原则

```
保留: 345 行真正有价值的业务逻辑
删除: 1600+ 行样板代码
合并: 4 个文件 → 1 个 Repository
```

### 成功标准

- [ ] 代码量减少 80%+
- [ ] 调用链从 4 层减到 3 层
- [ ] 所有功能不变
- [ ] 测试全部通过

---

## 三、核心价值识别

### ItemQueryService 的核心价值

```dart
// 1. 数据组装：物品 + 位置 + 标签
// 价值：UI 需要显示 locationName、tags，但数据库只存 ID
Future<List<HouseholdItem>> getItemsWithDetails(String householdId) async {
  final items = await _localDb.itemsDao.getByHousehold(householdId);
  final locations = await _getLocationsWithFallback(householdId);
  final tags = await _getTagsWithFallback(householdId);
  // 组装到对象上...
}

// 2. 远程回退：本地为空时从远程拉取
// 价值：保证数据可用性
Future<List<ItemLocation>> _getLocationsWithFallback(String householdId) async {
  final local = await _localDb.locationsDao.getByHousehold(householdId);
  if (local.isNotEmpty) return local;
  
  final remote = await _fetchRemoteLocations(householdId);
  for (final loc in remote) {
    await _localDb.locationsDao.insertOrUpdateLocation(...);
  }
  return remote;
}

// 3. 位图解析：从 tagsMask 解析标签列表
// 价值：支持标签位图存储方案
Future<List<ItemTag>> _getTagsFromMask(int tagsMask, String householdId) async {
  final allTags = await getTags(householdId);
  final tagMap = {for (var t in allTags) if (t.tagIndex != null) t.tagIndex!: t};
  final tagIndices = TagsMaskHelper.getTagIds(tagsMask);
  return tagIndices.map((idx) => tagMap[idx]).whereType<ItemTag>().toList();
}
```

### ItemCommandService 的核心价值

```dart
// 1. UUID 生成 + 时间戳设置
// 价值：保证 ID 唯一性，时间戳一致性
Future<HouseholdItem> createItem(HouseholdItem item) async {
  final newItem = item.copyWith(
    id: const Uuid().v4(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    syncStatus: SyncStatus.pending,
  );
}

// 2. 版本号管理（乐观锁）
// 价值：冲突解决基础
Future<HouseholdItem> updateItem(HouseholdItem item) async {
  final current = await _localDb.itemsDao.getById(item.id);
  final newVersion = (current?.version ?? 0) + 1;
  final updatedItem = item.copyWith(version: newVersion);
}

// 3. 位图标签操作
// 价值：标签的高效存储和查询
Future<void> setItemTags(String itemId, List<String> tagIds) async {
  final tagIndices = tagIds.map((id) => tagMap[id]).whereType<int>().toList();
  final newMask = TagsMaskHelper.createMask(tagIndices);
  await _localDb.itemsDao.updateItem(HouseholdItemsCompanion(
    tagsMask: Value(newMask),
  ));
}
```

### ItemSyncService 的核心价值

```dart
// 1. 版本冲突解决
// 价值：处理本地和远程同时修改的情况
for (final localItem in pendingItems) {
  final remoteItem = remoteItemMap[localItem.id];
  final remoteVersion = remoteItem['version'] as int? ?? 0;
  
  if (localItem.version > remoteVersion) {
    itemsToUpdate.add(localItem.toRemoteJson());  // 本地更新推送到远程
  } else {
    itemsToPull.add(localItem.id);  // 拉取远程更新
  }
}

// 2. 增量同步策略
// 价值：只同步变化的数据，提高效率
final itemsToSync = remoteItems.where((remoteItem) {
  final localItem = localItemMap[remoteItem.id];
  return localItem == null || remoteItem.updatedAt.isAfter(localItem.updatedAt);
}).toList();
```

---

## 四、目标架构

```
┌─────────────────────────────────────────────────────────────────────┐
│  Provider 层                                                        │
│  ├── offlineItemsProvider (状态 + 列表 + 同步)                      │
│  └── paginatedItemsProvider (纯派生，切片显示)                      │
├─────────────────────────────────────────────────────────────────────┤
│  Repository 层 (唯一入口，~350行)                                   │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  class ItemRepository {                                         ││
│  │    // ===== 查询（数据组装） =====                               ││
│  │    Future<List<HouseholdItem>> getItemsWithDetails(...)         ││
│  │    Future<PaginatedItemsResult> getItemsPaginated(...)          ││
│  │                                                                 ││
│  │    // ===== 写入（版本管理） =====                               ││
│  │    Future<HouseholdItem> createItem(...)                        ││
│  │    Future<HouseholdItem> updateItem(...)                        ││
│  │    Future<void> deleteItem(...)                                 ││
│  │                                                                 ││
│  │    // ===== 标签（位图操作） =====                               ││
│  │    Future<void> setItemTags(...)                                ││
│  │    Future<List<ItemTag>> _getTagsFromMask(...)                  ││
│  │                                                                 ││
│  │    // ===== 同步（冲突解决） =====                               ││
│  │    Future<SyncResult> sync(...)                                 ││
│  │    Future<List<ItemLocation>> _getLocationsWithFallback(...)    ││
│  │  }                                                              ││
│  └─────────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────────┤
│  DAO 层 (不变)                                                      │
│  ├── ItemsDao (448行)                                               │
│  ├── LocationsDao                                                   │
│  ├── TagsDao                                                        │
│  └── TypesDao                                                       │
├─────────────────────────────────────────────────────────────────────┤
│  数据库 (Drift/SQLite)                                              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 五、分阶段实施

### Phase 1: 合并 Repository + 删除 Service (Week 1)

#### Step 1.1: 扩展 `ItemRepository`

```dart
// lib/data/repositories/item_repository.dart
class ItemRepository {
  final AppDatabase _localDb = getDatabase();
  final SupabaseClient _client = SupabaseClientManager.client;
  
  // ========== 保留原有方法 ==========
  Future<List<ItemLocation>> getLocations(String householdId) { ... }
  Future<List<ItemTag>> getTags(String householdId) { ... }
  // ...
  
  // ========== 从 ItemQueryService 迁移核心价值 ==========
  
  /// 数据组装：物品 + 位置 + 标签
  Future<List<HouseholdItem>> getItemsWithDetails(String householdId) async {
    final items = await _localDb.itemsDao.getByHousehold(householdId);
    final locations = await _getLocationsWithFallback(householdId);
    final locationMap = {for (var l in locations) l.id: l};
    final tags = await _getTagsWithFallback(householdId);
    final tagMap = {for (var t in tags) if (t.tagIndex != null) t.tagIndex!: t};
    
    return items.where((i) => i.deletedAt == null).map((i) {
      final item = i.toHouseholdItemModel();
      final tagIndices = TagsMaskHelper.getTagIds(i.tagsMask);
      final itemTags = tagIndices.map((idx) => tagMap[idx]).whereType<ItemTag>().toList();
      
      return item.copyWith(
        locationName: locationMap[i.locationId]?.name,
        locationIcon: locationMap[i.locationId]?.icon,
        locationPath: locationMap[i.locationId]?.path,
        tags: itemTags,
      );
    }).toList();
  }
  
  /// 分页查询（直接调用 DAO，无包装）
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
    final items = await _localDb.itemsDao.getByHouseholdPaginated(
      householdId,
      limit: limit,
      offset: offset,
      searchQuery: searchQuery,
      itemType: itemType,
      locationId: locationId,
      ownerId: ownerId,
      sortBy: sortBy,
      ascending: sortAsc,
    );
    final totalCount = await _localDb.itemsDao.getCountByHousehold(
      householdId,
      searchQuery: searchQuery,
      itemType: itemType,
      locationId: locationId,
      ownerId: ownerId,
    );
    return PaginatedItemsResult(
      items: items.map((i) => i.toHouseholdItemModel()).toList(),
      totalCount: totalCount,
      hasMore: offset + items.length < totalCount,
    );
  }
  
  // ========== 从 ItemCommandService 迁移核心价值 ==========
  
  /// 创建物品（UUID + 时间戳）
  Future<HouseholdItem> createItem(HouseholdItem item) async {
    final newItem = item.copyWith(
      id: const Uuid().v4(),
      syncStatus: SyncStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _localDb.itemsDao.insertItem(newItem.toCompanion(syncPending: true));
    return newItem;
  }
  
  /// 更新物品（版本号管理）
  Future<HouseholdItem> updateItem(HouseholdItem item) async {
    final current = await _localDb.itemsDao.getById(item.id);
    final newVersion = (current?.version ?? 0) + 1;
    final updatedItem = item.copyWith(
      version: newVersion,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    await _localDb.itemsDao.updateItem(updatedItem.toCompanion(syncPending: true));
    return updatedItem;
  }
  
  /// 设置物品标签（位图操作）
  Future<void> setItemTags(String itemId, List<String> tagIds) async {
    final item = await _localDb.itemsDao.getById(itemId);
    final tags = await _localDb.tagsDao.getByHousehold(item!.householdId);
    final tagMap = {for (var tag in tags) tag.id: tag.tagIndex};
    final tagIndices = tagIds.map((id) => tagMap[id]).whereType<int>().toList();
    final newMask = TagsMaskHelper.createMask(tagIndices);
    
    await _localDb.itemsDao.updateItem(HouseholdItemsCompanion(
      id: Value(itemId),
      tagsMask: Value(newMask),
      updatedAt: Value(DateTime.now()),
      syncPending: const Value(true),
    ));
  }
  
  // ========== 从 ItemSyncService 迁移核心价值 ==========
  
  /// 同步（冲突解决）
  Future<SyncResult> sync(String householdId) async {
    final pendingItems = await _localDb.itemsDao.getSyncPending();
    if (pendingItems.isEmpty) return SyncResult(success: true);
    
    final itemIds = pendingItems.map((i) => i.id).toList();
    final remoteItems = await _client
        .from('household_items')
        .select('id, updated_at, version, deleted_at')
        .or('id.in.(${itemIds.join(',')})');
    final remoteItemMap = {for (var item in remoteItems) item['id']: item};
    
    final itemsToInsert = <Map<String, dynamic>>[];
    final itemsToUpdate = <Map<String, dynamic>>[];
    final itemsToPull = <String>[];
    
    for (final localItem in pendingItems) {
      final remoteItem = remoteItemMap[localItem.id];
      
      if (localItem.deletedAt != null) {
        // 删除同步
        if (remoteItem != null && remoteItem['deleted_at'] == null) {
          await _client.from('household_items')
              .update({'deleted_at': DateTime.now().toIso8601String()})
              .eq('id', localItem.id);
          await _localDb.itemsDao.markSynced(localItem.id);
        }
        continue;
      }
      
      if (remoteItem == null) {
        itemsToInsert.add(localItem.toRemoteJson());
      } else {
        final remoteVersion = remoteItem['version'] as int? ?? 0;
        if (localItem.version > remoteVersion) {
          itemsToUpdate.add(localItem.toRemoteJson());
        } else {
          itemsToPull.add(localItem.id);
        }
      }
    }
    
    // 执行插入、更新、拉取
    if (itemsToInsert.isNotEmpty) {
      await _client.from('household_items').insert(itemsToInsert);
      for (final item in itemsToInsert) {
        await _localDb.itemsDao.markSynced(item['id']);
      }
    }
    if (itemsToUpdate.isNotEmpty) {
      for (final item in itemsToUpdate) {
        await _client.from('household_items').update(item).eq('id', item['id']);
        await _localDb.itemsDao.markSynced(item['id']);
      }
    }
    if (itemsToPull.isNotEmpty) {
      for (final itemId in itemsToPull) {
        final remoteItem = await _fetchRemoteItem(itemId);
        if (remoteItem != null) await _syncItemToLocal(remoteItem);
      }
    }
    
    return SyncResult(success: true, pushed: itemsToInsert.length + itemsToUpdate.length, pulled: itemsToPull.length);
  }
  
  // ========== 内部辅助方法 ==========
  
  Future<List<ItemLocation>> _getLocationsWithFallback(String householdId) async {
    final local = await _localDb.locationsDao.getByHousehold(householdId);
    if (local.isNotEmpty) return local.map((l) => l.toItemLocationModel()).toList();
    
    final remote = await _fetchRemoteLocations(householdId);
    for (final loc in remote) {
      await _localDb.locationsDao.insertOrUpdateLocation(...);
    }
    return remote;
  }
  
  Future<List<ItemTag>> _getTagsWithFallback(String householdId) async {
    final local = await _localDb.tagsDao.getByHousehold(householdId);
    if (local.isNotEmpty) return local.map((t) => t.toItemTagModel()).toList();
    
    final remote = await _fetchRemoteTags(householdId);
    for (final tag in remote) {
      await _localDb.tagsDao.insertOrUpdateTag(...);
    }
    return remote;
  }
}
```

#### Step 1.2: 迁移调用点

```bash
# 查找所有 Service 调用
grep -r "ItemQueryService\|ItemCommandService\|ItemSyncService" lib/ --include="*.dart"
grep -r "offlineItemRepositoryProvider" lib/ --include="*.dart"
```

| 原调用 | 新调用 |
|--------|--------|
| `ref.read(offlineItemRepositoryProvider)` | `ItemRepository()` |
| `_repository.commandService.createItem()` | `_repository.createItem()` |
| `_repository.queryService.getItemsPaginated()` | `_repository.getItemsPaginated()` |
| `_repository.syncService.autoSync()` | `_repository.sync()` |

#### Step 1.3: 删除文件

```bash
# 删除 Service 层
rm lib/data/services/item_query_service.dart
rm lib/data/services/item_command_service.dart
rm lib/data/services/item_sync_service.dart

# 删除旧 Repository
rm lib/data/repositories/offline_item_repository.dart

# 删除 offlineItemRepositoryProvider
# 修改 offline_item_stats_provider.dart，删除 offlineItemRepositoryProvider 定义
```

#### Step 1.4: 验证

```bash
flutter analyze
flutter test
```

---

### Phase 2: 统一 Provider (Week 2)

#### Step 2.1: 删除 `itemsProvider`

```bash
# 查找使用
grep -r "itemsProvider" lib/ --include="*.dart" | grep -v "offline"

# 删除文件
rm lib/features/items/providers/items_provider.dart
```

#### Step 2.2: 迁移调用点

| 原调用 | 新调用 |
|--------|--------|
| `ref.watch(itemsProvider)` | `ref.watch(offlineItemsProvider)` |
| `ref.read(itemsProvider.notifier).createItem()` | `ref.read(offlineItemsProvider.notifier).createItem()` |

---

### Phase 3: 简化分页 Provider (Week 3)

#### Step 3.1: 改为纯派生

```dart
// lib/features/items/providers/paginated_items_provider.dart

/// 分页视图（纯派生，无独立数据源）
class PaginatedView {
  final List<HouseholdItem> items;
  final int totalCount;
  final bool hasMore;
  
  const PaginatedView({
    required this.items,
    required this.totalCount,
    required this.hasMore,
  });
}

/// 当前页码
final _currentPageProvider = StateProvider<int>((ref) => 0);

/// 分页视图 Provider（纯派生）
final paginatedItemsProvider = Provider<PaginatedView>((ref) {
  final itemsState = ref.watch(offlineItemsProvider);
  final page = ref.watch(_currentPageProvider);
  const pageSize = 20;
  
  final filteredItems = itemsState.filteredItems;
  final start = page * pageSize;
  final end = (start + pageSize).clamp(0, filteredItems.length);
  
  if (start >= filteredItems.length) {
    return const PaginatedView(items: [], totalCount: 0, hasMore: false);
  }
  
  return PaginatedView(
    items: filteredItems.sublist(start, end),
    totalCount: filteredItems.length,
    hasMore: end < filteredItems.length,
  );
});

/// 下一页
final nextPageProvider = Provider<void>((ref) {
  ref.read(_currentPageProvider.notifier).state++;
});

/// 重置到第一页
final resetPageProvider = Provider<void>((ref) {
  ref.read(_currentPageProvider.notifier).state = 0;
});
```

#### Step 3.2: 删除 `PaginatedItemsNotifier`

```bash
rm lib/features/items/providers/paginated_items_provider.dart
# 重新创建为纯 Provider 版本
```

---

## 六、收益对比

### 代码量

| 模块 | 当前 | 优化后 | 减少 |
|------|------|--------|------|
| OfflineItemRepository | 438行 | 删除 | -438行 |
| ItemQueryService | 587行 | 删除 | -587行 |
| ItemCommandService | 438行 | 删除 | -438行 |
| ItemSyncService | 491行 | 删除 | -491行 |
| ItemRepository | 798行 | 350行 | -448行 |
| PaginatedItemsNotifier | 350行 | 50行 | -300行 |
| **总计** | 3102行 | 400行 | **-2702行 (-87%)** |

### 文件数

| 类型 | 当前 | 优化后 | 减少 |
|------|------|--------|------|
| Repository | 2 | 1 | -1 |
| Service | 3 | 0 | -3 |
| Provider | 2 | 2 | 0 |
| **总计** | 7 | 3 | **-4** |

### 调用链

```
当前: Provider → Repository → Service → DAO (4层)
优化: Provider → Repository → DAO (3层)
```

---

## 七、测试策略

### 单元测试

```dart
// Repository 直接测试
test('createItem should generate UUID and set timestamps', () async {
  final repo = ItemRepository();
  final item = HouseholdItem(name: 'test', householdId: 'h1');
  
  final created = await repo.createItem(item);
  
  expect(created.id, isNotEmpty);
  expect(created.createdAt, isNotNull);
  expect(created.syncStatus, SyncStatus.pending);
});

test('updateItem should increment version', () async {
  final repo = ItemRepository();
  // 先创建
  final item = await repo.createItem(sampleItem);
  expect(item.version, 1);
  
  // 再更新
  final updated = await repo.updateItem(item.copyWith(name: 'updated'));
  expect(updated.version, 2);
});
```

### 集成测试清单

- [ ] 创建物品 → 本地保存 → 自动同步
- [ ] 批量录入 → 全部保存 → 列表显示
- [ ] 离线操作 → 上线 → 自动同步
- [ ] 冲突解决 → 版本号处理

---

## 八、风险与回滚

### 风险评估

| 风险 | 概率 | 影响 | 对策 |
|------|------|------|------|
| 遗漏边界情况 | 中 | 中 | 完善测试用例 |
| 同步逻辑引入 bug | 低 | 高 | 保留冲突解决测试 |

### 回滚方案

```bash
# 打 tag
git tag v3-phase-1-start
git tag v3-phase-2-start
git tag v3-phase-3-start

# 回滚
git checkout v3-phase-1-start
```

---

## 九、变更记录

| 日期 | 版本 | 变更内容 |
|------|------|----------|
| 2026-03-27 | v3.0 | 基于核心价值分析的完整优化方案 |
