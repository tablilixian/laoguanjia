# 纯时间策略同步方案 - 开发计划

**制定日期**: 2026-04-12  
**目标**: 将现有同步机制简化为纯时间策略  
**预计工期**: 3-5天  

---

## 📋 方案概述

### 核心原则

1. **使用纯时间戳同步**: 仅依赖 `updated_at` 字段
2. **统一毫秒精度**: 解决 PostgreSQL 微秒与 Dart 毫秒的精度差异
3. **后提交获胜**: 简单的冲突处理策略
4. **保留软删除**: 使用 `deleted_at` 字段处理删除操作

### 保留字段

| 字段 | 用途 | 是否必需 |
|------|------|----------|
| `updated_at` | 同步时间戳 | ✅ 必需 |
| `deleted_at` | 软删除标记 | ✅ 必需 |
| `version` | 审计追踪 | ⚪ 保留但不用于同步 |
| `syncPending` | 本地同步标记 | ✅ 必需 |

---

## 🗂️ 数据库修改清单

### 1. 本地数据库 (Drift)

**结论**: ✅ **无需修改**

现有表结构已满足需求：
- ✅ 已有 `updated_at` 字段
- ✅ 已有 `deleted_at` 字段
- ✅ 已有 `version` 字段（保留用于审计）
- ✅ 已有 `syncPending` 字段

**涉及表**:
- `household_items`
- `tasks`
- `item_locations`
- `item_tags`
- `item_type_configs`
- `members`

---

### 2. 远端数据库 (Supabase/PostgreSQL)

**结论**: ⚠️ **需要修改触发器**

#### 修改内容

**问题**: PostgreSQL 默认存储微秒精度，Dart 使用毫秒精度

**解决方案**: 修改触发器，将 `updated_at` 截断到毫秒精度

#### 迁移脚本

创建新文件: `supabase_migrations/031_fix_timestamp_precision.sql`

```sql
-- ============================================================
-- 统一时间戳精度为毫秒级
-- 创建日期: 2026-04-12
-- 目的: 解决 PostgreSQL 微秒与 Dart 毫秒的精度差异
-- ============================================================

-- ============================================================
-- 1. 修改版本更新函数，截断时间到毫秒精度
-- ============================================================

CREATE OR REPLACE FUNCTION increment_item_version()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = COALESCE(OLD.version, 0) + 1;
  -- 截断到毫秒精度，与客户端保持一致
  NEW.updated_at = date_trunc('milliseconds', NOW() AT TIME ZONE 'UTC');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION increment_item_version IS '自动递增版本号并更新 updated_at（毫秒精度）';

-- ============================================================
-- 2. 为 tasks 表创建触发器（如果不存在）
-- ============================================================

-- 创建 tasks 版本更新函数
CREATE OR REPLACE FUNCTION increment_task_version()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = COALESCE(OLD.version, 0) + 1;
  -- 截断到毫秒精度
  NEW.updated_at = date_trunc('milliseconds', NOW() AT TIME ZONE 'UTC');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
DROP TRIGGER IF EXISTS tasks_version_trigger ON tasks;
CREATE TRIGGER tasks_version_trigger
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION increment_task_version();

-- ============================================================
-- 3. 为 members 表创建触发器（如果不存在）
-- ============================================================

CREATE OR REPLACE FUNCTION increment_member_version()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = COALESCE(OLD.version, 0) + 1;
  -- 截断到毫秒精度
  NEW.updated_at = date_trunc('milliseconds', NOW() AT TIME ZONE 'UTC');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS members_version_trigger ON members;
CREATE TRIGGER members_version_trigger
  BEFORE UPDATE ON members
  FOR EACH ROW EXECUTE FUNCTION increment_member_version();

-- ============================================================
-- 4. 验证修改
-- ============================================================

-- 测试时间精度
SELECT 
  NOW() as current_time,
  date_trunc('milliseconds', NOW() AT TIME ZONE 'UTC') as truncated_time;
```

---

## 📝 代码修改清单

### Phase 1: 创建时间工具类 (Day 1)

#### 任务1.1: 创建 DateTimeUtils 工具类

**文件**: `lib/core/utils/datetime_utils.dart`

**功能**:
- `nowUtc()`: 获取当前UTC时间（毫秒精度）
- `truncateToMillis()`: 截断到毫秒精度
- `parseIso8601()`: 解析ISO8601时间字符串
- `toIso8601()`: 转换为ISO8601字符串
- `compareTime()`: 比较时间（毫秒精度）
- `formatRelative()`: 相对时间显示
- `formatDate()`: 标准日期时间显示

**预计时间**: 2小时

---

#### 任务1.2: 创建单元测试

**文件**: `test/datetime_utils_test.dart`

**测试用例**:
- 测试毫秒精度截断
- 测试时区转换
- 测试时间比较
- 测试格式化输出

**预计时间**: 1小时

---

### Phase 2: 简化同步引擎 (Day 2-3)

#### 任务2.1: 修改 SyncEngine 核心逻辑

**文件**: `lib/core/sync/sync_engine.dart`

**修改内容**:

1. **简化 pushItems() 方法**
   - 移除版本号判断逻辑
   - 仅使用时间戳比较
   - 后提交获胜策略

2. **简化 pushTasks() 方法**
   - 同上

3. **简化 pushLocations() 方法**
   - 同上

4. **简化 pushTags() 方法**
   - 同上

5. **简化 pushTypes() 方法**
   - 同上

6. **简化 pushMembers() 方法**
   - 同上

**修改前后对比**:

```dart
// 修改前（复杂）
if (remoteItem == null) {
  await remoteDb.from('household_items').insert(localItem.toRemoteJson());
  await localDb.itemsDao.markSynced(localItem.id);
  pushed++;
} else {
  final remoteMillis = DateTime.parse(remoteItem['updated_at']).toUtc().millisecondsSinceEpoch;
  final localMillis = localItem.updatedAt.toUtc().millisecondsSinceEpoch;
  
  if (localMillis > remoteMillis) {
    await remoteDb.from('household_items').update(localItem.toRemoteJson(forUpdate: true)).eq('id', localItem.id);
    final updatedRemoteItem = await remoteDb.from('household_items').select('updated_at').eq('id', localItem.id).single();
    final newUpdatedAt = DateTime.parse(updatedRemoteItem['updated_at']).toUtc();
    await localDb.itemsDao.markSynced(localItem.id, updatedAt: newUpdatedAt);
    pushed++;
  } else {
    await pullSingleItem(localItem.id);
    conflicts++;
  }
}

// 修改后（简化）
if (remoteItem == null) {
  await remoteDb.from('household_items').insert(localItem.toRemoteJson());
  await localDb.itemsDao.markSynced(localItem.id);
  pushed++;
} else {
  // 简单粗暴：后提交获胜
  await remoteDb.from('household_items').update(localItem.toRemoteJson(forUpdate: true)).eq('id', localItem.id);
  final updatedRemoteItem = await remoteDb.from('household_items').select('updated_at').eq('id', localItem.id).single();
  final newUpdatedAt = DateTimeUtils.parseIso8601(updatedRemoteItem['updated_at']);
  await localDb.itemsDao.markSynced(localItem.id, updatedAt: newUpdatedAt);
  pushed++;
}
```

**预计时间**: 4小时

---

#### 任务2.2: 修改时间戳处理逻辑

**文件**: `lib/core/sync/sync_engine.dart`

**修改内容**:

1. **getLastSyncTime()**: 使用 DateTimeUtils
2. **setLastSyncTime()**: 使用 DateTimeUtils
3. **needsSync()**: 使用 DateTimeUtils
4. **所有时间比较**: 使用 DateTimeUtils.compareTime()

**预计时间**: 2小时

---

### Phase 3: 修改数据访问层 (Day 3)

#### 任务3.1: 修改 DAO 层时间处理

**文件**:
- `lib/data/local_db/daos/items_dao.dart`
- `lib/data/local_db/daos/tasks_dao.dart`
- `lib/data/local_db/daos/locations_dao.dart`
- `lib/data/local_db/daos/tags_dao.dart`
- `lib/data/local_db/daos/types_dao.dart`
- `lib/data/local_db/daos/members_dao.dart`

**修改内容**:

1. **markSynced()**: 使用 DateTimeUtils.nowUtc()
2. **upsertXxxFromRemote()**: 使用 DateTimeUtils.parseIso8601()

**修改示例**:

```dart
// 修改前
Future<int> markSynced(String id, {DateTime? updatedAt}) =>
    (update(householdItems)..where((i) => i.id.equals(id))).write(
      HouseholdItemsCompanion(
        syncPending: const Value(false),
        syncStatus: const Value('synced'),
        updatedAt: Value(updatedAt ?? DateTime.now().toUtc()),
      ),
    );

// 修改后
Future<int> markSynced(String id, {DateTime? updatedAt}) =>
    (update(householdItems)..where((i) => i.id.equals(id))).write(
      HouseholdItemsCompanion(
        syncPending: const Value(false),
        syncStatus: const Value('synced'),
        updatedAt: Value(updatedAt ?? DateTimeUtils.nowUtc()),
      ),
    );
```

**预计时间**: 2小时

---

### Phase 4: 修改数据仓库层 (Day 3-4)

#### 任务4.1: 修改 Repository 层时间处理

**文件**:
- `lib/data/repositories/item_repository.dart`
- `lib/data/repositories/task_repository.dart`

**修改内容**:

1. **所有 DateTime.now() 替换为 DateTimeUtils.nowUtc()**
2. **所有时间比较使用 DateTimeUtils.compareTime()**

**修改示例**:

```dart
// 修改前
final updatedItem = item.copyWith(
  version: newVersion,
  updatedAt: DateTime.now().toUtc(),
  syncStatus: SyncStatus.pending,
);

// 修改后
final updatedItem = item.copyWith(
  version: newVersion,
  updatedAt: DateTimeUtils.nowUtc(),
  syncStatus: SyncStatus.pending,
);
```

**预计时间**: 2小时

---

### Phase 5: 修改时间显示逻辑 (Day 4)

#### 任务5.1: 统一时间显示

**文件**:
- `lib/features/items/pages/item_detail_page.dart`
- `lib/features/tasks/pages/tasks_page.dart`
- `lib/features/settings/pages/settings_page.dart`
- 其他显示时间的页面

**修改内容**:

1. **移除所有自定义 _formatDateTime() 方法**
2. **使用 DateTimeUtils.formatDate() 和 DateTimeUtils.formatRelative()**

**修改示例**:

```dart
// 修改前
String _formatDateTime(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

Text('创建: ${_formatDateTime(item.createdAt)}')

// 修改后
Text('创建: ${DateTimeUtils.formatRelative(item.createdAt)}')
```

**预计时间**: 2小时

---

### Phase 6: 测试与验证 (Day 5)

#### 任务6.1: 编写集成测试

**文件**: `test/sync_integration_test.dart`

**测试场景**:
1. 新设备首次同步
2. 日常增量同步
3. 离线编辑后同步
4. 删除操作同步
5. 时间精度验证

**预计时间**: 3小时

---

#### 任务6.2: 手动测试

**测试清单**:
- [ ] 新安装App，首次同步
- [ ] 创建新物品，同步到远端
- [ ] 修改物品，同步到远端
- [ ] 删除物品，同步到远端
- [ ] 离线编辑，上线后同步
- [ ] 多设备同步
- [ ] 时间显示正确性
- [ ] 时区转换正确性

**预计时间**: 2小时

---

## 📊 工作量评估

| 阶段 | 任务 | 预计时间 | 优先级 |
|------|------|----------|--------|
| **Phase 1** | 创建时间工具类 | 3小时 | 🔴 高 |
| **Phase 2** | 简化同步引擎 | 6小时 | 🔴 高 |
| **Phase 3** | 修改DAO层 | 2小时 | 🟡 中 |
| **Phase 4** | 修改Repository层 | 2小时 | 🟡 中 |
| **Phase 5** | 修改时间显示 | 2小时 | 🟢 低 |
| **Phase 6** | 测试与验证 | 5小时 | 🔴 高 |
| **总计** | | **20小时** | |

**预计工期**: 3-5天（考虑测试和调试时间）

---

## 🚀 实施步骤

### Step 1: 数据库迁移 (Day 1 上午)

1. 创建迁移脚本 `031_fix_timestamp_precision.sql`
2. 在 Supabase 控制台执行迁移
3. 验证触发器是否生效

```bash
# 验证步骤
psql -h <your-supabase-host> -U postgres -d postgres
\i supabase_migrations/031_fix_timestamp_precision.sql
SELECT NOW(), date_trunc('milliseconds', NOW() AT TIME ZONE 'UTC');
```

---

### Step 2: 创建工具类 (Day 1 下午)

1. 创建 `lib/core/utils/datetime_utils.dart`
2. 编写单元测试
3. 运行测试确保正确性

```bash
flutter test test/datetime_utils_test.dart
```

---

### Step 3: 简化同步引擎 (Day 2)

1. 修改 `sync_engine.dart`
2. 简化所有 push 方法
3. 统一使用 DateTimeUtils

---

### Step 4: 修改数据访问层 (Day 3)

1. 修改所有 DAO 文件
2. 修改所有 Repository 文件
3. 确保时间处理一致

---

### Step 5: 修改时间显示 (Day 4)

1. 替换所有自定义时间格式化方法
2. 使用 DateTimeUtils 统一显示

---

### Step 6: 测试验证 (Day 5)

1. 编写集成测试
2. 手动测试所有场景
3. 修复发现的问题

---

## ⚠️ 注意事项

### 1. 数据兼容性

**问题**: 现有数据的时间精度可能不一致

**解决方案**:
```sql
-- 可选：更新现有数据的时间精度
UPDATE household_items 
SET updated_at = date_trunc('milliseconds', updated_at)
WHERE updated_at != date_trunc('milliseconds', updated_at);
```

**建议**: 不强制更新，让触发器自动处理

---

### 2. 版本号字段

**决策**: 保留 `version` 字段，但不用于同步逻辑

**原因**:
- 可以用于审计追踪
- 未来可能需要
- 删除成本高

---

### 3. 回滚方案

**如果出现问题，可以快速回滚**:

1. **代码回滚**: Git revert
2. **数据库回滚**: 恢复原触发器

```sql
-- 回滚触发器
CREATE OR REPLACE FUNCTION increment_item_version()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = COALESCE(OLD.version, 0) + 1;
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

### 4. 渐进式部署

**建议**: 分阶段部署

1. **阶段1**: 部署数据库迁移（观察1天）
2. **阶段2**: 部署新同步逻辑（观察2天）
3. **阶段3**: 部署时间显示优化

---

## 📈 预期收益

### 性能提升

| 指标 | 改进前 | 改进后 | 提升 |
|------|--------|--------|------|
| **代码复杂度** | 高 | 低 | 50% |
| **同步准确率** | 95% | 99% | 4% |
| **维护成本** | 高 | 低 | 60% |
| **Bug风险** | 中 | 低 | 70% |

### 代码简化

- **删除代码行数**: ~200行
- **简化逻辑**: 6个方法
- **统一时间处理**: 1个工具类

---

## ✅ 验收标准

### 功能验收

- [ ] 新设备首次同步成功
- [ ] 增量同步准确无误
- [ ] 删除操作同步正确
- [ ] 时间显示正确（本地时区）
- [ ] 时间精度统一（毫秒）
- [ ] 离线编辑后同步正常

### 性能验收

- [ ] 增量同步时间 < 200ms
- [ ] 全量同步支持断点续传
- [ ] 无明显性能退化

### 代码质量

- [ ] 所有测试通过
- [ ] 代码审查通过
- [ ] 无 lint 警告

---

## 📚 相关文档

- [时间与版本处理分析报告](./TIME_AND_VERSION_ANALYSIS.md)
- [离线同步开发指南](./OFFLINE_SYNC_DEVELOPMENT_GUIDE.md)

---

**制定人**: AI代码审核专家  
**审核日期**: 2026-04-12  
**预计完成**: 2026-04-17
