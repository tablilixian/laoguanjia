-- ============================================================
-- 标签系统 - 添加位图支持字段
-- 创建日期: 2026-03-26
-- 说明: 为 item_tags 表添加 tag_index 和 applicable_types 字段以支持位图标签
-- ============================================================

-- ============================================================
-- 1. 添加 tag_index 字段
-- ============================================================

ALTER TABLE item_tags 
ADD COLUMN IF NOT EXISTS tag_index INTEGER;

-- 为现有标签分配序号（按创建时间排序）
WITH numbered_tags AS (
  SELECT 
    id,
    ROW_NUMBER() OVER (ORDER BY created_at) - 1 as tag_index
  FROM item_tags
)
UPDATE item_tags t
SET tag_index = n.tag_index
FROM numbered_tags n
WHERE t.id = n.id
  AND t.tag_index IS NULL;

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_item_tags_tag_index ON item_tags(tag_index);

-- 添加唯一约束（确保每个标签有唯一的序号）
ALTER TABLE item_tags 
DROP CONSTRAINT IF EXISTS unique_tag_index;

ALTER TABLE item_tags 
ADD CONSTRAINT unique_tag_index UNIQUE (tag_index);

-- ============================================================
-- 2. 添加 applicable_types 字段
-- ============================================================

ALTER TABLE item_tags 
ADD COLUMN IF NOT EXISTS applicable_types TEXT;

-- 为现有标签设置默认值（空数组表示适用于所有类型）
UPDATE item_tags 
SET applicable_types = '[]'
WHERE applicable_types IS NULL;

-- ============================================================
-- 3. 验证结果
-- ============================================================

-- 查看表结构
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'item_tags' 
  AND table_schema = 'public'
  AND column_name IN ('tag_index', 'applicable_types')
ORDER BY ordinal_position;

-- 查看标签数据
SELECT id, name, tag_index, applicable_types, created_at 
FROM item_tags 
ORDER BY tag_index;

-- ============================================================
-- 4. 说明
-- ============================================================

-- tag_index: 标签序号（0-62），用于位图存储
--   - 每个标签有唯一的序号
--   - 物品的 tags_mask 字段使用位图存储标签：1 << tag_index
--   - 例如：标签序号为 2，则 tags_mask = 1 << 2 = 4

-- applicable_types: 适用的物品类型列表
--   - JSON 数组格式：["appliance", "furniture"]
--   - 空数组 [] 表示适用于所有类型
--   - 用于限制标签只能用于特定类型的物品
