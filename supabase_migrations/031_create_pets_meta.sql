-- Phase 1: 创建 pets_meta 表 (云端最小化存储)
-- 仅存储宠物身份映射，所有动态状态数据存于本地

CREATE TABLE IF NOT EXISTS pets_meta (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  owner_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  breed TEXT,
  avatar_url TEXT,
  state_snapshot JSONB,
  last_sync_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_pets_meta_household ON pets_meta(household_id);
CREATE INDEX IF NOT EXISTS idx_pets_meta_owner ON pets_meta(owner_id);

-- 启用 RLS
ALTER TABLE pets_meta ENABLE ROW LEVEL SECURITY;

-- 家庭成员可查看宠物元数据
CREATE POLICY "家庭成员可查看宠物元数据" ON pets_meta
  FOR SELECT USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

-- 家庭成员可创建宠物 (INSERT)
CREATE POLICY "家庭成员可创建宠物" ON pets_meta
  FOR INSERT WITH CHECK (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

-- 宠物主人可更新/删除
CREATE POLICY "宠物主人可管理元数据" ON pets_meta
  FOR ALL USING (owner_id = auth.uid());
