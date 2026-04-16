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
  NEW.updated_at = date_trunc('milliseconds', NOW() AT TIME ZONE 'UTC');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION increment_item_version IS '自动递增版本号并更新 updated_at（毫秒精度）';

-- ============================================================
-- 2. 为 tasks 表创建触发器（如果不存在）
-- ============================================================

CREATE OR REPLACE FUNCTION increment_task_version()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = COALESCE(OLD.version, 0) + 1;
  NEW.updated_at = date_trunc('milliseconds', NOW() AT TIME ZONE 'UTC');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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

SELECT 
  NOW() as current_time,
  date_trunc('milliseconds', NOW() AT TIME ZONE 'UTC') as truncated_time;
