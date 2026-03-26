# 日志系统使用指南

## 概述

本项目使用统一的日志系统 `AppLogger` 来管理所有日志输出，支持日志级别控制、模块开关等功能。

## 功能特性

- ✅ 日志级别控制（debug、info、warning、error）
- ✅ 全局开关
- ✅ 模块级别开关
- ✅ 自动添加时间戳和模块标识
- ✅ 使用 emoji 图标区分日志级别
- ✅ 支持错误堆栈跟踪

## 使用方法

### 1. 基本使用

```dart
import 'package:laoguanjia/core/utils/logger.dart';

// 使用静态方法
AppLogger.debug('这是一条调试信息');
AppLogger.info('这是一条普通信息');
AppLogger.warning('这是一条警告信息');
AppLogger.error('这是一条错误信息');

// 使用 Logger 实例（推荐）
final logger = Logger('ItemSyncService');
logger.debug('开始同步...');
logger.info('同步完成');
logger.warning('同步超时');
logger.error('同步失败', error: e, stackTrace: stackTrace);
```

### 2. 在类中使用

```dart
class ItemSyncService {
  final Logger _logger = Logger('ItemSyncService');

  Future<void> sync() async {
    _logger.debug('开始同步...');
    
    try {
      // 业务逻辑
      _logger.info('同步成功');
    } catch (e, stackTrace) {
      _logger.error('同步失败', error: e, stackTrace: stackTrace);
    }
  }
}
```

### 3. 日志级别控制

```dart
// 在应用启动时设置（main.dart）
void main() {
  // 设置最小日志级别
  AppLogger.setMinLevel(LogLevel.info); // 只显示 info 及以上级别

  // 或者完全禁用日志
  AppLogger.setEnabled(false);

  runApp(MyApp());
}
```

### 4. 模块开关

```dart
// 禁用特定模块的日志
AppLogger.setModuleEnabled('ItemSyncService', false);
AppLogger.setModuleEnabled('SyncEngine', false);

// 启用特定模块的日志
AppLogger.setModuleEnabled('PaginatedItemsNotifier', true);
```

### 5. 日志级别说明

| 级别 | Emoji | 用途 | 示例 |
|------|-------|------|------|
| debug | 🔵 | 调试信息，详细的状态跟踪 | '开始加载第一页' |
| info | ✅ | 正常操作信息，重要的业务流程 | '同步完成，更新了 10 个物品' |
| warning | ⚠️ | 警告信息，不影响功能但需要注意 | '同步已在进行中，跳过' |
| error | 🔴 | 错误信息，功能异常 | '同步失败: NetworkException' |

## 迁移指南

### 从 print 迁移到 Logger

**之前：**
```dart
print('🔄 [ItemSyncService] 开始同步...');
print('✅ [ItemSyncService] 同步完成');
print('🔴 [ItemSyncService] 同步失败: $e');
```

**之后：**
```dart
final logger = Logger('ItemSyncService');

logger.debug('开始同步...');
logger.info('同步完成');
logger.error('同步失败', error: e);
```

### 批量替换建议

1. 在类中添加 Logger 实例：
```dart
final Logger _logger = Logger('ClassName');
```

2. 使用正则表达式批量替换：
- `print\('🔵 \[ClassName\] (.+)'\)` → `_logger.debug('$1')`
- `print\('✅ \[ClassName\] (.+)'\)` → `_logger.info('$1')`
- `print\('⚠️ \[ClassName\] (.+)'\)` → `_logger.warning('$1')`
- `print\('🔴 \[ClassName\] (.+)'\)` → `_logger.error('$1')`

## 最佳实践

1. **使用 Logger 实例而不是静态方法**
   - 更清晰，便于模块级别控制
   - 自动添加模块标识

2. **合理使用日志级别**
   - `debug`: 详细的调试信息，只在开发时使用
   - `info`: 重要的业务流程信息，生产环境也需要
   - `warning`: 潜在问题，但不影响功能
   - `error`: 错误信息，需要关注和修复

3. **错误日志包含堆栈**
   ```dart
   try {
     // 代码
   } catch (e, stackTrace) {
     _logger.error('操作失败', error: e, stackTrace: stackTrace);
   }
   ```

4. **避免在循环中打印大量日志**
   - 使用汇总日志代替
   - 例如：`logger.info('处理了 100 个物品')` 而不是打印每个物品

## 配置示例

### 开发环境
```dart
AppLogger.setMinLevel(LogLevel.debug);
AppLogger.setEnabled(true);
```

### 生产环境
```dart
AppLogger.setMinLevel(LogLevel.info);
AppLogger.setModuleEnabled('SyncEngine', false); // 关闭详细同步日志
```

### 完全禁用
```dart
AppLogger.setEnabled(false);
```

## 常见问题

**Q: 如何在发布版本中禁用所有日志？**
```dart
// 在 main.dart 中
void main() {
  if (kReleaseMode) {
    AppLogger.setEnabled(false);
  }
  runApp(MyApp());
}
```

**Q: 如何只看某个模块的日志？**
```dart
// 先禁用所有模块
AppLogger.setEnabled(false);

// 只启用需要的模块
AppLogger.setModuleEnabled('ItemSyncService', true);
```

**Q: 日志会输出到控制台还是文件？**
- 目前只输出到控制台
- 未来可以扩展支持文件输出
