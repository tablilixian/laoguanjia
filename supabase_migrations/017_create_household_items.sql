-- ============================================================
-- 家庭物品模块 (Household Items) 数据库迁移
-- 创建日期: 2026-03-13
-- 包含: 5张表 + 索引 + RLS策略 + 触发器 + 预设数据
-- ============================================================

-- ============================================================
-- 1. item_type_configs (类型配置表) - 先创建，因为 household_items 依赖它
-- ============================================================

CREATE TABLE IF NOT EXISTS item_type_configs (
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

-- 类型配置表索引
CREATE INDEX IF NOT EXISTS idx_type_configs_household ON item_type_configs(household_id);
CREATE INDEX IF NOT EXISTS idx_type_configs_active ON item_type_configs(household_id, is_active);

-- 类型配置表 RLS
ALTER TABLE item_type_configs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "成员可查看类型配置" ON item_type_configs
  FOR SELECT USING (
    household_id IS NULL OR  -- 系统预设，所有用户可见
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "成员可管理家庭类型配置" ON item_type_configs
  FOR INSERT WITH CHECK (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "成员可更新家庭类型配置" ON item_type_configs
  FOR UPDATE USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "成员可删除家庭类型配置" ON item_type_configs
  FOR DELETE USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

-- 插入系统预设类型数据
INSERT INTO item_type_configs (household_id, type_key, type_label, icon, color, sort_order) VALUES
  (NULL, 'appliance', '家电', '🔌', '#2196F3', 1),
  (NULL, 'clothing', '衣物', '👕', '#E91E63', 2),
  (NULL, 'furniture', '家具', '🛋️', '#795548', 3),
  (NULL, 'tableware', '餐具', '🍽️', '#FF9800', 4),
  (NULL, 'tool', '工具', '🔧', '#607D8B', 5),
  (NULL, 'decoration', '装饰品', '🖼️', '#9C27B0', 6),
  (NULL, 'daily', '日用品', '🧴', '#4CAF50', 7),
  (NULL, 'book', '书籍', '📚', '#3F51B5', 8),
  (NULL, 'medicine', '药品', '💊', '#F44336', 9),
  (NULL, 'sports', '运动器材', '⚽', '#00BCD4', 10),
  (NULL, 'toy', '玩具', '🎮', '#FF5722', 11),
  (NULL, 'other', '其他', '📦', '#9E9E9E', 99)
ON CONFLICT (household_id, type_key) DO NOTHING;


-- ============================================================
-- 2. item_locations (位置表) - 支持层级结构
-- ============================================================

CREATE TABLE IF NOT EXISTS item_locations (
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

-- 位置表索引
CREATE INDEX IF NOT EXISTS idx_locations_household ON item_locations(household_id);
CREATE INDEX IF NOT EXISTS idx_locations_parent ON item_locations(parent_id);
CREATE INDEX IF NOT EXISTS idx_locations_path ON item_locations(path);

-- 位置表 RLS
ALTER TABLE item_locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "成员可管理位置" ON item_locations
  FOR ALL USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

-- 位置表更新时间触发器
DROP TRIGGER IF EXISTS update_item_locations_updated_at ON item_locations;

CREATE TRIGGER update_item_locations_updated_at
  BEFORE UPDATE ON item_locations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();


-- ============================================================
-- 3. item_tags (标签表) - 支持分组
-- ============================================================

CREATE TABLE IF NOT EXISTS item_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,

  name TEXT NOT NULL,                           -- 标签名称
  color TEXT DEFAULT '#6B7280',                 -- 标签颜色（十六进制）
  icon TEXT,                                    -- 图标（可选）
  category TEXT DEFAULT 'other',                -- 标签分组: season/color/status/type/other

  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(household_id, name)                    -- 同一家庭内标签名不重复
);

-- 标签表索引
CREATE INDEX IF NOT EXISTS idx_tags_household ON item_tags(household_id);
CREATE INDEX IF NOT EXISTS idx_tags_category ON item_tags(household_id, category);

-- 标签表 RLS
ALTER TABLE item_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "成员可管理标签" ON item_tags
  FOR ALL USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );


-- ============================================================
-- 4. household_items (物品主表)
-- ============================================================

CREATE TABLE IF NOT EXISTS household_items (
  -- 基础字段
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,

  -- 物品基本信息
  name TEXT NOT NULL,                           -- 物品名称（必填）
  description TEXT,                             -- 描述

  -- 三个独立分类维度
  item_type TEXT NOT NULL DEFAULT 'other',       -- 物品类型键：引用 item_type_configs.type_key
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

-- 物品主表索引
CREATE INDEX IF NOT EXISTS idx_items_household ON household_items(household_id);
CREATE INDEX IF NOT EXISTS idx_items_type ON household_items(household_id, item_type);
CREATE INDEX IF NOT EXISTS idx_items_location ON household_items(location_id);
CREATE INDEX IF NOT EXISTS idx_items_owner ON household_items(owner_id);
CREATE INDEX IF NOT EXISTS idx_items_sync ON household_items(sync_status) WHERE sync_status != 'synced';
CREATE INDEX IF NOT EXISTS idx_items_active ON household_items(household_id) WHERE deleted_at IS NULL;

-- 物品主表 RLS
ALTER TABLE household_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "成员可查看家庭物品" ON household_items
  FOR SELECT USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "成员可添加家庭物品" ON household_items
  FOR INSERT WITH CHECK (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "成员可更新家庭物品" ON household_items
  FOR UPDATE USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "成员可删除家庭物品" ON household_items
  FOR DELETE USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

-- 物品主表更新时间触发器
DROP TRIGGER IF EXISTS update_household_items_updated_at ON household_items;

CREATE TRIGGER update_household_items_updated_at
  BEFORE UPDATE ON household_items
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();


-- ============================================================
-- 5. item_tag_relations (标签关联表) - 多对多关系
-- ============================================================

CREATE TABLE IF NOT EXISTS item_tag_relations (
  item_id UUID NOT NULL REFERENCES household_items(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES item_tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  PRIMARY KEY (item_id, tag_id)                 -- 联合主键，防止重复
);

-- 标签关联表索引
CREATE INDEX IF NOT EXISTS idx_tag_relations_item ON item_tag_relations(item_id);
CREATE INDEX IF NOT EXISTS idx_tag_relations_tag ON item_tag_relations(tag_id);

-- 标签关联表 RLS
ALTER TABLE item_tag_relations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "成员可管理标签关联" ON item_tag_relations
  FOR ALL USING (
    item_id IN (
      SELECT id FROM household_items WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
  );
