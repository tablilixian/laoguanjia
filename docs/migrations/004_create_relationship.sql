-- 步骤3: 创建 pet_relationship 表

CREATE TABLE IF NOT EXISTS pet_relationship (
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
