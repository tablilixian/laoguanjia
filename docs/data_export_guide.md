# 数据导入/导出系统使用指南

## 架构概览

```
lib/core/services/data_export/
├── data_export_source.dart      # 抽象接口定义
├── data_export_registry.dart    # 注册中心（所有数据源集中注册）
├── data_export_service.dart     # 统一导出/导入服务（文件打包、分享、保存）
└── sources/
    ├── chat_source.dart         # 聊天记录数据源
    ├── pet_interaction_source.dart  # 宠物互动日志数据源
    ├── pet_memory_source.dart   # 宠物记忆数据源
    └── finance_source.dart      # 财务数据数据源

lib/features/data_export/
└── pages/
    └── data_export_page.dart    # 统一导出/导入页面
```

## 核心接口

所有数据源必须实现 `DataExportSource` 抽象类：

```dart
abstract class DataExportSource {
  String get id;           // 唯一标识，如 "chat"
  String get name;         // 显示名称，如 "聊天记录"
  String get description;  // 简短描述
  IconData get icon;       // 图标

  Future<bool> hasData();  // 是否有数据可导出

  /// 导出数据，返回画一个 Map，结构为：
  /// { '<source_id>': { ...data... }, '_meta': { ... } }
  Future<Map<String, dynamic>> exportData();

  /// 导入数据，data 参数是 exportData 返回的 'source_id' 对应的值
  Future<ImportSummary> importData(Map<String, dynamic> data);
}
```

导入返回：

```dart
class ImportSummary {
  final bool success;
  final int itemCount;    // 导入的记录数
  final String? message;  // 提示信息
}
```

## 统一导出格式

所有选定数据源合并成单个 JSON 文件，格式如下：

```json
{
  "exportVersion": "1.0",
  "exportDate": "2026-05-28T12:00:00.000Z",
  "appName": "老管家",
  "sources": ["finance", "chat", "pet_logs", "pet_memories"],
  "data": {
    "finance": { ... },
    "chat": { ... },
    "pet_logs": { ... },
    "pet_memories": { ... }
  }
}
```

## 添加新的数据源（三步完成）

### 第一步：创建数据源类

在 `lib/core/services/data_export/sources/` 下新建文件，实现 `DataExportSource`：

```dart
import 'package:flutter/material.dart';
import '../data_export_source.dart';

class MyNewSource implements DataExportSource {
  @override
  String get id => 'my_new_data';

  @override
  String get name => '我的新数据';

  @override
  String get description => '新数据的描述';

  @override
  IconData get icon => Icons.new_data;

  @override
  Future<bool> hasData() async {
    // 检查是否有数据
    return true;
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    // 读取数据并返回
    return {
      'my_new_data': {
        'items': [...],
        '_meta': {'count': 0},
      },
    };
  }

  @override
  Future<ImportSummary> importData(Map<String, dynamic> data) async {
    try {
      // 解析 data['my_new_data'] 并存储
      return ImportSummary(success: true, itemCount: n, message: '成功');
    } catch (e) {
      return ImportSummary(success: false, itemCount: 0, message: '失败: $e');
    }
  }
}
```

### 第二步：注册到注册中心

编辑 `lib/core/services/data_export/data_export_registry.dart`：

```dart
// 普通数据源（不需要额外参数）
static final List<DataExportSource Function()> sourceFactories = [
  () => ChatSource(),
  () => PetInteractionSource(),
  () => PetMemorySource(),
  () => MyNewSource(),  // ← 加在这里，一行即可
];

// 需要 householdId 的数据源
static final List<DataExportSource Function(String householdId)> householdSourceFactories = [
  (householdId) => FinanceSource(householdId: householdId),
];
```

### 第三步（可选）：需要 householdId 的数据源

如果数据源依赖当前家庭 ID（如财务数据），注册到 `householdSourceFactories` 中。

## 导出方式说明

用户导出时有两种选择：

| 方式 | 说明 | 平台兼容性 |
|------|------|-----------|
| **系统分享** | 调用系统分享菜单（share_plus），可发送到微信、邮件等 | iOS / Android / macOS |
| **保存到本地** | 保存到应用文档目录的 `exports/` 子目录，路径复制到剪贴板 | 所有平台 |

## 文件清单

| 文件 | 功能 |
|------|------|
| `data_export_source.dart` | 抽象接口 + ImportSummary |
| `data_export_registry.dart` | 数据源注册中心 |
| `data_export_service.dart` | 统一打包、分享、保存、解析服务 |
| `sources/finance_source.dart` | 财务数据适配器 |
| `sources/chat_source.dart` | 聊天记录适配器 |
| `sources/pet_interaction_source.dart` | 宠物互动日志适配器 |
| `sources/pet_memory_source.dart` | 宠物记忆适配器 |
| `data_export_page.dart` | 统一导出/导入页面 |

## 注意事项

1. **ID 唯一性**：每个数据源的 `id` 必须在注册中心中唯一，不能与其他数据源重复。
2. **导出格式**：`exportData()` 返回的 Map 必须包含 `'<source_id>': { ... }` 作为键，与 `id` 一致。
3. **幂等导入**：导入操作不应破坏已有数据。聊天和宠物日志为追加导入；财务数据为覆盖导入。
4. **错误处理**：`importData()` 必须捕获所有异常，返回 `ImportSummary` 而非抛出异常。
