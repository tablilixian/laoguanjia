-- 修复迁移 - 先清理再重建

DROP POLICY IF EXISTS "宠物主人可管理性格" ON pet_personalities;
DROP POLICY IF EXISTS "宠物主人可管理记忆" ON pet_memories;
DROP POLICY IF EXISTS "宠物主人可管理关系" ON pet_relationship;
DROP POLICY IF EXISTS "宠物主人可管理宠物" ON pets;
DROP POLICY IF EXISTS "家庭成员可查看宠物" ON pets;

DROP TABLE IF EXISTS pet_personalities CASCADE;
DROP TABLE IF EXISTS pet_memories CASCADE;
DROP TABLE IF EXISTS pet_relationship CASCADE;

CREATE TABLE pet_personalities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  openness DECIMAL(3,2) DEFAULT 0.5,
  agreeableness DECIMAL(3,2) DEFAULT 0.5,
  extraversion DECIMAL(3,2) DEFAULT 0.5,
  conscientiousness DECIMAL(3,2) DEFAULT 0.5,
  neuroticism DECIMAL(3,2) DEFAULT 0.5,
  traits TEXT[] DEFAULT '{}',
  habits TEXT[] DEFAULT '{}',
  fears TEXT[] DEFAULT '{}',
  speech_style TEXT DEFAULT 'normal',
  origin_description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_personalities_pet ON pet_personalities(pet_id);
ALTER TABLE pet_personalities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "宠物主人可管理性格" ON pet_personalities
  FOR ALL USING (pet_id IN (SELECT id FROM pets WHERE owner_id = auth.uid()));

CREATE TABLE pet_memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  memory_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  emotion TEXT,
  participants TEXT[],
  importance INT DEFAULT 3 CHECK (importance >= 1 AND importance <= 5),
  is_summarized BOOLEAN DEFAULT FALSE,
  interaction_id UUID,
  occurred_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_memories_pet ON pet_memories(pet_id);
CREATE INDEX idx_memories_type ON pet_memories(pet_id, memory_type);
CREATE INDEX idx_memories_importance ON pet_memories(pet_id, importance DESC);
CREATE INDEX idx_memories_occurred ON pet_memories(pet_id, occurred_at DESC);
ALTER TABLE pet_memories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "宠物主人可管理记忆" ON pet_memories
  FOR ALL USING (pet_id IN (SELECT id FROM pets WHERE owner_id = auth.uid()));

CREATE TABLE pet_relationship (
  pet_id UUID PRIMARY KEY REFERENCES pets(id) ON DELETE CASCADE,
  trust_level INT DEFAULT 0 CHECK (trust_level >= 0 AND trust_level <= 100),
  intimacy_level INT DEFAULT 0 CHECK (intimacy_level >= 0 AND intimacy_level <= 5),
  total_interactions INT DEFAULT 0,
  feed_count INT DEFAULT 0,
  play_count INT DEFAULT 0,
  chat_count INT DEFAULT 0,
  last_interaction_at TIMESTAMPTZ,
  joy_score DECIMAL(10,2) DEFAULT 0,
  sadness_score DECIMAL(10,2) DEFAULT 0,
  first_interaction_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE pet_relationship ENABLE ROW LEVEL SECURITY;
CREATE POLICY "宠物主人可管理关系" ON pet_relationship
  FOR ALL USING (pet_id IN (SELECT id FROM pets WHERE owner_id = auth.uid()));

ALTER TABLE pets ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id);
ALTER TABLE pets ADD COLUMN IF NOT EXISTS personality_id UUID REFERENCES pet_personalities(id);
ALTER TABLE pets ADD COLUMN IF NOT EXISTS current_mood TEXT DEFAULT 'neutral';
ALTER TABLE pets ADD COLUMN IF NOT EXISTS mood_text TEXT;

ALTER TABLE pets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "宠物主人可管理宠物" ON pets FOR ALL USING (owner_id = auth.uid());
CREATE POLICY "家庭成员可查看宠物" ON pets FOR SELECT USING (household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));
