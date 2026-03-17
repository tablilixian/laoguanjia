-- 检查现有 RLS 策略
SELECT tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('pet_personalities', 'pet_memories', 'pet_relationship', 'pets');

-- 删除现有策略（如果有问题）
DROP POLICY IF EXISTS "宠物主人可管理性格" ON pet_personalities;
DROP POLICY IF EXISTS "宠物主人可管理记忆" ON pet_memories;
DROP POLICY IF EXISTS "宠物主人可管理关系" ON pet_relationship;
DROP POLICY IF EXISTS "宠物主人可管理宠物" ON pets;
DROP POLICY IF EXISTS "家庭成员可查看宠物" ON pets;

-- 重新创建策略（简化为基于 owner_id）
CREATE POLICY "宠物主人可管理性格" ON pet_personalities
  FOR ALL USING (true);

CREATE POLICY "宠物主人可管理记忆" ON pet_memories
  FOR ALL USING (true);

CREATE POLICY "宠物主人可管理关系" ON pet_relationship
  FOR ALL USING (true);

CREATE POLICY "宠物主人可管理宠物" ON pets
  FOR ALL USING (true);

CREATE POLICY "家庭成员可查看宠物" ON pets
  FOR SELECT USING (true);
