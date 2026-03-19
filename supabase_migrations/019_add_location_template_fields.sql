-- ============================================================
-- 位置模板系统扩展
-- 创建日期: 2026-03-19
-- 功能: 为 item_locations 和 household_items 添加模板系统字段
-- ============================================================

-- ============================================================
-- 1. item_locations 表扩展 - 添加模板相关字段
-- ============================================================

-- 模板类型: direction(方向型) / index(编号型) / grid(网格型) / stack(堆叠型) / none(无模板)
ALTER TABLE item_locations ADD COLUMN IF NOT EXISTS template_type TEXT
  CHECK (template_type IS NULL OR template_type IN ('direction', 'index', 'grid', 'stack', 'none'));

-- 模板配置 (JSONB) - 存储模板的具体参数
-- direction: {directions: {enabled, labels, includeCenter}, heights: {enabled, labels}}
-- index: {totalSlots, startFrom, namingPattern, columns}
-- grid: {rows, cols, rowLabels, colLabels}
-- stack: {levels, labels}
ALTER TABLE item_locations ADD COLUMN IF NOT EXISTS template_config JSONB;

-- 在父级中的位置 (JSONB) - 用于方向型位置
-- direction: {direction: "east", height: "top"}
-- index: {index: 2}
-- grid: {row: 1, col: 2}
-- stack: {level: 1}
ALTER TABLE item_locations ADD COLUMN IF NOT EXISTS position_in_parent JSONB;

-- 位置描述 (TEXT) - 冗余存储，用于快速显示，如 "东南角上层"、"第3层"
ALTER TABLE item_locations ADD COLUMN IF NOT EXISTS position_description TEXT;

-- 添加注释
COMMENT ON COLUMN item_locations.template_type IS '模板类型: direction(方向型) / index(编号型) / grid(网格型) / stack(堆叠型) / none(无模板) / NULL(未设置)';
COMMENT ON COLUMN item_locations.template_config IS '模板配置参数(JSONB)，存储模板的具体参数配置';
COMMENT ON COLUMN item_locations.position_in_parent IS '在父级中的位置(JSONB)，用于方向型位置定位';
COMMENT ON COLUMN item_locations.position_description IS '位置描述文本，用于快速显示，如 "东南角上层"、"第3层"';

-- ============================================================
-- 2. household_items 表扩展 - 添加槽位位置字段
-- ============================================================

-- 物品在格子中的精确位置 (JSONB)
-- direction: {direction: "east", height: "top"}
-- index: {index: 2}
-- grid: {row: 1, col: 2}
-- stack: {level: 1}
ALTER TABLE household_items ADD COLUMN IF NOT EXISTS slot_position JSONB;

COMMENT ON COLUMN household_items.slot_position IS '物品在位置槽位中的精确位置(JSONB)';

-- ============================================================
-- 3. 创建索引 - 优化模板相关查询
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_locations_template_type ON item_locations(template_type) WHERE template_type IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_locations_parent_template ON item_locations(parent_id, template_type) WHERE parent_id IS NOT NULL;

-- ============================================================
-- 4. 更新位置路径计算函数（可选，如有需要）
-- ============================================================

-- 注意: path 字段在创建/更新位置时需要手动维护或通过触发器自动计算
-- 建议在应用层实现路径计算逻辑
