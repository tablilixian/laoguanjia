-- ============================================================
-- 物品系统离线同步 - 版本控制支持
-- 创建日期: 2026-03-23
-- 包含: 为物品相关表添加版本控制字段
-- ============================================================

-- ============================================================
-- 1. 为 household_items 表添加版本控制字段
-- ============================================================

ALTER TABLE household_items
  ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

COMMENT ON COLUMN household_items.version IS '数据版本号，每次更新时自动递增';
COMMENT ON COLUMN household_items.updated_at IS '最后更新时间';

-- ============================================================
-- 2. 为 item_locations 表添加版本控制字段
-- ============================================================

ALTER TABLE item_locations
  ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

COMMENT ON COLUMN item_locations.version IS '数据版本号，每次更新时自动递增';
COMMENT ON COLUMN item_locations.updated_at IS '最后更新时间';

-- ============================================================
-- 3. 为 item_tags 表添加版本控制字段
-- ============================================================

ALTER TABLE item_tags
  ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

COMMENT ON COLUMN item_tags.version IS '数据版本号，每次更新时自动递增';
COMMENT ON COLUMN item_tags.updated_at IS '最后更新时间';

-- ============================================================
-- 4. 为 item_type_configs 表添加版本控制字段
-- ============================================================

ALTER TABLE item_type_configs
  ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

COMMENT ON COLUMN item_type_configs.version IS '数据版本号，每次更新时自动递增';
COMMENT ON COLUMN item_type_configs.updated_at IS '最后更新时间';

-- ============================================================
-- 5. 初始化现有数据的版本号和更新时间
-- ============================================================

-- household_items
UPDATE household_items
SET version = 1, updated_at = COALESCE(updated_at, created_at, NOW())
WHERE version IS NULL OR updated_at IS NULL;

-- item_locations
UPDATE item_locations
SET version = 1, updated_at = COALESCE(updated_at, created_at, NOW())
WHERE version IS NULL OR updated_at IS NULL;

-- item_tags
UPDATE item_tags
SET version = 1, updated_at = COALESCE(updated_at, created_at, NOW())
WHERE version IS NULL OR updated_at IS NULL;

-- item_type_configs
UPDATE item_type_configs
SET version = 1, updated_at = COALESCE(updated_at, created_at, NOW())
WHERE version IS NULL OR updated_at IS NULL;
