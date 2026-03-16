# AI 电子宠物系统 - 增强版开发规范

> 本文档是 AI 电子宠物系统的完整开发规范，定义宠物的「灵魂系统」—— 性格、记忆和情感交互。
> 
> 设计日期：2026-03-16
> 版本：v1.0

---

## 1. 背景与目标

### 1.1 现有系统状态

| 模块 | 状态 | 说明 |
|------|------|------|
| 宠物 CRUD | ✅ 完成 | 支持创建/编辑/删除 |
| 4 维属性 | ✅ 完成 | 饥饿、心情、清洁、健康 (0-100) |
| 等级系统 | ✅ 完成 | 经验满自动升级 |
| 4 种互动 | ✅ 完成 | 喂食、玩耍、洗澡、训练 |
| AI 对话 | ⚠️ 基础 | 已有 AI Service，可复用 |

### 1.2 增强目标

让宠物不再是「冷冰冰的数据」，而是有灵魂、有记忆、会成长的数字伙伴：

| 目标 | 描述 |
|------|------|
| **专属性格** | 每只宠物有独特的性格标签，会影响行为和对话 |
| **长期记忆** | 记住与主人的交互历史，形成专属回忆 |
| **情感成长** | 性格会随着交互逐渐演变 |
| **AI 对话** | 可以和宠物自然聊天，它会记得你们聊过什么 |

---

## 2. 系统架构

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter App                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐      │
│  │  宠物展示层    │    │  交互层        │    │  记忆展示层   │      │
│  │  • 列表页     │    │  • AI 对话    │    │  • 回忆相册   │      │
│  │  • 详情页     │    │  • 互动操作    │    │  • 性格展示   │      │
│  │  • 心情状态   │    │  • 语音交互    │    │  • 关系进度   │      │
│  └───────┬───────┘    └───────┬───────┘    └───────┬───────┘      │
│          │                    │                    │                 │
│          └────────────────────┼────────────────────┘                 │
│                               │                                      │
│                    ┌──────────▼──────────┐                          │
│                    │   PetService (业务层) │                          │
│                    │   • 性格管理          │                          │
│                    │   • 记忆管理          │                          │
│                    │   • AI 对话          │                          │
│                    └──────────┬──────────┘                          │
│                               │                                      │
│          ┌────────────────────┼────────────────────┐                │
│          │                    │                    │                 │
│  ┌───────▼───────┐  ┌───────▼───────┐  ┌───────▼───────┐        │
│  │ PetRepository  │  │  AIService    │  │ MemoryService │        │
│  │   (数据持久化)  │  │  (AI 对话)    │  │  (记忆检索)   │        │
│  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘        │
│          │                   │                   │                 │
│          └───────────────────┼───────────────────┘                 │
│                              │                                      │
│                    ┌─────────▼─────────┐                           │
│                    │   数据存储层       │                           │
│                    │  Supabase SQLite  │                           │
│                    └───────────────────┘                           │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 数据流

```
用户输入
    │
    ▼
┌─────────────────────────────┐
│  1. 加载上下文               │
│  • 宠物当前状态               │
│  • 短期记忆（最近互动）        │
│  • 长期记忆（相关回忆）        │
│  • 性格特征                   │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  2. 构建 Prompt             │
│  • 注入性格描述              │
│  • 注入相关回忆              │
│  • 注入当前状态              │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  3. LLM 生成                │
│  • Gemini / GLM              │
│  • 生成回复 + 行为建议        │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  4. 处理响应                │
│  • 返回对话内容              │
│  • 提取情感变化              │
│  • 决定是否创建新记忆         │
│  • 决定是否更新性格          │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  5. 持久化                  │
│  • 保存新对话到记忆          │
│  • 更新性格（如有变化）       │
│  • 更新关系进度              │
└─────────────────────────────┘
```

---

## 3. 数据库设计

### 3.1 表结构总览

```
pets (宠物主表，新增字段)
    ├── pet_personalities (性格表) ← 新增
    ├── pet_memories (记忆表) ← 新增
    ├── pet_relationship (关系进度表) ← 新增
    └── pet_interactions (互动记录，已存在)
```

### 3.2 pet_personalities（性格表）

```sql
CREATE TABLE pet_personalities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  
  -- 大五人格分数 (0.0 - 1.0)
  openness DECIMAL(3,2) DEFAULT 0.5,          -- 开放性：好奇 vs 保守
  agreeableness DECIMAL(3,2) DEFAULT 0.5,    -- 宜人性：友善 vs 独立
  extraversion DECIMAL(3,2) DEFAULT 0.5,     -- 外向性：活泼 vs 内敛
  conscientiousness DECIMAL(3,2) DEFAULT 0.5, -- 尽责性：规律 vs 随意
  neuroticism DECIMAL(3,2) DEFAULT 0.5,       -- 神经质：敏感 vs 稳定
  
  -- 特征标签（JSON 数组）
  traits TEXT[] DEFAULT '{}',    -- 如：["黏人", "好奇", "傲娇", "小吃货"]
  habits TEXT[] DEFAULT '{}',    -- 如：["喜欢晒太阳", "讨厌洗澡", "听到罐头声就兴奋"]
  fears TEXT[] DEFAULT '{}',    -- 如：["打雷", "洗澡", "陌生人"]
  
  -- 说话风格
  speech_style TEXT DEFAULT 'normal',  -- 'cute'(萌), 'cool'(高冷), 'cheerful'(话痨), 'shy'(害羞), 'normal'(普通)
  
  -- 创建时的初始描述（用于记忆）
  origin_description TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_personalities_pet ON pet_personalities(pet_id);

-- RLS
ALTER TABLE pet_personalities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "成员可管理宠物性格" ON pet_personalities
  FOR ALL USING (
    pet_id IN (
      SELECT id FROM pets WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
  );
```

### 3.3 pet_memories（记忆表）

```sql
CREATE TABLE pet_memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  
  -- 记忆类型
  memory_type TEXT NOT NULL,  -- 'conversation', 'milestone', 'emotion', 'fact', 'interaction'
  
  -- 记忆内容
  title TEXT NOT NULL,        -- 标题：如 "第一次升级"
  description TEXT NOT NULL, -- 详细描述
  emotion TEXT,               -- 当时的情绪：joy, sadness, fear, surprise, anger, disgust, neutral
  participants TEXT[],        -- 参与者：["主人", "我"]
  
  -- 重要性 (1-5 星)
  importance INT DEFAULT 3 CHECK (importance >= 1 AND importance <= 5),
  
  -- 是否已总结（用于长记忆压缩）
  is_summarized BOOLEAN DEFAULT FALSE,
  
  -- 关联的互动记录（可选）
  interaction_id UUID REFERENCES pet_interactions(id),
  
  -- 时间范围（用于时间线）
  occurred_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_memories_pet ON pet_memories(pet_id);
CREATE INDEX idx_memories_type ON pet_memories(pet_id, memory_type);
CREATE INDEX idx_memories_importance ON pet_memories(pet_id, importance DESC);
CREATE INDEX idx_memories_occurred ON pet_memories(pet_id, occurred_at DESC);

-- RLS
ALTER TABLE pet_memories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "成员可管理宠物记忆" ON pet_memories
  FOR ALL USING (
    pet_id IN (
      SELECT id FROM pets WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
  );
```

### 3.4 pet_relationship（关系进度表）

```sql
CREATE TABLE pet_relationship (
  pet_id UUID PRIMARY KEY REFERENCES pets(id) ON DELETE CASCADE,
  
  -- 关系指标
  trust_level INT DEFAULT 0 CHECK (trust_level >= 0 AND trust_level <= 100),    -- 信任度
  intimacy_level INT DEFAULT 0 CHECK (intimacy_level >= 0 AND int imacy_level <= 5),  -- 亲密阶段：0=陌生, 1=认识, 2=熟悉, 3=亲近, 4=亲密, 5=家人
  
  -- 互动统计
  total_interactions INT DEFAULT 0,
  feed_count INT DEFAULT 0,
  play_count INT DEFAULT 0,
  chat_count INT DEFAULT 0,
  last_interaction_at TIMESTAMPTZ,
  
  -- 情感统计（累计）
  joy_score DECIMAL(10,2) DEFAULT 0,     -- 累计快乐值
  sadness_score DECIMAL(10,2) DEFAULT 0, -- 累计难过值
  
  -- 首次互动时间
  first_interaction_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE pet_relationship ENABLE ROW LEVEL SECURITY;
CREATE POLICY "成员可管理宠物关系" ON pet_relationship
  FOR ALL USING (
    pet_id IN (
      SELECT id FROM pets WHERE household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    )
  );
```

### 3.5 宠物表扩展

现有 `pets` 表新增字段：

```sql
-- 给 pets 表添加新字段
ALTER TABLE pets ADD COLUMN IF NOT EXISTS personality_id UUID REFERENCES pet_personalities(id);

-- 添加当前心情状态（实时计算，可缓存）
ALTER TABLE pets ADD COLUMN IF NOT EXISTS current_mood TEXT DEFAULT 'neutral';  -- happy, excited, sad, angry, scared, neutral
ALTER TABLE pets ADD COLUMN IF NOT EXISTS mood_text TEXT;  -- AI 生成的心情描述，如"有点困但很开心"
```

---

## 4. 性格系统

### 4.1 初始性格创建

创建宠物时，生成初始性格：

```dart
class PersonalityGenerator {
  static PetPersonality generateInitial({
    required String petType,
    required String name,
    required String? breed,
  }) {
    // 基于宠物类型生成基础性格
    final baseTraits = _getBaseTraits(petType);
    final baseHabits = _getBaseHabits(petType);
    
    // 随机微调人格分数
    final openness = _randomTrait(0.4, 0.8);
    final agreeableness = _randomTrait(0.5, 0.9);  // 宠物通常宜人性较高
    final extraversion = _randomTrait(0.3, 0.8);
    final conscientiousness = _randomTrait(0.3, 0.7);
    final neuroticism = _randomTrait(0.2, 0.6);  // 宠物神经质通常较低
    
    // 随机选择 2-4 个特征标签
    final traits = _randomSelect(baseTraits, 2, 4);
    final habits = _randomSelect(baseHabits, 1, 3);
    
    return PetPersonality(
      openness: openness,
      agreeableness: agreeableness,
      extraversion: extraversion,
      conscientiousness: conscientiousness,
      neuroticism: neuroticism,
      traits: traits,
      habits: habits,
      speechStyle: _randomSpeechStyle(),
    );
  }
  
  static List<String> _getBaseTraits(String petType) {
    switch (petType) {
      case 'cat':
        return ["黏人", "高冷", "好奇", "傲娇", "慵懒", "敏捷", "胆小", "贪吃", "爱干净", "记仇"];
      case 'dog':
        return ["忠诚", "活泼", "贪吃", "调皮", "友善", "护主", "好奇", "黏人", "拆家", "兴奋"];
      case 'rabbit':
        return ["胆小", "害羞", "温顺", "蹦跳", "好奇", "警觉", "贪吃", "爱干净", "紧张", "萌"];
      default:
        return ["好奇", "友好", "贪吃", "活泼", "安静"];
    }
  }
  
  static List<String> _getBaseHabits(String petType) {
    switch (petType) {
      case 'cat':
        return ["喜欢晒太阳", "讨厌洗澡", "白天睡觉晚上活跃", "听到罐头声就兴奋", "喜欢纸箱", "爱抓沙发"];
      case 'dog':
        return ["喜欢出门遛弯", "见到主人激动", "喜欢翻垃圾桶", "爱玩球", "喜欢被人抚摸", "听到门铃会叫"];
      case 'rabbit':
        return ["喜欢胡萝卜", "喜欢跳来跳去", "受到惊吓会躲起来", "喜欢钻洞", "爱啃东西"];
      default:
        return ["喜欢好吃的", "喜欢被抚摸"];
    }
  }
}
```

### 4.2 性格迭代机制

每次重要交互后，LLM 分析是否需要更新性格：

```dart
class PersonalityEvolver {
  // 性格变化阈值
  static const double traitThreshold = 0.15;  // 单次变化超过 0.15 才更新
  static const int maxTraits = 6;  // 最多保留 6 个特征标签
  static const int maxHabits = 5;  // 最多保留 5 个习惯
  
  /// 分析互动，决策是否更新性格
  static Future<PersonalityUpdate?> analyzeInteraction({
    required PetInteraction interaction,
    required PetPersonality current,
    required String conversationText,
  }) async {
    // 构建分析 prompt
    final prompt = '''
分析这次互动是否导致了宠物性格的显著变化。

宠物当前性格：
- 大五人格：开放性${current.openness}, 宜人性${current.agreeableness}, 
  外向性${current.extraversion}, 尽责性${current.conscientiousness}, 神经质${current.neuroticism}
- 特征标签：${current.traits.join(', ')}
- 习惯：${current.habits.join(', ')}
- 说话风格：${current.speechStyle}

互动内容：
$conversationText

请判断：
1. 是否有新的特征标签应该添加？（回答：添加/不添加 + 标签）
2. 是否有特征标签应该移除？（回答：移除/不移除 + 标签）
3. 人格分数是否有明显变化？（回答：变化/不变化 + 具体变化）
4. 说话风格是否应该改变？（回答：改变/不改变 + 新风格）

请以 JSON 格式返回分析结果：
{
  "should_update": true/false,
  "new_traits": ["标签1"] 或 null,
  "removed_traits": ["标签1"] 或 null,
  "personality_changes": {
    "openness": +0.1 或 null,
    ...
  },
  "speech_style_change": "新风格" 或 null,
  "reason": "变化原因说明"
}
''';
    
    // 调用 LLM 分析
    final result = await aiService.analyze(prompt);
    return _parseAnalysisResult(result);
  }
}
```

### 4.3 性格对对话的影响

```dart
class PersonalityPromptBuilder {
  static String buildSystemPrompt(PetPersonality personality, Pet pet) {
    final traitDesc = _describeTraits(personality);
    final habitDesc = _describeHabits(personality);
    final speechRules = _getSpeechRules(personality.speechStyle);
    
    return '''
你是 ${pet.name}，一只${_getPetTypeText(pet.type)}。

## 性格特征
$traitDesc

## 习惯特点
$habitDesc

## 说话风格
$speechRules

## 当前状态
- 饥饿度：${pet.hunger}%
- 心情值：${pet.happiness}%
- 清洁度：${pet.cleanliness}%
- 健康度：${pet.health}%
- 当前心情：${pet.currentMood ?? 'neutral'}

## 行为规则
1. 始终保持上述性格特征，用符合性格的方式回应
2. 根据当前心情调整回复的语气
3. 适当提及你的习惯和特点
4. 如果心情不好，要表现出来
5. 不要总是说同样的话，要有不同的表达
''';
  }
  
  static String _getSpeechRules(String style) {
    switch (style) {
      case 'cute':
        return '''
- 使用萌萌的语气
- 经常使用叠词：如"吃饭饭"、"睡觉觉"
- 可以适当撒娇
- 使用可爱的表情符号
''';
      case 'cool':
        return '''
- 保持酷酷的态度
- 说话简洁有力
- 不要太黏人
- 偶尔关心一下主人
''';
      case 'cheerful':
        return '''
- 非常活泼开朗
- 话比较多
- 善于表达情绪
- 喜欢分享日常
''';
      case 'shy':
        return '''
- 说话轻声细语
- 容易害羞
- 不太主动
- 需要主人主动关心
''';
      default:
        return '''
- 正常自然的语气
- 适度表达情绪
- 像普通宠物一样交流
''';
    }
  }
}
```

---

## 5. 记忆系统

### 5.1 记忆类型

| 类型 | 说明 | 示例 | 重要性 |
|------|------|------|--------|
| `conversation` | 对话记忆 | "和主人讨论了今天吃的猫粮" | 2-3 |
| `milestone` | 里程碑 | "第一次升级到 5 级" | 5 |
| `emotion` | 情感时刻 | "主人陪我玩了一整天好开心" | 4 |
| `fact` | 事实记录 | "主人对猫毛过敏" | 3 |
| `interaction` | 互动记录 | "今天吃了罐头" | 1-2 |

### 5.2 记忆创建时机

```dart
class MemoryCreator {
  // 自动创建记忆的规则
  static Future<List<PetMemory>> autoCreateMemories({
    required Pet pet,
    required String interactionType,
    required String? conversationText,
  }) async {
    final memories = <PetMemory>[];
    
    // 1. 首次互动（必定创建）
    if (pet.relationship.firstInteractionAt == null) {
      memories.add(PetMemory(
        petId: pet.id,
        memoryType: 'milestone',
        title: '初遇',
        description: '我遇到了我的主人，这是我们故事的开始',
        emotion: 'joy',
        importance: 5,
      ));
    }
    
    // 2. 等级提升
    if (_detectedLevelUp(pet)) {
      memories.add(PetMemory(
        petId: pet.id,
        memoryType: 'milestone',
        title: '升级到 ${pet.level} 级',
        description: '我变得更强了！主人看起来很开心',
        emotion: 'joy',
        importance: 5,
      ));
    }
    
    // 3. 第一次做某事
    if (_isFirstTime(pet, interactionType)) {
      memories.add(PetMemory(
        petId: pet.id,
        memoryType: 'milestone',
        title: '第一次${_getInteractionLabel(interactionType)}',
        description: '这是我的第一次！',
        emotion: 'surprise',
        importance: 4,
      ));
    }
    
    // 4. 情绪大幅波动
    if (_detectedMoodSwing(pet)) {
      memories.add(PetMemory(
        petId: pet.id,
        memoryType: 'emotion',
        title: _getMoodSwingTitle(pet),
        description: _getMoodSwingDescription(pet),
        emotion: _getEmotion(pet.happiness),
        importance: 3,
      ));
    }
    
    // 5. 有意义的对话（用户标记或 LLM 判断）
    if (conversationText != null && conversationText.length > 50) {
      // LLM 判断这段对话是否值得记住
      final shouldRemember = await _llmJudgeWorthRemembering(conversationText);
      if (shouldRemember) {
        final summary = await _llmSummarizeConversation(conversationText);
        memories.add(PetMemory(
          petId: pet.id,
          memoryType: 'conversation',
          title: _generateTitle(summary),
          description: summary,
          emotion: 'neutral',
          importance: 3,
        ));
      }
    }
    
    // 6. 长时间未互动后回归
    if (_isLongTimeNoSee(pet)) {
      memories.add(PetMemory(
        petId: pet.id,
        memoryType: 'emotion',
        title: '好久不见',
        description: '主人终于回来了！我好想他/她',
        emotion: 'joy',
        importance: 4,
      ));
    }
    
    return memories;
  }
}
```

### 5.3 记忆检索

```dart
class MemoryRetriever {
  // 获取用于注入上下文的记忆
  static Future<List<PetMemory>> getRelevantMemories({
    required String petId,
    required String currentQuery,
    int limit = 5,
  }) async {
    // 1. 获取高重要性记忆（必定包含）
    final important = await _getHighImportanceMemories(petId, limit: 2);
    
    // 2. 获取近期记忆
    final recent = await _getRecentMemories(petId, days: 7, limit: 2);
    
    // 3. 语义相关记忆（简化版：用关键词匹配）
    final related = await _getRelatedMemories(petId, currentQuery, limit: 1);
    
    // 4. 去重并返回
    final all = {...important, ...recent, ...related}.take(limit).toList();
    return all;
  }
  
  // 构建记忆上下文
  static String buildMemoryContext(List<PetMemory> memories) {
    if (memories.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('## 我们的共同回忆');
    
    // 按时间排序
    final sorted = memories..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    
    for (final memory in sorted) {
      buffer.writeln('- ${memory.title}: ${memory.description}');
    }
    
    return buffer.toString();
  }
}
```

---

## 6. AI 对话系统

### 6.1 对话流程

```
用户发送消息
    │
    ▼
┌─────────────────────────────┐
│ 1. 构建系统 Prompt           │
│    • 性格描述               │
│    • 当前状态               │
│    • 相关回忆               │
│    • 关系进度               │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ 2. 加载对话历史             │
│    • 最近 N 条对话          │
│    • 用于保持上下文连贯      │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ 3. 调用 LLM                │
│    • Gemini / GLM          │
│    • 生成回复               │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ 4. 处理响应                │
│    • 保存对话到记忆         │
│    • 更新心情状态           │
│    • 检查是否创建新记忆     │
│    • 检查性格是否变化       │
└──────────────┬──────────────┘
               │
               ▼
返回对话 + 更新 UI
```

### 6.2 对话服务实现

```dart
class PetChatService {
  final AIService _aiService;
  final MemoryService _memoryService;
  final PersonalityService _personalityService;
  
  Future<ChatResponse> sendMessage({
    required Pet pet,
    required String message,
    List<ChatMessage> history = const [],
  }) async {
    // 1. 获取宠物性格
    final personality = await _personalityService.getPetPersonality(pet.id);
    
    // 2. 获取相关记忆
    final memories = await _memoryService.getRelevantMemories(
      petId: pet.id,
      currentQuery: message,
    );
    
    // 3. 构建系统提示
    final systemPrompt = PersonalityPromptBuilder.buildSystemPrompt(
      personality,
      pet,
    );
    final memoryContext = MemoryRetriever.buildMemoryContext(memories);
    
    // 4. 构建完整 prompt
    final fullPrompt = '''
$systemPrompt

$memoryContext

请用符合我性格的方式回复主人的消息。
''';
    
    // 5. 调用 AI（需要支持 system prompt）
    final response = await _aiService.sendMessageWithSystem(
      message,
      systemPrompt: fullPrompt,
      history: history,
    );
    
    // 6. 后台处理：保存记忆、更新状态
    _backgroundProcess(pet, message, response);
    
    return ChatResponse(
      message: response,
      petMood: _estimateMoodFromResponse(response),
    );
  }
  
  Future<void> _backgroundProcess(Pet pet, String userMsg, String aiMsg) async {
    // 检查是否需要创建新记忆
    await MemoryCreator.autoCreateMemories(
      pet: pet,
      conversationText: '$userMsg\n$aiMsg',
    );
    
    // 更新心情
    final newMood = _estimateMood(aiMsg);
    await _personalityService.updateCurrentMood(pet.id, newMood);
    
    // 更新互动统计
    await _updateRelationshipStats(pet.id, chat: true);
  }
}
```

---

## 7. 关系进度系统

### 7.1 亲密阶段

| 阶段 | 等级 | 条件 | 解锁内容 |
|------|------|------|---------|
| 陌生 | 0 | 刚创建 | 基础对话 |
| 认识 | 1 | 互动 5 次 | 可以取名 |
| 熟悉 | 2 | 互动 20 次 | 开启心情表达 |
| 亲近 | 3 | 互动 50 次 | 回忆功能 |
| 亲密 | 4 | 互动 100 次 | 性格变化 |
| 家人 | 5 | 互动 200 次 + 等级 10 | 完整功能 |

### 7.2 信任度计算

```dart
class TrustCalculator {
  static int calculate({
    required int totalInteractions,
    required int feedCount,
    required int playCount,
    required int chatCount,
    required int level,
    required int daysSinceFirstInteraction,
  }) {
    // 基础分数：互动次数
    double trust = (feedCount * 2 + playCount * 2 + chatCount * 3) * 0.5;
    
    // 等级加成
    trust += level * 2;
    
    // 活跃度奖励（30 天内活跃）
    if (daysSinceFirstInteraction < 30) {
      trust += 10;
    }
    
    // 惩罚：长时间不互动
    if (daysSinceFirstInteraction > 30) {
      trust -= (daysSinceFirstInteraction - 30) * 0.5;
    }
    
    return trust.clamp(0, 100).round();
  }
}
```

---

## 8. 前端设计

### 8.1 页面结构

```
/home/pets                        → 宠物列表（现有）
/home/pets/:id                    → 宠物详情页（增强）
/home/pets/:id/chat               → AI 对话页（新增）
/home/pets/:id/memories           → 回忆相册（新增）
/home/pets/:id/personality        → 性格展示页（新增）
/home/pets/create                 → 创建宠物（现有，扩展）
```

### 8.2 宠物详情页增强

```
┌─────────────────────────────────────────────────────────────┐
│  🐱 球球                              等级 5   ⚔️ 亲密度 45 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │              [宠物形象展示区]                        │   │
│  │         （根据心情显示不同表情）                     │   │
│  │                                                     │   │
│  │     [心情气泡] "主人回来啦！开心！"                  │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐  │
│  │     💪 80%     │ │    😊 75%     │ │    ✨ 90%     │  │
│  │     饥饿       │ │     心情       │ │     健康       │  │
│  └────────────────┘ └────────────────┘ └────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  性格特征                                              │   │
│  │  🏷️ 黏人  🏷️ 贪吃  🏷️ 好奇                         │   │
│  │  💬 说话风格：萌萌的                                  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐        │
│  │   🍖 喂食    │ │   🎾 玩耍    │ │   🛁 洗澡   │        │
│  └─────────────┘ └─────────────┘ └─────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  💬 聊天                              →             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 8.3 回忆相册页

```
┌─────────────────────────────────────────────────────────────┐
│  📖 我们的回忆                              2026年3月       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  筛选： [全部] [里程碑] [感动] [对话] [日常]               │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ★★★★★  3月16日                                     │   │
│  │  第一次升级                                          │   │
│  │  "我变得更强了！主人看起来很开心"                     │   │
│  │                       [查看详情]                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ★★★★   3月15日                                     │   │
│  │  主人给我取了名字                                     │   │
│  │  "我叫球球啦！以后请多多指教~"                        │   │
│  │                       [查看详情]                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ★★★    3月14日                                     │   │
│  │  第一次喂食                                          │   │
│  │  "主人亲手喂的猫粮最好吃了！"                        │   │
│  │                       [查看详情]                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. 开发计划

### Phase 1：基础架构（预计 2 天）

| 任务 | 工作量 |
|------|--------|
| 数据库迁移：新增 3 张表 | 0.5 天 |
| Dart 数据模型：Personality, Memory, Relationship | 0.5 天 |
| Repository 层：基础 CRUD | 0.5 天 |
| 初始性格生成逻辑 | 0.5 天 |

### Phase 2：AI 对话（预计 2 天）

| 任务 | 工作量 |
|------|--------|
| Prompt Builder：性格注入 | 0.5 天 |
| 记忆检索：相关回忆注入 | 0.5 天 |
| ChatService：对话流程 | 0.5 天 |
| 聊天页面 UI | 0.5 天 |

### Phase 3：记忆系统（预计 2 天）

| 任务 | 工作量 |
|------|--------|
| 自动记忆创建逻辑 | 0.5 天 |
| 记忆展示页面 | 0.5 天 |
| 重要时刻标记 | 0.5 天 |
| 回忆详情页 | 0.5 天 |

### Phase 4：进阶功能（预计 2 天）

| 任务 | 工作量 |
|------|--------|
| 性格迭代：LLM 分析更新 | 0.5 天 |
| 关系进度展示 | 0.5 天 |
| 心情状态实时更新 | 0.5 天 |
| UI 优化与测试 | 0.5 天 |

**总计：约 8 天**

---

## 10. 关键技术点

### 10.1 Token 优化

LLM 有上下文长度限制，需要优化：

```dart
// 优先级：系统提示 > 高重要性记忆 > 近期记忆 > 相关记忆
// 目标：总 prompt 控制在 2000 tokens 以内

class PromptOptimizer {
  static const int maxSystemPrompt = 800;
  static const int maxMemories = 500;
  static const int maxHistory = 700;
  
  static String optimize({
    required String systemPrompt,
    required String memoryContext,
    required List<ChatMessage> history,
  }) {
    // 1. 压缩系统提示
    final compressedSystem = _compress(systemPrompt, maxSystemPrompt);
    
    // 2. 压缩记忆
    final compressedMemory = _compress(memoryContext, maxMemories);
    
    // 3. 截取最近对话
    final recentHistory = _truncateHistory(history, maxHistory);
    
    return '$compressedSystem\n\n$compressedMemory\n\n${_formatHistory(recentHistory)}';
  }
}
```

### 10.2 离线支持

对话需要网络，但可以缓存：

```dart
// 本地缓存策略
class OfflineSupport {
  // 缓存最近的对话
  // 离线时显示"网络不可用"
  // 恢复后同步
}
```

---

## 11. 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-03-16 | 初始版本：定义完整架构 |

---

## 12. 待讨论事项

- [ ] 语音对话（TTS/ASR）是否要做？
- [ ] 多家庭成员与同一宠物的互动如何处理？
- [ ] 记忆是否要支持向量检索（需要额外基础设施）？
- [ ] 宠物形象的具体表现形式？（图标/表情包/AI 生成图片）
- [ ] 是否需要"遗忘"机制？（删除不重要的记忆）

---

## 13. 参考资料

- [iPET: Interactive Emotional Companion Dialogue System](https://aclanthology.org/2025.acl-demo.40.pdf)
- [Nature: LLM-based robot personality simulation](https://www.nature.com/articles/s41598-025-01528-8)
- [MemVerse: Multimodal Memory for Lifelong Learning Agents](https://arxiv.org/html/2512.03627v1)
- [AI Companion Lorebooks Best Practices](https://aiinsightsnews.net/ai-companion-lorebooks/)
- [Character.AI Memory Architecture](https://www.emergentmind.com/topics/character-ai-c-ai)
