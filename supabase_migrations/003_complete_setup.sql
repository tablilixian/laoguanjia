-- 删除已存在的表（如果需要重新创建）
-- DROP TABLE IF EXISTS members CASCADE;
-- DROP TABLE IF EXISTS households CASCADE;

-- households 表
CREATE TABLE IF NOT EXISTS households (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- members 表
CREATE TABLE IF NOT EXISTS members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 启用 RLS
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;

-- 删除旧的策略（如果存在）
DROP POLICY IF EXISTS "成员可访问自己家庭的households" ON households;
DROP POLICY IF EXISTS "管理员可创建households" ON households;
DROP POLICY IF EXISTS "管理员可更新households" ON households;
DROP POLICY IF EXISTS "认证用户可创建households" ON households;
DROP POLICY IF EXISTS "成员可查看自己家庭的members" ON members;
DROP POLICY IF EXISTS "管理员可添加members" ON members;
DROP POLICY IF EXISTS "管理员可更新members" ON members;
DROP POLICY IF EXISTS "管理员可删除members" ON members;
DROP POLICY IF EXISTS "认证用户可创建members" ON members;

-- households 表的 RLS 策略
-- 允许认证用户创建家庭
CREATE POLICY "认证用户可创建households" ON households
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 允许成员查看自己家庭
CREATE POLICY "成员可查看自己家庭" ON households
  FOR SELECT USING (
    id IN (SELECT household_id FROM members WHERE user_id = auth.uid())
  );

-- 允许管理员更新家庭
CREATE POLICY "管理员可更新家庭" ON households
  FOR UPDATE USING (
    id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );

-- members 表的 RLS 策略
-- 允许认证用户创建成员（首次创建家庭时需要）
CREATE POLICY "认证用户可创建members" ON members
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 允许成员查看家庭的所有成员
CREATE POLICY "成员可查看家庭成员" ON members
  FOR SELECT USING (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid())
  );

-- 允许管理员添加成员
CREATE POLICY "管理员可添加成员" ON members
  FOR INSERT WITH CHECK (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );

-- 允许管理员更新成员
CREATE POLICY "管理员可更新成员" ON members
  FOR UPDATE USING (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );

-- 允许管理员删除成员
CREATE POLICY "管理员可删除成员" ON members
  FOR DELETE USING (
    household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid() AND role = 'admin')
  );

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_members_household_id ON members(household_id);
CREATE INDEX IF NOT EXISTS idx_members_user_id ON members(user_id);

-- 更新时间戳触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_households_updated_at ON households;
CREATE TRIGGER update_households_updated_at
  BEFORE UPDATE ON households
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
