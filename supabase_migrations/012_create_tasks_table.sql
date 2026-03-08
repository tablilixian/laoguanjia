-- 创建 tasks 表
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  assigned_to UUID REFERENCES members(id) ON DELETE SET NULL,
  due_date TIMESTAMPTZ,
  recurrence TEXT NOT NULL DEFAULT 'none' CHECK (recurrence IN ('none', 'daily', 'weekly', 'monthly')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_tasks_household_id ON tasks(household_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_created_by ON tasks(created_by);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);

-- 更新时间戳触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_tasks_updated_at ON tasks;

CREATE TRIGGER update_tasks_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 启用 RLS
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- 删除已存在的策略
DROP POLICY IF EXISTS "tasks_insert" ON tasks;
DROP POLICY IF EXISTS "tasks_select" ON tasks;
DROP POLICY IF EXISTS "tasks_update" ON tasks;
DROP POLICY IF EXISTS "tasks_delete" ON tasks;

-- 创建 RLS 策略
CREATE POLICY "tasks_insert" ON tasks
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM members WHERE household_id = tasks.household_id AND user_id = auth.uid())
  );

CREATE POLICY "tasks_select" ON tasks
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM members WHERE household_id = tasks.household_id AND user_id = auth.uid())
  );

CREATE POLICY "tasks_update" ON tasks
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM members WHERE household_id = tasks.household_id AND user_id = auth.uid())
  );

CREATE POLICY "tasks_delete" ON tasks
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM members WHERE household_id = tasks.household_id AND user_id = auth.uid())
  );
