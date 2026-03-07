-- 添加 households_delete RLS 策略
-- 允许管理员删除家庭

CREATE POLICY "households_delete" ON households
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM members 
      WHERE household_id = households.id 
      AND user_id = auth.uid() 
      AND role = 'admin'
    )
  );
