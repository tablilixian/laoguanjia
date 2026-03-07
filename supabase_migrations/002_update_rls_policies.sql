-- households 表的 RLS 策略（如果不存在则创建）
DROP POLICY IF EXISTS "成员可访问自己家庭的households" ON households;
CREATE POLICY "成员可访问自己家庭的households" ON households
  FOR SELECT USING (
    id IN (SELECT household_id FROM members WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "管理员可创建households" ON households;
CREATE POLICY "管理员可创建households" ON households
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "管理员可更新households" ON households;
CREATE POLICY "管理员可更新households" ON households
  FOR UPDATE USING (
    id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );

-- members 表的 RLS 策略（如果不存在则创建）
DROP POLICY IF EXISTS "成员可查看自己家庭的members" ON members;
CREATE POLICY "成员可查看自己家庭的members" ON members
  FOR SELECT USING (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "管理员可添加members" ON members;
CREATE POLICY "管理员可添加members" ON members
  FOR INSERT WITH CHECK (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "管理员可更新members" ON members;
CREATE POLICY "管理员可更新members" ON members
  FOR UPDATE USING (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "管理员可删除members" ON members;
CREATE POLICY "管理员可删除members" ON members
  FOR DELETE USING (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );

-- 允许认证用户创建 households（临时策略，用于首次创建）
DROP POLICY IF EXISTS "认证用户可创建households" ON households;
CREATE POLICY "认证用户可创建households" ON households
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 允许认证用户创建 members（临时策略，用于首次创建）
DROP POLICY IF EXISTS "认证用户可创建members" ON members;
CREATE POLICY "认证用户可创建members" ON members
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
