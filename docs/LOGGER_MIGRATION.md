# 日志迁移示例

本文档展示如何将现有的 `print()` 语句迁移到新的 `Logger` 系统。

## 迁移步骤

### 步骤 1: 在类中添加 Logger 实例

```dart
class ItemSyncService {
  // 添加这一行
  final Logger _logger = Logger('ItemSyncService');

  // ... 其他代码
}
```

### 步骤 2: 替换 print 语句

#### 示例 1: item_sync_service.dart

**迁移前：**
```dart
print('⚠️ [ItemSyncService] 同步已在进行中，跳过');
print('🔄 [ItemSyncService] 开始自动同步...');
print('✅ [ItemSyncService] 没有待同步的物品');
print('📋 [ItemSyncService] 待同步物品数量: ${pendingItems.length}');
print('🔴 [ItemSyncService] 自动同步失败: $e');
```

**迁移后：**
```dart
_logger.warning('同步已在进行中，跳过');
_logger.debug('开始自动同步...');
_logger.info('没有待同步的物品');
_logger.debug('待同步物品数量: ${pendingItems.length}');
_logger.error('自动同步失败', error: e);
```

#### 示例 2: sync_engine.dart

**迁移前：**
```dart
print('🔄 [SyncEngine] 开始同步物品: localVersion=$localVersion, remoteVersion=$remoteVersion');
print('📤 [SyncEngine] 推送结果: pushed=$pushed, conflicts=$conflicts, errors=${errors.length}');
print('📥 [SyncEngine] 拉取了 $pulled 个物品');
print('✅ [SyncEngine] 物品同步成功，更新版本为 $remoteVersion');
print('❌ [SyncEngine] 物品同步失败: ${errors.join(', ')}');
print('❌ [SyncEngine] 物品同步异常: $e');
```

**迁移后：**
```dart
_logger.debug('开始同步物品: localVersion=$localVersion, remoteVersion=$remoteVersion');
_logger.info('推送结果: pushed=$pushed, conflicts=$conflicts, errors=${errors.length}');
_logger.info('拉取了 $pulled 个物品');
_logger.info('物品同步成功，更新版本为 $remoteVersion');
_logger.error('物品同步失败: ${errors.join(', ')}');
_logger.error('物品同步异常', error: e);
```

#### 示例 3: paginated_items_provider.dart

**迁移前：**
```dart
print('🔵 [PaginatedItemsNotifier] 检查初始家庭状态: householdId=$householdId, isLoading=${householdState.isLoading}');
print('🔵 [PaginatedItemsNotifier] 初始家庭ID存在，开始初始化: $householdId');
print('🔵 [PaginatedItemsNotifier] 家庭状态变化: householdId=$householdId, previous=${previous?.currentHousehold?.id}, isLoading=${next.isLoading}');
print('🔴 [PaginatedItemsNotifier] 家庭ID为空且不在加载中，清空数据');
print('🔴 [PaginatedItemsNotifier] 初始化失败: $e');
print('🔴 [PaginatedItemsNotifier] 堆栈: $stackTrace');
```

**迁移后：**
```dart
_logger.debug('检查初始家庭状态: householdId=$householdId, isLoading=${householdState.isLoading}');
_logger.debug('初始家庭ID存在，开始初始化: $householdId');
_logger.debug('家庭状态变化: householdId=$householdId, previous=${previous?.currentHousehold?.id}, isLoading=${next.isLoading}');
_logger.warning('家庭ID为空且不在加载中，清空数据');
_logger.error('初始化失败', error: e, stackTrace: stackTrace);
```

## 批量替换正则表达式

### VS Code / IntelliJ IDEA

1. 打开 "Find and Replace" (Ctrl+H / Cmd+H)
2. 勾选 "Use Regular Expression"
3. 使用以下正则表达式进行替换

#### 模式 1: 调试日志 (🔵)
```
查找: print\('🔵 \[ClassName\] (.+)'\)
替换: _logger.debug('$1')
```

#### 模式 2: 信息日志 (✅)
```
查找: print\('✅ \[ClassName\] (.+)'\)
替换: _logger.info('$1')
```

#### 模式 3: 警告日志 (⚠️)
```
查找: print\('⚠️ \[ClassName\] (.+)'\)
替换: _logger.warning('$1')
```

#### 模式 4: 错误日志 (🔴)
```
查找: print\('🔴 \[ClassName\] (.+)'\)
替换: _logger.error('$1')
```

#### 模式 5: 其他图标日志
```
查找: print\('(.+?) \[ClassName\] (.+)'\)
替换: _logger.debug('$2')
```

### 通用替换（所有模块）

如果你想一次性替换所有模块的日志：

```
查找: print\('(.+?) \[(.+?)\] (.+)'\)
替换: _logger.$1('$3')
```

注意：这个模式需要手动调整，因为需要根据 emoji 判断日志级别。

## 迁移检查清单

- [ ] 在类中添加 `final Logger _logger = Logger('ClassName');`
- [ ] 替换所有 `print()` 语句为 `_logger.xxx()`
- [ ] 检查日志级别是否合适
- [ ] 错误日志是否包含 `error: e` 和 `stackTrace: stackTrace`
- [ ] 测试日志输出是否正常
- [ ] 验证日志开关功能

## 常见问题

### Q: 如何处理没有 emoji 的 print 语句？

**迁移前：**
```dart
print('Some message');
```

**迁移后：**
```dart
_logger.debug('Some message');
```

### Q: 如何处理包含变量的复杂日志？

**迁移前：**
```dart
print('📥 [ItemSyncService] 从远程获取了 ${remoteItems.length} 个物品，需要同步 ${itemsToSync.length} 个');
```

**迁移后：**
```dart
_logger.debug('从远程获取了 ${remoteItems.length} 个物品，需要同步 ${itemsToSync.length} 个');
```

### Q: 如何处理多行日志？

**迁移前：**
```dart
print('🔍 [SyncEngine] 物品 ${localItem.name} (${localItem.id}):');
print('   本地: version=${localItem.version}, updatedAt=${localItem.updatedAt.toIso8601String()}');
print('   远程: version=$remoteVersion, updatedAt=${remoteUpdatedAt.toIso8601String()}');
```

**迁移后：**
```dart
_logger.debug('物品 ${localItem.name} (${localItem.id}):');
_logger.debug('  本地: version=${localItem.version}, updatedAt=${localItem.updatedAt.toIso8601String()}');
_logger.debug('  远程: version=$remoteVersion, updatedAt=${remoteUpdatedAt.toIso8601String()}');
```

或者合并为一行：
```dart
_logger.debug('物品 ${localItem.name} (${localItem.id}): 本地 version=${localItem.version}, 远程 version=$remoteVersion');
```

## 优先级建议

建议按以下优先级迁移：

1. **高优先级**（核心业务逻辑）
   - item_sync_service.dart
   - sync_engine.dart
   - item_query_service.dart
   - item_command_service.dart

2. **中优先级**（数据层）
   - offline_item_repository.dart
   - item_repository.dart
   - 各个 DAO 文件

3. **低优先级**（UI 层）
   - 各个 Provider 文件
   - 各个 Page 文件

## 迁移后的好处

1. ✅ 可以统一控制所有日志
2. ✅ 可以按模块开关日志
3. ✅ 可以设置日志级别
4. ✅ 错误日志自动包含堆栈
5. ✅ 日志格式统一，便于查看
6. ✅ 生产环境可以完全禁用
