# 宠物探索世界功能 - 开发规范

> 文档版本：v1.0
> 创建日期：2026-03-17
> 功能：让宠物根据自身特点生成探索世界的日记故事

---

## 1. 功能概述

### 1.1 核心能力

宠物可以外出探索世界，根据以下特征生成独特的冒险日记：

| 特征 | 来源 | 对故事的影响 |
|------|------|-------------|
| 宠物类型 | 创建时选择 | 决定适合的地点和遭遇 |
| 性格特征 | Big Five + 标签 | 影响遇到事情的反应 |
| 技能 | 用户选择 + 隐藏 | 解锁特殊事件和能力 |
| 说话风格 | 随机/选择 | 决定日记的语言基调 |
| 等级 | 互动成长 | 影响遇到事件的难度 |
| 心情/饱食度 | 实时状态 | 决定探索的积极程度 |

### 1.2 故事输出示例

```
# 球球（小狗）的探索日记

## 第一站：社区小花园
- 怎么去的：早上趁主人不注意，偷偷从门缝钻出去，一路上摇着尾巴小跑
- 遇到：一群在花丛中采蜜的蜜蜂，还有一只叫"小灰"的流浪猫
- 感受：春天的花真香呀！但是蜜蜂有点可怕，喵了一声就跑开了

## 第二站：宠物公园
- 怎么去的：穿过花园，沿着经常遛弯的小路走，还遇到了热情的隔壁金毛
- 遇到：很多其他狗狗，大家一起追逐玩耍，还学到了新游戏"追飞盘"
- 感受：太开心了！就是有点累，舌头都伸出来了

## 第三站：便利店门口
- 怎么去的：闻到了香味，自动导航到便利店门口
- 遇到：店主阿姨给了点火腿肠，还遇到了经常一起玩的泰迪"豆豆"
- 感受：火腿肠太好吃了！豆豆说它最近学会了新技能，我也想学

...（共8-9站）

## 回家
- 夕阳西下，我该回家了
- 今天遇到了好多新朋友，学到了新东西
- 最想的是主人，不知道他有没有担心我
- 回到家要蹭蹭主人的腿，告诉他我今天的故事
```

---

## 2. 技术架构

### 2.1 系统架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Flutter App                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐   │
│  │   探索入口 UI    │    │   日记展示页    │    │   回忆相册      │   │
│  │  • 详情页按钮   │    │  • 滚动阅读     │    │  • 历史日记     │   │
│  │  • 探索进度     │    │  • 分享功能     │    │  • 筛选排序     │   │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘   │
│           │                       │                       │            │
│           └───────────────────────┼───────────────────────┘            │
│                                   ▼                                     │
│                    ┌────────────────────────┐                          │
│                    │   ExplorationService    │                          │
│                    │   (探索服务层)           │                          │
│                    └────────────┬────────────┘                          │
│                                   │                                     │
│           ┌───────────────────────┼───────────────────────┐           │
│           ▼                       ▼                       ▼           │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐       │
│  │ PromptBuilder  │    │  AI Service    │    │ Repository     │       │
│  │ (构建提示词)   │    │  (流式生成)    │    │ (数据持久化)   │       │
│  └────────────────┘    └────────────────┘    └────────────────┘       │
│                                   │                                     │
└───────────────────────────────────┼─────────────────────────────────────┘
                                    ▼
                         ┌─────────────────────┐
                         │   Supabase 数据库   │
                         │  • 探索日记表       │
                         │  • 宠物表(扩展)    │
                         └─────────────────────┘
```

### 2.2 数据流

```
用户点击"去探索"
       │
       ▼
┌─────────────────────┐
│ 1. 检查前置条件     │
│    • 饱食度 >= 20   │
│    • 心情 >= 30     │
│    • 今日次数 < 3   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 2. 加载宠物上下文   │
│    • 基本信息       │
│    • 性格          │
│    • 技能          │
│    • 心情状态      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 3. 构建 Prompt      │
│    • 注入宠物特征   │
│    • 注入地点池    │
│    • 注入故事要求  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 4. AI 流式生成     │
│    • 流式输出 UI   │
│    • 打字机效果    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 5. 解析并存储       │
│    • 解析故事内容   │
│    • 保存到数据库   │
│    • 消耗饱食度    │
└──────────┬──────────┘
           │
           ▼
    展示日记页面
```

---

## 3. 数据库设计

### 3.1 新建表：pet_exploration_diaries

```sql
CREATE TABLE pet_exploration_diaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  
  -- 日记基本信息
  title TEXT NOT NULL,                    -- 日记标题，如"球球的冒险日记"
  content TEXT NOT NULL,                  -- 完整日记内容（Markdown格式）
  
  -- 结构化数据（便于筛选和展示）
  stops JSONB NOT NULL DEFAULT '[]',       -- 各地点详情，详见 3.2
  
  -- 探索元数据
  exploration_type TEXT DEFAULT 'normal',  -- 探索类型：normal(普通), special(特殊), auto(自动)
  duration_minutes INT DEFAULT 60,         -- 假设探索时长
  mood_after TEXT,                         -- 探索后的心情：excited, tired, happy, scared
  
  -- 关联
  intimacy_level_at_explore INT,           -- 探索时的亲密度
  
  -- 时间戳
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_diaries_pet ON pet_exploration_diaries(pet_id, created_at DESC);
CREATE INDEX idx_diaries_type ON pet_exploration_diaries(pet_id, exploration_type);

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
```

### 3.2 stops 字段结构

```json
[
  {
    "order": 1,
    "name": "社区小花园",
    "type": "real",              // real: 真实地点, fictional: 虚构地点
    "transport": "偷偷溜出去",
    "encounter": "遇到了小灰一只猫",
    "feeling": "紧张又兴奋",
    "mood_change": "happy"      // 心情变化
  },
  {
    "order": 2,
    "name": "宠物公园",
    "type": "real",
    "transport": "沿着平时遛弯的路",
    "encounter": "和很多狗狗一起玩飞盘",
    "feeling": "非常开心",
    "mood_change": "excited"
  }
]
```

### 3.3 宠物表扩展

```sql
-- 添加探索相关字段
ALTER TABLE pets ADD COLUMN IF NOT EXISTS 
  exploration_count INT DEFAULT 0;         -- 探索总次数

ALTER TABLE pets ADD COLUMN IF NOT EXISTS 
  last_explored_at TIMESTAMPTZ;            -- 上次探索时间

ALTER TABLE pets ADD COLUMN IF NOT EXISTS 
  today_exploration_count INT DEFAULT 0;   -- 今日探索次数

-- 每日重置的字段需要通过应用逻辑或定时任务处理
```

### 3.4 探索配置表（可选）

```sql
CREATE TABLE exploration_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_type TEXT NOT NULL,                 -- 宠物类型
  
  -- 地点池
  real_locations JSONB NOT NULL,          -- 真实地点列表
  fictional_locations JSONB NOT NULL,      -- 虚构地点列表
  
  -- 遭遇池
  encounters JSONB NOT NULL,              -- 可能的遭遇
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 4. 数据模型设计

### 4.1 ExplorationDiary 模型

```dart
class ExplorationDiary {
  final String id;
  final String petId;
  final String title;
  final String content;
  final List<ExplorationStop> stops;
  final String explorationType;
  final int durationMinutes;
  final String? moodAfter;
  final int intimacyLevelAtExplore;
  final DateTime createdAt;

  // ...
}

class ExplorationStop {
  final int order;
  final String name;
  final String type;           // 'real' or 'fictional'
  final String transport;
  final String encounter;
  final String feeling;
  final String moodChange;
}
```

### 4.2 ExplorationConfig 模型

```dart
class ExplorationConfig {
  final String petType;
  final List<Location> realLocations;
  final List<Location> fictionalLocations;
  final List<Encounter> encounters;
}

class Location {
  final String name;
  final String description;
  final String region;         // 地区：urban, suburb, nature
  final List<String> suitableTypes;  // 适合的宠物类型
}

class Encounter {
  final String id;
  final String description;
  final String moodEffect;     // 心情影响
  final List<String> petTypes; // 适用的宠物类型
}
```

---

## 5. 服务层设计

### 5.1 ExplorationService

```dart
class ExplorationService {
  final PetAIRepository _repository = PetAIRepository();
  
  /// 检查是否可以探索
  Future<ExplorationCheckResult> checkCanExplore(Pet pet) async {
    // 检查饱食度
    if (pet.hunger < 20) {
      return ExplorationCheckResult(
        canExplore: false,
        reason: '太饿了，先吃点东西吧',
      );
    }
    
    // 检查心情
    if (pet.happiness < 30) {
      return ExplorationCheckResult(
        canExplore: false,
        reason: '心情不好，想在家里休息',
      );
    }
    
    // 检查今日次数
    if (pet.todayExplorationCount >= 3) {
      return ExplorationCheckResult(
        canExplore: false,
        reason: '今天已经玩累了，明天再出去吧',
      );
    }
    
    return ExplorationCheckResult(canExplore: true);
  }
  
  /// 生成探索日记
  Future<ExplorationDiary> generateDiary({
    required Pet pet,
    required PetPersonality personality,
    required List<PetSkill> skills,
    int stops = 8,
  }) async {
    final prompt = ExplorationPromptBuilder.build(
      pet: pet,
      personality: personality,
      skills: skills,
      stops: stops,
    );
    
    // 调用 AI 生成（流式）
    final content = await AIService.instance.generate(prompt);
    
    // 解析内容
    final parsed = _parseDiaryContent(content);
    
    // 保存到数据库
    final diary = await _repository.saveDiary(
      petId: pet.id,
      title: parsed.title,
      content: content,
      stops: parsed.stops,
      explorationType: 'normal',
      moodAfter: parsed.moodAfter,
      intimacyLevelAtExplore: await _getIntimacyLevel(pet.id),
    );
    
    // 更新宠物状态（消耗饱食度）
    await _updatePetAfterExploration(pet);
    
    return diary;
  }
  
  /// 获取宠物探索历史
  Future<List<ExplorationDiary>> getDiaries(String petId, {int limit = 10}) {
    return _repository.getDiaries(petId, limit: limit);
  }
}
```

### 5.2 ExplorationPromptBuilder

```dart
class ExplorationPromptBuilder {
  static String build({
    required Pet pet,
    required PetPersonality personality,
    required List<PetSkill> skills,
    int stops = 8,
  }) {
    return '''
你是 ${pet.name}，一只可爱的${_getPetTypeText(pet.type)}。

## 你的基本信息
- 名字：${pet.name}
- 年龄：${_getAgeDescription(pet.level)}
- 性别：${pet.breed ?? '未知'}

## 你的性格特征
${_formatTraits(personality)}

## 你的习惯
${_formatHabits(personality)}

## 你害怕的事情
${_formatFears(personality)}

## 你的说话风格
${_getSpeechStyleInstructions(personality.speechStyle)}

## 你的技能
${_formatSkills(skills)}

## 你当前的状态
- 饥饿度：${pet.hunger}% ${_getHungerDescription(pet.hunger)}
- 心情值：${pet.happiness}% ${_getMoodDescription(pet.happiness)}
- 健康度：${pet.health}%
- 等级：${pet.level}

## 你生活的世界
${_getWorldDescription(pet.type)}

## 任务
请以第一人称写一篇你外出探索世界的日记。

### 要求
1. 包含 **${stops}个地点** 的冒险故事
2. 每个地点必须包含：
   - **地点名称**（可以是中国或世界的真实地名，也可以是虚构的奇妙地方）
   - **怎么到达的**（描述你用什么方式去的）
   - **遇到了什么**（可以是人、其他动物、有趣的事情）
   - **你的感受和想法**

3. **必须体现你的性格**：
   - 如果你${personality.traits.join('、')}，在故事中要表现出来
   - 如果你${personality.habits.join('、')}，这些习惯会影响你的选择
   - 如果你害怕${personality.fears.join('、')}，遇到时要表现出害怕

4. **适当展现你的技能**（如果有）：
   ${skills.map((s) => '- ${s.name}: 在${_getSkillScene(s)}时展现了').join('\n')}

5. **语言风格要符合你的说话风格**：
   ${_getSpeechStyleInstructions(personality.speechStyle)}

6. **故事要有起伏**：
   - 有开心的事情
   - 有困难或挫折
   - 有惊喜或意外
   - 有疲惫想回家的时候

7. **最后要表达**：
   - 很想念主人
   - 期待回家和主人分享

### 输出格式
# ${pet.name} 的探索日记

## 第一站：[地点名]
- 怎么去的：[描述]
- 遇到：[描述]
- 感受：[描述]

## 第二站：[地点名]
- 怎么去的：[描述]
- 遇到：[描述]
- 感受：[描述]

...（共 ${stops} 站）

## 回家
- 描述回家的心情和想法
''';
  }
  
  static String _getPetTypeText(String type) {
    const types = {
      'cat': '小猫',
      'dog': '小狗',
      'rabbit': '小兔子',
      'hamster': '小仓鼠',
      'guinea_pig': '小豚鼠',
      'chinchilla': '小龙猫',
      'bird': '小鸟',
      'parrot': '小鹦鹉',
      'fish': '小鱼',
      'turtle': '小乌龟',
      'lizard': '小蜥蜴',
      'hedgehog': '小刺猬',
      'ferret': '小雪貂',
      'pig': '小猪猪',
      'other': '小宠物',
    };
    return types[type] ?? '小宠物';
  }
  
  static String _formatTraits(Personality p) {
    if (p.traits.isEmpty) return '一只普通的小宠物';
    return p.traits.join('、') + '的';
  }
  
  // ... 更多辅助方法
}
```

### 5.3 地点和遭遇配置

```dart
class ExplorationData {
  static const Map<String, List<Location>> locations = {
    'cat': [
      Location(name: '社区小花园', type: 'real', description: '有很多花草的社区花园'),
      Location(name: '便利店门口', type: 'real', description: '24小时便利店'),
      Location(name: '咖啡馆', type: 'real', description: '街角的咖啡馆'),
      Location(name: '喵星大使馆', type: 'fictional', description: '喵星人在地球的秘密基地'),
      Location(name: '罐头工厂', type: 'fictional', description: '传说中的美味罐头产地'),
    ],
    'dog': [
      Location(name: '宠物公园', type: 'real', description: '有很多狗狗的公园'),
      Location(name: '海滩', type: 'real', description: '可以玩沙子的海滩'),
      Location(name: '森林步道', type: 'real', description: '有树有草的自然步道'),
      Location(name: '汪汪训练营', type: 'fictional', description: '狗狗们的训练圣地'),
      Location(name: '骨头山', type: 'fictional', description: '堆满骨头的神秘山峰'),
    ],
    // ... 其他宠物类型
  };
  
  static const Map<String, List<Encounter>> encounters = {
    'cat': [
      Encounter(description: '一只橘猫', moodEffect: 'happy'),
      Encounter(description: '飞来飞去的蝴蝶', moodEffect: 'excited'),
      Encounter(description: '凶恶的大狗', moodEffect: 'scared'),
      Encounter(description: '好心的喂食阿姨', moodEffect: 'happy'),
    ],
    'dog': [
      Encounter(description: '其他狗狗', moodEffect: 'happy'),
      Encounter(description: '飞盘', moodEffect: 'excited'),
      Encounter(description: '可爱的小朋友', moodEffect: 'happy'),
      Encounter(description: '洗澡', moodEffect: 'sad'),
    ],
    // ... 其他
  };
}
```

---

## 6. UI/UX 设计

### 6.1 入口：宠物详情页

```
┌─────────────────────────────────────────────┐
│  🐕 球球                    等级 5  ⭐⭐⭐   │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │                                     │   │
│  │           [宠物形象]                │   │
│  │        😊 开心，今天想出去玩         │   │
│  │                                     │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐          │
│  │饥饿 │ │心情 │ │清洁 │ │健康 │          │
│  │ 80% │ │ 75% │ │ 90% │ │100% │          │
│  └─────┘ └─────┘ └─────┘ └─────┘          │
│                                             │
│  ┌───────┐ ┌───────┐ ┌───────┐            │
│  │ 喂食  │ │ 玩耍  │ │ 洗澡  │            │
│  └───────┘ └───────┘ └───────┘            │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ 💬 聊天                    →       │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ 🗺️ 探索世界                →       │   │  ← 新增按钮
│  └─────────────────────────────────────┘   │
│                                             │
│  📖 回忆                    →              │
│                                             │
└─────────────────────────────────────────────┘
```

**探索按钮状态：**
- 正常：显示"🗺️ 探索世界"
- 饱食度不足：显示"🗺️ 饿了，去不了"（灰色禁用）
- 今日次数用完：显示"🗺️ 今天累了"（灰色禁用）

### 6.2 探索页面

```
┌─────────────────────────────────────────────┐
│  ← 球球的探索日记                            │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │         🐕 正在准备出发...           │   │
│  │                                       │   │
│  │   [      探索中动画       ]          │   │
│  │                                       │   │
│  │   "今天天气真好，我想去冒险..."       │   │
│  └─────────────────────────────────────┘   │
│                                             │
└─────────────────────────────────────────────┘
```

**探索中状态：**
- 显示加载动画
- 流式显示 AI 生成的日记内容
- 打字机效果，每生成一段就显示

### 6.3 日记阅读页面

```
┌─────────────────────────────────────────────┐
│  ← 探索日记详情              📤 分享       │
├─────────────────────────────────────────────┤
│                                             │
│  # 球球的探索日记                            │
│  📅 2026年3月17日  星期三                   │
│                                             │
│  ─────────────────────────────────────────  │
│                                             │
│  ## 第一站：社区小花园                       │
│  - **怎么去的**：早上趁主人不注意，从门缝   │
│    偷偷钻出去，一路上摇着尾巴小跑           │
│  - **遇到**：一群在花丛中采蜜的蜜蜂，还     │
│    有一只叫"小灰"的流浪猫                  │
│  - **感受**：春天的花真香呀！但是蜜蜂有     │
│    点可怕，喵了一声就跑开了                  │
│                                             │
│  ─────────────────────────────────────────  │
│                                             │
│  ## 第二站：宠物公园                         │
│  - **怎么去的**：穿过花园，沿着经常遛弯     │
│    的小路走，还遇到了热情的隔壁金毛         │
│  - **遇到**：很多其他狗狗，大家一起追逐     │
│    玩耍，还学到了新游戏"追飞盘"            │
│  - **感受**：太开心了！就是有点累，舌头     │
│    都伸出来了                                │
│                                             │
│  ...                                        │
│                                             │
│  ─────────────────────────────────────────  │
│                                             │
│  ## 回家                                    │
│  夕阳西下，我该回家了。今天遇到了好多新     │
│  朋友，学到了新东西。最想的是主人，不知道   │
│  他有没有担心我。回到家要蹭蹭主人的腿，     │
│  告诉他我今天的故事。                        │
│                                             │
│  ─────────────────────────────────────────  │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  探索花费：-15 饱食度               │   │
│  │  心情变化：+5 心情                   │   │
│  └─────────────────────────────────────┘   │
│                                             │
└─────────────────────────────────────────────┘
```

### 6.4 历史日记列表（回忆页新增 Tab）

```
┌─────────────────────────────────────────────┐
│  📖 我们的回忆                    🗺️ 探索   │
├─────────────────────────────────────────────┤
│                                             │
│  [ 全部 ] [ 对话 ] [ 互动 ] [ 探索日记 ]    │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  🗺️ 2026年3月17日                   │   │
│  │  球球的探索日记 - 8个地点            │   │
│  │  心情：开心    探索类型：普通        │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  🗺️ 2026年3月15日                   │   │
│  │  球球的冒险 - 9个地点               │   │
│  │  心情：兴奋    探索类型：自动        │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  ⭐ 2026年3月14日                   │   │
│  │  第一次升级                          │   │
│  │  "我变得更强了！"                   │   │
│  └─────────────────────────────────────┘   │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 7. 路由设计

```dart
// app.dart 中添加
'/pets/:id/explore'           → 探索生成页（新日记）
'/pets/:id/explore/:diaryId' → 探索日记详情页
```

---

## 8. 实现步骤

### Phase 1：数据库和模型（0.5天）

| 任务 | 工作量 |
|------|--------|
| 创建 pet_exploration_diaries 表 | 0.1 天 |
| 添加 pets 表探索相关字段 | 0.1 天 |
| 创建 ExplorationDiary 模型 | 0.1 天 |
| 创建 ExplorationStop 模型 | 0.1 天 |
| 创建 Repository 基础方法 | 0.1 天 |

### Phase 2：Prompt 构建器（0.5天）

| 任务 | 工作量 |
|------|--------|
| 设计地点配置数据结构 | 0.1 天 |
| 设计遭遇配置数据结构 | 0.1 天 |
| 实现 ExplorationPromptBuilder | 0.2 天 |
| 测试不同宠物的 prompt 输出 | 0.1 天 |

### Phase 3：服务层（0.5天）

| 任务 | 工作量 |
|------|--------|
| 实现 ExplorationService | 0.2 天 |
| 添加探索前置条件检查 | 0.1 天 |
| 实现日记解析逻辑 | 0.1 天 |
| 实现状态更新逻辑 | 0.1 天 |

### Phase 4：UI 实现（1天）

| 任务 | 工作量 |
|------|--------|
| 详情页添加探索入口 | 0.1 天 |
| 探索生成页面（流式） | 0.3 天 |
| 日记阅读页面 | 0.2 天 |
| 历史日记列表 Tab | 0.2 天 |
| 探索按钮状态管理 | 0.2 天 |

### Phase 5：测试和优化（0.5天）

| 任务 | 工作量 |
|------|--------|
| 测试不同宠物的日记生成 | 0.1 天 |
| 优化 prompt 提高质量 | 0.2 天 |
| 处理边界情况 | 0.2 天 |

**总计：约 3 天**

---

## 9. 扩展功能

### 9.1 自动探索（离线奖励）

当用户长时间未打开应用（>24小时），再次打开时自动生成一篇探索日记：

```dart
// 检测是否需要自动探索
Future<void> checkAndGenerateAutoExploration(Pet pet) async {
  final lastExplore = pet.lastExploredAt;
  final now = DateTime.now();
  
  // 超过24小时没探索，且今日还未探索
  if (lastExplore != null && 
      now.difference(lastExplore).inHours > 24 &&
      pet.todayExplorationCount == 0) {
    
    // 随机概率触发（50%）
    if (Random().nextBool()) {
      await generateDiary(pet, explorationType: 'auto');
    }
  }
}
```

### 9.2 特殊探索事件

根据宠物技能或亲密度触发特殊事件：

| 条件 | 特殊事件 |
|------|----------|
| 亲密度 ≥ 4 | 遇到主人的朋友，被夸奖 |
| 有"旅行"技能 | 去了很远的地方冒险 |
| 有"寻宝"技能 | 发现了隐藏的小礼物 |
| 等级 ≥ 10 | 遇到了其他高等级宠物 |

### 9.3 探索相册

将探索日记生成为可分享的图片：

```dart
class ExplorationShareGenerator {
  static Future<ByteData> generateShareImage(ExplorationDiary diary) async {
    // 使用 Canvas 生成分享图片
    // 包含：宠物形象、地点缩略图、心情标签
  }
}
```

---

## 10. 注意事项

### 10.1 Token 优化

- 每次探索约消耗 1500-2500 tokens
- 建议设置 AI 响应限制：max_tokens = 2000

### 10.2 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| AI 生成失败 | 显示"今天有点累，下次再出去吧" |
| 网络超时 | 重试1次，失败则提示 |
| 内容审核失败 | 过滤敏感词，重新生成 |

### 10.3 冷却机制

| 条件 | 冷却 |
|------|------|
| 每次探索 | -15 饱食度 |
| 每日上限 | 3 次 |
| 饱食度要求 | ≥ 20% |
| 心情要求 | ≥ 30% |

---

## 11. 待讨论事项

- [ ] 探索是否需要消耗其他资源？
- [ ] 是否需要"探索装备"系统？（牵引绳、背包等）
- [ ] 自动探索的概率和触发条件
- [ ] 是否需要分享到社交媒体功能？
- [ ] 探索日记是否要支持评论/互动？

---

## 12. 相关文件

| 文件 | 描述 | 状态 |
|------|------|------|
| `lib/data/models/pet.dart` | 宠物模型 | ✅ 已更新（添加探索字段） |
| `lib/data/models/pet_personality.dart` | 性格模型（已存在） | ✅ |
| `lib/data/models/pet_skill.dart` | 技能模型（已存在） | ✅ |
| `lib/data/models/pet_memory.dart` | 记忆模型（已存在） | ✅ |
| `lib/data/models/exploration_diary.dart` | 探索日记模型 | ✅ 已创建 |
| `lib/data/repositories/exploration_repository.dart` | 探索数据仓库 | ✅ 已创建 |
| `lib/core/services/pet_ai_service.dart` | AI 服务（已存在） | ✅ |
| `lib/core/services/prompt_builder.dart` | Prompt 构建器（已存在） | ✅ |
| `lib/core/services/exploration_prompt_builder.dart` | 探索 Prompt | ✅ 已创建 |
| `lib/core/services/exploration_service.dart` | 探索服务 | ✅ 已创建 |
| `lib/features/pets/pages/pet_explore_page.dart` | 探索页 | ✅ 已创建 |
| `lib/features/pets/pages/pet_explore_detail_page.dart` | 日记详情页 | ✅ 已创建 |
| `lib/features/pets/pages/pet_exploration_list_page.dart` | 探索日记列表 | ✅ 已创建 |
| `lib/app.dart` | 路由配置 | ✅ 已更新 |

---

## 13. 数据库迁移

### 迁移脚本

执行 `docs/migrations/012_create_exploration_diaries.sql` 创建：

1. **pet_exploration_diaries 表** - 存储探索日记
2. **pets 表扩展** - 添加探索相关字段：
   - `exploration_count` - 探索总次数
   - `today_exploration_count` - 今日探索次数
   - `last_explored_at` - 上次探索时间
   - `last_exploration_date` - 上次探索日期（用于判断跨天重置）

### 每日重置机制

通过应用层逻辑实现：
- 读取 `last_exploration_date` 与当前日期比较
- 不同则重置 `today_exploration_count` 为 0
