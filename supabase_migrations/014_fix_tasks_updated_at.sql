-- 修复 tasks 表的 updated_at 字段问题

-- 1. 首先检查并添加 updated_at 字段（如果不存在）
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tasks' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE tasks ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
END $$;

-- 2. 更新所有现有记录的 updated_at 字段
UPDATE tasks SET updated_at = created_at WHERE updated_at IS NULL;

-- 3. 删除所有可能存在的旧触发器
DROP TRIGGER IF EXISTS update_tasks_updated_at ON tasks;

-- 4. 删除并重新创建触发器函数（确保干净）
DROP FUNCTION IF EXISTS update_updated_at_column();

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. 重新创建触发器
CREATE TRIGGER update_tasks_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 6. 验证修复
SELECT 'Fix completed' as status;
