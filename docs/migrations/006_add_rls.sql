-- 步骤5: 添加 RLS 策略

ALTER TABLE pet_personalities ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_memories ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_relationship ENABLE ROW LEVEL SECURITY;

CREATE POLICY "宠物主人可管理性格" ON pet_personalities
  FOR ALL USING (pet_id IN (SELECT id FROM pets WHERE owner_id = auth.uid()));

CREATE POLICY "宠物主人可管理记忆" ON pet_memories
  FOR ALL USING (pet_id IN (SELECT id FROM pets WHERE owner_id = auth.uid()));

CREATE POLICY "宠物主人可管理关系" ON pet_relationship
  FOR ALL USING (pet_id IN (SELECT id FROM pets WHERE owner_id = auth.uid()));
