# 家庭财务系统 (Family Finance) 开发规范

> 本文档是家庭财务模块的完整开发规范，供 AI 开发助手直接使用。
> 设计日期：2026-05-26

---

## 1. 模块概述

### 1.1 功能目标

家庭财务追踪模块，帮助家庭成员管理所有资金账户，追踪净资产变化，计算被动收入覆盖率。

核心功能：
- 多层级组织：家庭 → 成员 → 渠道 → 快照
- 快照式资产追踪：定期记录各账户资产/负债，自动核算净资产变化
- 智能收支拆分：小额增长自动归为被动收入，大额增长弹窗确认主动收入
- 核心指标计算：月净资产、月支出、被动收入覆盖率、储蓄率

### 1.2 核心设计理念

**快照法 (Snapshot-Based)**

用户不需要逐笔记账，只需要不定期记录每个账户的「当前资产」和「当前负债」，系统自动计算出净资产变化，并通过智能规则拆分出主动收入、被动收入和支出。

**四层组织架构**

```
家庭 (Household)
  └── 成员 (Member) —— 谁的钱？
        └── 渠道 (Account) —— 钱在哪？
              └── 快照 (Snapshot) —— 当时有多少？
```

三个维度独立，可按任意组合聚合统计：
- **按成员**：爸爸赚多少、妈妈花多少
- **按渠道类型**：银行卡 vs 理财 vs 现金
- **按家庭**：全家净资产、总收支

---

## 2. 存储方案

### 2.1 为什么用 JSON

| 对比项 | JSON | Drift/SQLite |
|--------|------|-------------|
| 数据规模 | ✅ 适合百/千级快照 | 适合万级以上 |
| 查询需求 | ✅ Filter + reduce 即可 | SQL 聚合能力 |
| 扩展性 | ✅ 加字段零成本 | Migration 流程 |
| 复杂度 | ✅ 单文件读写，零依赖 | codegen + .g.dart |
| 同步需求 | ❌ 纯本地，不上云 | 需要同步才用 |

**结论**：纯本地存储、低频写入、轻量查询，JSON 的简单性完胜。

### 2.2 存储实现

使用 `shared_preferences` 跨平台存储（Web / macOS / iOS / Android），一个家庭一条记录：

| 平台 | 实际存储后端 | 键格式 |
|------|-------------|--------|
| Web | localStorage | `finance_data_{household_id}` |
| macOS/iOS/Android | NSUserDefaults / SharedPreferences | 同上 |

**原因**：`path_provider` 在 Web 上不支持（`getApplicationSupportDirectory` 抛出 MissingPluginException），而 `shared_preferences` 全平台兼容。

**大小限制**：localStorage 约 5MB 每域名，快照数据（几百条文本 JSON）远低于此限制。

### 2.3 JSON Schema

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-05-26T12:00:00.000Z",
  "accounts": [
    {
      "id": "a1b2c3d4-...",
      "memberId": "m1-...",
      "name": "招行工资卡",
      "type": "debit_card",
      "sortOrder": 1
    },
    {
      "id": "e5f6g7h8-...",
      "memberId": "m1-...",
      "name": "招行信用卡",
      "type": "credit_card",
      "sortOrder": 2
    }
  ],
  "snapshots": [
    {
      "id": "s1-...",
      "accountId": "a1b2c3d4-...",
      "recordDate": "2026-05-26T10:30:00.000Z",
      "assetAmount": 52300.00,
      "liabilityAmount": 0,
      "activeIncome": 15000.00,
      "notes": "发工资了"
    },
    {
      "id": "s2-...",
      "accountId": "e5f6g7h8-...",
      "recordDate": "2026-05-26T10:30:00.000Z",
      "assetAmount": 0,
      "liabilityAmount": 3200.00,
      "activeIncome": 0,
      "notes": null
    }
  ]
}
```

---

## 3. 数据模型 (Dart)

### 3.1 渠道类型枚举

```dart
enum AccountType {
  debitCard('储蓄卡', 'debit_card'),
  creditCard('信用卡', 'credit_card'),
  alipay('支付宝', 'alipay'),
  wechat('微信', 'wechat'),
  cash('现金', 'cash'),
  investment('理财/基金', 'investment'),
  loan('贷款', 'loan'),
  other('其他', 'other');

  final String label;
  final String dbValue;
  const AccountType(this.label, this.dbValue);
  static AccountType fromString(String value) { /* ... */ }
}
```

### 3.2 账户模型

```dart
class FinanceAccount {
  final String id;
  final String memberId;
  final String name;
  final AccountType type;
  final int sortOrder;

  const FinanceAccount({
    required this.id,
    required this.memberId,
    required this.name,
    required this.type,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => { /* ... */ };
  factory FinanceAccount.fromJson(Map<String, dynamic> json) => /* ... */;
}
```

### 3.3 快照模型

```dart
class FinanceSnapshot {
  final String id;
  final String accountId;
  final DateTime recordDate;
  final double assetAmount;
  final double liabilityAmount;
  final double activeIncome;    // 用户确认的主动收入，默认 0
  final String? notes;

  const FinanceSnapshot({
    required this.id,
    required this.accountId,
    required this.recordDate,
    required this.assetAmount,
    required this.liabilityAmount,
    this.activeIncome = 0,
    this.notes,
  });

  /// 净资产
  double get netWorth => assetAmount - liabilityAmount;

  Map<String, dynamic> toJson() => { /* ... */ };
  factory FinanceSnapshot.fromJson(Map<String, dynamic> json) => /* ... */;
}
```

### 3.4 财务数据容器

```dart
class FinanceData {
  final int schemaVersion;
  final DateTime updatedAt;
  final List<FinanceAccount> accounts;
  final List<FinanceSnapshot> snapshots;

  // ... toJson / fromJson
}
```

---

## 4. 核心业务逻辑

### 4.1 智能收入判断

```
输入新快照时：

1. 查找该账户最近一次快照
2. 计算 Δ净资产 = 新净资产 - 旧净资产

3. 根据 Δ净资产 判断：
   ├── |Δ净资产| < ¥100 且 Δ净资产 > 0
   │   └── 自动标记为被动收入（零打扰）
   │
   ├── Δ净资产 ≥ ¥100
   │   └── 弹出确认框：「本次新增 ¥xxx，是否包含主动收入？」
   │       用户填写主动收入金额后：
   │       - 主动收入 = 用户填写值
   │       - 被动收入 = Δ净资产 - 主动收入
   │       （如果主动收入留空，全部算被动收入）
   │
   ├── Δ净资产 < 0
   │   └── 算作支出，不弹窗
   │
   └── 首次快照（无上次记录）
       └── 初始值，不计入任何收入，静默保存
```

**阈值配置**：
```dart
class FinanceConfig {
  static const double activeIncomeThreshold = 100.0; // 默认 ¥100
}
```

### 4.2 核心指标计算

所有计算基于快照的**家庭维度聚合**，跨账户转账在家庭层面自然抵消。

```dart
class FinanceCalculator {
  /// 获取指定月份的快照范围
  static (DateTime start, DateTime end) _monthRange(int year, int month);

  /// 计算某月的总收入（主动 + 被动）
  static double totalIncome(List<FinanceSnapshot> monthSnapshots);

  /// 计算某月的净资产变化
  static double netWorthChange(
    List<FinanceSnapshot> allSnapshots,
    int year, int month,
  );

  /// 计算某月的总支出
  /// 公式：月支出 = 月总收入 - 月净资产变化
  static double totalExpense(
    List<FinanceSnapshot> monthSnapshots,
    List<FinanceSnapshot> allSnapshots,
    int year, int month,
  );

  /// 计算某月的被动收入覆盖率
  /// 公式：被动收入覆盖率 = 当月被动收入 ÷ 当月总支出 × 100%
  static double passiveIncomeCoverageRatio(
    List<FinanceSnapshot> monthSnapshots,
    List<FinanceSnapshot> allSnapshots,
    int year, int month,
  );

  /// 计算储蓄率
  /// 公式：储蓄率 = 净资产变化 ÷ 总收入 × 100%
  static double savingsRate(
    List<FinanceSnapshot> monthSnapshots,
    List<FinanceSnapshot> allSnapshots,
    int year, int month,
  );
}
```

### 4.3 自定义计算流程

```
用户场景：3月份家庭财务数据

Step 1: 筛选所有3月份的快照
Step 2: 计算 主动收入总额 = sum(快照.activeIncome)
Step 3: 计算 被动收入总额 = sum(快照.Δ净资产 - 主动收入)
         = (3月末净资产 - 2月末净资产) - 主动收入总额
Step 4: 总收入 = 主动收入 + 被动收入
Step 5: 净资产变化 = 3月末净资产 - 2月末净资产
Step 6: 总支出 = 总收入 - 净资产变化
Step 7: 覆盖比 = 被动收入 / 总支出 × 100%
```

---

## 5. JSON 存储层

### 5.1 文件结构

```
lib/data/finance/
├── finance_storage.dart         # JSON 文件读写
├── finance_calculator.dart      # 核心指标计算
├── finance_snapshot_analyzer.dart # 智能预判逻辑
├── models/
│   ├── finance_account.dart     # 账户模型
│   ├── finance_snapshot.dart    # 快照模型
│   └── finance_data.dart        # 数据容器
```

### 5.2 FinanceStorage

```dart
/// JSON 文件存储封装
class FinanceStorage {
  static FinanceStorage? _instance;
  static FinanceStorage get instance => _instance ??= FinanceStorage._();

  String? _basePath;

  Future<String> get _storagePath async {
    if (_basePath == null) {
      final dir = await getApplicationSupportDirectory();
      _basePath = '${dir.path}/finance';
      await Directory(_basePath!).create(recursive: true);
    }
    return _basePath!;
  }

  Future<File> _getFile(String householdId) async {
    final path = await _storagePath;
    return File('$path/$householdId.json');
  }

  /// 读取完整数据
  Future<FinanceData> load(String householdId) async {
    final file = await _getFile(householdId);
    if (!file.existsSync()) {
      return FinanceData.empty();
    }
    final json = jsonDecode(await file.readAsString());
    return FinanceData.fromJson(json);
  }

  /// 保存完整数据
  Future<void> save(String householdId, FinanceData data) async {
    data.updatedAt = DateTime.now();
    final file = await _getFile(householdId);
    await file.writeAsString(jsonEncode(data.toJson()));
  }

  // ============ 账户操作 ============

  Future<List<FinanceAccount>> getAccounts(String householdId) async {
    final data = await load(householdId);
    return data.accounts;
  }

  Future<void> addAccount(String householdId, FinanceAccount account) async {
    final data = await load(householdId);
    data.accounts.add(account);
    await save(householdId, data);
  }

  Future<void> deleteAccount(String householdId, String accountId) async {
    final data = await load(householdId);
    data.accounts.removeWhere((a) => a.id == accountId);
    data.snapshots.removeWhere((s) => s.accountId == accountId);
    await save(householdId, data);
  }

  // ============ 快照操作 ============

  Future<List<FinanceSnapshot>> getSnapshots(
    String householdId, {
    String? accountId,
  }) async {
    final data = await load(householdId);
    var snapshots = data.snapshots;
    if (accountId != null) {
      snapshots = snapshots.where((s) => s.accountId == accountId).toList();
    }
    return snapshots..sort((a, b) => b.recordDate.compareTo(a.recordDate));
  }

  Future<void> addSnapshot(
    String householdId,
    FinanceSnapshot snapshot,
  ) async {
    final data = await load(householdId);
    data.snapshots.add(snapshot);
    await save(householdId, data);
  }

  Future<void> deleteSnapshot(
    String householdId,
    String snapshotId,
  ) async {
    final data = await load(householdId);
    data.snapshots.removeWhere((s) => s.id == snapshotId);
    await save(householdId, data);
  }
}
```

### 5.3 FinanceSnapshotAnalyzer

```dart
/// 智能预判逻辑
class FinanceSnapshotAnalyzer {
  /// 分析新快照，返回是否需要弹窗确认主动收入
  static AnalysisResult analyze(
    FinanceSnapshot newSnapshot,
    FinanceSnapshot? previousSnapshot,
  ) {
    // 首次快照：不计收入
    if (previousSnapshot == null) {
      return AnalysisResult(
        action: AnalysisAction.none,
        netWorthChange: 0,
      );
    }

    final delta = newSnapshot.netWorth - previousSnapshot.netWorth;

    // 净资产下降：支出
    if (delta < 0) {
      return AnalysisResult(
        action: AnalysisAction.expense,
        netWorthChange: delta,
      );
    }

    // 小额增长：自动被动收入
    if (delta < FinanceConfig.activeIncomeThreshold) {
      return AnalysisResult(
        action: AnalysisAction.passiveIncome,
        netWorthChange: delta,
      );
    }

    // 大额增长：需要确认主动收入
    return AnalysisResult(
      action: AnalysisAction.askActiveIncome,
      netWorthChange: delta,
    );
  }
}

enum AnalysisAction {
  none,               // 首次快照，不计
  passiveIncome,      // 自动归为被动收入
  askActiveIncome,    // 大额，弹窗询问
  expense,            // 支出
}

class AnalysisResult {
  final AnalysisAction action;
  final double netWorthChange;
  // ...
}
```

---

## 6. UI 结构

### 6.1 页面清单

```
lib/features/finance/
├── pages/
│   ├── finance_home_page.dart         # 财务总览主页
│   ├── finance_accounts_page.dart     # 账户管理（增删）
│   ├── account_detail_page.dart       # 账户详情 + 快照历史
│   ├── snapshot_create_page.dart      # 录快照页（含智能弹窗）
│   └── member_accounts_page.dart      # 某成员的所有账户
├── widgets/
│   ├── finance_home_card.dart         # 首页卡片（含金币粒子动画）
│   └── active_income_dialog.dart      # 主动收入确认弹窗
└── providers/
    └── finance_providers.dart         # 10+ 个 Provider（数据/账户/快照/指标）
```

### 6.2 路由

```
# 财务模块路由（在 ShellRoute 内）
/home/finance              → FinanceHomePage（财务总览）
/home/finance/member/:id   → MemberAccountsPage（成员账户列表）
/home/finance/accounts     → AccountListPage（账户管理）
/home/finance/account/:id  → AccountDetailPage（账户详情 + 快照历史）
/home/finance/snapshot/add → SnapshotCreatePage（录快照）
/home/finance/analytics    → FinanceAnalyticsPage（分析统计页）
```

### 6.3 首页卡片

在 `DashboardPage` 上添加财务概览卡片，使用 `ConsumerStatefulWidget` 实现动画效果。

**布局**：

```
┌─────────────────────────────────────────┐
│ 💰 财务概览                      ›      │
│                                          │
│ 总资产 ¥52,300   总负债 ¥3,200          │
│ 净资产 ¥49,100                           │
│                                          │
│ 🏝️ 财富自由进度                13.0%   │
│ ▓▓▓▓░░░░░░░░░░░░░░░░░░░                 │
│ 被动收入 ¥200   月支出 ¥1,500           │
│                                          │
│ 🪙 +¥12 （金币粒子从底部飘起）         │
└─────────────────────────────────────────┘
```

**动画效果**：

- **金币粒子**：每 2-4 秒从底部飘起一个金币图标（🪙 +¥X），3.5 秒后淡出消失
- 金额根据当月净资产变化 ÷ 已过天数算出日均值
- 资产增加飘金币（🪙），支出/负债增加飘 💸
- **财富自由进度条**：纯展示，不做动效干扰

**关键指标**：

| 指标 | 公式 | 含义 |
|------|------|------|
| 财富自由进度 | 月被动收入 ÷ 月总支出 × 100% | 离"不工作也够花"多远 |
| 日均增长 | 月净资产变化 ÷ 当月已过天数 | 每天大概攒多少钱 |

### 6.4 录快照流程

```
Page: SnapshotCreatePage

① 选择成员 → ② 选择账户 → ③ 输入资产金额 → ④ 输入负债金额（可选）→ ⑤ 确认
                                                                          │
                                                     ┌────────────────────┘
                                                     ▼
                                         智能预判分析（analyze）
                                                     │
                                           ┌─────────┼─────────┐
                                           ▼         ▼         ▼
                                     无弹窗     弹窗询问     无弹窗
                                    （被动收入） （主动收入）  （支出 / 首次）
                                                           （收入自动忽略）

确认弹窗：
┌───────────────────────────────┐
│ 本次新增 ¥5,300               │
│                               │
│ 是否包含主动收入？             │
│ （如工资、奖金、红包等）       │
│                               │
│ 主动收入金额 [_________] ¥    │
│ 备注 [________________]       │
│                               │
│    跳过       确认            │
└───────────────────────────────┘
```

### 6.5 关键页面布局

#### FinanceHomePage（财务总览）

```
AppBar: 财务概览
Body:
├── 时间选择器（← 2026年5月 →）
├── NetWorthSummaryCard（总净资产 + 月度变化）
├── MonthlyOverviewCard（收入 / 支出 / 结余）
├── CoverageRatioChart（被动收入覆盖比环形图）
├── 成员概览区
│   ├── 👨 爸爸 → 净资产 ¥152,000（展开看账户列表）
│   └── 👩 妈妈 → 净资产 ¥96,300
└── 快捷操作区
    ├── [+ 录快照]
    └── [管理账户]
```

#### AccountDetailPage（账户详情）

```
AppBar: 招行工资卡
Body:
├── 账户摘要卡片
│   ├── 当前资产 ¥52,300
│   ├── 当前负债 ¥0
│   ├── 净资产 ¥52,300
│   └── 本月净变化 +¥2,300
├── 操作区
│   ├── [+ 录新快照]
│   └── [删除账户]
└── 快照历史列表（倒序）
    ├── 5/26 资产 ¥52,300  负债 ¥0  收入 +¥15,000
    ├── 5/10 资产 ¥37,000  负债 ¥0  自动(利息)
    └── 4/28 资产 ¥36,800  负债 ¥0  初始记录
```

---

## 7. Provider 层

```dart
/// 1. 存储单例注入
final financeStorageProvider = Provider<FinanceStorage>((ref) {
  return FinanceStorage.instance;
});

/// 2. 家庭财务数据
final financeDataProvider = FutureProvider.family<FinanceData, String>(
  (ref, householdId) async {
    final storage = ref.watch(financeStorageProvider);
    return storage.load(householdId);
  },
);

/// 3. 账户列表
final financeAccountsProvider = FutureProvider.family<List<FinanceAccount>, String>(
  (ref, householdId) async {
    final data = await ref.watch(financeDataProvider(householdId).future);
    return data.accounts;
  },
);

/// 4. 快照列表
final financeSnapshotsProvider = FutureProvider.family<List<FinanceSnapshot>, String>(
  (ref, householdId) async {
    final data = await ref.watch(financeDataProvider(householdId).future);
    return data.snapshots;
  },
);

/// 5. 月度财务指标
final monthlyFinanceMetricsProvider =
  FutureProvider.family<MonthlyMetrics, ({String householdId, int year, int month})>(
  (ref, params) async {
    final data = await ref.watch(financeDataProvider(params.householdId).future);
    return FinanceCalculator.calculateMonthly(data.snapshots, params.year, params.month);
  },
);

/// 6. 账户可用余额列表（用于录入时选择）
final memberAccountsProvider =
  Provider.family<List<FinanceAccount>, String>((ref, memberId) {
  // 从 accounts 中筛选属于该成员的
});
```

---

## 8. 开发检查清单

### Phase 1: 数据层

- [ ] 创建 `models/finance_account.dart`（账户模型 + AccountType 枚举）
- [ ] 创建 `models/finance_snapshot.dart`（快照模型）
- [ ] 创建 `models/finance_data.dart`（数据容器 + JSON 序列化）
- [ ] 创建 `finance_storage.dart`（JSON 文件读写 + CRUD）
- [ ] 创建 `finance_calculator.dart`（核心指标计算）
- [ ] 创建 `finance_snapshot_analyzer.dart`（智能预判逻辑）

### Phase 2: UI 层

- [ ] 创建 `providers/`（Provider 层）
- [ ] 创建 `widgets/finance_home_card.dart`（首页卡片）
- [ ] 创建 `pages/finance_home_page.dart`（财务总览页）
- [ ] 创建 `pages/account_list_page.dart`（账户管理页）
- [ ] 创建 `pages/account_detail_page.dart`（账户详情页）
- [ ] 创建 `pages/snapshot_create_page.dart`（录快照页 + 智能弹窗）
- [ ] 创建 `widgets/coverage_ratio_chart.dart`（被动收入覆盖比环形图）
- [ ] 配置路由
- [ ] 首页集成财务卡片

### Phase 3: 增强

- [ ] 创建 `pages/finance_analytics_page.dart`（月度趋势分析页）
- [ ] 趋势图表（月度净资产 / 收入 / 支出折线图）
- [ ] 支出分布图
- [ ] 被动收入覆盖比趋势

---

## 9. 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-05-26 | 初始版本，完成完整设计 |
| v1.1 | 2026-05-26 | 确认存储方案为纯 JSON 文件 |

---

## 附录: 指标计算示例

### 场景：家庭3月份财务

```
家庭有两个成员：爸爸、妈妈
爸爸账户：招行卡 + 余额宝
妈妈账户：微信

2月底快照：
  招行卡: 资产 ¥50,000  负债 ¥0
  余额宝: 资产 ¥20,000  负债 ¥0
  微信:   资产 ¥5,000   负债 ¥0
  家庭净资产: ¥75,000

3月份录入：
  招行卡 3/5:  资产 ¥48,000  负债 ¥0          → 支出 ¥2,000
  招行卡 3/15: 资产 ¥63,000  负债 ¥0 主动+15k  → 主动收入 ¥15,000（弹窗确认）
  余额宝 3/20: 资产 ¥20,050  负债 ¥0          → 被动收入 ¥50（自动）
  微信 3/25:   资产 ¥3,000   负债 ¥0           → 支出 ¥2,000

3月汇总：
  主动收入: ¥15,000
  被动收入: ¥50
  总收入:   ¥15,050
  净资产:   (48k-0) + (20,050-0) + (3,000-0) = ¥71,050 → 3月净资产 ¥71,050
  2月净资产: ¥75,000
  净资产变化: ¥71,050 - ¥75,000 = -¥3,950（3月花得比赚的多）
  总支出: ¥15,050 - (-¥3,950) = ¥19,000
  被动收入覆盖率: ¥50 ÷ ¥19,000 ≈ 0.26%

注：净资产下降是因为 3/5 支出 ¥2,000 + 3/25 支出 ¥2,000 + 3/15 发工资前可能有大额支出
    （只录了部分快照，中间的支出被快照间隔覆盖了）
```

---

*文档结束*
