-- 为 item_locations 表添加软删除支持
-- 使位置删除操作能够通过同步机制传播到其他设备

ALTER TABLE item_locations
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 为 deleted_at 创建索引，优化软删除查询性能
CREATE INDEX IF NOT EXISTS idx_locations_deleted_at ON item_locations(deleted_at);
