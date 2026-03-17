-- 步骤2: 创建 pet_memories 表

CREATE TABLE IF NOT EXISTS pet_memories (
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
