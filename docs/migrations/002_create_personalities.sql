-- 步骤1: 创建 pet_personalities 表
CREATE TABLE IF NOT EXISTS pet_personalities (
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
