-- 安全删除所有可能存在的策略
DO $$
DECLARE
    pol record;
BEGIN
    -- 删除 households 表的所有策略
    FOR pol IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'households' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON households', pol.policyname);
    END LOOP;
    
    -- 删除 members 表的所有策略
    FOR pol IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'members' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON members', pol.policyname);
    END LOOP;
END $$;

-- households 表的 RLS 策略
CREATE POLICY "认证用户可创建households" ON households
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "成员可查看自己家庭" ON households
  FOR SELECT USING (
    id IN (SELECT household_id FROM members WHERE user_id = auth.uid())
  );

CREATE POLICY "管理员可更新家庭" ON households
  FOR UPDATE USING (
    id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );

-- members 表的 RLS 策略
CREATE POLICY "认证用户可创建members" ON members
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "成员可查看家庭成员" ON members
  FOR SELECT USING (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid())
  );

CREATE POLICY "管理员可添加成员" ON members
  FOR INSERT WITH CHECK (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "管理员可更新成员" ON members
  FOR UPDATE USING (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "管理员可删除成员" ON members
  FOR DELETE USING (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );
