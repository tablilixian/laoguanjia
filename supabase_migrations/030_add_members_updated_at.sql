-- 为 members 表添加 updated_at 字段，支持增量同步
ALTER TABLE members ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 将已有记录的 updated_at 设置为 created_at
UPDATE members SET updated_at = created_at WHERE updated_at IS NULL OR updated_at = created_at;

-- 添加触发器，自动更新 updated_at
CREATE OR REPLACE TRIGGER set_members_updated_at
  BEFORE UPDATE ON members
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 添加索引，加速增量同步查询
CREATE INDEX IF NOT EXISTS idx_members_updated_at ON members(updated_at);
