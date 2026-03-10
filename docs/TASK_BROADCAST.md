# 老管家 AI 任务播报功能详解

## 一、功能概述

AI 任务播报是老管家应用的核心功能之一，它允许用户通过语音或文字触发 AI 播报当前家庭的任务列表。AI 会将任务整理成自然流畅的口语化播报，并通过 TTS 语音朗读出来。

### 1.1 功能特点

- **自然语言处理**: 将结构化任务数据转换为自然流畅的口语播报
- **智能提醒**: 包含任务内容、负责人、截止时间等信息
- **语音合成**: 支持中文语音朗读
- **多渠道触发**: 支持快捷按钮、文字输入等多种触发方式

---

## 二、工作流程

### 2.1 完整流程图

```
用户输入文字
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  1. AI Chat 页面检测关键词                              │
│     (_checkTaskBroadcast 方法)                         │
└─────────────────────────────────────────────────────────┘
    │
    ▼ 判断是"播报任务"关键词？
    │  ─────────────────────────────────────
    │  YES                               NO
    │    │                                 │
    │    ▼                                 ▼
    │  2. 触发任务播报               普通 AI 对话
    │     处理逻辑                    流程
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  2. 获取家庭信息和任务列表                              │
│     (HouseholdProvider + TaskRepository)               │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  3. TaskBroadcastService 格式化任务数据                │
│     (格式化成结构化文本)                                │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  4. 构建 AI Prompt (提示词)                             │
│     (让 AI 生成自然语言播报)                            │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  5. 调用 AI 大模型 (智谱AI/Gemini)                     │
│     (生成自然流畅的播报内容)                             │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  6. TTS 语音播放                                        │
│     (Flutter TTS 朗读播报内容)                          │
└─────────────────────────────────────────────────────────┘
```

---

## 三、触发方式

### 3.1 快捷按钮

在 AI 聊天页面底部，点击"播报任务"快捷按钮。

### 3.2 文字输入

输入以下关键词均可触发：

| 关键词 | 说明 |
|--------|------|
| 播报任务 | 最常用的触发词 |
| 任务播报 | 完整描述 |
| 朗读任务 | 强调朗读功能 |
| 读出任务 | 强调读出来 |
| 有哪些任务 | 询问形式 |
| 任务列表 | 列表形式 |
| 今天的任务 | 时间限定 |
| 本周任务 | 时间限定 |
| 报告任务 | 正式用语 |
| 帮我播报当前的任务列表 | 完整命令 |

---

## 四、核心技术实现

### 4.1 文件结构

```
lib/
├── core/
│   ├── services/
│   │   └── task_broadcast_service.dart    # 任务播报核心服务
│   └── utils/
│       └── task_formatter.dart           # 任务格式化工具
├── features/
│   └── ai_chat/
│       └── pages/
│           └── ai_chat_page.dart         # AI 聊天页面（触发逻辑）
└── data/
    └── ai/
        ├── ai_providers.dart             # 状态管理
        └── tts_provider.dart             # 语音合成服务
```

### 4.2 关键词检测

**文件**: `lib/features/ai_chat/pages/ai_chat_page.dart`

```dart
bool _checkTaskBroadcast(String text) {
  final keywords = [
    '播报任务',
    '任务播报',
    '朗读任务',
    '读出任务',
    '有哪些任务',
    '任务列表',
    '今天的任务',
    '本周任务',
    '帮我任务',
    '报告任务',
    '帮我播报当前的任务列表',
  ];

  return keywords.any((keyword) => text.contains(keyword));
}
```

**工作原理**:
1. 用户输入文字后，系统调用 `_checkTaskBroadcast` 方法
2. 方法检查输入是否包含预定义的关键词
3. 如果匹配成功，触发任务播报流程
4. 否则，走普通 AI 对话流程

### 4.3 获取任务数据

**文件**: `lib/core/services/task_broadcast_service.dart`

```dart
Future<String> generateBroadcastText(String householdId, List<Member> members) async {
  // 1. 从数据库获取任务列表
  final tasks = await _taskRepo.getTasks(householdId);

  // 2. 格式化任务数据
  final formattedTasks = _formatTasksForBroadcast(tasks, members);

  // 3. 构建 AI 提示词
  final prompt = _buildBroadcastPrompt(formattedTasks);

  // 4. 调用 AI 生成播报内容
  final result = await _aiService.sendMessage(prompt, []);
  return result;
}
```

### 4.4 任务数据格式化

**任务格式化的目标**: 将数据库中的任务转换为 AI 可理解的结构化文本。

```dart
String _formatTasksForBroadcast(List<Task> tasks, List<Member> members) {
  // 1. 创建成员映射表（id -> name）
  final memberMap = {for (var m in members) m.id: m.name};
  
  // 2. 筛选未完成的任务
  final pendingTasks = tasks.where((t) => !t.isCompleted).toList();

  // 3. 处理无任务情况
  if (pendingTasks.isEmpty) {
    return '当前没有任何待完成的任务';
  }

  // 4. 格式化每个任务
  final buffer = StringBuffer();
  for (int i = 0; i < pendingTasks.length; i++) {
    final task = pendingTasks[i];
    
    // 获取负责人名称
    final assignee = task.assignedTo != null
        ? memberMap[task.assignedTo] ?? '未指定'
        : '未指定';
    
    // 格式化截止时间
    final dueDate = task.dueDate != null
        ? _formatDateTime(task.dueDate!)
        : '未指定';

    buffer.writeln('任务${i + 1}：${task.title}');
    buffer.writeln('  - 负责人：$assignee');
    buffer.writeln('  - 截止时间：$dueDate');
    
    if (task.description != null && task.description!.isNotEmpty) {
      buffer.writeln('  - 说明：${task.description}');
    }
    buffer.writeln('');
  }

  return buffer.toString();
}
```

**格式化结果示例**:

```
任务1：洗碗
  - 负责人：爸爸
  - 截止时间：今天 20:00
  - 说明：用洗洁精清洗

任务2：拖地
  - 负责人：妈妈
  - 截止时间：明天 12:00
```

### 4.5 日期时间格式化

```dart
String _formatDateTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(dt.year, dt.month, dt.day);

  final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  if (due == today) {
    return '今天 $timeStr';
  } else if (due == today.add(const Duration(days: 1))) {
    return '明天 $timeStr';
  } else if (due.isBefore(today)) {
    return '已过期';
  } else {
    return '${dt.month}月${dt.day}日 $timeStr';
  }
}
```

### 4.6 AI Prompt 构建

**Prompt 设计原则**:
1. 角色设定：温暖的家庭助手
2. 输出格式：自然流畅的口语化播报
3. 内容要求：任务内容、负责人、截止时间
4. 语气：亲切、鼓励
5. 特殊情况处理：无任务时的鼓励语气

```dart
String _buildBroadcastPrompt(String formattedTasks) {
  return '''
你是一个温暖的家庭助手。请将以下任务列表转换成自然、流畅的口语化播报。

要求：
1. 开头有友好的问候语
2. 清晰说明每个任务：任务内容、负责人、截止时间
3. 语气亲切，鼓励家庭成员完成任务
4. 如果没有任务，要表现得开心和鼓励
5. 播报长度适中，不要太啰嗦
6. 直接输出播报内容，不要添加格式符号（如星号等）

任务列表：
$formattedTasks

请生成播报内容：
''';
}
```

### 4.7 AI 生成播报示例

**输入** (格式化后的任务列表):
```
任务1：洗碗
  - 负责人：爸爸
  - 截止时间：今天 20:00

任务2：拖地
  - 负责人：妈妈
  - 截止时间：明天 12:00
```

**AI 输出** (自然语言播报):
> "亲爱的家人们，早上好呀！今天我们有 2 个任务需要完成哦～
> 
> 第一个任务是洗碗，由爸爸负责，截止时间是今天晚上八点。爸爸加油💪
> 
> 第二个任务是拖地，由妈妈负责，截止时间是明天中午十二点。妈妈也加油💪
> 
> 大家辛苦了，完成任务后就可以休息啦！有什么需要帮忙的随时说～"

### 4.8 TTS 语音播放

**文件**: `lib/data/ai/tts_provider.dart`

```dart
Future<void> speak(String text) async {
  try {
    _lastError = null;
    await stop();
    await _flutterTts.speak(text);  // 语音播放
  } catch (e) {
    _lastError = e.toString();
    state = TTSState.stopped;
  }
}
```

**TTS 配置**:
- 语言：zh-CN（中文）
- 语速：0.5（中等速度）
- 音量：1.0（最大音量）
- 音调：1.0（正常音调）

---

## 五、数据模型

### 5.1 Task 模型

```dart
class Task {
  final String id;
  final String householdId;
  final String title;              // 任务标题
  final String? description;        // 任务描述
  final String? assignedTo;         // 负责人（成员ID）
  final DateTime? dueDate;          // 截止时间
  final TaskRecurrence recurrence;  // 重复类型
  final TaskStatus status;          // 任务状态
  final String createdBy;
  final DateTime createdAt;
}
```

### 5.2 Member 模型

```dart
class Member {
  final String id;
  final String householdId;
  final String name;                // 成员名称
  final MemberRole role;            // 角色（admin/member）
}
```

---

## 六、播报任务处理逻辑

**文件**: `lib/features/ai_chat/pages/ai_chat_page.dart`

```dart
Future<void> _handleTaskBroadcast() async {
  // 1. 获取家庭信息
  final householdState = ref.read(householdProvider);
  final householdId = householdState.currentHousehold?.id;

  // 2. 检查是否加入家庭
  if (householdId == null) {
    _addErrorMessage('请先加入一个家庭');
    return;
  }

  // 3. 添加用户消息到聊天列表
  _addUserMessage('帮我播报当前的任务列表');

  try {
    // 4. 创建播报服务
    final aiService = ref.read(aiServiceProvider);
    final broadcastService = TaskBroadcastService(aiService);

    // 5. 获取成员信息
    final members = householdState.members;

    // 6. 生成播报内容
    final broadcastText = await broadcastService.generateBroadcastText(
      householdId, 
      members,
    );

    // 7. 添加 AI 消息到聊天列表
    ref.read(chatProvider.notifier).addAiMessage(broadcastText);

    // 8. 延迟一下确保 TTS 初始化完成
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 9. 语音播放
    final ttsNotifier = ref.read(ttsProvider.notifier);
    await ttsNotifier.speak(broadcastText);
  } catch (e) {
    _addErrorMessage('任务播报失败: ${e.toString()}');
  }
}
```

---

## 七、异常处理

### 7.1 未加入家庭

```
用户输入："播报任务"
系统检测：未加入家庭
处理：显示提示"请先加入一个家庭"
```

### 7.2 无任务

```
AI 收到任务列表："当前没有任何待完成的任务"
AI 输出："太棒了！所有任务都已完成！大家辛苦啦，今天可以好好休息～"
```

### 7.3 网络错误

```
网络请求失败
处理：显示错误提示"任务播报失败: 网络连接失败"
```

### 7.4 TTS 失败

```
TTS 引擎不可用
处理：只显示文字播报内容，不播放语音
```

---

## 八、版本记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.7 | 2026-03-10 | 初始版本，支持任务播报功能 |

---

## 九、相关文件索引

| 文件路径 | 说明 |
|---------|------|
| `lib/core/services/task_broadcast_service.dart` | 任务播报核心服务 |
| `lib/core/utils/task_formatter.dart` | 任务格式化工具 |
| `lib/features/ai_chat/pages/ai_chat_page.dart` | AI 聊天页面 |
| `lib/data/ai/ai_providers.dart` | 状态管理 |
| `lib/data/ai/tts_provider.dart` | 语音合成服务 |
| `lib/data/ai/ai_service.dart` | AI 调用服务 |
| `lib/data/models/task.dart` | 任务数据模型 |
| `lib/data/models/member.dart` | 成员数据模型 |
