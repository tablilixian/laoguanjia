-- 删除已废弃的 item_tag_relations 表
-- 标签关系已迁移到位图方案（tags_mask 字段存储在 household_items 表中）
-- 该表在 Dart 代码中零引用，删除不影响任何功能

DROP TABLE IF EXISTS item_tag_relations;
