-- 彻底重建数据库
-- 执行顺序：先删除表（注意外键依赖顺序）

-- 1. 删除现有表（按依赖顺序）
DROP TABLE IF EXISTS members CASCADE;
DROP TABLE IF EXISTS households CASCADE;

-- 2. 创建 households 表
CREATE TABLE households (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 创建 members 表
CREATE TABLE members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. 创建索引
CREATE INDEX idx_members_household_id ON members(household_id);
CREATE INDEX idx_members_user_id ON members(user_id);

-- 5. 更新时间戳触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_households_updated_at
  BEFORE UPDATE ON households
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 6. 启用 RLS
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;

-- 7. 创建 RLS 策略（使用 auth.uid() 直接检查，避免递归）
-- households 策略
CREATE POLICY " households_insert" ON households
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "households_select" ON households
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM members WHERE household_id = households.id AND user_id = auth.uid())
  );

CREATE POLICY "households_update" ON households
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM members WHERE household_id = households.id AND user_id = auth.uid())
  );

-- members 策略
CREATE POLICY "members_insert" ON members
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "members_select" ON members
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM members m2 WHERE m2.household_id = members.household_id AND m2.user_id = auth.uid())
  );

CREATE POLICY "members_update" ON members
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM members m2 WHERE m2.household_id = members.household_id AND m2.user_id = auth.uid())
  );

CREATE POLICY "members_delete" ON members
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM members m2 WHERE m2.household_id = members.household_id AND m2.user_id = auth.uid())
  );
