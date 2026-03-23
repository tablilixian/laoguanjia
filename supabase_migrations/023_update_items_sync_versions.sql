-- ============================================================
-- 物品系统离线同步 - 更新 sync_versions 表
-- 创建日期: 2026-03-23
-- 包含: 为物品相关表添加版本追踪记录
-- ============================================================

-- ============================================================
-- 1. 为 household_items 表添加版本追踪记录
-- ============================================================

INSERT INTO sync_versions (table_name, max_version, row_count, updated_at)
SELECT 
  'household_items',
  COALESCE(MAX(version), 0),
  COUNT(*),
  NOW()
FROM household_items
ON CONFLICT (table_name) 
DO UPDATE SET 
  max_version = EXCLUDED.max_version,
  row_count = EXCLUDED.row_count,
  updated_at = NOW();

-- ============================================================
-- 2. 为 item_locations 表添加版本追踪记录
-- ============================================================

INSERT INTO sync_versions (table_name, max_version, row_count, updated_at)
SELECT 
  'item_locations',
  COALESCE(MAX(version), 0),
  COUNT(*),
  NOW()
FROM item_locations
ON CONFLICT (table_name) 
DO UPDATE SET 
  max_version = EXCLUDED.max_version,
  row_count = EXCLUDED.row_count,
  updated_at = NOW();

-- ============================================================
-- 3. 为 item_tags 表添加版本追踪记录
-- ============================================================

INSERT INTO sync_versions (table_name, max_version, row_count, updated_at)
SELECT 
  'item_tags',
  COALESCE(MAX(version), 0),
  COUNT(*),
  NOW()
FROM item_tags
ON CONFLICT (table_name) 
DO UPDATE SET 
  max_version = EXCLUDED.max_version,
  row_count = EXCLUDED.row_count,
  updated_at = NOW();

-- ============================================================
-- 4. 为 item_type_configs 表添加版本追踪记录
-- ============================================================

INSERT INTO sync_versions (table_name, max_version, row_count, updated_at)
SELECT 
  'item_type_configs',
  COALESCE(MAX(version), 0),
  COUNT(*),
  NOW()
FROM item_type_configs
ON CONFLICT (table_name) 
DO UPDATE SET 
  max_version = EXCLUDED.max_version,
  row_count = EXCLUDED.row_count,
  updated_at = NOW();

-- ============================================================
-- 5. 创建索引优化查询
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_household_items_version ON household_items(version);
CREATE INDEX IF NOT EXISTS idx_item_locations_version ON item_locations(version);
CREATE INDEX IF NOT EXISTS idx_item_tags_version ON item_tags(version);
CREATE INDEX IF NOT EXISTS idx_item_type_configs_version ON item_type_configs(version);
