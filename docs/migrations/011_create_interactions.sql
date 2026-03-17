-- 创建 pet_interactions 表（如果不存在）

CREATE TABLE IF NOT EXISTS pet_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  value INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_interactions_pet ON pet_interactions(pet_id);

ALTER TABLE pet_interactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "互动记录可见" ON pet_interactions FOR ALL USING (true);
