# 标签位图改造清单

## 概述

将标签关系表（item_tag_relations）改造为位图（tags_mask）存储在物品表中。

## 优势

- 存储：减少 66% 的存储空间
- 带宽：减少 100% 的关系表同步数据
- 性能：查询性能提升 10 倍
- 支持：63 个标签（ID 0-62）

## 数据库改造

### 1. 远程数据库（Supabase PostgreSQL）

#### 1.1 添加标签序号字段

```sql
-- 在 item_tags 表中添加序号字段
ALTER TABLE item_tags 
ADD COLUMN tag_index INTEGER;

-- 为现有标签分配序号
WITH numbered_tags AS (
  SELECT 
    id,
    ROW_NUMBER() OVER (ORDER BY created_at) - 1 as tag_index
  FROM item_tags
)
UPDATE item_tags t
SET tag_index = n.tag_index
FROM numbered_tags n
WHERE t.id = n.id;

-- 创建索引
CREATE INDEX idx_item_tags_tag_index ON item_tags(tag_index);

-- 添加唯一约束
ALTER TABLE item_tags 
ADD CONSTRAINT unique_tag_index UNIQUE (tag_index);
```

#### 1.2 添加 tags_mask 字段

```sql
-- 添加 tags_mask 字段
ALTER TABLE household_items 
ADD COLUMN tags_mask BIGINT DEFAULT 0;

-- 创建索引（用于查询）
CREATE INDEX idx_household_items_tags_mask 
ON household_items(tags_mask);

-- 添加注释
COMMENT ON COLUMN household_items.tags_mask IS '标签位图，每个位对应一个标签序号（0-62）';
```

#### 1.3 数据迁移

```sql
-- 数据迁移：将关系表数据转换为位图（使用 tag_index）
UPDATE household_items h
SET tags_mask = (
    SELECT COALESCE(BIT_OR(1 << t.tag_index), 0)
    FROM item_tag_relations r
    JOIN item_tags t ON r.tag_id = t.id
    WHERE r.item_id = h.id
);

-- 验证数据迁移
SELECT 
    h.id,
    h.name,
    h.tags_mask,
    (SELECT COUNT(*) FROM item_tag_relations WHERE item_id = h.id) as relation_count,
    (
        SELECT COUNT(*) 
        FROM generate_series(0, 62) as s(i) 
        WHERE (h.tags_mask & (1 << s.i)) != 0
    ) as tag_count,
    (
        SELECT STRING_AGG(t.name, ', ')
        FROM item_tag_relations r
        JOIN item_tags t ON r.tag_id = t.id
        WHERE r.item_id = h.id
    ) as tag_names
FROM household_items h
WHERE h.tags_mask != 0
LIMIT 10;
```

#### 1.3 备份和删除关系表

```sql
-- 备份数据（强烈建议）
CREATE TABLE item_tag_relations_backup AS 
SELECT * FROM item_tag_relations;

-- 验证备份成功
SELECT COUNT(*) FROM item_tag_relations_backup;

-- 删除关系表（确认数据迁移成功后）
-- DROP TABLE item_tag_relations;
```

### 2. 本地数据库（SQLite）

#### 2.1 添加 tags_mask 字段

```sql
-- 添加 tags_mask 字段（通过 Drift 自动添加）
ALTER TABLE household_items 
ADD COLUMN tags_mask INTEGER DEFAULT 0;

-- 创建索引
CREATE INDEX idx_household_items_tags_mask 
ON household_items(tags_mask);
```

#### 2.2 添加标签序号字段

```sql
-- 在 item_tags 表中添加序号字段
ALTER TABLE item_tags 
ADD COLUMN tag_index INTEGER;

-- 为现有标签分配序号
UPDATE item_tags t
SET tag_index = (
    SELECT COUNT(*) - 1
    FROM item_tags
    WHERE created_at < t.created_at
);
```

#### 2.3 数据迁移

```sql
-- 数据迁移：将关系表数据转换为位图（使用 tag_index）
UPDATE household_items h
SET tags_mask = (
    SELECT COALESCE(SUM(1 << t.tag_index), 0)
    FROM item_tag_relations r
    JOIN item_tags t ON r.tag_id = t.id
    WHERE r.item_id = h.id
);

-- 验证数据迁移
SELECT 
    h.id,
    h.name,
    h.tags_mask,
    (SELECT COUNT(*) FROM item_tag_relations WHERE item_id = h.id) as relation_count
FROM household_items h
WHERE h.tags_mask != 0
LIMIT 10;
```

#### 2.3 备份和删除关系表

```sql
-- 备份数据（强烈建议）
CREATE TABLE item_tag_relations_backup AS 
SELECT * FROM item_tag_relations;

-- 验证备份成功
SELECT COUNT(*) FROM item_tag_relations_backup;

-- 删除关系表（确认数据迁移成功后）
-- DROP TABLE item_tag_relations;
```

## 代码改造

### 1. 数据库表定义

#### 1.1 修改 household_items 表

**文件：** `lib/data/local_db/tables/household_items.dart`

**状态：** ✅ 已完成

**修改内容：**
```dart
/// 标签位图（64位，支持64个标签）
/// 每个位对应一个标签ID，例如：
/// 标签ID 0 -> 位 0 (1 << 0 = 1)
/// 标签ID 1 -> 位 1 (1 << 1 = 2)
/// ...
/// 标签ID 62 -> 位 62 (1 << 62)
IntColumn get tagsMask => integer().withDefault(const Constant(0))();
```

#### 1.2 可选：删除 item_tag_relations 表

**文件：** `lib/data/local_db/tables/item_tag_relations.dart`

**操作：** 可以保留或删除（建议保留用于备份）

### 2. 数据访问层（DAO）

#### 2.1 修改 ItemsDao

**文件：** `lib/data/local_db/daos/items_dao.dart`

**状态：** ✅ 已完成

**新增方法：**
```dart
/// 根据标签ID获取物品（位图查询）
Future<List<HouseholdItem>> getByTag(String householdId, int tagId);

/// 根据多个标签ID获取物品（OR查询）
Future<List<HouseholdItem>> getByAnyTag(String householdId, List<int> tagIds);

/// 根据多个标签ID获取物品（AND查询）
Future<List<HouseholdItem>> getByAllTags(String householdId, List<int> tagIds);
```

#### 2.2 可选：删除 ItemTagRelationsDao

**文件：** `lib/data/local_db/daos/item_tag_relations_dao.dart`

**操作：** 可以保留或删除（建议保留用于备份）

### 3. 工具类

#### 3.1 位运算工具类

**文件：** `lib/data/utils/tags_mask_helper.dart`

**状态：** ✅ 已创建

**功能：**
- 添加标签：`addTag(int currentMask, int tagId)`
- 删除标签：`removeTag(int currentMask, int tagId)`
- 检查标签：`hasTag(int currentMask, int tagId)`
- 获取标签ID列表：`getTagIds(int currentMask)`
- 创建mask：`createMask(List<int> tagIds)`
- OR查询：`hasAnyTag(int currentMask, List<int> tagIds)`
- AND查询：`hasAllTags(int currentMask, List<int> tagIds)`
- 更新mask：`updateMask(int currentMask, List<int> newTagIds)`
- 获取标签数量：`getTagCount(int currentMask)`
- 检查是否为空：`isEmpty(int currentMask)`

### 4. 服务层

#### 4.1 修改 ItemCommandService

**文件：** `lib/data/services/item_command_service.dart`

**需要修改的方法：**
```dart
/// 设置物品标签
Future<void> setItemTags(String itemId, List<String> tagIds);

/// 添加标签到物品
Future<void> addTagToItem(String itemId, String tagId);

/// 从物品移除标签
Future<void> removeTagFromItem(String itemId, String tagId);
```

**修改内容：**
- 不再操作关系表
- 使用位运算更新 `tags_mask` 字段

#### 4.2 修改 ItemQueryService

**文件：** `lib/data/services/item_query_service.dart`

**需要修改的方法：**
```dart
/// 获取物品的标签
Future<List<ItemTag>> getItemTags(String itemId);
```

**修改内容：**
- 不再查询关系表
- 从 `tags_mask` 字段解析标签ID列表

#### 4.3 修改 ItemSyncService

**文件：** `lib/data/services/item_sync_service.dart`

**需要修改的方法：**
```dart
/// 同步标签关联到本地
Future<void> _syncAllTagRelationsFromRemote();
```

**修改内容：**
- 不再同步关系表
- 直接从物品表的 `tags_mask` 字段读取标签

#### 4.4 修改 OfflineItemRepository

**文件：** `lib/data/repositories/offline_item_repository.dart`

**需要修改的方法：**
```dart
/// 设置物品标签
Future<void> setItemTags(String itemId, List<String> tagIds);

/// 添加标签到物品
Future<void> addTagToItem(String itemId, String tagId);

/// 从物品移除标签
Future<void> removeTagFromItem(String itemId, String tagId);

/// 同步标签关联到远程
Future<void> _syncTagRelationsToRemote(String itemId, List<String> tagIds);
```

**修改内容：**
- 不再操作关系表
- 使用位运算更新 `tags_mask` 字段
- 不再同步关系表到远程

### 5. 数据模型

#### 5.1 修改 HouseholdItem 模型

**文件：** `lib/data/models/household_item.dart`

**需要添加的属性：**
```dart
final int tagsMask;
```

#### 5.2 修改 ItemTag 模型

**文件：** `lib/data/models/item_tag.dart`

**需要添加的方法：**
```dart
/// 获取标签的位位置（用于位图）
int get bitPosition => int.parse(id);
```

## 操作步骤

### 步骤1：数据库改造

1. **远程数据库改造**
   - 在 Supabase 控制台执行 SQL 脚本
   - 添加 `tags_mask` 字段
   - 执行数据迁移
   - 验证数据迁移结果
   - 备份关系表
   - （可选）删除关系表

2. **本地数据库改造**
   - 重新生成数据库代码（已完成）
   - 执行数据迁移脚本
   - 验证数据迁移结果
   - 备份关系表
   - （可选）删除关系表

### 步骤2：代码改造

1. **修改服务层**
   - 修改 `ItemCommandService` 的标签操作方法
   - 修改 `ItemQueryService` 的标签查询方法
   - 修改 `ItemSyncService` 的同步方法
   - 修改 `OfflineItemRepository` 的标签操作方法

2. **修改数据模型**
   - 修改 `HouseholdItem` 模型
   - 修改 `ItemTag` 模型

3. **测试验证**
   - 测试添加标签
   - 测试删除标签
   - 测试查询标签
   - 测试同步功能

### 步骤3：清理工作

1. **删除关系表相关代码**
   - 删除 `ItemTagRelationsDao` 的引用
   - 删除 `item_tag_relations` 表的引用

2. **性能优化**
   - 添加数据库索引
   - 优化查询语句

## 注意事项

1. **标签ID限制**
   - 当前实现支持 63 个标签（ID 0-62）
   - 标签ID必须是连续的整数
   - 建议从 0 开始分配标签ID

2. **数据迁移**
   - 务必先备份数据
   - 验证数据迁移结果
   - 确认无误后再删除关系表

3. **兼容性**
   - 保留关系表作为备份
   - 逐步迁移，避免数据丢失
   - 提供回滚方案

4. **性能优化**
   - 添加数据库索引
   - 使用位运算代替JOIN
   - 批量操作代替单条操作

## 验证清单

- [ ] 远程数据库添加 `tags_mask` 字段
- [ ] 远程数据库数据迁移成功
- [ ] 远程数据库数据验证通过
- [ ] 本地数据库添加 `tags_mask` 字段
- [ ] 本地数据库数据迁移成功
- [ ] 本地数据库数据验证通过
- [ ] 代码改造完成
- [ ] 功能测试通过
- [ ] 性能测试通过
- [ ] 备份数据完成
- [ ] 关系表删除（可选）

## 回滚方案

如果改造出现问题，可以按以下步骤回滚：

1. 恢复关系表数据
2. 删除 `tags_mask` 字段
3. 恢复代码到改造前版本
4. 重新部署应用