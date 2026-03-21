-- ============================================================
-- 版本控制系统
-- 创建日期: 2026-03-21
-- 功能: 为 tasks 表添加版本控制字段，创建同步版本追踪表
-- ============================================================

-- ============================================================
-- 1. 给 tasks 表添加版本控制字段
-- ============================================================

ALTER TABLE tasks 
  ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 添加注释
COMMENT ON COLUMN tasks.version IS '数据版本号，每次更新时自动递增';
COMMENT ON COLUMN tasks.updated_at IS '最后更新时间，每次更新时自动更新';

-- ============================================================
-- 2. 创建同步版本追踪表
-- ============================================================

CREATE TABLE IF NOT EXISTS sync_versions (
  table_name TEXT PRIMARY KEY,
  max_version BIGINT NOT NULL DEFAULT 0,
  row_count BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 添加注释
COMMENT ON TABLE sync_versions IS '同步版本追踪表，记录每张表的最高版本号';
COMMENT ON COLUMN sync_versions.table_name IS '表名';
COMMENT ON COLUMN sync_versions.max_version IS '当前最高版本号';
COMMENT ON COLUMN sync_versions.row_count IS '当前行数';
COMMENT ON COLUMN sync_versions.updated_at IS '最后更新时间';

-- 初始化 tasks 表的版本记录
INSERT INTO sync_versions (table_name, max_version, row_count)
SELECT 'tasks', COALESCE(MAX(version), 0), COUNT(*)
FROM tasks
ON CONFLICT (table_name) DO UPDATE
SET 
  max_version = EXCLUDED.max_version,
  row_count = EXCLUDED.row_count,
  updated_at = NOW();

-- ============================================================
-- 3. 创建自动更新版本的触发器函数
-- ============================================================

CREATE OR REPLACE FUNCTION increment_task_version()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = COALESCE(OLD.version, 0) + 1;
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION increment_task_version IS '自动递增 tasks 表的 version 字段并更新 updated_at';

-- ============================================================
-- 4. 创建触发器
-- ============================================================

DROP TRIGGER IF EXISTS tasks_version_trigger ON tasks;

CREATE TRIGGER tasks_version_trigger
  BEFORE UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION increment_task_version();

-- ============================================================
-- 5. 创建更新 sync_versions 表的触发器函数
-- ============================================================

CREATE OR REPLACE FUNCTION update_sync_version_for_tasks()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO sync_versions (table_name, max_version, row_count, updated_at)
  VALUES (
    'tasks',
    NEW.version,
    (SELECT COUNT(*) FROM tasks),
    NOW()
  )
  ON CONFLICT (table_name) DO UPDATE
  SET 
    max_version = GREATEST(sync_versions.max_version, NEW.version),
    row_count = (SELECT COUNT(*) FROM tasks),
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_sync_version_for_tasks IS '更新 sync_versions 表中 tasks 的版本信息';

-- ============================================================
-- 6. 创建触发器
-- ============================================================

DROP TRIGGER IF EXISTS tasks_sync_version_trigger ON tasks;

CREATE TRIGGER tasks_sync_version_trigger
  AFTER INSERT OR UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_sync_version_for_tasks();

-- ============================================================
-- 7. 创建索引优化查询性能
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_tasks_version ON tasks(version);
CREATE INDEX IF NOT EXISTS idx_tasks_updated_at ON tasks(updated_at);
