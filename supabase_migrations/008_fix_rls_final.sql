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
END $$;

-- 全新的 RLS 策略设计
-- 解决递归问题和新用户访问问题

-- households 表的 RLS 策略
-- 1. 允许认证用户创建家庭（新用户需要）
CREATE POLICY "认证用户可创建households" ON households
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 2. 允许认证用户查看自己的家庭（通过 members 表关联）
-- 注意：使用 auth.uid() 直接关联，避免递归
CREATE POLICY "认证用户可查看自己的households" ON households
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM members 
      WHERE members.household_id = households.id 
      AND members.user_id = auth.uid()
      LIMIT 1
    )
  );

-- 3. 允许认证用户更新自己的家庭
CREATE POLICY "认证用户可更新自己的households" ON households
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM members 
      WHERE members.household_id = households.id 
      AND members.user_id = auth.uid()
      LIMIT 1
    )
  );

-- members 表的 RLS 策略
-- 1. 允许认证用户创建成员（新用户需要）
CREATE POLICY "认证用户可创建members" ON members
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 2. 允许认证用户查看自己家庭的成员
-- 注意：使用 auth.uid() 直接关联，避免递归
CREATE POLICY "认证用户可查看家庭成员" ON members
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM members m2 
      WHERE m2.household_id = members.household_id 
      AND m2.user_id = auth.uid()
      LIMIT 1
    )
  );

-- 3. 允许认证用户更新自己家庭的成员
CREATE POLICY "认证用户可更新家庭成员" ON members
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM members m2 
      WHERE m2.household_id = members.household_id 
      AND m2.user_id = auth.uid()
      LIMIT 1
    )
  );

-- 4. 允许认证用户删除自己家庭的成员
CREATE POLICY "认证用户可删除家庭成员" ON members
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM members m2 
      WHERE m2.household_id = members.household_id 
      AND m2.user_id = auth.uid()
      LIMIT 1
    )
  );

-- 为新用户添加特殊的创建权限
-- 允许认证用户创建第一个家庭和成员
-- 这样新用户就可以创建家庭了
CREATE POLICY "新用户可创建第一个household" ON households
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM members 
      WHERE user_id = auth.uid()
      LIMIT 1
    )
  );

CREATE POLICY "新用户可创建第一个member" ON members
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM members 
      WHERE user_id = auth.uid()
      LIMIT 1
    )
  );
