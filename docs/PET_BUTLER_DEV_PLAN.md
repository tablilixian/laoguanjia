# 宠物管家 (Pet Butler) 系统开发文档

> 版本: v1.0 | 日期: 2026-04-05 | 状态: 设计阶段

---

## 目录

1. [系统概述](#1-系统概述)
2. [数据架构设计](#2-数据架构设计)
3. [功能设计](#3-功能设计)
4. [技术架构](#4-技术架构)
5. [渐进实施计划](#5-渐进实施计划)
6. [风险与对策](#6-风险与对策)
7. [参考项目](#7-参考项目)

---

## 1. 系统概述

### 1.1 产品定位

**不是传统电子宠物，而是"有性格的家庭管家"。**

| 维度 | 传统电子宠物 | 宠物管家 |
|------|-------------|---------|
| 核心价值 | 娱乐消遣 | 实用陪伴 |
| 数据来源 | 仅互动数据 | 天气+任务+物品+家庭 |
| 交互方式 | 被动点击 | 主动推送 + 对话 |
| 用户粘性 | 新鲜感消退后流失 | 实用功能形成依赖 |
| 差异化 | 同质化严重 | 独一无二 |

**一句话定位**: 把冰冷的家庭管理数据，变成有温度的自然语言交互。

### 1.2 目标用户

- 家庭管理者，需要任务/物品/天气提醒的人
- 喜欢宠物陪伴但需要实用功能的用户
- 追求生活品质的年轻人

### 1.3 核心功能矩阵

| 模块 | 功能 | 优先级 | 阶段 | 依赖 |
|------|------|--------|------|------|
| 宠物主页 | 展示+状态+快捷互动 | P0 | Phase 2 | 本地存储 |
| 管家播报 | 晨间播报+主动提醒 | P0 | Phase 3 | 天气+任务+物品 |
| AI 对话 | 流式对话+TTS+记忆 | P0 | Phase 2 | LLM API |
| 任务管家 | 提醒+建议+庆祝 | P0 | Phase 3 | 任务系统 |
| 物品管家 | 过期+库存+维护 | P1 | Phase 3 | 物品系统 |
| 宠物房间 | 2.5D 等距视角 | P1 | Phase 4 | Flame Engine |
| 小游戏 | 接食物/记忆翻牌 | P2 | Phase 4 | Flame Engine |
| 技能系统 | 亲密度解锁 | P1 | Phase 2 | 本地存储 |
| 记忆系统 | 家庭事件记录 | P1 | Phase 2 | 本地存储 |
| 设置 | 个性化配置 | P2 | Phase 2 | - |

---

## 2. 数据架构设计

### 2.1 云端数据 (pets_meta 表)

```sql
-- supabase_migrations/031_create_pets_meta.sql
CREATE TABLE IF NOT EXISTS pets_meta (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  owner_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  breed TEXT,
  avatar_url TEXT,
  state_snapshot JSONB,
  last_sync_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_pets_meta_household ON pets_meta(household_id);
CREATE INDEX idx_pets_meta_owner ON pets_meta(owner_id);

-- RLS 策略
ALTER TABLE pets_meta ENABLE ROW LEVEL SECURITY;

CREATE POLICY "家庭成员可查看宠物元数据" ON pets_meta
  FOR SELECT USING (
    household_id IN (
      SELECT household_id FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "宠物主人可管理元数据" ON pets_meta
  FOR ALL USING (owner_id = auth.uid());
```

**字段说明**:

| 字段 | 类型 | 说明 | 写入频率 |
|------|------|------|---------|
| id | UUID | 宠物唯一标识 | 创建时 |
| household_id | UUID | 关联家庭 | 创建时 |
| owner_id | UUID | 关联用户 | 创建时 |
| name | TEXT | 宠物名称 | 改名时 |
| type | TEXT | 宠物类型 | 创建时 |
| breed | TEXT | 品种 | 修改时 |
| avatar_url | TEXT | 头像URL | 换装时 |
| state_snapshot | JSONB | 状态快照(可选) | 同步时 |
| last_sync_at | TIMESTAMPTZ | 最后同步时间 | 每次同步 |

### 2.2 本地数据结构

**文件路径**: `<appDir>/home_manager_data/pets/pet_{petId}_YYYY-MM.json`

**完整 JSON Schema**:

```json
{
  "version": "2.0",
  "petId": "uuid-xxx-xxx",
  "month": "2026-04",
  "generatedAt": "2026-04-05T10:00:00Z",

  "state": {
    "hunger": 80,
    "happiness": 90,
    "cleanliness": 70,
    "health": 100,
    "level": 5,
    "experience": 230,
    "currentMood": "happy",
    "moodText": "今天心情很好！",
    "skills": [
      { "id": "weather_sense", "name": "天气感知", "unlocked": true, "level": 1 },
      { "id": "item_patrol", "name": "物品巡检", "unlocked": false, "level": 0 }
    ],
    "explorationCount": 12,
    "todayExplorationCount": 2,
    "lastExploredAt": "2026-04-04T15:00:00Z",
    "lastFedAt": "2026-04-05T08:00:00Z",
    "lastPlayedAt": "2026-04-05T09:00:00Z",
    "lastBathedAt": "2026-04-03T10:00:00Z"
  },

  "personality": {
    "openness": 0.7,
    "agreeableness": 0.8,
    "extraversion": 0.5,
    "conscientiousness": 0.6,
    "neuroticism": 0.3,
    "traits": ["好奇", "粘人", "爱撒娇"],
    "habits": ["喜欢在窗台晒太阳", "听到门铃会跑过去"],
    "fears": ["打雷", "吸尘器"],
    "speechStyle": "活泼",
    "originDescription": "一只从流浪猫救助站领养的小橘猫"
  },

  "relationship": {
    "trustLevel": 65,
    "intimacyLevel": 3,
    "totalInteractions": 128,
    "feedCount": 45,
    "playCount": 50,
    "chatCount": 33,
    "lastInteractionAt": "2026-04-05T09:30:00Z",
    "joyScore": 78.5,
    "sadnessScore": 12.3,
    "firstInteractionAt": "2026-01-15T10:00:00Z"
  },

  "interactions": [
    {
      "id": "1712289000000",
      "type": "feed",
      "value": 20,
      "createdAt": "2026-04-05T08:00:00Z"
    }
  ],

  "memories": [
    {
      "id": "mem-001",
      "memoryType": "interaction",
      "title": "享用美食",
      "description": "吃了美味的食物，肚子饱饱的，好开心！",
      "emotion": "joy",
      "importance": 2,
      "occurredAt": "2026-04-05T08:00:00Z"
    },
    {
      "id": "mem-002",
      "memoryType": "household_event",
      "title": "搬新家",
      "description": "今天和主人一起搬进了新家",
      "emotion": "joy",
      "importance": 5,
      "occurredAt": "2026-01-15T10:00:00Z"
    }
  ],

  "conversations": [
    {
      "role": "user",
      "content": "你今天开心吗？",
      "createdAt": "2026-04-05T09:00:00Z"
    },
    {
      "role": "assistant",
      "content": "开心呀！主人陪我玩了好久~",
      "createdAt": "2026-04-05T09:00:01Z"
    }
  ],

  "explorations": [
    {
      "id": "exp-001",
      "title": "客厅巡查",
      "content": "我转了一圈，发现...",
      "explorationType": "patrol",
      "durationMinutes": 5,
      "moodAfter": "satisfied",
      "findings": [
        { "location": "客厅", "observation": "沙发上有3件衣服没收拾" },
        { "location": "厨房", "observation": "水槽有点漏水" }
      ],
      "createdAt": "2026-04-04T15:00:00Z"
    }
  ]
}
```

**拆分策略**:

| 策略 | 触发条件 | 行为 |
|------|---------|------|
| 按月拆分 | 跨月自动 | 新月创建新文件，旧文件归档到 `pets/archive/` |
| 按大小拆分 | 文件 > 5MB | 立即归档当前文件，创建新文件 |
| 对话滚动清理 | conversations > 200 条 | 保留最近 100 条，其余清理 |
| 记忆压缩 | memories > 500 条 | importance < 3 的记忆合并为摘要 |

### 2.3 数据流图

```
┌─────────────────────────────────────────────────────────────┐
│                        用户操作                               │
│              (喂食/聊天/完成任务/查看物品)                      │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  PetV2Service (业务逻辑层)                     │
│                                                               │
│  1. 读取本地 JSON → 修改状态 → 写回本地 JSON                    │
│  2. 触发记忆记录                                               │
│  3. 更新关系数据                                               │
│  4. 检查技能解锁条件                                           │
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
     ┌──────────┐  ┌──────────┐  ┌──────────┐
     │ 本地存储  │  │ 管家播报  │  │ 可选同步  │
     │          │  │          │  │          │
     │ JSON文件 │  │ LLM生成  │  │ pets_meta│
     │ 按月归档 │  │ 主动推送  │  │ 状态快照  │
     └──────────┘  └──────────┘  └──────────┘
```

**旧系统 → 新系统迁移流程**:

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ 旧系统 7 张表 │ ──→ │ 一次性迁移脚本 │ ──→ │ 新系统本地JSON│
│ (Supabase)  │     │ (读取+转换)   │     │ + pets_meta │
└─────────────┘     └──────────────┘     └─────────────┘
```

### 2.4 外部数据接入

| 数据源 | 接入方式 | 更新频率 | 缓存策略 |
|--------|---------|---------|---------|
| 天气 | `WeatherService.getWeatherByCity()` | 30min 缓存 | 内存缓存 |
| 任务 | `TaskRepository.getTasks(householdId)` | 实时 | Riverpod Provider |
| 物品 | `ItemsDao.getAll()` (Drift) | 实时 | Stream 监听 |
| 家庭 | `householdProvider` | 低频 | Riverpod StateNotifier |

---

## 3. 功能设计

### 3.1 宠物主页 (Pet Home)

**功能**: 宠物展示 + 状态卡片 + 快捷互动

#### UI 设计

```
┌──────────────────────────────────────┐
│  ← 宠物管家              ⚙️          │
├──────────────────────────────────────┤
│                                      │
│        ╭──────────────────╮          │
│        │                  │          │
│        │   🐱 宠物大图     │          │
│        │   (动画/表情)     │          │
│        │                  │          │
│        ╰──────────────────╯          │
│                                      │
│          小橘 · Lv.5 猫咪             │
│         "今天心情很好！" ☁️           │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 饥饿  ████████░░  80%  🍖     │  │
│  │ 心情  █████████░  90%  😊     │  │
│  │ 清洁  ███████░░░  70%  🛁     │  │
│  │ 健康  ██████████ 100%  💪     │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐│
│  │ 🍖   │ │ 🎾   │ │ 🛁   │ │ 📚   ││
│  │ 喂食  │ │ 玩耍  │ │ 洗澡  │ │ 训练  ││
│  └──────┘ └──────┘ └──────┘ └──────┘│
│                                      │
├──────────────────────────────────────┤
│  📋 管家播报  │  💬 聊天  │  🏠 房间  │
└──────────────────────────────────────┘
```

**设计规范**:
- **背景**: 柔和渐变 (暖色调 `#FFF5E6` → `#FFE8CC`)
- **宠物区域**: 圆形裁剪，带呼吸动画 (scale 1.0 → 1.02 循环)
- **状态条**: 圆角进度条，颜色随值变化 (绿→黄→红)
- **互动按钮**: 64x64 圆形，按下缩放 0.9，带弹性回弹动画
- **底部导航**: 3 个 Tab，当前选中项有底部指示线

#### 交互设计

| 操作 | 反馈 |
|------|------|
| 点击宠物 | 随机表情/动作 + 随机文字气泡 ("喵~" / "主人摸我！") |
| 点击喂食 | 按钮缩放 → 粒子效果 (食物飞入) → 宠物吃播动画 → 状态条更新 |
| 点击玩耍 | 按钮缩放 → 宠物跳跃动画 → 心情值 +20 |
| 下拉刷新 | 宠物打招呼 ("早上好主人！" / "想我了吗？") |
| 长按状态条 | 显示详细数值 + 上次更新时间 |
| 点击底部 Tab | 页面切换动画 (淡入淡出) |

---

### 3.2 管家播报 (Butler Briefing)

**功能**: 晨间播报 + 主动提醒

#### UI 设计

```
┌──────────────────────────────────────┐
│  ← 返回                  📋 管家播报   │
├──────────────────────────────────────┤
│                                      │
│  ╭────────────────────────────────╮  │
│  │ ☀️ 2026年4月5日 周日 08:00     │  │
│  │                                │  │
│  │ 🌤️ 北京 晴天 22°C 湿度 45%    │  │
│  │ 体感 24°C · 东南风 2级         │  │
│  │                                │  │
│  │ 💡 穿衣建议: 今天温度适宜，     │  │
│  │ 建议穿薄外套+长裤，早晚温差大    │  │
│  │ 记得带件外套哦~                 │  │
│  ╰────────────────────────────────╯  │
│                                      │
│  ╭────────────────────────────────╮  │
│  │ 📋 今日待办 (2项)               │  │
│  │                                │  │
│  │ ⚠️ 缴纳水电费                  │  │
│  │    截止: 今天 15:00            │  │
│  │    [ 延期 ]  [ 完成 ]          │  │
│  │                                │  │
│  │ 📝 买猫粮                      │  │
│  │    截止: 明天 12:00            │  │
│  │    [ 延期 ]  [ 完成 ]          │  │
│  ╰────────────────────────────────╯  │
│                                      │
│  ╭────────────────────────────────╮  │
│  │ 🚨 物品提醒 (1项)               │  │
│  │                                │  │
│  │ 🥛 牛奶 · 明天过期              │  │
│  │    [ 加入购物清单 ] [ 忽略 ]    │  │
│  ╰────────────────────────────────╯  │
│                                      │
└──────────────────────────────────────┘
```

**设计规范**:
- **风格**: 专业卡片风 (区别于可爱互动区)
- **天气卡片**: 蓝色渐变背景 (`#E3F2FD` → `#BBDEFB`)
- **任务卡片**: 白色背景，紧急项红色左边框 (`#FF5252`)
- **物品卡片**: 白色背景，过期项橙色左边框 (`#FF9800`)
- **字体**: 播报文字用较大字号 (16sp)，标题加粗

#### 交互设计

| 操作 | 反馈 |
|------|------|
| 页面打开 | 播报文字逐字显示 (typewriter effect, 30ms/字) |
| 点击"延期" | 弹出日期选择器 → 确认后任务更新 → 宠物回复 "好的主人！" |
| 点击"完成" | 任务打勾动画 → 撒花效果 → 宠物庆祝 |
| 左滑卡片 | 标记为已读/忽略 |
| 点击任务 | 跳转到任务详情页 |
| 下拉刷新 | 重新获取最新数据 |

---

### 3.3 AI 对话 (Pet Chat)

**功能**: 流式 AI 对话 + TTS + 历史记录

#### UI 设计

```
┌──────────────────────────────────────┐
│  ← 返回          🐱 小橘  💬         │
├──────────────────────────────────────┤
│  ┌────────────────────────────────┐  │
│  │  🐱 [宠物头像 - 思考中动画]     │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌──────────────────────────────┐    │
│  │ 你今天开心吗？                │ ◀  │
│  └──────────────────────────────┘    │
│                                      │
│    ┌────────────────────────────┐    │
│    │ 开心呀！主人陪我玩了好久~   │ ◀  │
│    │ 对了，今天天气很好，        │    │
│    │ 要不要出去走走？            │    │
│    └────────────────────────────┘    │
│                                      │
│  ┌──────────────────────────────┐    │
│  │ 好呀，去哪里呢？              │ ◀  │
│  └──────────────────────────────┘    │
│                                      │
│    ┌────────────────────────────┐    │
│    │ 去公园吧！听说最近花开得很好 │    │
│    │ 🌸 而且温度刚刚好~          │    │
│    └────────────────────────────┘    │
│                                      │
├──────────────────────────────────────┤
│  💡 建议: "聊聊天气" "问问任务"      │
│  ┌──────────────────────────┐ ┌───┐  │
│  │ 输入消息...               │ │ 🎤│  │
│  └──────────────────────────┘ └───┘  │
└──────────────────────────────────────┘
```

**设计规范**:
- **用户消息**: 右侧，蓝色渐变 (`#1976D2`)，白色文字
- **宠物消息**: 左侧，暖色渐变 (`#FFF3E0` → `#FFE0B2`)，深色文字
- **宠物头像**: 固定在顶部，对话中有"思考中"动画 (三个跳动圆点)
- **建议 Chips**: 底部输入框上方，可点击快速发送
- **TTS 按钮**: 长按宠物消息播放语音

#### 交互设计

| 操作 | 反馈 |
|------|------|
| 发送消息 | 消息上滑 → 宠物头像显示"思考中" → 流式响应逐字显示 |
| 长按宠物消息 | 弹出菜单: 复制 / TTS 播放 / 删除 |
| 点击建议 Chip | 自动发送该消息 |
| 下拉 | 加载历史消息 (最多 50 条) |
| 宠物回复时 | 顶部宠物形象有"说话中"动画 (嘴巴动) |

---

### 3.4 任务管家 (Task Butler)

**功能**: 任务提醒 + 智能建议 + 完成庆祝

#### UI 设计

```
┌──────────────────────────────────────┐
│  ← 返回              📋 任务管家      │
├──────────────────────────────────────┤
│                                      │
│  🐱 "主人，今天有 2 个任务要完成哦！" │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 🔴 紧急                        │  │
│  │                                │  │
│  │ 🐱 缴纳水电费                  │  │
│  │    ⏰ 今天 15:00 截止          │  │
│  │    👤 负责人: 我               │  │
│  │    [ 去完成 ]  [ 延期 ]        │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 🟡 今天                        │  │
│  │                                │  │
│  │ 🐱 买猫粮                      │  │
│  │    ⏰ 明天 12:00 截止          │  │
│  │    👤 负责人: 我               │  │
│  │    [ 去完成 ]  [ 延期 ]        │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 🟢 建议                        │  │
│  │                                │  │
│  │ 🐱 今天下雨，适合在家做         │  │
│  │    「整理衣柜」这个任务~        │  │
│  │    [ 好的，开始 ]  [ 算了 ]    │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

#### 交互设计

| 操作 | 反馈 |
|------|------|
| 点击"去完成" | 跳转到任务详情 → 完成后返回 → 撒花动画 |
| 点击"延期" | 弹出日期选择器 → 确认后更新 |
| 点击"开始" | 任务状态变为进行中 |
| 完成任务 | 全屏撒花 + 宠物庆祝文字 + 亲密度 +5 |
| 任务逾期 | 宠物焦急表情 + 催办消息 |

---

### 3.5 物品管家 (Item Steward)

**功能**: 过期提醒 + 库存检查 + 维护建议

#### UI 设计

```
┌──────────────────────────────────────┐
│  ← 返回              📦 物品管家      │
├──────────────────────────────────────┤
│                                      │
│  🐱 "我检查了一下家里的物品..."      │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 🚨 已过期 (1项)                 │  │
│  │                                │  │
│  │ 🥛 牛奶                         │  │
│  │    过期: 2026-04-04            │  │
│  │    位置: 冰箱                  │  │
│  │    [ 丢弃 ]  [ 加入购物清单 ]   │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ⚠️ 即将过期 (2项)               │  │
│  │                                │  │
│  │ 🧴 洗发水                       │  │
│  │    过期: 2026-04-10 (5天后)    │  │
│  │    [ 加入购物清单 ]            │  │
│  │                                │  │
│  │ 🍞 面包                         │  │
│  │    过期: 2026-04-08 (3天后)    │  │
│  │    [ 加入购物清单 ]            │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 💡 维护建议 (1项)               │  │
│  │                                │  │
│  │ 🔧 空调滤网                     │  │
│  │    已使用 90 天，建议清洗        │  │
│  │    [ 创建任务 ]  [ 忽略 ]       │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

#### 交互设计

| 操作 | 反馈 |
|------|------|
| 点击"加入购物清单" | 物品添加到物品系统 → 宠物确认 "已加入！" |
| 点击"创建任务" | 弹出任务创建页，预填物品信息 |
| 点击"丢弃" | 确认弹窗 → 标记物品为已处理 |
| 下拉刷新 | 重新扫描物品状态 |
| 点击物品 | 跳转到物品详情页 |

---

### 3.6 宠物房间 (Pet Room) - 等距视角

**功能**: 2.5D 房间展示，宠物在其中活动，上帝视角观察

#### UI 设计

```
┌──────────────────────────────────────┐
│  ← 返回              🏠 宠物房间      │
├──────────────────────────────────────┤
│                                      │
│  ╔══════════════════════════════════╗║
│  ║                                  ║║
│  ║    🛋️        📺                 ║║
│  ║                                  ║║
│  ║         🐱 (宠物在走动)          ║║
│  ║                                  ║║
│  ║    🪴              🚪            ║║
│  ║                                  ║║
│  ╚══════════════════════════════════╝║
│                                       │
│  ┌────────────────────────────────┐  │
│  │ 🐱 小橘                         │  │
│  │ 状态: 开心 😊                   │  │
│  │ 位置: 客厅中央                   │  │
│  │ [ 互动 ]  [ 喂食 ]  [ 玩耍 ]    │  │
│  └────────────────────────────────┘  │
│                                      │
│  🏠 客厅  │  🛏️ 卧室  │  🍳 厨房    │
└──────────────────────────────────────┘
```

**设计规范**:
- **视角**: 2.5D 等距视角 (isometric)，参考 openclaw-world 风格
- **房间**: 使用 Tiled Map Editor 制作，导出为 JSON/TSX
- **宠物**: 精灵动画 (sprite sheet)，idle/walk/eat/play 等状态
- **家具**: 可点击，显示信息卡片 (Flutter Overlay)
- **底部**: 房间切换 Tab

#### 技术实现

```
┌─────────────────────────────────────────┐
│              Flutter Page              │
│  ┌───────────────────────────────────┐  │
│  │        Flame GameWidget          │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  IsometricTileMapComponent  │  │  │
│  │  │  (房间地图 - Tiled 生成)     │  │  │
│  │  │                             │  │  │
│  │  │  PetSpriteComponent         │  │  │
│  │  │  (宠物精灵 - 状态驱动)       │  │  │
│  │  │                             │  │  │
│  │  │  FurnitureComponent[]       │  │  │
│  │  │  (可点击家具)                │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  Flutter Overlay Widgets          │  │
│  │  - 宠物信息卡                      │  │
│  │  - 家具详情卡                      │  │
│  │  - 互动菜单                        │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

**依赖包**:
```yaml
dependencies:
  flame: ^1.20.0
  flame_isometric: ^0.4.2
  flame_forge2d: ^0.18.0  # 物理引擎 (小游戏用)
```

#### 交互设计

| 操作 | 反馈 |
|------|------|
| 拖拽 | 平移房间视角 (有限范围) |
| 点击宠物 | 弹出互动菜单 (喂食/玩耍/聊天) |
| 点击家具 | 弹出信息卡 (如冰箱 → 显示物品状态) |
| 双击房间 | 切换楼层/场景 |
| 底部 Tab 切换 | 房间切换动画 (淡入淡出) |
| 长按家具 | 跳转到物品/任务详情 |

**宠物行为规则**:

| 宠物状态 | 房间行为 |
|---------|---------|
| hunger < 30 | 走向食盆/冰箱区域 |
| happiness < 30 | 蜷缩在沙发/床上 |
| cleanliness < 30 | 走向浴室区域 |
| happiness > 80 | 在房间内活跃跑动 |
| 空闲 | 随机走动，偶尔坐下/睡觉 |

---

### 3.7 小游戏系统 (Mini Games)

**功能**: 喂食小游戏、训练小游戏、探索小游戏

#### 游戏列表

| 游戏 | 类型 | 引擎 | 奖励 |
|------|------|------|------|
| 接食物 | 反应类 | Flame + Forge2D | hunger +10~30 |
| 记忆翻牌 | 记忆类 | Flutter Widget | experience +5~15 |
| 反应测试 | 反应类 | Flame | experience +10~20 |
| 探索冒险 | 文字冒险 | Flutter Widget | 随机奖励 + 探索日记 |

#### 接食物游戏 UI

```
┌──────────────────────────────────────┐
│  ← 返回        🎮 接食物      ⏱️ 30s │
├──────────────────────────────────────┤
│                                      │
│  🍖          🍕         🍗           │
│                                      │
│                                      │
│            🍎                        │
│                                      │
│                                      │
│                                      │
│                                      │
│                                      │
│              🐱                      │
│           ◀──────▶                   │
│                                      │
│  得分: 15    连击: 3     missed: 2   │
└──────────────────────────────────────┘
```

#### 交互设计

| 操作 | 反馈 |
|------|------|
| 左右滑动 | 宠物移动接食物 |
| 接到食物 | 得分 +1，连击 +1，宠物开心动画 |
| 漏接食物 | missed +1，宠物遗憾表情 |
| 连击 x5 | 额外奖励 +5，全屏特效 |
| 时间结束 | 结算画面 → 奖励写入本地 JSON |

---

### 3.8 技能系统 (Skills)

**功能**: 亲密度驱动的能力解锁

#### UI 设计

```
┌──────────────────────────────────────┐
│  ← 返回              ⭐ 宠物技能      │
├──────────────────────────────────────┤
│                                      │
│  亲密度 Lv.3  ███████░░░  65/100     │
│  下一级解锁: 购物助手                 │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ✅ 天气感知 (Lv.1)              │  │
│  │    解锁于 Lv.1                  │  │
│  │    读取天气数据，生成穿衣建议    │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ✅ 物品巡检 (Lv.2)              │  │
│  │    解锁于 Lv.2                  │  │
│  │    检查物品过期/库存不足         │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ✅ 任务提醒 (Lv.2)              │  │
│  │    解锁于 Lv.2                  │  │
│  │    主动催办任务，智能建议        │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 🔒 购物助手 (Lv.4)              │  │
│  │    还需 35 亲密度               │  │
│  │    自动生成购物清单，比价建议    │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 🔒 家庭报告 (Lv.5)              │  │
│  │    还需 35 亲密度               │  │
│  │    每周生成家庭运营报告          │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

#### 交互设计

| 操作 | 反馈 |
|------|------|
| 点击已解锁技能 | 展开详细说明 + 当前状态 |
| 点击锁定技能 | 显示解锁条件 + 当前进度 |
| 技能解锁时 | 全屏动画 + 宠物语音提示 |

---

### 3.9 记忆系统 (Memories)

**功能**: 记录所有家庭事件

#### UI 设计

```
┌──────────────────────────────────────┐
│  ← 返回              💭 宠物记忆      │
├──────────────────────────────────────┤
│                                      │
│  全部  互动  任务  物品  天气  家庭   │
│                                      │
│  ─── 2026年4月 ───                   │
│                                      │
│  📌 4月5日                           │
│  ┌────────────────────────────────┐  │
│  │ 😊 享用美食                     │  │
│  │    吃了美味的食物，肚子饱饱的    │  │
│  │    重要性: ⭐⭐                 │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ✅ 完成了大扫除                 │  │
│  │    主人今天好勤快！             │  │
│  │    重要性: ⭐⭐⭐              │  │
│  └────────────────────────────────┘  │
│                                      │
│  ─── 2026年3月 ───                   │
│                                      │
│  📌 3月20日                          │
│  ┌────────────────────────────────┐  │
│  │ 🌧️ 今天下了第一场春雨          │  │
│  │    主人说春雨贵如油~            │  │
│  │    重要性: ⭐⭐⭐              │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

#### 交互设计

| 操作 | 反馈 |
|------|------|
| 点击记忆 | 展开详情 + 完整描述 |
| 下拉 | 加载更多历史记忆 |
| 长按记忆 | 弹出菜单: 编辑重要性 / 删除 |
| 切换 Tab | 按类型过滤 |
| 搜索 | 按关键词搜索记忆 |

---

### 3.10 设置与个性化

**功能**: 宠物名称/外观/播报频率/通知设置

#### UI 设计

```
┌──────────────────────────────────────┐
│  ← 返回              ⚙️ 宠物设置      │
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 基本信息                        │  │
│  │                                │  │
│  │ 名称: 小橘              [修改]  │  │
│  │ 品种: 橘猫              [修改]  │  │
│  │ 性别: 公                [修改]  │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 播报设置                        │  │
│  │                                │  │
│  │ 晨间播报          [开启] ────○  │  │
│  │ 播报时间          08:00   [设置] │  │
│  │ 任务提醒          [开启] ────○  │  │
│  │ 物品提醒          [开启] ────○  │  │
│  │ 天气提醒          [开启] ────○  │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 通知设置                        │  │
│  │                                │  │
│  │ 推送通知          [开启] ────○  │  │
│  │ 通知频率            按需    [设置] │  │
│  │ 免打扰时段   22:00 - 07:00 [设置] │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 数据管理                        │  │
│  │                                │  │
│  │ 导出宠物数据             [导出]  │  │
│  │ 导入宠物数据             [导入]  │  │
│  │ 清除本地缓存             [清除]  │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

---

## 4. 技术架构

### 4.1 目录结构

```
lib/
├── core/
│   ├── config/
│   │   └── feature_flags.dart              # 功能开关
│   └── services/
│       ├── pet_local_storage_v2.dart       # 新本地存储
│       ├── pet_butler_service.dart         # 管家播报核心
│       ├── pet_memory_service.dart         # 记忆管理
│       └── pet_v2_service.dart             # 统一业务逻辑
│
├── data/
│   ├── models/
│   │   ├── pet_meta.dart                   # 云端元数据
│   │   ├── pet_local_data.dart             # 本地完整数据
│   │   ├── pet_state.dart                  # 宠物状态
│   │   ├── pet_interaction.dart            # 互动记录
│   │   ├── pet_memory.dart                 # 记忆 (扩展)
│   │   ├── pet_relationship.dart           # 关系 (扩展)
│   │   ├── pet_skill.dart                  # 技能
│   │   └── exploration_diary.dart          # 探索/巡查日记
│   └── repositories/
│       ├── pet_meta_repository.dart        # 云端 pets_meta 操作
│       └── pet_local_repository.dart       # 本地 JSON 操作
│
├── features/
│   └── pets_v2/
│       ├── providers/
│       │   ├── pet_v2_provider.dart        # Riverpod 状态管理
│       │   └── pet_butler_provider.dart    # 管家播报 Provider
│       ├── pages/
│       │   ├── pet_home_page.dart          # 宠物主页
│       │   ├── pet_room_page.dart          # 宠物房间
│       │   ├── pet_chat_page.dart          # AI 对话
│       │   ├── pet_briefing_page.dart      # 管家播报
│       │   ├── pet_tasks_page.dart         # 任务管家
│       │   ├── pet_items_page.dart         # 物品管家
│       │   ├── pet_memories_page.dart      # 记忆系统
│       │   ├── pet_skills_page.dart        # 技能系统
│       │   └── pet_settings_page.dart      # 设置
│       ├── widgets/
│       │   ├── pet_avatar.dart             # 宠物头像组件
│       │   ├── status_bar.dart             # 状态条组件
│       │   ├── briefing_card.dart          # 播报卡片
│       │   ├── interaction_button.dart     # 互动按钮
│       │   └── memory_card.dart            # 记忆卡片
│       └── game/
│           ├── room/
│           │   ├── pet_room_game.dart      # 房间游戏世界
│           │   ├── room_map.dart           # 房间地图组件
│           │   ├── pet_sprite.dart         # 宠物精灵
│           │   └── furniture_component.dart # 家具组件
│           └── mini_games/
│               ├── catch_food_game.dart    # 接食物游戏
│               └── memory_card_game.dart   # 记忆翻牌游戏
│
└── ... (其他现有代码不变)
```

### 4.2 核心服务设计

#### PetLocalStorageV2

```dart
class PetLocalStorageV2 {
  final LocalStorageService _storage = LocalStorageService.instance;
  
  static const int MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
  static const int MAX_CONVERSATIONS = 200;

  String _filename(String petId) {
    final now = DateTime.now();
    return 'pets/pet_${petId}_${now.year}-${now.month.toString().padLeft(2, '0')}.json';
  }

  /// 读取当月完整数据
  Future<PetLocalData?> loadData(String petId) async {
    final data = await _storage.readJsonFile(_filename(petId));
    if (data == null) return null;
    return PetLocalData.fromJson(data);
  }

  /// 写入完整数据 (覆盖写)
  Future<void> saveData(PetLocalData data) async {
    await _storage.writeJsonFile(_filename(data.petId), data.toJson());
    await _checkAndArchive(data.petId);
  }

  /// 原子更新: 读取 → 修改 → 写入
  Future<T> update<T>(
    String petId,
    T Function(PetLocalData) mutator,
  ) async {
    final data = await loadData(petId) ?? PetLocalData.empty(petId);
    final result = mutator(data);
    await saveData(data);
    return result;
  }

  /// 检查文件大小，超限则归档
  Future<void> _checkAndArchive(String petId) async {
    final size = await _storage.getFileSize(_filename(petId));
    if (size > MAX_FILE_SIZE) {
      await _archiveCurrentMonth(petId);
    }
  }
}
```

#### PetButlerService

```dart
class PetButlerService {
  final WeatherService _weatherService;
  final TaskRepository _taskRepo;
  final ItemsDao _itemsDao;
  final PetLocalStorageV2 _localStorage;

  /// 生成晨间播报
  Future<String> generateMorningBriefing(String petId) async {
    final data = await _localStorage.loadData(petId);
    if (data == null) return '';

    // 获取外部数据
    final weather = await _getWeather();
    final tasks = await _getTodayTasks();
    final itemAlerts = await _getItemAlerts();

    // 构建 Prompt
    final prompt = _buildBriefingPrompt(
      pet: data,
      weather: weather,
      tasks: tasks,
      items: itemAlerts,
      timeOfDay: 'morning',
    );

    // LLM 生成播报
    return await _aiService.sendMessage(prompt, []);
  }

  /// 构建播报 Prompt
  String _buildBriefingPrompt({
    required PetLocalData pet,
    WeatherData? weather,
    required List<Task> tasks,
    required List<ItemAlert> items,
    required String timeOfDay,
  }) {
    final personality = pet.personality;
    return '''
你是${pet.state.name}，一个${personality.speechStyle}的家庭管家。

【你的状态】心情: ${pet.state.currentMood}，亲密度: Lv.${pet.relationship.intimacyLevel}

【当前环境】
${weather != null ? '天气: ${weather.description}, ${weather.temperature}°C, 湿度${weather.humidity}%' : '天气数据不可用'}

【待办事项】
${tasks.map((t) => '- ${t.title} (截止: ${t.dueDate})').join('\n') ?: '暂无待办'}

【物品提醒】
${items.map((a) => '- ${a.message}').join('\n') ?: '无异常'}

【播报要求】
1. 用${personality.speechStyle}的语气
2. 优先提醒紧急事项
3. 天气相关建议要具体
4. 语气温暖自然，像家人一样
5. 长度控制在100字以内
6. 适当使用emoji
''';
  }
}
```

#### PetMemoryService

```dart
class PetMemoryService {
  final PetLocalStorageV2 _localStorage;
  final AIService _aiService;

  /// 从对话中自动提取重要事件并记录为记忆
  Future<void> extractMemoryFromConversation({
    required String petId,
    required String userMessage,
    required String petResponse,
  }) async {
    // LLM 判断是否有值得记录的事件
    final extractionPrompt = '''
请判断以下对话中是否有值得记录的重要事件。
如果有，请提取事件信息。

用户: $userMessage
宠物: $petResponse

如果有重要事件，返回 JSON:
{"hasEvent": true, "title": "事件标题", "description": "描述", "emotion": "joy/sad/neutral", "importance": 1-5}
如果没有，返回: {"hasEvent": false}
''';

    final result = await _aiService.sendMessage(extractionPrompt, []);
    final extraction = jsonDecode(result);

    if (extraction['hasEvent'] == true) {
      await _localStorage.update(petId, (data) {
        data.memories.add(PetMemory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          memoryType: 'conversation_highlight',
          title: extraction['title'],
          description: extraction['description'],
          emotion: extraction['emotion'],
          importance: extraction['importance'],
          occurredAt: DateTime.now(),
        ));
        return null;
      });
    }
  }
}
```

### 4.3 LLM Prompt 架构

```
┌─────────────────────────────────────────────────────┐
│                  System Prompt                       │
│                                                     │
│  【角色定义】                                         │
│  你是 {name}，一只 {type}，{speechStyle} 的家庭管家   │
│                                                     │
│  【人格特征】                                         │
│  开放性: {openness} | 宜人性: {agreeableness}        │
│  外向性: {extraversion} | 尽责性: {conscientiousness}│
│  神经质: {neuroticism}                              │
│                                                     │
│  【当前状态】                                         │
│  心情: {mood} | 亲密度: Lv.{intimacyLevel}           │
│  技能: {skills}                                     │
│                                                     │
│  【近期记忆】                                         │
│  {recentMemories}                                    │
│                                                     │
│  【实时数据】(根据解锁技能动态注入)                     │
│  天气: {weather}                                     │
│  任务: {tasks}                                       │
│  物品: {items}                                       │
│                                                     │
│  【对话规则】                                         │
│  1. 保持 {speechStyle} 的语气                        │
│  2. 适当引用记忆                                     │
│  3. 主动提供建议 (如果解锁相关技能)                    │
│  4. 长度适中，不要啰嗦                                │
└─────────────────────────────────────────────────────┘
```

### 4.4 Flame 游戏集成方案

```dart
// lib/features/pets_v2/pages/pet_room_page.dart
class PetRoomPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: PetRoomGame(petId: widget.petId),
        overlayBuilderMap: {
          'petInfo': (context, game) => PetInfoOverlay(petId: widget.petId),
          'furnitureInfo': (context, game) => FurnitureInfoOverlay(
            furniture: game.selectedFurniture,
          ),
          'interactionMenu': (context, game) => InteractionMenuOverlay(
            petId: widget.petId,
          ),
        },
        initialActiveOverlays: ['petInfo'],
      ),
    );
  }
}

// lib/features/pets_v2/game/room/pet_room_game.dart
class PetRoomGame extends FlameGame {
  final String petId;
  
  @override
  Future<void> onLoad() async {
    // 加载等距地图
    final map = await loadIsometricMap('assets/maps/living_room.json');
    add(map);
    
    // 加载宠物精灵
    final pet = await PetSpriteComponent.load(petId);
    add(pet);
    
    // 加载家具组件
    final furniture = await loadFurniture('assets/maps/living_room_furniture.json');
    addAll(furniture);
  }
}
```

**游戏结果回调更新数据**:

```dart
// 小游戏结束后更新宠物状态
void onGameComplete(GameResult result) {
  petLocalStorageV2.update(widget.petId, (data) {
    data.state.experience += result.experienceReward;
    data.state.happiness += result.happinessReward;
    
    // 检查升级
    while (data.state.experience >= data.state.level * 100) {
      data.state.experience -= data.state.level * 100;
      data.state.level++;
    }
    
    return null;
  });
}
```

---

## 5. 渐进实施计划

### Phase 1: 基础设施 (Week 1-2)

| 目标 | 交付物 | 验收标准 |
|------|--------|---------|
| 新建 `pets_meta` 表 | SQL 迁移文件 | Supabase 执行成功 |
| 实现 `PetLocalStorageV2` | 本地存储服务 | 读写/归档/拆分测试通过 |
| 实现 `PetMetaRepository` | 云端仓库 | CRUD 测试通过 |
| 实现数据模型 | 所有 model 文件 | 序列化/反序列化测试通过 |
| Feature Flag 开关 | `feature_flags.dart` | 可切换新旧系统 |

### Phase 2: 核心功能 (Week 3-4)

| 目标 | 交付物 | 验收标准 |
|------|--------|---------|
| 宠物主页 | `pet_home_page.dart` | 展示/互动/状态更新正常 |
| AI 对话 | `pet_chat_page.dart` | 流式响应/TTS/记忆正常 |
| 技能系统 | `pet_skills_page.dart` | 解锁/展示正常 |
| 记忆系统 | `pet_memories_page.dart` | 记录/展示/搜索正常 |
| 设置页 | `pet_settings_page.dart` | 配置/导出/导入正常 |

### Phase 3: 管家功能 (Week 5-6)

| 目标 | 交付物 | 验收标准 |
|------|--------|---------|
| 管家播报 | `pet_briefing_page.dart` + `PetButlerService` | 天气+任务+物品播报正常 |
| 任务管家 | `pet_tasks_page.dart` | 提醒/建议/完成庆祝正常 |
| 物品管家 | `pet_items_page.dart` | 过期/库存/维护提醒正常 |
| 巡查系统 | 改造探索为巡查 | 巡查报告生成正常 |

### Phase 4: 房间与游戏 (Week 7-8)

| 目标 | 交付物 | 验收标准 |
|------|--------|---------|
| Flame 集成 | 依赖配置 + 基础 GameWidget | 游戏画面正常渲染 |
| 宠物房间 | `pet_room_page.dart` + 等距地图 | 房间展示/宠物活动/家具交互正常 |
| 接食物游戏 | `catch_food_game.dart` | 游戏可玩/结果写入数据 |
| 记忆翻牌 | `memory_card_game.dart` | 游戏可玩/结果写入数据 |

### Phase 5: 灰度与替换 (Week 9-10)

| 目标 | 交付物 | 验收标准 |
|------|--------|---------|
| 旧数据迁移脚本 | `migrate_from_old_system.dart` | 7 张表 → 新 JSON 迁移成功 |
| 灰度发布 | Feature Flag 部分用户开启 | 新系统运行稳定 |
| 全量切换 | Feature Flag = true | 所有用户走新系统 |
| 旧代码清理 | 删除旧 Repository | 无回归问题 |

---

## 6. 风险与对策

| 风险 | 影响 | 概率 | 对策 |
|------|------|------|------|
| 数据丢失 (用户卸载 App) | 高 | 中 | 强化导出/备份提醒，云端保留 state_snapshot |
| 大 JSON 文件性能 | 中 | 低 | 按月拆分 + 5MB 归档 + 对话滚动清理 |
| LLM 成本控制 | 中 | 中 | 缓存播报结果，批量请求，设置每日上限 |
| Flame 学习曲线 | 中 | 中 | 先用 Flutter Widget 实现小游戏，Flame 仅用于房间 |
| 新旧系统数据不一致 | 高 | 低 | Feature Flag 切换时执行一次性迁移脚本 |
| 主动推送打扰用户 | 中 | 中 | 提供细粒度通知设置，免打扰时段 |

---

## 7. 参考项目

| 项目 | 技术栈 | 参考价值 | 链接 |
|------|--------|---------|------|
| **openclaw-world** | TypeScript + Three.js | 3D 等距房间，AI 角色实时活动 | https://github.com/ChenKuanSun/openclaw-world |
| **MyClaw3D** | React + Three.js | 等距视角管理 AI agents | https://github.com/0xMerl99/MyClaw3D |
| **Desktop-Pixel-Pet** | Flutter | 像素宠物帧动画，101 stars | https://github.com/CanFlyhang/Desktop-Pixel-Pet |
| **flame_isometric** | Flutter/Flame | 等距地图 Flutter 包 | https://pub.dev/packages/flame_isometric |
| **flame-games/isometric_map** | Flutter/Flame | Flame 官方等距地图示例 | https://github.com/flame-games/isometric_map |
| **kkclaw** | JavaScript | 桌面宠物 AI 助手，144 stars | https://github.com/kk43994/kkclaw |

---

> **文档维护**: 本文档随开发进度持续更新，重大变更需记录版本号。
> **最后更新**: 2026-04-05 v1.0
