-- 安全删除所有相关策略
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
    
    -- 删除函数（如果存在）
    DROP FUNCTION IF EXISTS get_user_household_id();
    DROP FUNCTION IF EXISTS is_household_admin();
END $$;

-- 创建辅助函数来获取用户的 household_id
CREATE OR REPLACE FUNCTION get_user_household_id()
RETURNS UUID AS $$
  SELECT household_id FROM members WHERE user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE;

-- 创建辅助函数来检查用户是否是管理员
CREATE OR REPLACE FUNCTION is_household_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM members 
    WHERE user_id = auth.uid() 
    AND role = 'admin' 
    LIMIT 1
  );
$$ LANGUAGE sql STABLE;

-- households 表的 RLS 策略
CREATE POLICY "认证用户可创建households" ON households
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "成员可查看自己家庭" ON households
  FOR SELECT USING (
    id = get_user_household_id()
  );

CREATE POLICY "管理员可更新家庭" ON households
  FOR UPDATE USING (
    id = get_user_household_id() AND is_household_admin()
  );

-- members 表的 RLS 策略
CREATE POLICY "认证用户可创建members" ON members
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "成员可查看家庭成员" ON members
  FOR SELECT USING (
    household_id = get_user_household_id()
  );

CREATE POLICY "管理员可添加成员" ON members
  FOR INSERT WITH CHECK (
    household_id = get_user_household_id() AND is_household_admin()
  );

CREATE POLICY "管理员可更新成员" ON members
  FOR UPDATE USING (
    household_id = get_user_household_id() AND is_household_admin()
  );

CREATE POLICY "管理员可删除成员" ON members
  FOR DELETE USING (
    household_id = get_user_household_id() AND is_household_admin()
  );
