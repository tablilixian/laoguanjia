-- 扩展 pets 表的 type 字段支持更多宠物类型

-- 先将不合法类型改为 'other'
UPDATE pets SET type = 'other' 
WHERE type NOT IN ('cat', 'dog', 'rabbit', 'hamster', 'guinea_pig', 'chinchilla', 'bird', 'parrot', 'fish', 'turtle', 'lizard', 'hedgehog', 'ferret', 'pig', 'other');

-- 删除旧约束
ALTER TABLE pets DROP CONSTRAINT IF EXISTS pets_type_check;

-- 添加新约束
ALTER TABLE pets ADD CONSTRAINT pets_type_check 
CHECK (type = ANY (ARRAY[
  'cat'::text, 
  'dog'::text, 
  'rabbit'::text, 
  'hamster'::text, 
  'guinea_pig'::text, 
  'chinchilla'::text, 
  'bird'::text, 
  'parrot'::text, 
  'fish'::text, 
  'turtle'::text, 
  'lizard'::text, 
  'hedgehog'::text, 
  'ferret'::text, 
  'pig'::text, 
  'other'::text
]));
