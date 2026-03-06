# 家庭管理器 (Home Manager) 开发规范

## 1. 项目概述

### 1.1 项目目标

一款支持多平台（iOS/Android/Web）的家庭管理应用，帮助家庭成员协作管理：
- 任务/家务分配
- 购物清单
- 日历日程
- 账单支出
- 家庭资产

### 1.2 目标用户

- 2-6 人家庭
- 家庭成员需要共享和协作日常事务
- 需要追踪家庭开支和资产

### 1.3 产品阶段

| 阶段 | 目标 | 预计时间 |
|------|------|----------|
| MVP | 核心功能可用 | 5.5 天 |
| Phase 2 | 完善基础功能 | 6 天 |
| Phase 3 | 体验优化 | 迭代中 |

---

## 2. 技术栈

### 2.1 前端

| 技术 | 用途 | 版本 |
|------|------|------|
| Flutter | 跨平台 UI 框架 | >=3.19.0 |
| Riverpod | 状态管理 | ^2.5.0 |
| GoRouter | 路由管理 | ^14.0.0 |
| Drift | 本地 SQLite 缓存 | ^2.18.0 |
| Supabase SDK | 后端交互 | ^2.0.0 |

### 2.2 后端

| 技术 | 用途 |
|------|------|
| Supabase | 数据库 + 认证 + Realtime |
| Supabase Database | PostgreSQL |
| Supabase Auth | 邮箱/手机认证 |
| Supabase Realtime | 实时同步 |

### 2.3 开发工具

| 工具 | 用途 |
|------|------|
| VS Code / Android Studio | IDE |
| Flutter CLI | 构建/调试 |
| Supabase CLI | 本地开发 |

---

## 3. 数据库设计

### 3.1 表结构总览

```
households (家庭)
├── members (成员)
├── tasks (任务)
├── shopping_lists (购物清单)
│   └── shopping_items (购物项)
├── events (日历事件)
├── bills (账单)
└── assets (资产)
```

### 3.2 详细表设计

#### 3.2.1 households (家庭表)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| name | text | 家庭名称 |
| created_at | timestamptz | 创建时间 |
| updated_at | timestamptz | 更新时间 |

#### 3.2.2 members (成员表)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| household_id | uuid | 所属家庭 |
| name | text | 成员名称 |
| avatar_url | text | 头像 URL |
| role | text | admin / member |
| user_id | uuid | 关联的 Auth 用户 |
| created_at | timestamptz | 创建时间 |

#### 3.2.3 tasks (任务表)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| household_id | uuid | 所属家庭 |
| title | text | 任务标题 |
| description | text | 任务描述 |
| assigned_to | uuid | 指派成员 |
| due_date | date | 截止日期 |
| recurrence | text | 重复: daily/weekly/monthly/none |
| status | text | pending / completed |
| created_by | uuid | 创建人 |
| created_at | timestamptz | 创建时间 |
| completed_at | timestamptz | 完成时间 |

#### 3.2.4 shopping_lists (购物清单)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| household_id | uuid | 所属家庭 |
| name | text | 清单名称 |
| created_by | uuid | 创建人 |
| created_at | timestamptz | 创建时间 |

#### 3.2.5 shopping_items (购物项)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| list_id | uuid | 所属清单 |
| name | text | 物品名称 |
| quantity | text | 数量 |
| completed | boolean | 是否完成 |
| created_by | uuid | 创建人 |
| created_at | timestamptz | 创建时间 |

#### 3.2.6 events (日历事件)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| household_id | uuid | 所属家庭 |
| title | text | 事件标题 |
| description | text | 事件描述 |
| all_day | boolean | 是否全天 |
| start_time | timestamptz | 开始时间 |
| end_time | timestamptz | 结束时间 |
| recurrence | text | 重复规则 |
| created_by | uuid | 创建人 |
| created_at | timestamptz | 创建时间 |

#### 3.2.7 bills (账单表)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| household_id | uuid | 所属家庭 |
| title | text | 账单名称 |
| amount | decimal(10,2) | 金额 |
| category | text | 类别: 水电/燃气/网络/其他 |
| due_date | date | 到期日期 |
| paid | boolean | 是否已付 |
| paid_by | uuid | 付款人 |
| notes | text | 备注 |
| created_at | timestamptz | 创建时间 |

#### 3.2.8 assets (资产表)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| household_id | uuid | 所属家庭 |
| name | text | 资产名称 |
| category | text | 类别: 家电/家具/电子产品/其他 |
| purchase_date | date | 购买日期 |
| warranty_expiry | date | 保修期 |
| value | decimal(10,2) | 价值 |
| notes | text | 备注 |
| created_at | timestamptz | 创建时间 |

### 3.3 RLS 策略

所有表启用 Row Level Security，确保成员只能访问自己家庭的数据。

```sql
-- 示例策略：成员只能访问自己家庭的任务
create policy "成员可访问家庭任务" on tasks
  for select using (
    household_id in (
      select household_id from members where user_id = auth.uid()
    )
  );
```

---

## 4. 前端架构

### 4.1 目录结构

```
lib/
├── main.dart                 # 入口
├── app.dart                  # App 配置
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   ├── theme/
│   │   └── app_theme.dart    # Material 3 主题
│   └── utils/
│       └── date_utils.dart
├── data/
│   ├── models/               # 数据模型
│   │   ├── household.dart
│   │   ├── member.dart
│   │   ├── task.dart
│   │   └── ...
│   ├── repositories/         # 数据仓库
│   │   └── task_repository.dart
│   └── supabase/
│       └── supabase_client.dart
├── features/
│   ├── auth/                 # 认证模块
│   │   ├── pages/
│   │   │   ├── login_page.dart
│   │   │   └── register_page.dart
│   │   └── providers/
│   │       └── auth_provider.dart
│   ├── dashboard/            # 首页
│   │   └── pages/
│   │       └── dashboard_page.dart
│   ├── tasks/                # 任务模块
│   │   ├── pages/
│   │   │   ├── tasks_page.dart
│   │   │   └── task_detail_page.dart
│   │   └── providers/
│   │       └── tasks_provider.dart
│   ├── shopping/             # 购物模块
│   ├── calendar/             # 日历模块
│   ├── bills/                # 账单模块
│   ├── assets/               # 资产模块
│   └── settings/             # 设置模块
│       └── pages/
│           └── settings_page.dart
└── shared/
    ├── widgets/
    │   ├── app_scaffold.dart
    │   └── loading_widget.dart
    └── providers/
        └── household_provider.dart
```

### 4.2 路由配置

```
/                     → 重定向到 /login 或 /home
/login                → 登录页
/register             → 注册页
/home                 → 首页（仪表盘）
/home/tasks           → 任务列表
/home/tasks/:id       → 任务详情
/home/shopping        → 购物清单
/home/calendar        → 日历
/home/bills           → 账单
/home/assets          → 资产
/settings             → 设置
/settings/household   → 家庭管理
/settings/members     → 成员管理
```

### 4.3 状态管理 (Riverpod)

```dart
// Provider 示例
@riverpod
class TasksNotifier extends _$TasksNotifier {
  @override
  Future<List<Task>> build() async {
    return supabase.from('tasks').select().execute();
  }
  
  Future<void> addTask(Task task) async {...}
  Future<void> toggleComplete(String id) async {...}
  Future<void> deleteTask(String id) async {...}
}
```

### 4.4 UI 设计规范

#### 4.4.1 主题配置

- 使用 Material Design 3
- 主色：蓝色 (ColorScheme.fromSeed)
- 圆角：12dp (BorderRadius.circular(12))
- 卡片阴影：轻微 (elevation: 1)

#### 4.4.2 通用组件

| 组件 | 用途 |
|------|------|
| AppScaffold | 带底部导航的脚手架 |
| LoadingWidget | 加载中状态 |
| EmptyWidget | 空状态显示 |
| ConfirmDialog | 确认对话框 |
| DatePicker | 日期选择器 |

---

## 5. 功能清单

### 5.1 MVP 功能

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 用户注册/登录 | 邮箱注册登录 | P0 |
| 创建家庭 | 创建新家庭 | P0 |
| 加入家庭 | 通过邀请码加入已有家庭 | P0 |
| 成员管理 | 查看/添加/移除家庭成员 | P0 |
| 任务 CRUD | 创建/查看/编辑/删除任务 | P0 |
| 任务完成 | 标记任务完成 | P0 |
| 购物清单 CRUD | 创建/查看/编辑/删除清单 | P0 |
| 购物项管理 | 添加/勾选/删除购物项 | P0 |
| 仪表盘 | 显示各模块汇总 | P0 |

### 5.2 Phase 2 功能

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 日历事件 CRUD | 创建/查看/编辑/删除日历事件 | P1 |
| 账单 CRUD | 创建/查看/编辑/删除账单 | P1 |
| 账单支付标记 | 标记账单已付 | P1 |
| 资产 CRUD | 创建/查看/编辑/删除资产 | P1 |
| Realtime 同步 | 多人实时数据同步 | P1 |
| 推送通知 | 任务/账单到期提醒 | P2 |

### 5.3 Phase 3 功能

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 离线支持 | 本地缓存，离线可用 | P1 |
| 任务指派 | 将任务指派给特定成员 | P1 |
| 任务提醒 | 任务到期前提醒 | P1 |
| 账单统计 | 月度支出统计 | P2 |
| 资产统计 | 资产总价值统计 | P2 |

---

## 6. 开发里程碑

### Phase 1: MVP

| 序号 | 任务 | 工作量 |
|------|------|--------|
| 1 | Supabase 项目初始化 + 数据库表 | 0.5 天 |
| 2 | Flutter 项目初始化 + 路由 | 0.5 天 |
| 3 | 登录/注册 | 1 天 |
| 4 | 创建/加入家庭 | 0.5 天 |
| 5 | 成员管理 | 0.5 天 |
| 6 | 任务 CRUD | 1.5 天 |
| 7 | 购物清单 CRUD | 1 天 |
| 8 | 仪表盘 | 0.5 天 |

**小计：5.5 天**

### Phase 2: 完善基础功能

| 序号 | 任务 | 工作量 |
|------|------|--------|
| 9 | 日历事件 CRUD | 1.5 天 |
| 10 | 账单管理 | 1.5 天 |
| 11 | 资产记录 | 1 天 |
| 12 | Realtime 同步 | 1 天 |
| 13 | 推送通知 | 1 天 |

**小计：6 天**

### Phase 3: 体验优化

| 序号 | 任务 |
|------|------|
| 14 | 离线支持 |
| 15 | 任务指派 + 提醒 |
| 16 | 账单到期提醒 |
| 17 | 统计报表 |

---

## 7. 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v0.1 | 2026-03-06 | 初始版本，创建规范文档 |

---

## 8. 待定事项

- [ ] 离线数据同步策略
- [ ] 推送通知实现细节
- [ ] 邀请码生成规则
- [ ] Web 端特殊适配
