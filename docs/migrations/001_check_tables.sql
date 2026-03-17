-- 步骤1: 检查 pets 表是否存在
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public'
   AND table_name = 'pets'
);

-- 步骤2: 检查 auth.users 表是否存在  
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'auth'
   AND table_name = 'users'
);
