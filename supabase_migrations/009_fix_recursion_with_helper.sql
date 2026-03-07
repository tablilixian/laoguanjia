-- 修复 members 表的 RLS 无限递归问题
-- 方案：创建 SECURITY DEFINER 函数，在函数内部关闭 RLS

-- 1. 删除所有现有策略
DO $$
DECLARE
    pol record;
BEGIN
    FOR pol IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'households' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON households', pol.policyname);
    END LOOP;
    
    FOR pol IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'members' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON members', pol.policyname);
    END LOOP;
    
    DROP FUNCTION IF EXISTS user_has_household_access(UUID);
    DROP FUNCTION IF EXISTS get_user_household_ids();
END $$;

-- 2. 创建 helper 函数 - 使用 SECURITY DEFINER 和 SET row_security = off 避免递归
CREATE OR REPLACE FUNCTION get_user_household_ids()
RETURNS TABLE(household_id UUID) AS $$
BEGIN
  -- 关闭 RLS 检查，避免递归
  SET row_security = off;
  
  RETURN QUERY
  SELECT m.household_id 
  FROM members m 
  WHERE m.user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. households 表的 RLS 策略
-- 允许认证用户创建家庭
CREATE POLICY "allow_insert_households" ON households
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 允许用户查看自己家庭
CREATE POLICY "allow_select_households" ON households
  FOR SELECT USING (
    id IN (SELECT household_id FROM get_user_household_ids())
  );

-- 允许用户更新自己家庭
CREATE POLICY "allow_update_households" ON households
  FOR UPDATE USING (
    id IN (SELECT household_id FROM get_user_household_ids())
  );

-- 4. members 表的 RLS 策略
-- 允许认证用户创建成员
CREATE POLICY "allow_insert_members" ON members
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 允许用户查看自己家庭的成员（使用 helper 函数，避免递归）
CREATE POLICY "allow_select_members" ON members
  FOR SELECT USING (
    household_id IN (SELECT household_id FROM get_user_household_ids())
  );

-- 允许用户更新自己家庭的成员
CREATE POLICY "allow_update_members" ON members
  FOR UPDATE USING (
    household_id IN (SELECT household_id FROM get_user_household_ids())
  );

-- 允许用户删除自己家庭的成员
CREATE POLICY "allow_delete_members" ON members
  FOR DELETE USING (
    household_id IN (SELECT household_id FROM get_user_household_ids())
  );
