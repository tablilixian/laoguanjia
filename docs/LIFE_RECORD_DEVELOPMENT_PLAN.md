# 生活记录功能开发计划

## 一、功能概述

### 1.1 功能定位
- 独立的生活记录模块，专注于日常活动追踪和修炼记录
- 纯本地JSON存储，支持导入导出
- 功能独立，不影响现有功能

### 1.2 核心功能
- 活动记录（计时/手动）
- 修炼日记（丹道修炼专用）
- 修炼计划（内置完整方案）
- 统计分析（图表展示）
- 数据导入导出

### 1.3 技术栈
- 状态管理：Riverpod
- 本地存储：LocalStorageService（JSON/JSONL格式）
- 图表：fl_chart
- 导入导出：复用现有DataExportSource框架
- UI风格：与现有项目一致（Material Design + flex_color_scheme）

## 二、数据模型设计

### 2.1 活动类型模型 (ActivityType)

```dart
class ActivityType {
  final String id;              // 唯一标识，如 'meditation', 'reading'
  final String name;            // 显示名称，如 '静坐', '读书'
  final String category;        // 分类：'cultivation', 'work', 'exercise', 'life', 'entertainment'
  final String iconCode;        // Material Icons代码，如 'e900'
  final String colorHex;        // 颜色值，如 '#4CAF50'
  final List<String> parameters; // 需要的参数列表
  final bool supportTimer;      // 是否支持计时
}
```

**预设活动类型**

| ID | 名称 | 分类 | 图标 | 颜色 | 参数 | 计时 |
|----|------|------|------|------|------|------|
| meditation | 静坐 | cultivation | self_improvement | #9C27B0 | posture, method, breathState, distractionLevel | 是 |
| breathing | 调息 | cultivation | air | #2196F3 | breathType, count | 是 |
| reading | 读书 | work | menu_book | #4CAF50 | bookTitle, pages, chapter | 是 |
| exercise | 锻炼 | exercise | fitness_center | #FF5722 | exerciseType, distance, calories | 是 |
| work | 工作 | work | work | #607D8B | taskType | 是 |
| video | 刷视频 | entertainment | smart_display | #F44336 | platform, contentCategory | 是 |
| cooking | 做饭 | life | kitchen | #FF9800 | mealType | 是 |
| cleaning | 打扫 | life | cleaning | #8BC34A | area | 是 |

### 2.2 活动记录模型 (ActivityRecord)

```dart
class ActivityRecord {
  final String id;                    // UUID
  final String activityTypeId;        // 关联活动类型ID
  final DateTime startTime;           // 开始时间
  final DateTime? endTime;            // 结束时间（null表示进行中）
  final int durationSeconds;          // 持续时长（秒）
  final Map<String, dynamic> parameters; // 动态参数
  final String? notes;                // 备注
  final int? moodRating;              // 心情评分 1-5
  final int? energyRating;            // 精力评分 1-5
}
```

### 2.3 修炼记录模型 (CultivationRecord)

```dart
class CultivationRecord {
  final String id;
  final DateTime date;                // 日期
  final String weather;               // 天气：晴/阴/雨/雪
  final String bodyCondition;         // 身体状况：良好/一般/疲劳/不适
  final String mentalState;           // 精神状态：清明/平和/烦躁/昏沉
  final List<MeditationSession> sessions; // 修炼会话列表
  final DailyCultivationSummary summary;  // 每日总结
}

class MeditationSession {
  final String id;
  final String period;                // 时段：morning/noon/evening/night
  final DateTime startTime;           // 开始时间
  final DateTime endTime;             // 结束时间
  final String posture;               // 姿势：散盘/单盘/双盘/坐椅
  final String method;                // 功法：回光法/调息/守窍/其他
  final String breathState;           // 呼吸状态：均匀/粗重/细长/不稳
  final String distractionLevel;      // 杂念程度：很少/较少/较多/很多
  final String bodyFeeling;           // 身体感受
  final String notes;                 // 备注
}

class DailyCultivationSummary {
  final int totalDurationMinutes;     // 总修炼时长（分钟）
  final int morningDuration;          // 晨间时长
  final int noonDuration;             // 日间时长
  final int eveningDuration;          // 晚间时长
  final String insights;              // 今日心得
  final String bodyChanges;           // 身体变化/功境进展
  final String problems;              // 遇到的问题
  final String adjustments;           // 解决方案/调整计划
}
```

### 2.4 修炼计划模型 (CultivationPlan)

```dart
class CultivationPlan {
  final String id;
  final String name;                  // 计划名称
  final String description;           // 描述
  final List<PlanPhase> phases;       // 阶段列表
  final List<DailyRoutine> routines;  // 每日例行
}

class PlanPhase {
  final String id;
  final String name;                  // 阶段名称
  final int startMonth;               // 起始月份
  final int endMonth;                 // 结束月份
  final String description;           // 描述
  final List<String> goals;           // 目标列表
  final List<String> practices;       // 修炼内容
}

class DailyRoutine {
  final String timeSlot;              // 时间段
  final String activity;              // 活动
  final int durationMinutes;          // 时长（分钟）
  final String description;           // 说明
  final bool isCore;                  // 是否核心
}
```

## 三、内置修炼计划（完整方案）

### 3.1 百日筑基修炼计划

#### 第一阶段：入门筑基（第1-3个月）

**目标**
- 建立每日修炼习惯
- 掌握静坐基本方法
- 学习理论基础

**每日修炼清单**

| 时段 | 时间 | 活动 | 时长 | 说明 | 是否核心 |
|------|------|------|------|------|----------|
| 晨间 | 6:00-6:30 | 静坐 | 30分钟 | 散盘或坐椅，调息入门 | 是 |
| 晨间 | 6:30-6:40 | 诵读 | 10分钟 | 《太乙金华宗旨》章节 | 否 |
| 通勤 | 路上 | 观呼吸 | 15-30分钟 | 地铁/公交上默数呼吸 | 否 |
| 午休 | 12:30-12:45 | 静坐 | 15分钟 | 办公室静坐调息 | 是 |
| 晚间 | 21:00-21:30 | 静坐 | 30分钟 | 回光法练习 | 是 |
| 晚间 | 21:30-21:45 | 阅读 | 15分钟 | 丹道典籍学习 | 否 |
| 睡前 | 22:00 | 总结 | 5分钟 | 记录今日修炼感受 | 是 |

**每周重点**
- 第1-2周：适应静坐姿势，每次15分钟起步
- 第3-4周：增加到30分钟，学习调息
- 第5-8周：掌握回光法基本要领
- 第9-12周：稳定每日修炼习惯

**阅读计划**
- 第1个月：《太乙金华宗旨》典籍简介、第一章天心
- 第2个月：第二章元神识神、第三章回光之功
- 第3个月：第四章回光证验、第五章回光差别

#### 第二阶段：系统提升（第3-6个月）

**目标**
- 深入修炼功法
- 学习《灵宝毕法》
- 提升静坐质量

**每日修炼清单**

| 时段 | 时间 | 活动 | 时长 | 说明 | 是否核心 |
|------|------|------|------|------|----------|
| 晨间 | 5:30-6:15 | 静坐 | 45分钟 | 单盘尝试，回光法深入 | 是 |
| 晨间 | 6:15-6:30 | 调息 | 15分钟 | 聚散水火练习 | 是 |
| 通勤 | 路上 | 默念口诀 | 15-30分钟 | 修炼口诀默念 | 否 |
| 午休 | 12:30-12:50 | 静坐 | 20分钟 | 守窍练习 | 是 |
| 晚间 | 20:30-21:30 | 静坐 | 60分钟 | 完整修炼流程 | 是 |
| 晚间 | 21:30-22:00 | 阅读 | 30分钟 | 《灵宝毕法》学习 | 否 |
| 睡前 | 22:30 | 总结 | 10分钟 | 详细修炼日记 | 是 |

**每月重点**
- 第4个月：尝试单盘，学习聚散水火
- 第5个月：守窍练习，交媾龙虎入门
- 第6个月：烧炼丹药理解，静坐质量提升

**阅读计划**
- 第4个月：《灵宝毕法》上卷第一门匹配阴阳
- 第5个月：第二门聚散水火、第三门交媾龙虎
- 第6个月：第四门烧炼丹药、中卷入门

#### 第三阶段：深入精进（第6-12个月）

**目标**
- 稳定修炼状态
- 深入中下卷功法
- 形成个人修炼体系

**每日修炼清单**

| 时段 | 时间 | 活动 | 时长 | 说明 | 是否核心 |
|------|------|------|------|------|----------|
| 晨间 | 5:00-6:00 | 静坐 | 60分钟 | 双盘尝试，完整功法 | 是 |
| 晨间 | 6:00-6:20 | 辅助功法 | 20分钟 | 叩齿、鸣天鼓、梳头 | 否 |
| 通勤 | 路上 | 观想 | 15-30分钟 | 内景观想 | 否 |
| 午休 | 12:30-13:00 | 静坐 | 30分钟 | 午时修炼 | 是 |
| 晚间 | 20:00-21:30 | 静坐 | 90分钟 | 深度修炼 | 是 |
| 晚间 | 21:30-22:00 | 阅读 | 30分钟 | 参考资料研读 | 否 |
| 睡前 | 22:30 | 总结 | 10分钟 | 周/月总结 | 是 |

**每季度重点**
- 第7-8个月：中卷长生不死法学习
- 第9-10个月：下卷超凡入圣法入门
- 第11-12个月：个人修炼体系形成

### 3.2 周末修炼方案

**周六**
| 时段 | 时间 | 活动 | 时长 |
|------|------|------|------|
| 晨间 | 5:00-6:30 | 静坐+辅助功法 | 90分钟 |
| 上午 | 9:00-10:00 | 典籍研读 | 60分钟 |
| 下午 | 14:00-15:00 | 静坐 | 60分钟 |
| 晚间 | 20:00-21:00 | 静坐+总结 | 60分钟 |

**周日**
| 时段 | 时间 | 活动 | 时长 |
|------|------|------|------|
| 晨间 | 5:30-6:30 | 静坐 | 60分钟 |
| 上午 | 9:00-10:30 | 周总结+计划 | 90分钟 |
| 下午 | 14:00-15:00 | 自由修炼 | 60分钟 |
| 晚间 | 20:00-21:00 | 静坐 | 60分钟 |

### 3.3 修炼时间汇总

**工作日每日统计**
- 晨间：45-60分钟
- 日间：30-60分钟（碎片时间）
- 晚间：60-90分钟
- 合计：135-210分钟（2.25-3.5小时）

**周度统计**
- 工作日：5天 × 135-210分钟 = 675-1050分钟
- 周末：2天 × 240-300分钟 = 480-600分钟
- 周合计：1155-1650分钟（19-27.5小时）

## 四、本地存储设计

### 4.1 存储路径
```
home_manager_data/
├── activities/
│   ├── activity_types.json      # 活动类型配置
│   ├── records.jsonl            # 活动记录（JSONL格式）
│   └── cultivation/
│       ├── daily_records.jsonl  # 修炼日记
│       └── plans.json           # 修炼计划
└── exports/                     # 导出文件目录
```

### 4.2 JSON格式示例

**activity_types.json**
```json
{
  "version": "1.0",
  "types": [
    {
      "id": "meditation",
      "name": "静坐",
      "category": "cultivation",
      "iconCode": "e900",
      "colorHex": "#9C27B0",
      "parameters": ["posture", "method", "breathState", "distractionLevel"],
      "supportTimer": true
    }
  ]
}
```

**records.jsonl** (每行一条记录)
```jsonl
{"id":"uuid-001","activityTypeId":"meditation","startTime":"2026-06-08T06:00:00.000Z","endTime":"2026-06-08T06:30:00.000Z","durationSeconds":1800,"parameters":{"posture":"散盘","method":"回光法","breathState":"均匀","distractionLevel":"较少"},"notes":"","moodRating":4,"energyRating":4}
{"id":"uuid-002","activityTypeId":"reading","startTime":"2026-06-08T21:30:00.000Z","endTime":"2026-06-08T21:45:00.000Z","durationSeconds":900,"parameters":{"bookTitle":"太乙金华宗旨","pages":10,"chapter":"第三章"},"notes":"回光之功理解更深了","moodRating":5,"energyRating":3}
```

**cultivation/daily_records.jsonl**
```jsonl
{"id":"uuid-003","date":"2026-06-08","weather":"晴","bodyCondition":"良好","mentalState":"清明","sessions":[{"id":"session-001","period":"morning","startTime":"2026-06-08T06:00:00.000Z","endTime":"2026-06-08T06:30:00.000Z","posture":"散盘","method":"回光法","breathState":"均匀","distractionLevel":"较少","bodyFeeling":"腿部微麻，气息顺畅","notes":""}],"summary":{"totalDurationMinutes":90,"morningDuration":30,"noonDuration":15,"eveningDuration":45,"insights":"今日静坐状态较好","bodyChanges":"气息更顺畅","problems":"腿部容易麻","adjustments":"明日尝试散盘"}}
```

### 4.3 存储服务接口

```dart
class ActivityStorage {
  // 活动类型
  Future<List<ActivityType>> loadActivityTypes();
  Future<void> saveActivityTypes(List<ActivityType> types);
  
  // 活动记录
  Future<List<ActivityRecord>> loadRecords();
  Future<void> appendRecord(ActivityRecord record);
  Future<void> updateRecord(ActivityRecord record);
  Future<void> deleteRecord(String id);
  
  // 修炼记录
  Future<List<CultivationRecord>> loadCultivationRecords();
  Future<void> appendCultivationRecord(CultivationRecord record);
  Future<void> updateCultivationRecord(CultivationRecord record);
  
  // 查询方法
  Future<List<ActivityRecord>> getRecordsByDate(DateTime date);
  Future<List<ActivityRecord>> getRecordsByType(String activityTypeId);
  Future<ActivityRecord?> getLastRecord(String activityTypeId);
  Future<List<ActivityRecord>> getRecordsByDateRange(DateTime start, DateTime end);
}
```

## 五、导入导出设计

### 5.1 ActivityExportSource 实现

```dart
class ActivitySource implements DataExportSource {
  @override
  String get id => 'activities';
  
  @override
  String get name => '生活记录';
  
  @override
  String get description => '日常活动记录与修炼日记';
  
  @override
  IconData get icon => Icons.track_changes_outlined;
  
  @override
  Future<bool> hasData() async {
    final records = await _storage.loadRecords();
    final cultivationRecords = await _storage.loadCultivationRecords();
    return records.isNotEmpty || cultivationRecords.isNotEmpty;
  }
  
  @override
  Future<Map<String, dynamic>> exportData() async {
    final records = await _storage.loadRecords();
    final cultivationRecords = await _storage.loadCultivationRecords();
    final activityTypes = await _storage.loadActivityTypes();
    
    return {
      'activities': {
        'activityTypes': activityTypes.map((t) => t.toJson()).toList(),
        'records': records.map((r) => r.toJson()).toList(),
        'cultivationRecords': cultivationRecords.map((r) => r.toJson()).toList(),
        '_meta': {
          'typeCount': activityTypes.length,
          'recordCount': records.length,
          'cultivationRecordCount': cultivationRecords.length,
        },
      },
    };
  }
  
  @override
  Future<ImportSummary> importData(Map<String, dynamic> data) async {
    try {
      final activityTypes = (data['activityTypes'] as List)
          .map((t) => ActivityType.fromJson(t))
          .toList();
      final records = (data['records'] as List)
          .map((r) => ActivityRecord.fromJson(r))
          .toList();
      final cultivationRecords = (data['cultivationRecords'] as List)
          .map((r) => CultivationRecord.fromJson(r))
          .toList();
      
      await _storage.saveActivityTypes(activityTypes);
      for (final record in records) {
        await _storage.appendRecord(record);
      }
      for (final record in cultivationRecords) {
        await _storage.appendCultivationRecord(record);
      }
      
      return ImportSummary(
        success: true,
        itemCount: records.length + cultivationRecords.length,
        message: '生活记录已导入（${records.length} 条活动，${cultivationRecords.length} 条修炼记录）',
      );
    } catch (e) {
      return ImportSummary(
        success: false,
        itemCount: 0,
        message: '导入生活记录失败: $e',
      );
    }
  }
}
```

### 5.2 注册到 DataExportRegistry

在 `lib/core/services/data_export/data_export_registry.dart` 中添加：

```dart
import 'sources/activity_source.dart';

static final List<DataExportSource Function()> sourceFactories = [
  () => ChatSource(),
  () => PetInteractionSource(),
  () => PetMemorySource(),
  () => ActivitySource(),  // 新增
];
```

## 六、页面结构设计

### 6.1 页面列表

| 页面 | 路由 | 说明 |
|------|------|------|
| LifeRecordHomePage | /life-record | 生活记录首页 |
| ActivityListPage | /life-record/activities | 活动列表页 |
| AddActivityPage | /life-record/add | 添加活动页 |
| ActivityDetailPage | /life-record/activity/:id | 活动详情页 |
| CultivationRecordPage | /life-record/cultivation | 修炼记录页 |
| CultivationPlanPage | /life-record/plan | 修炼计划页 |
| StatisticsPage | /life-record/statistics | 统计分析页 |

### 6.2 导航结构

**首页Tab配置** (修改 `lib/app.dart` 或相关路由配置)

```dart
// 在现有TabBar中添加新Tab
Tab(
  icon: Icon(Icons.track_changes),
  text: '生活记录',
),
```

**路由配置**

```dart
GoRoute(
  path: '/life-record',
  builder: (context, state) => const LifeRecordHomePage(),
  routes: [
    GoRoute(
      path: 'activities',
      builder: (context, state) => const ActivityListPage(),
    ),
    GoRoute(
      path: 'add',
      builder: (context, state) => const AddActivityPage(),
    ),
    GoRoute(
      path: 'activity/:id',
      builder: (context, state) => ActivityDetailPage(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: 'cultivation',
      builder: (context, state) => const CultivationRecordPage(),
    ),
    GoRoute(
      path: 'plan',
      builder: (context, state) => const CultivationPlanPage(),
    ),
    GoRoute(
      path: 'statistics',
      builder: (context, state) => const StatisticsPage(),
    ),
  ],
),
```

## 七、文件结构

```
lib/features/life_record/
├── models/
│   ├── activity_type.dart           # 活动类型模型
│   ├── activity_record.dart         # 活动记录模型
│   ├── cultivation_record.dart      # 修炼记录模型
│   └── cultivation_plan.dart        # 修炼计划模型
├── services/
│   ├── activity_storage.dart        # 活动存储服务
│   ├── time_tracking_service.dart   # 时间追踪服务
│   └── activity_export_source.dart  # 导入导出源
├── providers/
│   ├── activity_types_provider.dart # 活动类型Provider
│   ├── activity_records_provider.dart # 活动记录Provider
│   ├── cultivation_records_provider.dart # 修炼记录Provider
│   └── statistics_provider.dart     # 统计Provider
├── pages/
│   ├── life_record_home_page.dart   # 首页
│   ├── activity_list_page.dart      # 活动列表页
│   ├── add_activity_page.dart       # 添加活动页
│   ├── activity_detail_page.dart    # 活动详情页
│   ├── cultivation_record_page.dart # 修炼记录页
│   ├── cultivation_plan_page.dart   # 修炼计划页
│   └── statistics_page.dart         # 统计分析页
├── widgets/
│   ├── activity_card.dart           # 活动卡片组件
│   ├── timer_widget.dart            # 计时器组件
│   ├── cultivation_session_form.dart # 修炼会话表单
│   ├── daily_summary_form.dart      # 每日总结表单
│   ├── calendar_view.dart           # 日历视图
│   └── statistics_charts.dart       # 统计图表
└── utils/
    ├── activity_constants.dart      # 活动常量
    └── cultivation_defaults.dart    # 修炼默认配置
```

## 八、状态管理设计

### 8.1 Riverpod Providers

```dart
// 活动类型 Provider
final activityTypesProvider = StateNotifierProvider<ActivityTypesNotifier, List<ActivityType>>((ref) {
  return ActivityTypesNotifier();
});

class ActivityTypesNotifier extends StateNotifier<List<ActivityType>> {
  ActivityTypesNotifier() : super([]) {
    _loadTypes();
  }
  
  Future<void> _loadTypes() async {
    final storage = ActivityStorage();
    state = await storage.loadActivityTypes();
  }
  
  Future<void> addType(ActivityType type) async {
    final storage = ActivityStorage();
    await storage.saveActivityTypes([...state, type]);
    state = [...state, type];
  }
}

// 今日记录 Provider
final todayRecordsProvider = FutureProvider<List<ActivityRecord>>((ref) async {
  final storage = ActivityStorage();
  return storage.getRecordsByDate(DateTime.now());
});

// 修炼记录 Provider
final cultivationRecordsProvider = StateNotifierProvider<CultivationRecordsNotifier, List<CultivationRecord>>((ref) {
  return CultivationRecordsNotifier();
});

// 统计数据 Provider
final statisticsProvider = FutureProvider<ActivityStatistics>((ref) async {
  final storage = ActivityStorage();
  final records = await storage.loadRecords();
  return ActivityStatistics.calculate(records);
});

// 当前计时 Provider
final activeTimerProvider = StateNotifierProvider<ActiveTimerNotifier, ActivityRecord?>((ref) {
  return ActiveTimerNotifier();
});
```

### 8.2 时间追踪服务

```dart
class TimeTrackingService {
  final ActivityStorage _storage = ActivityStorage();
  
  // 计算上次做此事到现在的间隔
  Future<Duration> getTimeSinceLastActivity(String activityTypeId) async {
    final lastRecord = await _storage.getLastRecord(activityTypeId);
    if (lastRecord == null) return Duration.zero;
    return DateTime.now().difference(lastRecord.endTime!);
  }
  
  // 计算连续天数
  Future<int> getConsecutiveDays(String activityTypeId) async {
    final records = await _storage.getRecordsByType(activityTypeId);
    return _calculateConsecutiveDays(records);
  }
  
  // 计算累计时长
  Future<int> getTotalDuration(String activityTypeId, [DateTime? startDate]) async {
    final records = await _storage.getRecordsByType(activityTypeId);
    final filtered = startDate != null 
        ? records.where((r) => r.startTime.isAfter(startDate)).toList()
        : records;
    return filtered.fold(0, (sum, r) => sum + r.durationSeconds);
  }
  
  int _calculateConsecutiveDays(List<ActivityRecord> records) {
    if (records.isEmpty) return 0;
    
    final dates = records
        .map((r) => DateTime(r.startTime.year, r.startTime.month, r.startTime.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    
    int consecutive = 1;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    if (dates.first != todayDate) return 0;
    
    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i - 1].difference(dates[i]).inDays;
      if (diff == 1) {
        consecutive++;
      } else {
        break;
      }
    }
    
    return consecutive;
  }
}
```

## 九、核心功能实现

### 9.1 快速记录功能

```dart
class QuickRecordService {
  final ActivityStorage _storage = ActivityStorage();
  
  // 开始计时
  Future<ActivityRecord> startActivity(String activityTypeId) async {
    final record = ActivityRecord(
      id: const Uuid().v4(),
      activityTypeId: activityTypeId,
      startTime: DateTime.now(),
      durationSeconds: 0,
      parameters: {},
    );
    await _storage.appendRecord(record);
    return record;
  }
  
  // 结束计时
  Future<ActivityRecord> stopActivity(String recordId, {Map<String, dynamic>? parameters, String? notes}) async {
    final records = await _storage.loadRecords();
    final index = records.indexWhere((r) => r.id == recordId);
    if (index == -1) throw Exception('Record not found');
    
    final record = records[index];
    final endTime = DateTime.now();
    final duration = endTime.difference(record.startTime);
    
    final updated = record.copyWith(
      endTime: endTime,
      durationSeconds: duration.inSeconds,
      parameters: parameters ?? record.parameters,
      notes: notes ?? record.notes,
    );
    
    records[index] = updated;
    await _storage.saveRecords(records);
    return updated;
  }
}
```

### 9.2 修炼日记表单

```dart
class CultivationRecordForm extends ConsumerStatefulWidget {
  const CultivationRecordForm({super.key});
  
  @override
  ConsumerState<CultivationRecordForm> createState() => _CultivationRecordFormState();
}

class _CultivationRecordFormState extends ConsumerState<CultivationRecordForm> {
  final _formKey = GlobalKey<FormState>();
  
  // 基本信息
  String _weather = '晴';
  String _bodyCondition = '良好';
  String _mentalState = '清明';
  
  // 会话列表
  final List<MeditationSession> _sessions = [];
  
  // 总结
  final _insightsController = TextEditingController();
  final _bodyChangesController = TextEditingController();
  final _problemsController = TextEditingController();
  final _adjustmentsController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 基本信息
          _buildBasicInfoSection(),
          const SizedBox(height: 24),
          
          // 修炼会话
          _buildSessionsSection(),
          const SizedBox(height: 24),
          
          // 今日总结
          _buildDailySummarySection(),
          const SizedBox(height: 24),
          
          // 保存按钮
          ElevatedButton(
            onPressed: _saveRecord,
            child: const Text('保存修炼记录'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('基本信息', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            
            // 天气
            DropdownButtonFormField<String>(
              value: _weather,
              decoration: const InputDecoration(labelText: '天气'),
              items: ['晴', '阴', '雨', '雪']
                  .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                  .toList(),
              onChanged: (v) => setState(() => _weather = v!),
            ),
            
            // 身体状况
            DropdownButtonFormField<String>(
              value: _bodyCondition,
              decoration: const InputDecoration(labelText: '身体状况'),
              items: ['良好', '一般', '疲劳', '不适']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _bodyCondition = v!),
            ),
            
            // 精神状态
            DropdownButtonFormField<String>(
              value: _mentalState,
              decoration: const InputDecoration(labelText: '精神状态'),
              items: ['清明', '平和', '烦躁', '昏沉']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _mentalState = v!),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSessionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('修炼会话', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        
        // 添加会话按钮
        OutlinedButton.icon(
          onPressed: _addSession,
          icon: const Icon(Icons.add),
          label: const Text('添加修炼会话'),
        ),
        
        const SizedBox(height: 8),
        
        // 会话列表
        ..._sessions.asMap().entries.map((entry) {
          return _buildSessionCard(entry.key, entry.value);
        }),
      ],
    );
  }
  
  Widget _buildSessionCard(int index, MeditationSession session) {
    return Card(
      child: ExpansionTile(
        title: Text('${_getPeriodName(session.period)} - ${session.method}'),
        subtitle: Text('${_formatDuration(session.startTime, session.endTime)}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSessionForm(index, session),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDailySummarySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今日总结', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            
            TextField(
              controller: _insightsController,
              decoration: const InputDecoration(
                labelText: '今日心得',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _bodyChangesController,
              decoration: const InputDecoration(
                labelText: '身体变化/功境进展',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _problemsController,
              decoration: const InputDecoration(
                labelText: '遇到的问题',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _adjustmentsController,
              decoration: const InputDecoration(
                labelText: '解决方案/调整计划',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
  
  void _addSession() {
    setState(() {
      _sessions.add(MeditationSession(
        id: const Uuid().v4(),
        period: 'morning',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        posture: '散盘',
        method: '回光法',
        breathState: '均匀',
        distractionLevel: '较少',
        bodyFeeling: '',
        notes: '',
      ));
    });
  }
  
  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;
    
    final record = CultivationRecord(
      id: const Uuid().v4(),
      date: DateTime.now(),
      weather: _weather,
      bodyCondition: _bodyCondition,
      mentalState: _mentalState,
      sessions: _sessions,
      summary: DailyCultivationSummary(
        totalDurationMinutes: _calculateTotalDuration(),
        morningDuration: _calculateDurationByPeriod('morning'),
        noonDuration: _calculateDurationByPeriod('noon'),
        eveningDuration: _calculateDurationByPeriod('evening'),
        insights: _insightsController.text,
        bodyChanges: _bodyChangesController.text,
        problems: _problemsController.text,
        adjustments: _adjustmentsController.text,
      ),
    );
    
    final storage = ActivityStorage();
    await storage.appendCultivationRecord(record);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('修炼记录已保存')),
      );
      Navigator.of(context).pop();
    }
  }
  
  int _calculateTotalDuration() {
    return _sessions.fold(0, (sum, s) {
      return sum + s.endTime.difference(s.startTime).inMinutes;
    });
  }
  
  int _calculateDurationByPeriod(String period) {
    return _sessions
        .where((s) => s.period == period)
        .fold(0, (sum, s) => sum + s.endTime.difference(s.startTime).inMinutes);
  }
  
  String _getPeriodName(String period) {
    switch (period) {
      case 'morning': return '晨间';
      case 'noon': return '日间';
      case 'evening': return '晚间';
      case 'night': return '夜间';
      default: return period;
    }
  }
  
  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    return '${duration.inMinutes}分钟';
  }
}
```

## 十、UI设计要点

### 10.1 首页布局

```
┌─────────────────────────────────┐
│  📅 今日概览                     │
│  ┌───────────────────────────┐  │
│  │ 连续修炼：15天             │  │
│  │ 今日时长：90分钟           │  │
│  │ 已完成：3/5 项             │  │
│  └───────────────────────────┘  │
│                                  │
│  ⚡ 快速记录                     │
│  [静坐] [调息] [读书] [锻炼]    │
│  [工作] [刷视频] [做饭] [打扫]  │
│                                  │
│  📋 今日活动                     │
│  ┌───────────────────────────┐  │
│  │ 06:00-06:30 静坐 30分钟   │  │
│  │ 12:30-12:45 静坐 15分钟   │  │
│  │ 21:00-21:30 静坐 30分钟   │  │
│  └───────────────────────────┘  │
│                                  │
│  📊 本周统计                     │
│  [折线图]                       │
│                                  │
│  [修炼计划] [统计分析] [设置]   │
└─────────────────────────────────┘
```

### 10.2 修炼记录页布局

```
┌─────────────────────────────────┐
│  📅 2026年6月8日 星期一          │
│  天气：晴 ☀️                    │
│  身体状况：良好 💪              │
│  精神状态：清明 🧘              │
│                                  │
│  🌅 晨间修炼                    │
│  ┌───────────────────────────┐  │
│  │ 静坐 06:00-06:30          │  │
│  │ 姿势：散盘                │  │
│  │ 功法：回光法              │  │
│  │ 呼吸：均匀                │  │
│  │ 杂念：较少                │  │
│  └───────────────────────────┘  │
│                                  │
│  🌞 日间修炼                    │
│  ┌───────────────────────────┐  │
│  │ 静坐 12:30-12:45          │  │
│  │ 姿势：坐椅                │  │
│  │ 功法：调息                │  │
│  └───────────────────────────┘  │
│                                  │
│  🌙 晚间修炼                    │
│  ┌───────────────────────────┐  │
│  │ 静坐 21:00-21:30          │  │
│  │ 姿势：单盘                │  │
│  │ 功法：回光法              │  │
│  └───────────────────────────┘  │
│                                  │
│  📝 今日总结                    │
│  ┌───────────────────────────┐  │
│  │ 总时长：75分钟            │  │
│  │ 心得：今日状态较好...     │  │
│  └───────────────────────────┘  │
│                                  │
│  [编辑] [添加会话] [导出]       │
└─────────────────────────────────┘
```

### 10.3 统计分析页布局

```
┌─────────────────────────────────┐
│  📊 统计分析                     │
│                                  │
│  [日] [周] [月] [年]            │
│                                  │
│  📈 修炼时长趋势                 │
│  ┌───────────────────────────┐  │
│  │ [折线图]                  │  │
│  └───────────────────────────┘  │
│                                  │
│  🥧 活动占比                     │
│  ┌───────────────────────────┐  │
│  │ [饼图]                    │  │
│  │ 静坐 60%                  │  │
│  │ 读书 20%                  │  │
│  │ 调息 15%                  │  │
│  │ 其他 5%                   │  │
│  └───────────────────────────┘  │
│                                  │
│  🔥 连续天数                     │
│  ┌───────────────────────────┐  │
│  │ 静坐：15天                │  │
│  │ 读书：8天                 │  │
│  │ 调息：12天                │  │
│  └───────────────────────────┘  │
│                                  │
│  📅 日历热力图                   │
│  ┌───────────────────────────┐  │
│  │ [GitHub风格热力图]        │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## 十一、开发阶段

### 第一阶段：基础架构（1-2周）

**任务清单**
- [ ] 创建数据模型文件（4个模型）
- [ ] 实现ActivityStorage服务
- [ ] 创建ActivityExportSource
- [ ] 注册到DataExportRegistry
- [ ] 配置路由
- [ ] 创建首页基础UI

**验收标准**
- 数据模型可正常序列化/反序列化
- 本地存储可正常读写
- 导入导出功能可用
- 首页可正常显示

### 第二阶段：核心功能（2-3周）

**任务清单**
- [ ] 实现活动记录功能（开始/结束计时）
- [ ] 实现修炼日记表单
- [ ] 实现活动列表页面
- [ ] 实现添加活动页面
- [ ] 实现修炼计划页面

**验收标准**
- 可正常添加/编辑/删除活动记录
- 修炼日记表单可正常填写保存
- 活动列表可正常显示
- 修炼计划可正常展示

### 第三阶段：统计分析（1-2周）

**任务清单**
- [ ] 实现日历视图
- [ ] 实现趋势图表（fl_chart）
- [ ] 实现连续天数统计
- [ ] 实现活动占比饼图
- [ ] 实现数据报告

**验收标准**
- 日历热力图可正常显示
- 趋势图表数据准确
- 统计计算正确

### 第四阶段：优化完善（1周）

**任务清单**
- [ ] UI细节优化
- [ ] 性能优化（分页、缓存）
- [ ] 边界情况处理
- [ ] 测试
- [ ] 文档完善

**验收标准**
- UI与现有项目风格一致
- 无明显性能问题
- 无崩溃bug

## 十二、技术要点

### 12.1 数据存储

**使用LocalStorageService**
```dart
final storage = LocalStorageService.instance;
await storage.init();

// 读取JSONL
final records = await storage.readJsonLines('activities/records.jsonl');

// 追加写入
await storage.appendJsonLine('activities/records.jsonl', record.toJson());

// 全量写入
await storage.writeJsonArray('activities/activity_types.json', typesJson);
```

**JSONL格式优势**
- 增量写入，性能更好
- 每行独立，易于解析
- 适合日志类数据

### 12.2 导入导出

**复用现有框架**
- 实现DataExportSource接口
- 注册到DataExportRegistry
- 自动获得导入导出UI

**导出JSON格式**
```json
{
  "exportVersion": "1.0",
  "exportDate": "2026-06-08T12:00:00.000Z",
  "appName": "老管家",
  "sources": ["activities", "finance", "chat"],
  "data": {
    "activities": {
      "activityTypes": [...],
      "records": [...],
      "cultivationRecords": [...]
    }
  }
}
```

### 12.3 状态管理

**Riverpod最佳实践**
- 使用StateNotifier管理复杂状态
- FutureProvider处理异步数据
- Provider依赖注入

**性能优化**
- 使用select避免不必要的重建
- 分页加载大数据集
- 缓存计算结果

### 12.4 UI风格

**与现有项目一致**
- 使用flex_color_scheme主题
- 遵循Material Design 3
- 使用现有组件样式

**响应式设计**
- 适配不同屏幕尺寸
- 支持深色/浅色模式
- 横竖屏适配

## 十三、注意事项

### 13.1 功能独立

**不修改现有代码**
- 新增功能在lib/features/life_record/目录下
- 独立的路由配置
- 独立的存储路径

**最小化依赖**
- 仅依赖core/services/local_storage_service.dart
- 仅依赖core/services/data_export/框架
- 不依赖其他feature模块

### 13.2 数据安全

**纯本地存储**
- 数据保存在设备本地
- 不上传云端
- 用户完全控制

**导入导出**
- JSON格式，用户可读
- 支持分享/备份
- 可手动编辑

### 13.3 性能优化

**分页加载**
- 活动列表分页显示
- 避免一次性加载全部数据

**图表缓存**
- 统计数据缓存
- 避免重复计算

**内存管理**
- 及时释放不用的资源
- 避免内存泄漏

## 十四、测试计划

### 14.1 单元测试

**数据模型测试**
- JSON序列化/反序列化
- 数据验证

**存储服务测试**
- 读写功能
- 边界情况

**时间追踪测试**
- 连续天数计算
- 时长统计

### 14.2 集成测试

**导入导出测试**
- 导出JSON格式正确
- 导入数据完整

**页面流程测试**
- 添加活动流程
- 修炼记录流程

### 14.3 UI测试

**组件测试**
- 表单验证
- 状态显示

**响应式测试**
- 不同屏幕尺寸
- 深色/浅色模式

## 十五、后续扩展

### 15.1 可选功能

**提醒功能**
- 修炼提醒
- 久坐提醒
- 刷手机超时提醒

**语音输入**
- 修炼感受语音转文字

**数据报告**
- 周报/月报生成
- PDF导出

**典籍学习**
- 集成丹道典籍内容
- 学习计划跟踪

### 15.2 数据同步（可选）

**Supabase同步**
- 多设备同步
- 数据备份

**注意**：当前版本纯本地存储，同步功能后续按需添加

## 十六、开发规范

### 16.1 代码规范

**命名规范**
- 文件名：snake_case
- 类名：PascalCase
- 变量名：camelCase

**注释规范**
- 公共API添加文档注释
- 复杂逻辑添加行内注释

### 16.2 Git规范

**提交信息**
- feat: 新功能
- fix: 修复bug
- refactor: 重构
- docs: 文档

**分支管理**
- feature/life-record 开发分支
- 完成后合并到main

## 十七、风险评估

### 17.1 技术风险

**本地存储性能**
- 数据量大时可能变慢
- 解决方案：分页、索引

**图表渲染性能**
- 大数据量图表可能卡顿
- 解决方案：数据采样、缓存

### 17.2 产品风险

**功能复杂度**
- 修炼表单字段较多
- 解决方案：分步表单、默认值

**用户学习成本**
- 丹道术语可能晦涩
- 解决方案：添加说明、 tooltips

## 十八、验收标准

### 18.1 功能验收

- [ ] 可添加/编辑/删除活动记录
- [ ] 可记录修炼日记
- [ ] 可查看修炼计划
- [ ] 可查看统计分析
- [ ] 可导入导出数据

### 18.2 质量验收

- [ ] 无崩溃bug
- [ ] 无明显性能问题
- [ ] UI与现有项目一致
- [ ] 代码符合规范
- [ ] 测试覆盖核心功能

### 18.3 文档验收

- [ ] 代码注释完整
- [ ] API文档清晰
- [ ] 用户使用说明

---

**文档版本**: v1.0  
**创建日期**: 2026-06-08  
**最后更新**: 2026-06-08
