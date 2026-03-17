-- 创建宠物对话历史表

CREATE TABLE IF NOT EXISTS pet_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conversations_pet ON pet_conversations(pet_id);
CREATE INDEX IF NOT EXISTS idx_conversations_created ON pet_conversations(pet_id, created_at DESC);

ALTER TABLE pet_conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "宠物对话历史可见" ON pet_conversations
  FOR ALL USING (true);
