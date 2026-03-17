-- 创建宠物探索日记表
-- 文档版本：v1.0
-- 创建日期：2026-03-17

CREATE TABLE IF NOT EXISTS pet_exploration_diaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  
  -- 日记基本信息
  title TEXT NOT NULL,                    -- 日记标题，如"球球的冒险日记"
  content TEXT NOT NULL,                  -- 完整日记内容（Markdown格式）
  
  -- 结构化数据（便于筛选和展示）
  stops JSONB NOT NULL DEFAULT '[]',     -- 各地点详情
  
  -- 探索元数据
  exploration_type TEXT DEFAULT 'normal', -- 探索类型：normal(普通), special(特殊), auto(自动)
  duration_minutes INT DEFAULT 60,        -- 假设探索时长
  mood_after TEXT,                        -- 探索后的心情：excited, tired, happy, scared, neutral
  
  -- 关联
  intimacy_level_at_explore INT DEFAULT 0,-- 探索时的亲密度
  
  -- 时间戳
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_diaries_pet ON pet_exploration_diaries(pet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_diaries_type ON pet_exploration_diaries(pet_id, exploration_type);

-- RLS
ALTER TABLE pet_exploration_diaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "成员可管理宠物探索日记" ON pet_exploration_diaries
  FOR ALL USING (
    pet_id IN (
      SELECT id FROM pets WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
  );

-- 为 pets 表添加探索相关字段
ALTER TABLE pets ADD COLUMN IF NOT EXISTS exploration_count INT DEFAULT 0;
ALTER TABLE pets ADD COLUMN IF NOT EXISTS last_explored_at TIMESTAMPTZ;
ALTER TABLE pets ADD COLUMN IF NOT EXISTS today_exploration_count INT DEFAULT 0;
ALTER TABLE pets ADD COLUMN IF NOT EXISTS last_exploration_date DATE;
