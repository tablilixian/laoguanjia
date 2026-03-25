-- ============================================================
-- 物品系统 - 清理服务器端的同步状态字段
-- 创建日期: 2026-03-25
-- 说明: 移除服务器数据库中不应该存在的本地同步状态字段
-- ============================================================

-- ============================================================
-- 1. 删除 household_items 表中的同步状态字段
-- ============================================================

-- 删除 sync_status 字段
ALTER TABLE household_items DROP COLUMN IF EXISTS sync_status;

-- 删除 remote_id 字段
ALTER TABLE household_items DROP COLUMN IF EXISTS remote_id;

-- 删除 sync_status 相关的索引
DROP INDEX IF EXISTS idx_items_sync;

-- ============================================================
-- 2. 验证清理结果
-- ============================================================

-- 查看表结构（Supabase SQL Editor 方式）
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'household_items' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- ============================================================
-- 3. 说明
-- ============================================================

-- 这些字段只应该存在于本地数据库中：
-- - sync_status: 本地同步状态（pending/synced/error）
-- - sync_pending: 是否待同步
-- - remote_id: 远程ID（本地数据库中指向服务器记录）

-- 服务器数据库中应该只包含业务数据：
-- - id: 主键
-- - household_id: 家庭ID
-- - name: 物品名称
-- - description: 描述
-- - item_type: 类型
-- - location_id: 位置
-- - owner_id: 归属人
-- - quantity: 数量
-- - brand: 品牌
-- - model: 型号
-- - purchase_date: 购买日期
-- - purchase_price: 购买价格
-- - warranty_expiry: 保修到期日
-- - condition: 状态
-- - image_url: 图片URL
-- - thumbnail_url: 缩略图URL
-- - notes: 备注
-- - created_by: 创建人
-- - created_at: 创建时间
-- - updated_at: 更新时间
-- - deleted_at: 软删除时间
-- - version: 版本号（用于同步）
-- - slot_position: 位置信息
