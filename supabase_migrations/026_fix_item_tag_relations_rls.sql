-- ============================================================
-- 修复 item_tag_relations 表的 RLS 策略
-- 创建日期: 2026-03-25
-- 问题: 当前的 RLS 策略过于严格，导致标签关联无法同步
-- ============================================================

-- 删除旧的 RLS 策略
DROP POLICY IF EXISTS "成员可管理标签关联" ON item_tag_relations;

-- 创建新的 RLS 策略，允许用户操作自己家庭的物品的标签关联
CREATE POLICY "成员可查看标签关联" ON item_tag_relations
  FOR SELECT USING (
    item_id IN (
      SELECT id FROM household_items WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "成员可添加标签关联" ON item_tag_relations
  FOR INSERT WITH CHECK (
    item_id IN (
      SELECT id FROM household_items WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
    AND tag_id IN (
      SELECT id FROM item_tags WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "成员可更新标签关联" ON item_tag_relations
  FOR UPDATE USING (
    item_id IN (
      SELECT id FROM household_items WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "成员可删除标签关联" ON item_tag_relations
  FOR DELETE USING (
    item_id IN (
      SELECT id FROM household_items WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
  );