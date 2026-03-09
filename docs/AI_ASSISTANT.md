# 老管家 AI 助手开发文档

## 一、项目概述

### 1.1 目标
为"老管家"家庭管理应用添加 AI 能力，使其能够：
- 与用户聊天，解答问题
- 播报天气、新闻等信息
- 记住家庭成员的纪念日、生日等重要日期
- 将 AI 返回的文字用语音朗读出来

### 1.2 技术栈
- **前端**: Flutter + Riverpod
- **后端**: Supabase
- **AI**: Google Gemini / 智谱AI (GLM)
- **TTS**: flutter_tts

---

## 二、已实现功能

### 2.1 AI 聊天
- [x] 多模型支持 (Gemini + 智谱AI)
- [x] 用户自行配置 API Key
- [x] API Key 安全存储 (flutter_secure_storage)
- [x] 对话历史管理
- [x] 流式响应 UI

### 2.2 语音合成 (TTS)
- [x] 中文语音朗读
- [x] 朗读/停止控制
- [x] 语速调节

### 2.3 设置页面
- [x] AI 提供商选择
- [x] 模型选择
- [x] API Key 配置 + 测试
- [x] 设置保存

---

## 三、文件结构

```
lib/
├── data/
│   ├── ai/
│   │   ├── ai_models.dart          # 数据模型定义
│   │   ├── ai_settings_service.dart # API Key 存储服务
│   │   ├── ai_service.dart         # AI 核心服务
│   │   ├── ai_providers.dart       # Riverpod 状态管理
│   │   └── tts_provider.dart       # 语音合成服务
│   └── ...
├── features/
│   ├── ai_chat/
│   │   └── pages/
│   │       └── ai_chat_page.dart   # AI 聊天页面
│   ├── settings/
│   │   └── pages/
│   │       └── ai_settings_page.dart # AI 设置页面
│   └── ...
└── app.dart                         # 路由配置
```

---

## 四、核心模块详解

### 4.1 AI 模型定义

**文件**: `lib/data/ai/ai_models.dart`

```dart
enum AIProvider {
  gemini('Google Gemini', 'https://generativelanguage.googleapis.com'),
  zhipu('智谱AI', 'https://open.bigmodel.cn');
}

class AIModel {
  final String id;
  final String name;
  final AIProvider provider;
  final String description;
}
```

### 4.2 API Key 存储

**文件**: `lib/data/ai/ai_settings_service.dart`

- 使用 `flutter_secure_storage` 加密存储
- 支持多 provider 的 API Key 切换
- 提供 Key 测试功能

### 4.3 AI 服务层

**文件**: `lib/data/ai/ai_service.dart`

```dart
class AIService {
  // 统一入口
  Future<String> sendMessage(String message, List<ChatMessage> history);
  
  // 各 provider 调用
  Future<String> _callGemini(...);
  Future<String> _callZhipu(...);
}
```

### 4.4 状态管理

**文件**: `lib/data/ai/ai_providers.dart`

```dart
// Provider 定义
final aiServiceProvider = Provider<AIService>(...);
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(...);
final ttsProvider = StateNotifierProvider<TTSNotifier, TTSState>(...);
```

---

## 五、API 对接

### 5.1 Google Gemini

**文档**: https://ai.google.dev/docs

**免费额度**: 100万 token/天

**API Key 获取**:
1. 访问 https://makersuite.google.com/app/apikey
2. 创建 API Key

### 5.2 智谱AI

**文档**: https://open.bigmodel.cn/doc

**免费额度**: 新用户有限额

**API Key 获取**:
1. 访问 https://open.bigmodel.cn
2. 注册/登录
3. 控制台 → API Key 管理

---

## 六、待开发功能

### 6.1 高优先级

| 序号 | 功能 | 说明 |
|-----|------|------|
| P1 | 天气查询 | 接入 OpenWeatherMap API |
| P2 | 新闻播报 | 接入 NewsAPI |
| P3 | 纪念日管理 | 数据库 + 提醒功能 |
| P4 | AI 上下文记忆 | 记住用户偏好 |

### 6.2 中优先级

| 序号 | 功能 | 说明 |
|-----|------|------|
| P5 | 对话摘要 | 节省 token |
| P6 | Prompt 优化 | 系统角色设定 |
| P7 | 语音唤醒 | 语音激活 AI |

### 6.3 低优先级

| 序号 | 功能 | 说明 |
|-----|------|------|
| P8 | 向量搜索 | pgvector 语义搜索 |
| P9 | 多语言支持 | 英文/中文 |
| P10 | 图像识别 | 图片理解 |

---

## 七、数据库设计 (待实现)

### 7.1 纪念日表

```sql
CREATE TABLE important_dates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  title TEXT NOT NULL,           -- "结婚纪念日"
  date DATE NOT NULL,
  recurrence_pattern TEXT,        -- 'annual', 'monthly'
  category TEXT,                 -- 'birthday', 'anniversary'
  remind_days_before INTEGER DEFAULT 7,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 7.2 用户偏好表

```sql
CREATE TABLE user_preferences (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  preferences JSONB DEFAULT '{}',
  ai_context JSONB DEFAULT '{}',  -- AI 记忆
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 7.3 对话历史表

```sql
CREATE TABLE chat_history (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  messages JSONB,
  summary TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 八、天气/新闻 API (待接入)

### 8.1 天气 API

**推荐**: OpenWeatherMap

| 项目 | 详情 |
|-----|------|
| 免费额度 | 60次/分钟 |
| 文档 | https://openweathermap.org/api |
| 端点 | `api.openweathermap.org/data/2.5/weather` |

### 8.2 新闻 API

**推荐**: NewsAPI

| 项目 | 详情 |
|-----|------|
| 免费额度 | 100次/天 |
| 文档 | https://newsapi.org/docs |
| 端点 | `newsapi.org/v2/top-headlines` |

---

## 九、TTS 配置

### 9.1 iOS 配置

**Info.plist** 添加:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### 9.2 Android 配置

**android/app/build.gradle**:
```groovy
defaultConfig {
    minSdkVersion 21
}
```

---

## 十、开发规范

### 10.1 新增 AI 功能流程

1. 在 `lib/data/ai/` 下创建服务文件
2. 在 `ai_providers.dart` 添加 Provider
3. 创建页面文件
4. 在 `app.dart` 添加路由
5. 添加设置入口 (可选)

### 10.2 代码风格

- 使用 Riverpod 管理状态
- API Key 必须存储在 flutter_secure_storage
- 错误需要友好提示
- 异步操作需要 loading 状态

---

## 十一、常见问题

### Q1: API Key 安全吗？
> A: 使用 flutter_secure_storage 加密存储在本地，不会上传。

### Q2: 免费额度够用吗？
> A: Gemini 免费额度 100万token/天，个人使用足够。

### Q3: 国内访问稳定吗？
> A: 智谱AI 国内访问稳定，可作为备选。

### Q4: 能添加更多 AI 吗？
> A: 可以，在 ai_models.dart 添加新枚举，在 ai_service.dart 添加调用逻辑。

---

## 十二、相关链接

- [Flutter AI 官方文档](https://docs.flutter.dev/ai)
- [Google Gemini SDK](https://pub.dev/packages/google_generative_ai)
- [flutter_tts](https://pub.dev/packages/flutter_tts)
- [智谱AI 开放平台](https://open.bigmodel.cn)
- [OpenWeatherMap](https://openweathermap.org)
- [NewsAPI](https://newsapi.org)

---

## 十三、版本记录

| 版本 | 日期 | 内容 |
|-----|------|------|
| v1.0.0 | 2026-03-09 | 初始版本：AI 聊天 + TTS + 设置页 |
