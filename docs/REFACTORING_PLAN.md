# 物品系统渐进式重构方案

> 版本: v1.0 | 日期: 2026-03-27 | 状态: 草案

---

## 📋 目录

1. [现状分析](#现状分析)
2. [重构目标](#重构目标)
3. [阶段划分](#阶段划分)
4. [详细方案](#详细方案)
5. [测试策略](#测试策略)
6. [回滚方案](#回滚方案)

---

## 现状分析

### 当前架构

```
┌─────────────────────────────────────────────────────────────────┐
│  Repository 层 (2个)                                            │
│  ┌─────────────────────┐  ┌──────────────────────────────────┐  │
│  │ ItemRepository      │  │ OfflineItemRepository            │  │
│  │ (旧版，798行)        │  │ (新版，门面模式)                   │  │
│  │ 直接操作 Supabase    │  │ CQRS + 离线优先                   │  │
│  └─────────────────────┘  └──────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│  Provider 层 (3个，都有 items 状态)                              │
│  ┌─────────────────────┐  ┌─────────────────────┐              │
│  │ itemsProvider       │  │ offlineItemsProvider │              │
│  │ (旧版，远程直接操作)  │  │ (新版，同步状态管理) │              │
│  └─────────────────────┘  └─────────────────────┘              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ paginatedItemsProvider (分页显示，独立数据源)              │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 问题清单

| ID | 问题 | 严重度 | 影响范围 |
|----|------|--------|----------|
| P1 | 双 Repository 并存，职责不清 | 高 | 维护成本 |
| P2 | 三 Provider 都有 items，易混淆 | 高 | 数据一致性 |
| P3 | 写操作直接触发同步，耦合度高 | 中 | 测试困难 |
| P4 | 旧版 ItemRepository 仍在使用 | 中 | 代码冗余 |
| P5 | 模型层膨胀，包含展示字段 | 低 | 职责模糊 |

---

## 重构目标

### 核心原则

1. **渐进式** - 每个阶段独立可验证
2. **可测试** - 每个改动都有对应测试
3. **可回滚** - 遇到问题能快速恢复
4. **不影响用户** - 重构期间功能正常

### 成功标准

- [ ] 统一使用 `OfflineItemRepository`
- [ ] Provider 减少到 2 个（状态 + 分页）
- [ ] 测试覆盖率 > 80%
- [ ] 无功能回归

---

## 阶段划分

```
Phase 1          Phase 2          Phase 3          Phase 4
(清理旧代码)      (统一 Provider)   (解耦同步)       (优化模型)
────────────────────────────────────────────────────────────────►
   1 周              1 周              1 周              1 周
   
风险: 低           风险: 中          风险: 中          风险: 低
收益: 清晰         收益: 一致性      收益: 可测试      收益: 职责分离
```

---

## 详细方案

### Phase 1: 清理旧代码 (Week 1)

**目标**: 删除 `ItemRepository`，统一使用 `OfflineItemRepository`

#### Step 1.1: 迁移所有调用点

查找所有使用 `ItemRepository` 的地方：

```bash
# 查找调用
grep -r "ItemRepository" lib/ --include="*.dart"
grep -r "import.*item_repository.dart" lib/ --include="*.dart"
```

需要迁移的文件：

| 文件 | 当前调用 | 迁移目标 |
|------|----------|----------|
| `item_ai_assistant_page.dart` | `ItemRepository().getXxx()` | `offlineItemRepositoryProvider.getXxx()` |
| `location_create_edit_page.dart` | `ItemRepository().buildLocationPath()` | `_queryService.getXxx()` |

#### Step 1.2: 创建兼容性适配器（可选）

如果某些功能依赖 `ItemRepository` 的特定方法，可以先创建适配器：

```dart
// lib/data/repositories/repository_adapter.dart
class RepositoryAdapter {
  final OfflineItemRepository _offlineRepo;
  
  // 包装旧方法到新 Repository
  Future<String?> buildLocationPath(String? id) async {
    final location = await _offlineRepo.queryService.getLocation(id);
    // ... 构建路径
  }
}
```

#### Step 1.3: 删除旧 Repository

```bash
# 确认无引用后删除
rm lib/data/repositories/item_repository.dart
```

#### Step 1.4: 验证

```bash
# 编译检查
flutter analyze

# 运行测试
flutter test

# 功能测试清单
- [ ] 创建物品
- [ ] 编辑物品
- [ ] 删除物品
- [ ] 批量录入
- [ ] 搜索物品
- [ ] 离线操作
- [ ] 同步功能
```

---

### Phase 2: 统一 Provider (Week 2)

**目标**: 合并 `itemsProvider` 和 `offlineItemsProvider`

#### Step 2.1: 分析 Provider 使用情况

```bash
# 查找 itemsProvider 的使用
grep -r "itemsProvider" lib/ --include="*.dart" | grep -v "offline"
```

#### Step 2.2: 迁移 Provider 调用

| 原调用 | 新调用 |
|--------|--------|
| `ref.watch(itemsProvider)` | `ref.watch(offlineItemsProvider)` |
| `ref.read(itemsProvider.notifier).createItem()` | `ref.read(offlineItemsProvider.notifier).createItem()` |

#### Step 2.3: 更新 ItemsNotifier

确保 `offlineItemsProvider` 的 `ItemsNotifier` 包含所有 `itemsProvider` 的方法：

```dart
// 需要确认存在的方法
class ItemsNotifier {
  Future<void> createItem(HouseholdItem item);
  Future<void> updateItem(HouseholdItem item);
  Future<void> deleteItem(String itemId);
  Future<void> refresh();
  void setFilters(ItemFilters filters);
  void setSearchQuery(String query);
  void setItemTypeFilter(String? typeKey);
}
```

#### Step 2.4: 删除旧 Provider

```bash
# 删除或重命名为 _deprecated
rm lib/features/items/providers/items_provider.dart
```

#### Step 2.5: 优化 Provider 依赖

让 `paginatedItemsProvider` 直接依赖 `offlineItemsProvider`：

```dart
class PaginatedItemsNotifier extends StateNotifier<PaginatedItemsState> {
  PaginatedItemsNotifier(this._ref) {
    // 监听数据变化，自动刷新
    _ref.listen(offlineItemsProvider, (prev, next) {
      if (_shouldRefresh(prev, next)) {
        refresh();
      }
    });
  }
  
  bool _shouldRefresh(ItemsState? prev, ItemsState next) {
    // 数据长度变化
    if (prev?.items.length != next.items.length) return true;
    // 有新同步的数据
    if (next.items.any((i) => i.syncStatus == SyncStatus.synced)) return true;
    return false;
  }
}
```

---

### Phase 3: 解耦同步逻辑 (Week 3)

**目标**: 写操作不再直接触发同步

#### Step 3.1: 移除同步回调

```dart
// Before
class ItemCommandService {
  final void Function(String householdId)? _onDataChanged;
  
  Future<HouseholdItem> createItem(HouseholdItem item) async {
    await _localDb.itemsDao.insertItem(...);
    _onDataChanged?.call(newItem.householdId);  // 删除
    return newItem;
  }
}

// After
class ItemCommandService {
  // 移除 _onDataChanged 回调
  
  Future<HouseholdItem> createItem(HouseholdItem item) async {
    await _localDb.itemsDao.insertItem(...);
    return newItem;
  }
}
```

#### Step 3.2: 引入事件机制

```dart
// lib/core/events/item_events.dart
class ItemChangedEvent {
  final String householdId;
  final String itemId;
  final ItemChangeType type;  // create, update, delete
  
  ItemChangedEvent({
    required this.householdId,
    required this.itemId,
    required this.type,
  });
}

// lib/core/events/event_bus.dart
class EventBus {
  final _controller = StreamController<ItemChangedEvent>.broadcast();
  
  Stream<ItemChangedEvent> get onItemChanged => _controller.stream;
  
  void fire(ItemChangedEvent event) => _controller.add(event);
}
```

#### Step 3.3: Provider 监听事件

```dart
class ItemsNotifier extends StateNotifier<ItemsState> {
  ItemsNotifier(this._ref) {
    // 监听事件，触发同步
    _eventBus.onItemChanged.listen((event) {
      if (state.isOnline && !state.isSyncing) {
        _triggerAutoSync();
      }
    });
  }
}
```

#### Step 3.4: 写操作发事件

```dart
class ItemCommandService {
  final EventBus _eventBus;
  
  Future<HouseholdItem> createItem(HouseholdItem item) async {
    await _localDb.itemsDao.insertItem(...);
    
    // 发事件，不直接调用同步
    _eventBus.fire(ItemChangedEvent(
      householdId: item.householdId,
      itemId: item.id,
      type: ItemChangeType.create,
    ));
    
    return item;
  }
}
```

---

### Phase 4: 优化模型层 (Week 4)

**目标**: 分离数据模型和展示模型

#### Step 4.1: 拆分 HouseholdItem

```dart
// lib/data/models/household_item_entity.dart
class HouseholdItemEntity {
  final String id;
  final String householdId;
  final String name;
  final String itemType;
  final int quantity;
  // ... 纯数据字段
}

// lib/data/models/household_item_view.dart
class HouseholdItemView extends HouseholdItemEntity {
  final String? locationName;   // join 结果
  final String? locationIcon;
  final String? ownerName;
  final List<ItemTag> tags;
  
  HouseholdItemView({
    required HouseholdItemEntity entity,
    this.locationName,
    this.locationIcon,
    this.ownerName,
    this.tags = const [],
  }) : super(/* ... */);
}
```

#### Step 4.2: 更新查询服务

```dart
class ItemQueryService {
  // 返回 Entity
  Future<HouseholdItemEntity> getItem(String id) async { ... }
  
  // 返回 View（包含 join 数据）
  Future<HouseholdItemView> getItemView(String id) async {
    final entity = await getItem(id);
    final location = await getLocation(entity.locationId);
    // ...
    return HouseholdItemView(entity: entity, locationName: location?.name);
  }
}
```

#### Step 4.3: 更新 UI 层

```dart
// UI 使用 ViewModel
class ItemListTile extends StatelessWidget {
  final HouseholdItemView item;  // 使用 View，包含展示字段
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.name),
      subtitle: Text(item.locationName ?? '未分配位置'),  // 直接使用
    );
  }
}
```

---

## 测试策略

### 测试金字塔

```
                    /\
                   /  \
                  / E2E \        5% - 关键流程
                 /--------\
                / Integration\   20% - Provider + Repository
               /--------------\
              /   Unit Tests    \ 75% - Service + Model
             /------------------\
```

### 各阶段测试

#### Phase 1 测试

```dart
// test/data/repositories/offline_item_repository_test.dart
void main() {
  group('OfflineItemRepository', () {
    test('createItem should insert to local db', () async {
      // Arrange
      final mockDb = MockAppDatabase();
      final repo = OfflineItemRepository(localDb: mockDb);
      
      // Act
      final item = await repo.createItem(sampleItem);
      
      // Assert
      verify(mockDb.itemsDao.insertItem(any)).called(1);
    });
  });
}
```

#### Phase 2 测试

```dart
// test/features/items/providers/offline_items_provider_test.dart
void main() {
  group('ItemsNotifier', () {
    test('should auto refresh when offlineItemsProvider changes', () async {
      // Arrange
      final container = ProviderContainer();
      
      // Act
      container.read(offlineItemsProvider.notifier).createItem(sampleItem);
      
      // Assert
      await Future.delayed(Duration(milliseconds: 100));
      final paginated = container.read(paginatedItemsProvider);
      expect(paginated.items.length, 1);
    });
  });
}
```

#### Phase 3 测试

```dart
// test/data/services/item_command_service_test.dart
void main() {
  group('ItemCommandService', () {
    test('createItem should emit event but not sync', () async {
      // Arrange
      final mockDb = MockAppDatabase();
      final mockEventBus = MockEventBus();
      final service = ItemCommandService(
        localDb: mockDb,
        eventBus: mockEventBus,
      );
      
      // Act
      await service.createItem(sampleItem);
      
      // Assert
      verify(mockEventBus.fire(any)).called(1);
      verifyNever(mockDb.itemsDao.markSynced(any));  // 未同步
    });
  });
}
```

### 集成测试清单

| 测试场景 | 用例 | 预期结果 |
|----------|------|----------|
| 创建物品 | 离线创建 | 写入本地，标记 pending |
| 创建物品 | 在线创建 | 写入本地，自动同步 |
| 批量录入 | 3个物品 | 全部保存，列表刷新 |
| 冲突解决 | 本地修改+远程修改 | 按版本号解决 |
| 网络恢复 | 离线->在线 | 自动同步 pending 数据 |

---

## 回滚方案

### 每阶段回滚点

```bash
# Phase 1 回滚
git checkout phase-1-start

# Phase 2 回滚  
git checkout phase-2-start

# Phase 3 回滚
git checkout phase-3-start
```

### 快速回滚命令

```bash
# 如果重构导致问题，立即回滚到上一个稳定版本
git stash  # 保存当前改动
git checkout master  # 回到主分支
git pull  # 拉取最新代码
```

### 数据库回滚

如果涉及数据库 schema 变更：

```sql
-- 保留旧表备份
CREATE TABLE household_items_backup AS SELECT * FROM household_items;

-- 回滚时恢复
DROP TABLE household_items;
ALTER TABLE household_items_backup RENAME TO household_items;
```

---

## 附录

### A. 涉及文件清单

#### Phase 1 需修改

| 文件 | 操作 |
|------|------|
| `lib/data/repositories/item_repository.dart` | 删除 |
| `lib/features/items/pages/item_ai_assistant_page.dart` | 修改调用 |
| `lib/features/items/pages/location_create_edit_page.dart` | 修改调用 |

#### Phase 2 需修改

| 文件 | 操作 |
|------|------|
| `lib/features/items/providers/items_provider.dart` | 删除 |
| 所有使用 `itemsProvider` 的文件 | 迁移到 `offlineItemsProvider` |

#### Phase 3 需修改

| 文件 | 操作 |
|------|------|
| `lib/core/events/event_bus.dart` | 新建 |
| `lib/core/events/item_events.dart` | 新建 |
| `lib/data/services/item_command_service.dart` | 移除回调 |

#### Phase 4 需修改

| 文件 | 操作 |
|------|------|
| `lib/data/models/household_item.dart` | 拆分 |
| `lib/data/models/household_item_entity.dart` | 新建 |
| `lib/data/models/household_item_view.dart` | 新建 |

### B. 检查清单

#### 重构前

- [ ] 创建 feature branch
- [ ] 运行现有测试，确认全部通过
- [ ] 备份数据库

#### 每阶段完成后

- [ ] `flutter analyze` 无错误
- [ ] `flutter test` 全部通过
- [ ] 功能测试清单验证
- [ ] 提交并推送到远程

#### 重构完成后

- [ ] 所有阶段测试通过
- [ ] 性能测试（大数据量）
- [ ] 用户验收测试
- [ ] 文档更新

---

## 时间线

| 周 | 阶段 | 产出 | 负责人 |
|----|------|------|--------|
| W1 | Phase 1 | 删除 ItemRepository | - |
| W2 | Phase 2 | 统一 Provider | - |
| W3 | Phase 3 | 事件解耦 | - |
| W4 | Phase 4 | 模型分层 | - |
| W5 | 集成测试 | 全流程验证 | - |

---

## 变更记录

| 日期 | 版本 | 变更内容 |
|------|------|----------|
| 2026-03-27 | v1.0 | 初始版本 |
