# 家庭物品模块 (Household Items) 开发规范

> 本文档是家庭物品模块的完整开发规范，供 AI 开发助手直接使用。
> 设计日期：2026-03-13

---

## 1. 模块概述

### 1.1 功能目标

家庭物品管理模块，帮助家庭成员管理家中所有物品，支持：
- 多维度分类（类型、位置、归属人、标签）
- 灵活查询（按任意维度组合筛选）
- 图片记录（拍照添加物品）
- 本地优先存储 + 云端同步
- AI 智能识别和分析

### 1.2 核心设计理念

**三个独立维度 + 灵活标签**

- **类型（item_type）**：这是什么？（家电、衣物、家具...）
- **位置（location_id）**：在哪里？（厨房、主卧衣柜...）
- **归属人（owner_id）**：属于谁？（爸爸、妈妈...）
- **标签（tags）**：还有什么特征？（冬装、深色、需要维修...）

这四个维度相互独立，可以任意组合查询。

---

## 2. 数据库设计（Supabase PostgreSQL）

### 2.1 表结构总览

```
household_items (物品主表)
    ├── item_type_configs (类型配置表) ← 动态可扩展
    ├── item_locations (位置表) ← 支持层级
    ├── item_tags (标签表) ← 支持分组
    └── item_tag_relations (标签关联表) ← 多对多

已有关联：
    ├── households (家庭表) ← 已有
    └── members (成员表) ← 已有
```

### 2.2 household_items（物品主表）

```sql
CREATE TABLE household_items (
  -- 基础字段
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,

  -- 物品基本信息
  name TEXT NOT NULL,                           -- 物品名称（必填）
  description TEXT,                             -- 描述

  -- 三个独立分类维度
  item_type TEXT NOT NULL DEFAULT 'other',       -- 物品类型键：引用 item_type_configs.type_key（动态可扩展）
  location_id UUID REFERENCES item_locations(id) ON DELETE SET NULL,  -- 位置
  owner_id UUID REFERENCES members(id) ON DELETE SET NULL,            -- 归属人

  -- 物品属性
  quantity INTEGER NOT NULL DEFAULT 1,          -- 数量
  brand TEXT,                                   -- 品牌
  model TEXT,                                   -- 型号
  purchase_date DATE,                           -- 购买日期
  purchase_price DECIMAL(10,2),                 -- 购买价格
  warranty_expiry DATE,                         -- 保修到期日
  condition TEXT DEFAULT 'good'                 -- 物品状态
    CHECK (condition IN ('new', 'good', 'fair', 'poor')),

  -- 图片
  image_url TEXT,                               -- 本地图片路径
  thumbnail_url TEXT,                           -- 缩略图路径

  -- 备注
  notes TEXT,                                   -- 备注信息

  -- 云端同步
  sync_status TEXT DEFAULT 'pending'            -- 同步状态：pending/synced/error
    CHECK (sync_status IN ('pending', 'synced', 'error')),
  remote_id TEXT,                               -- 云端ID（同步后回填）

  -- 审计字段
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ                        -- 软删除
);

-- 索引
CREATE INDEX idx_items_household ON household_items(household_id);
CREATE INDEX idx_items_type ON household_items(household_id, item_type);
CREATE INDEX idx_items_location ON household_items(location_id);
CREATE INDEX idx_items_owner ON household_items(owner_id);
CREATE INDEX idx_items_sync ON household_items(sync_status) WHERE sync_status != 'synced';
CREATE INDEX idx_items_search ON household_items USING gin(to_tsvector('simple', name));
CREATE INDEX idx_items_active ON household_items(household_id) WHERE deleted_at IS NULL;
```

**item_type 字段说明**：
- 存储 `item_type_configs.type_key`（如 `appliance`, `clothing`）
- 无 CHECK 约束，支持动态扩展
- 由应用层通过 `item_type_configs` 表校验有效性

**condition 可选值**：
- `new`：全新
- `good`：正常使用
- `fair`：有些磨损
- `poor`：需要维修或更换

### 2.3 item_type_configs（类型配置表）—— 可动态扩展

> **设计目的**：物品类型不再硬编码，支持系统预设 + 家庭自定义，可随时添加新类型。

```sql
CREATE TABLE item_type_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- household_id: NULL = 系统预设（所有家庭可见），非NULL = 该家庭自定义
  household_id UUID REFERENCES households(id) ON DELETE CASCADE,
  
  type_key TEXT NOT NULL,               -- 类型键：'appliance', 'clothing', 'book'...
  type_label TEXT NOT NULL,             -- 显示名称：'家电', '衣物', '书籍'...
  icon TEXT DEFAULT '📦',               -- 图标
  color TEXT DEFAULT '#6B7280',         -- 颜色（十六进制）
  sort_order INTEGER DEFAULT 0,         -- 排序
  is_active BOOLEAN DEFAULT true,       -- 是否启用（停用后新建物品不可选，已有数据保留）
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(household_id, type_key)        -- 同一家庭内类型键不重复
);

-- 索引
CREATE INDEX idx_type_configs_household ON item_type_configs(household_id);
CREATE INDEX idx_type_configs_active ON item_type_configs(household_id, is_active);
```

**系统预设数据（household_id = NULL）**：

| type_key | type_label | icon | color | sort_order |
|----------|-----------|------|-------|------------|
| appliance | 家电 | 🔌 | #2196F3 | 1 |
| clothing | 衣物 | 👕 | #E91E63 | 2 |
| furniture | 家具 | 🛋️ | #795548 | 3 |
| tableware | 餐具 | 🍽️ | #FF9800 | 4 |
| tool | 工具 | 🔧 | #607D8B | 5 |
| decoration | 装饰品 | 🖼️ | #9C27B0 | 6 |
| daily | 日用品 | 🧴 | #4CAF50 | 7 |
| book | 书籍 | 📚 | #3F51B5 | 8 |
| medicine | 药品 | 💊 | #F44336 | 9 |
| sports | 运动器材 | ⚽ | #00BCD4 | 10 |
| toy | 玩具 | 🎮 | #FF5722 | 11 |
| other | 其他 | 📦 | #9E9E9E | 99 |

**扩展性设计**：
- 用户可添加自定义类型（如"收藏品"、"园艺用品"）
- 用户可停用不需要的类型（is_active=false）
- 停用不影响已有物品数据
- 改名只需修改 type_label，不改 type_key（数据兼容）

**查询可用类型**：
```sql
-- 获取某家庭可用类型（系统预设 + 该家庭自定义）
SELECT * FROM item_type_configs
WHERE (household_id IS NULL OR household_id = $1) AND is_active = true
ORDER BY sort_order ASC;
```

### 2.4 item_locations（位置表）

```sql
CREATE TABLE item_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,

  name TEXT NOT NULL,                           -- 位置名称
  description TEXT,                             -- 描述
  icon TEXT DEFAULT '📍',                       -- 图标
  color TEXT,                                   -- 颜色标记

  -- 层级支持（自引用）
  parent_id UUID REFERENCES item_locations(id) ON DELETE CASCADE,
  depth INTEGER DEFAULT 0,                      -- 层级深度：0=顶层房间，1=家具，2=抽屉/隔层
  path TEXT,                                    -- 路径：用于快速查询子节点，如 "loc1.loc2.loc3"

  sort_order INTEGER DEFAULT 0,                 -- 排序

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_locations_household ON item_locations(household_id);
CREATE INDEX idx_locations_parent ON item_locations(parent_id);
CREATE INDEX idx_locations_path ON item_locations(path);
```

**层级示例**：
```
depth=0: 厨房、主卧、客厅、浴室...
depth=1: 衣柜、书桌、床头柜（属于主卧）
depth=2: 上层抽屉、下层隔层（属于衣柜）
```

**path 字段用法**：
- 顶层位置：`path = "loc1"`
- 子位置：`path = "loc1.loc2"`
- 孙位置：`path = "loc1.loc2.loc3"`
- 查询主卧所有物品（含子位置）：`WHERE path LIKE '主卧路径%'`

### 2.5 item_tags（标签表）

```sql
CREATE TABLE item_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,

  name TEXT NOT NULL,                           -- 标签名称
  color TEXT DEFAULT '#6B7280',                 -- 标签颜色（十六进制）
  icon TEXT,                                    -- 图标（可选）
  category TEXT DEFAULT 'other',                -- 标签分组

  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(household_id, name)                    -- 同一家庭内标签名不重复
);

-- 索引
CREATE INDEX idx_tags_household ON item_tags(household_id);
CREATE INDEX idx_tags_category ON item_tags(household_id, category);
```

**标签分组 category 可选值**：
- `season`：季节类（春装、夏装、秋装、冬装）
- `color`：颜色类（深色、浅色、彩色、黑白）
- `status`：状态类（需要维修、新品、待处理、待丢弃、已借出）
- `type`：细分类型（内衣、外衣、睡衣、正装、运动装）
- `other`：其他自定义标签

**预设标签（初始化时插入）**：

| 名称 | 分组 | 颜色 |
|------|------|------|
| 春装 | season | #4CAF50 |
| 夏装 | season | #FF9800 |
| 秋装 | season | #795548 |
| 冬装 | season | #2196F3 |
| 深色 | color | #424242 |
| 浅色 | color | #9E9E9E |
| 彩色 | color | #E91E63 |
| 需要维修 | status | #F44336 |
| 新品 | status | #4CAF50 |
| 待处理 | status | #FF9800 |
| 待丢弃 | status | #795548 |
| 内衣 | type | #E1BEE7 |
| 外衣 | type | #BBDEFB |
| 睡衣 | type | #C8E6C9 |
| 正装 | type | #3F51B5 |
| 运动装 | type | #FF5722 |

### 2.6 item_tag_relations（标签关联表）

```sql
CREATE TABLE item_tag_relations (
  item_id UUID NOT NULL REFERENCES household_items(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES item_tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  PRIMARY KEY (item_id, tag_id)                 -- 联合主键，防止重复
);

-- 索引
CREATE INDEX idx_tag_relations_item ON item_tag_relations(item_id);
CREATE INDEX idx_tag_relations_tag ON item_tag_relations(tag_id);
```

### 2.7 RLS 策略

```sql
-- household_items: 成员只能访问自己家庭的物品
ALTER TABLE household_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members_can_view_household_items" ON household_items
  FOR SELECT USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "members_can_insert_household_items" ON household_items
  FOR INSERT WITH CHECK (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "members_can_update_household_items" ON household_items
  FOR UPDATE USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "members_can_delete_household_items" ON household_items
  FOR DELETE USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

-- item_locations: 同上
ALTER TABLE item_locations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "members_can_manage_locations" ON item_locations
  FOR ALL USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

-- item_tags: 同上
ALTER TABLE item_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "members_can_manage_tags" ON item_tags
  FOR ALL USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

-- item_tag_relations: 通过 item_id 关联的 household_id 判断
ALTER TABLE item_tag_relations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "members_can_manage_tag_relations" ON item_tag_relations
  FOR ALL USING (
    item_id IN (
      SELECT id FROM household_items WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
  );
```

### 2.8 更新时间触发器

```sql
-- 自动更新 updated_at 字段
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_household_items_updated_at
  BEFORE UPDATE ON household_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_item_locations_updated_at
  BEFORE UPDATE ON item_locations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

## 3. 查询示例

### 3.1 基础查询

```sql
-- 查询家庭的所有物品（未删除）
SELECT * FROM household_items
WHERE household_id = $1 AND deleted_at IS NULL
ORDER BY updated_at DESC;

-- 查询所有家电
SELECT * FROM household_items
WHERE household_id = $1 AND item_type = '家电' AND deleted_at IS NULL;

-- 查询厨房的所有物品
SELECT * FROM household_items
WHERE household_id = $1 AND location_id = $厨房id AND deleted_at IS NULL;

-- 查询爸爸的所有物品
SELECT * FROM household_items
WHERE household_id = $1 AND owner_id = $爸爸id AND deleted_at IS NULL;
```

### 3.2 组合查询

```sql
-- 厨房的家电
SELECT * FROM household_items
WHERE household_id = $1
  AND item_type = '家电'
  AND location_id = $厨房id
  AND deleted_at IS NULL;

-- 爸爸的衣物
SELECT * FROM household_items
WHERE household_id = $1
  AND item_type = '衣物'
  AND owner_id = $爸爸id
  AND deleted_at IS NULL;
```

### 3.3 标签查询

```sql
-- 有"冬装"标签的物品
SELECT i.* FROM household_items i
JOIN item_tag_relations itr ON i.id = itr.item_id
JOIN item_tags t ON t.id = itr.tag_id
WHERE t.name = '冬装' AND i.household_id = $1 AND i.deleted_at IS NULL;

-- 同时有"冬装"和"深色"标签的物品
SELECT i.* FROM household_items i
WHERE i.household_id = $1 AND i.deleted_at IS NULL
  AND i.id IN (
    SELECT item_id FROM item_tag_relations itr
    JOIN item_tags t ON t.id = itr.tag_id
    WHERE t.name IN ('冬装', '深色') AND t.household_id = $1
    GROUP BY item_id
    HAVING COUNT(DISTINCT t.name) = 2
  );
```

### 3.4 层级位置查询

```sql
-- 查询主卧的所有物品（包括衣柜、床头柜等子位置）
SELECT i.* FROM household_items i
JOIN item_locations l ON i.location_id = l.id
WHERE l.path LIKE (SELECT path || '%' FROM item_locations WHERE id = $主卧id)
  AND i.household_id = $1 AND i.deleted_at IS NULL;
```

### 3.5 统计查询

```sql
-- 各类型物品数量
SELECT item_type, COUNT(*) as count
FROM household_items
WHERE household_id = $1 AND deleted_at IS NULL
GROUP BY item_type
ORDER BY count DESC;

-- 各位置物品数量
SELECT l.name, COUNT(i.id) as count
FROM item_locations l
LEFT JOIN household_items i ON i.location_id = l.id AND i.deleted_at IS NULL
WHERE l.household_id = $1
GROUP BY l.id, l.name
ORDER BY count DESC;

-- 各成员物品数量
SELECT m.name, COUNT(i.id) as count
FROM members m
LEFT JOIN household_items i ON i.owner_id = m.id AND i.deleted_at IS NULL
WHERE m.household_id = $1
GROUP BY m.id, m.name
ORDER BY count DESC;
```

---

## 4. 前端架构

### 4.1 目录结构

```
lib/
├── data/
│   ├── models/
│   │   ├── household_item.dart       # 物品模型
│   │   ├── item_location.dart        # 位置模型
│   │   ├── item_tag.dart             # 标签模型
│   │   └── item_type_config.dart     # 类型配置模型
│   ├── repositories/
│   │   ├── item_repository.dart      # 本地数据访问
│   │   └── item_remote_repository.dart  # 云端数据访问
│   └── local/
│       └── item_database.dart        # SQLite 本地数据库
├── features/
│   └── items/
│       ├── pages/
│       │   ├── items_list_page.dart      # 物品列表页
│       │   ├── item_detail_page.dart     # 物品详情页
│       │   ├── item_create_page.dart     # 添加/编辑物品页
│       │   ├── item_locations_page.dart  # 位置管理页
│       │   ├── item_tags_page.dart       # 标签管理页
│       │   └── item_type_manage_page.dart # 类型管理页
│       └── providers/
│           ├── items_provider.dart       # 物品列表状态
│           ├── item_filters_provider.dart # 筛选条件状态
│           ├── locations_provider.dart   # 位置管理状态
│           └── item_types_provider.dart  # 类型配置状态
├── core/
│   └── services/
│       ├── sync_service.dart         # 同步服务
│       ├── item_image_service.dart   # 图片处理服务
│       └── item_type_service.dart    # 类型配置服务
```

### 4.2 路由配置

```
/home/items              → 物品列表页
/home/items/create       → 添加物品页
/home/items/:id          → 物品详情页
/home/items/:id/edit     → 编辑物品页
/home/items/locations    → 位置管理页
/home/items/tags         → 标签管理页
/home/items/types        → 类型管理页（新增/停用类型）
```

### 4.3 数据模型（Dart）

```dart
// ===== 类型配置模型（动态可扩展） =====
class ItemTypeConfig {
  final String id;
  final String? householdId;  // null = 系统预设
  final String typeKey;       // 如 'appliance', 'clothing'
  final String typeLabel;     // 如 '家电', '衣物'
  final String icon;
  final Color color;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;

  bool get isPreset => householdId == null;

  const ItemTypeConfig({...});
  factory ItemTypeConfig.fromMap(Map<String, dynamic> map) {...}
  Map<String, dynamic> toMap() {...}
}

// ===== 物品状态枚举 =====
enum ItemCondition {
  new_('全新', 'new'),
  good('正常使用', 'good'),
  fair('有些磨损', 'fair'),
  poor('需要维修', 'poor');

  final String label;
  final String dbValue;
  const ItemCondition(this.label, this.dbValue);

  static ItemCondition fromString(String value) {
    return ItemCondition.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => ItemCondition.good,
    );
  }
}

// ===== 同步状态枚举 =====
enum SyncStatus {
  pending, synced, error;

  static SyncStatus fromString(String value) {
    return SyncStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncStatus.pending,
    );
  }
}

// ===== 物品模型 =====
class HouseholdItem {
  final String id;
  final String householdId;
  final String name;
  final String? description;
  final String itemType;      // 存储 type_key（如 'appliance'），非枚举
  final String? locationId;
  final String? ownerId;
  final int quantity;
  final String? brand;
  final String? model;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final DateTime? warrantyExpiry;
  final ItemCondition condition;
  final String? imageUrl;
  final String? thumbnailUrl;
  final String? notes;
  final SyncStatus syncStatus;
  final String? remoteId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  // 关联数据（JOIN 查询时填充）
  final String? locationName;
  final String? locationIcon;
  final String? ownerName;
  final List<ItemTag> tags;
  final ItemTypeConfig? typeConfig;  // 关联的类型配置

  const HouseholdItem({...});
  factory HouseholdItem.fromMap(Map<String, dynamic> map) {...}
  Map<String, dynamic> toMap() {...}
  HouseholdItem copyWith({...}) {...}

  // 便捷方法
  bool get isDeleted => deletedAt != null;
  bool get needsSync => syncStatus != SyncStatus.synced;
  bool get isInWarranty => warrantyExpiry != null && warrantyExpiry!.isAfter(DateTime.now());
}
```

**关键改动**：
- `ItemType` 硬编码枚举 → `ItemTypeConfig` 动态配置类
- `item_type` 字段存储 `type_key`（字符串），通过 `ItemTypeService` 查询显示名称
- 新增 `item_type_service.dart` 管理类型配置的 CRUD

---

## 5. Provider 层（Riverpod）

### 5.1 Provider 架构

```
itemRepositoryProvider        → 依赖注入（单例）
itemFiltersProvider           → StateNotifier（筛选条件）
itemsProvider(householdId)    → StateNotifier.family（物品列表 CRUD）
filteredItemsProvider         → Provider.family（组合筛选逻辑）
locationsProvider             → FutureProvider.family（位置列表）
tagsProvider                  → FutureProvider.family（标签列表）
itemTypesProvider             → FutureProvider.family（类型配置）
itemCountByTypeProvider       → FutureProvider.family（统计）
```

### 5.2 筛选条件模型

```dart
class ItemFilters {
  final String? itemType;
  final String? locationId;
  final String? ownerId;
  final List<String> tagNames;
  final String? searchQuery;
  final String sortBy;   // 'name', 'date', 'type'
  final bool sortAsc;
}
```

### 5.3 组合筛选逻辑

`filteredItemsProvider` 监听 `itemsProvider` 和 `itemFiltersProvider`，实时计算筛选结果。

---

## 6. 路由配置

### 6.1 路由表

| 路径 | 页面 | 说明 |
|------|------|------|
| `/home/items` | ItemsListPage | 物品列表（主入口） |
| `/home/items/create` | ItemCreatePage | 添加/编辑物品 |
| `/home/items/:itemId` | ItemDetailPage | 物品详情 |
| `/home/items/locations` | ItemLocationsPage | 位置管理 |
| `/home/items/tags` | ItemTagsPage | 标签管理 |
| `/home/items/types` | ItemTypeManagePage | 类型管理 |

### 6.2 路由实现

在 `lib/app.dart` 的 ShellRoute 内添加，遵循现有 tasks/pets 模式。

---

## 7. 本地存储 + 云端同步

### 5.1 本地 SQLite 表结构

与 Supabase 表结构相同，额外增加：
- `sync_status`：同步状态
- `remote_id`：云端 ID

### 5.2 同步策略

```
写入流程：
1. 用户操作 → 写入本地 SQLite（sync_status='pending'）
2. UI 立即更新（不等待同步）
3. 后台异步上传到 Supabase
4. 上传成功 → 更新 sync_status='synced'
5. 上传失败 → 保持 'pending'，下次重试

读取流程：
1. 优先读取本地 SQLite
2. 网络可用时，后台拉取远程更新
3. 合并远程数据到本地
```

### 5.3 冲突解决

策略：**最后写入获胜（Last Write Wins）**
- 比较 `updated_at` 时间戳
- 较新的版本覆盖较旧的
- 如果本地有未同步的变更，本地优先

---

## 6. AI 功能扩展

### 6.1 物品识别

使用 Gemini Vision API，拍照识别物品：
- 输入：物品照片
- 输出：名称、类型、品牌、颜色、建议标签

### 6.2 自然语言查询

注入物品数据上下文，让 AI 回答：
- "厨房有哪些家电？"
- "爸爸的冬装都在哪？"
- "家里最贵的东西是什么？"

### 6.3 分析报告

基于统计数据，AI 生成：
- 家庭物品总览
- 各房间物品分析
- 闲置物品识别（断舍离建议）
- 保养/更换提醒

---

## 7. 开发检查清单

### Phase 1: 基础架构
- [ ] 创建数据库迁移文件（5张表 + 索引 + RLS）— 包含 item_type_configs
- [ ] 创建 Dart 数据模型（4个模型类：HouseholdItem, ItemLocation, ItemTag, ItemTypeConfig）
- [ ] 创建本地 SQLite 数据库封装
- [ ] 创建 ItemTypeService（类型配置服务）
- [ ] 创建 Repository 层
- [ ] 创建 Provider 层（Riverpod）
- [ ] 配置路由
- [ ] 初始化系统预设类型数据

### Phase 2: 核心 UI
- [ ] 物品列表页（带搜索和筛选）
- [ ] 添加物品页
- [ ] 编辑物品页
- [ ] 物品详情页
- [ ] 位置管理页
- [ ] 标签管理页
- [ ] 类型管理页（添加/停用自定义类型）
- [ ] 底部导航集成

### Phase 3: 图片和同步
- [ ] 图片拍照/选择
- [ ] 图片压缩和缩略图
- [ ] 本地图片存储
- [ ] 云端同步服务
- [ ] 同步状态 UI 指示

### Phase 4: AI 功能
- [ ] AI 物品识别
- [ ] 自然语言查询
- [ ] AI 分析报告
- [ ] AI Chat 整合

---

## 8. 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-03-13 | 初始版本，完成数据库设计 |
| v1.1 | 2026-03-13 | 改进：物品类型从硬编码枚举改为动态配置表（item_type_configs），支持系统预设+家庭自定义，可随时扩展 |

