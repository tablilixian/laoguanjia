-- ============================================================
-- 给 tasks 表添加软删除支持
-- 创建日期: 2026-03-21
-- ============================================================

-- 1. 添加 deleted_at 字段
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 2. 创建索引（只查询未删除的记录）
CREATE INDEX IF NOT EXISTS idx_tasks_active ON tasks(household_id) WHERE deleted_at IS NULL;

-- 3. 创建索引（查询已删除的记录，用于恢复）
CREATE INDEX IF NOT EXISTS idx_tasks_deleted ON tasks(household_id, deleted_at) WHERE deleted_at IS NOT NULL;

-- 4. 更新触发器，删除时自动设置 deleted_at
CREATE OR REPLACE FUNCTION soft_delete_task()
RETURNS TRIGGER AS $$
BEGIN
  -- 如果是真正的删除操作，改为软删除
  IF TG_OP = 'DELETE' THEN
    UPDATE tasks 
    SET deleted_at = NOW(), version = version + 1
    WHERE id = OLD.id;
    RETURN NULL;  -- 取消真正的删除
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- 5. 创建触发器（可选，可以不用触发器，在应用层处理）
-- DROP TRIGGER IF EXISTS soft_delete_task_trigger ON tasks;
-- CREATE TRIGGER soft_delete_task_trigger
--   BEFORE DELETE ON tasks
--   FOR EACH ROW
--   EXECUTE FUNCTION soft_delete_task();

-- 6. 更新版本触发器，确保删除时也更新版本
CREATE OR REPLACE FUNCTION increment_task_version()
RETURNS TRIGGER AS $$
BEGIN
  -- 处理软删除
  IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
    NEW.version = COALESCE(OLD.version, 0) + 1;
    NEW.updated_at = NOW();
  -- 处理普通更新
  ELSIF NEW.deleted_at IS NULL THEN
    NEW.version = COALESCE(OLD.version, 0) + 1;
    NEW.updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. 重新创建触发器
DROP TRIGGER IF EXISTS tasks_version_trigger ON tasks;
CREATE TRIGGER tasks_version_trigger
  BEFORE UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION increment_task_version();
