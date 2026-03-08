-- 添加 updated_at 字段到 tasks 表

-- 添加 updated_at 字段
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 更新现有记录
UPDATE tasks SET updated_at = created_at WHERE updated_at IS NULL;

-- 验证
SELECT 'updated_at column added' as status;
