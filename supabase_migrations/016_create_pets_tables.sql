-- 创建宠物表
CREATE TABLE IF NOT EXISTS pets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('cat', 'dog', 'rabbit', 'other')),
  breed TEXT,
  hunger INTEGER NOT NULL DEFAULT 50 CHECK (hunger >= 0 AND hunger <= 100),
  happiness INTEGER NOT NULL DEFAULT 50 CHECK (happiness >= 0 AND happiness <= 100),
  cleanliness INTEGER NOT NULL DEFAULT 50 CHECK (cleanliness >= 0 AND cleanliness <= 100),
  health INTEGER NOT NULL DEFAULT 100 CHECK (health >= 0 AND health <= 100),
  level INTEGER NOT NULL DEFAULT 1,
  experience INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建宠物互动记录表
CREATE TABLE IF NOT EXISTS pet_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('feed', 'play', 'bath', 'train')),
  value INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建更新时间触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_pets_updated_at
BEFORE UPDATE ON pets
FOR EACH ROW
EXECUTE PROCEDURE update_updated_at_column();

-- 启用 RLS
ALTER TABLE pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_interactions ENABLE ROW LEVEL SECURITY;

-- 创建 RLS 策略
CREATE POLICY "成员可访问家庭宠物" ON pets
  FOR ALL USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "成员可访问宠物互动记录" ON pet_interactions
  FOR ALL USING (
    pet_id IN (
      SELECT id FROM pets WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
  );
