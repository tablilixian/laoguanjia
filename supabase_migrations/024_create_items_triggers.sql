-- ============================================================
-- 物品系统离线同步 - 创建自动更新触发器
-- 创建日期: 2026-03-23
-- 包含: 为物品相关表创建版本号自动递增和 sync_versions 更新触发器
-- ============================================================

-- ============================================================
-- 1. 创建通用版本更新函数（如果不存在）
-- ============================================================

CREATE OR REPLACE FUNCTION increment_item_version()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = COALESCE(OLD.version, 0) + 1;
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION increment_item_version IS '自动递增物品相关表的 version 字段并更新 updated_at';

-- ============================================================
-- 2. 创建 sync_versions 更新函数
-- ============================================================

-- household_items 版本更新函数
CREATE OR REPLACE FUNCTION update_sync_version_for_household_items()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO sync_versions (table_name, max_version, row_count, updated_at)
  VALUES (
    'household_items',
    NEW.version,
    (SELECT COUNT(*) FROM household_items),
    NOW()
  )
  ON CONFLICT (table_name) 
  DO UPDATE SET 
    max_version = GREATEST(sync_versions.max_version, NEW.version),
    row_count = EXCLUDED.row_count,
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_sync_version_for_household_items IS '更新 sync_versions 表中 household_items 的版本信息';

-- item_locations 版本更新函数
CREATE OR REPLACE FUNCTION update_sync_version_for_item_locations()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO sync_versions (table_name, max_version, row_count, updated_at)
  VALUES (
    'item_locations',
    NEW.version,
    (SELECT COUNT(*) FROM item_locations),
    NOW()
  )
  ON CONFLICT (table_name) 
  DO UPDATE SET 
    max_version = GREATEST(sync_versions.max_version, NEW.version),
    row_count = EXCLUDED.row_count,
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_sync_version_for_item_locations IS '更新 sync_versions 表中 item_locations 的版本信息';

-- item_tags 版本更新函数
CREATE OR REPLACE FUNCTION update_sync_version_for_item_tags()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO sync_versions (table_name, max_version, row_count, updated_at)
  VALUES (
    'item_tags',
    NEW.version,
    (SELECT COUNT(*) FROM item_tags),
    NOW()
  )
  ON CONFLICT (table_name) 
  DO UPDATE SET 
    max_version = GREATEST(sync_versions.max_version, NEW.version),
    row_count = EXCLUDED.row_count,
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_sync_version_for_item_tags IS '更新 sync_versions 表中 item_tags 的版本信息';

-- item_type_configs 版本更新函数
CREATE OR REPLACE FUNCTION update_sync_version_for_item_type_configs()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO sync_versions (table_name, max_version, row_count, updated_at)
  VALUES (
    'item_type_configs',
    NEW.version,
    (SELECT COUNT(*) FROM item_type_configs),
    NOW()
  )
  ON CONFLICT (table_name) 
  DO UPDATE SET 
    max_version = GREATEST(sync_versions.max_version, NEW.version),
    row_count = EXCLUDED.row_count,
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_sync_version_for_item_type_configs IS '更新 sync_versions 表中 item_type_configs 的版本信息';

-- ============================================================
-- 3. 为 household_items 表创建触发器
-- ============================================================

-- 版本号自动递增触发器
DROP TRIGGER IF EXISTS household_items_version_trigger ON household_items;
CREATE TRIGGER household_items_version_trigger
  BEFORE UPDATE ON household_items
  FOR EACH ROW EXECUTE FUNCTION increment_item_version();

-- sync_versions 更新触发器
DROP TRIGGER IF EXISTS household_items_sync_version_trigger ON household_items;
CREATE TRIGGER household_items_sync_version_trigger
  AFTER INSERT OR UPDATE ON household_items
  FOR EACH ROW EXECUTE FUNCTION update_sync_version_for_household_items();

-- ============================================================
-- 4. 为 item_locations 表创建触发器
-- ============================================================

-- 版本号自动递增触发器
DROP TRIGGER IF EXISTS item_locations_version_trigger ON item_locations;
CREATE TRIGGER item_locations_version_trigger
  BEFORE UPDATE ON item_locations
  FOR EACH ROW EXECUTE FUNCTION increment_item_version();

-- sync_versions 更新触发器
DROP TRIGGER IF EXISTS item_locations_sync_version_trigger ON item_locations;
CREATE TRIGGER item_locations_sync_version_trigger
  AFTER INSERT OR UPDATE ON item_locations
  FOR EACH ROW EXECUTE FUNCTION update_sync_version_for_item_locations();

-- ============================================================
-- 5. 为 item_tags 表创建触发器
-- ============================================================

-- 版本号自动递增触发器
DROP TRIGGER IF EXISTS item_tags_version_trigger ON item_tags;
CREATE TRIGGER item_tags_version_trigger
  BEFORE UPDATE ON item_tags
  FOR EACH ROW EXECUTE FUNCTION increment_item_version();

-- sync_versions 更新触发器
DROP TRIGGER IF EXISTS item_tags_sync_version_trigger ON item_tags;
CREATE TRIGGER item_tags_sync_version_trigger
  AFTER INSERT OR UPDATE ON item_tags
  FOR EACH ROW EXECUTE FUNCTION update_sync_version_for_item_tags();

-- ============================================================
-- 6. 为 item_type_configs 表创建触发器
-- ============================================================

-- 版本号自动递增触发器
DROP TRIGGER IF EXISTS item_type_configs_version_trigger ON item_type_configs;
CREATE TRIGGER item_type_configs_version_trigger
  BEFORE UPDATE ON item_type_configs
  FOR EACH ROW EXECUTE FUNCTION increment_item_version();

-- sync_versions 更新触发器
DROP TRIGGER IF EXISTS item_type_configs_sync_version_trigger ON item_type_configs;
CREATE TRIGGER item_type_configs_sync_version_trigger
  AFTER INSERT OR UPDATE ON item_type_configs
  FOR EACH ROW EXECUTE FUNCTION update_sync_version_for_item_type_configs();
