import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import '../../../data/supabase/supabase_client.dart';
import '../../../data/local_db/app_database.dart';
import '../../../data/models/task.dart' as models;
import '../../../data/repositories/task_repository.dart';
import '../../../core/sync/sync_engine.dart';

class DatabaseTestPage extends StatefulWidget {
  const DatabaseTestPage({super.key});

  @override
  State<DatabaseTestPage> createState() => _DatabaseTestPageState();
}

class _DatabaseTestPageState extends State<DatabaseTestPage> {
  final List<TestResult> _results = [];
  bool _isTesting = false;

  String get _platformName {
    if (kIsWeb) return 'Web';
    return 'Native (移动端/桌面端)';
  }

  String get _dbType {
    if (kIsWeb) return 'IndexedDB';
    return 'SQLite';
  }

  Future<void> _runTests() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    _addResult('平台检测', true, '当前平台: $_platformName，数据库: $_dbType');

    await _testSupabaseConnection();
    await _testTableExists('households');
    await _testTableExists('members');
    await _testLocalDbInsert();
    await _testLocalDbQuery();
    await _testLocalDbUpdate();
    await _testLocalDbDelete();
    await _testLocalDbSyncStatus();
    await _testSyncVersionCheck();
    await _testSyncFull();
    await _testTaskRepository();
    await _testSoftDelete();

    setState(() {
      _isTesting = false;
    });
  }

  Future<void> _testSupabaseConnection() async {
    try {
      final client = SupabaseClientManager.client;
      final user = client.auth.currentUser;
      _addResult(
        'Supabase 连接',
        true,
        '连接成功，用户: ${user?.email ?? "未登录"}',
      );
    } catch (e) {
      _addResult(
        'Supabase 连接',
        false,
        '连接失败: ${e.toString()}',
      );
    }
  }

  Future<void> _testTableExists(String tableName) async {
    try {
      final client = SupabaseClientManager.client;
      await client.from(tableName).select('id').limit(1);
      _addResult(
        '表 $tableName',
        true,
        '表存在且可访问',
      );
    } on PostgrestException catch (e) {
      if (e.code == '42P01') {
        _addResult(
          '表 $tableName',
          false,
          '表不存在，请在 Supabase 控制台创建表',
        );
      } else if (e.code == 'PGRST301') {
        _addResult(
          '表 $tableName',
          false,
          'RLS 策略阻止访问，请检查权限设置',
        );
      } else {
        _addResult(
          '表 $tableName',
          false,
          '错误: ${e.message} (代码: ${e.code})',
        );
      }
    } catch (e) {
      _addResult(
        '表 $tableName',
        false,
        '未知错误: ${e.toString()}',
      );
    }
  }

  Future<void> _testLocalDbInsert() async {
    try {
      final db = AppDatabase();
      final now = DateTime.now();
      final task = TasksCompanion(
        id: const Value('debug-test-001'),
        householdId: const Value('debug-household'),
        title: const Value('本地数据库测试任务'),
        description: const Value('这是一个测试任务'),
        recurrence: const Value('none'),
        status: const Value('pending'),
        createdBy: const Value('debug-user'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await db.tasksDao.insertTask(task);
      await db.close();

      _addResult(
        '本地数据库 - 插入',
        true,
        '任务插入成功',
      );
    } catch (e) {
      _addResult(
        '本地数据库 - 插入',
        false,
        '插入失败: ${e.toString()}',
      );
    }
  }

  Future<void> _testLocalDbQuery() async {
    try {
      final db = AppDatabase();
      final task = await db.tasksDao.getById('debug-test-001');
      await db.close();

      if (task != null) {
        _addResult(
          '本地数据库 - 查询',
          true,
          '查询成功: ${task.title} (version: ${task.version})',
        );
      } else {
        _addResult(
          '本地数据库 - 查询',
          false,
          '查询失败: 未找到任务',
        );
      }
    } catch (e) {
      _addResult(
        '本地数据库 - 查询',
        false,
        '查询失败: ${e.toString()}',
      );
    }
  }

  Future<void> _testLocalDbUpdate() async {
    try {
      final db = AppDatabase();
      final updated = TasksCompanion(
        id: const Value('debug-test-001'),
        title: const Value('更新后的标题'),
        updatedAt: Value(DateTime.now()),
      );

      await db.tasksDao.updateTask(updated);
      final task = await db.tasksDao.getById('debug-test-001');
      await db.close();

      if (task != null && task.title == '更新后的标题') {
        _addResult(
          '本地数据库 - 更新',
          true,
          '更新成功: ${task.title}',
        );
      } else {
        _addResult(
          '本地数据库 - 更新',
          false,
          '更新失败: 标题未更新',
        );
      }
    } catch (e) {
      _addResult(
        '本地数据库 - 更新',
        false,
        '更新失败: ${e.toString()}',
      );
    }
  }

  Future<void> _testLocalDbDelete() async {
    try {
      final db = AppDatabase();
      await db.tasksDao.deleteTask('debug-test-001');
      final task = await db.tasksDao.getById('debug-test-001');
      await db.close();

      if (task == null) {
        _addResult(
          '本地数据库 - 删除',
          true,
          '删除成功',
        );
      } else {
        _addResult(
          '本地数据库 - 删除',
          false,
          '删除失败: 任务仍然存在',
        );
      }
    } catch (e) {
      _addResult(
        '本地数据库 - 删除',
        false,
        '删除失败: ${e.toString()}',
      );
    }
  }

  Future<void> _testLocalDbSyncStatus() async {
    try {
      final db = AppDatabase();
      final now = DateTime.now();

      final task = TasksCompanion(
        id: const Value('debug-sync-001'),
        householdId: const Value('debug-household'),
        title: const Value('待同步任务'),
        recurrence: const Value('none'),
        status: const Value('pending'),
        createdBy: const Value('debug-user'),
        createdAt: Value(now),
        updatedAt: Value(now),
        syncPending: const Value(true),
      );

      await db.tasksDao.insertTask(task);
      final pending = await db.tasksDao.getSyncPending();
      await db.tasksDao.markSynced('debug-sync-001');
      final afterSync = await db.tasksDao.getById('debug-sync-001');
      await db.tasksDao.deleteTask('debug-sync-001');
      await db.close();

      if (pending.isNotEmpty && afterSync != null && !afterSync.syncPending) {
        _addResult(
          '本地数据库 - 同步状态',
          true,
          '同步状态管理正常',
        );
      } else {
        _addResult(
          '本地数据库 - 同步状态',
          false,
          '同步状态异常',
        );
      }
    } catch (e) {
      _addResult(
        '本地数据库 - 同步状态',
        false,
        '测试失败: ${e.toString()}',
      );
    }
  }

  Future<void> _testSyncVersionCheck() async {
    try {
      final db = AppDatabase();
      final client = SupabaseClientManager.client;
      final syncEngine = SyncEngine(localDb: db, remoteDb: client);
      
      final lastSync = await syncEngine.getLastSyncTime('last_sync_tasks');
      final needsSync = await syncEngine.needsSync('tasks', lastSync);
      
      await db.close();
      
      _addResult(
        '同步引擎 - 时间戳检查',
        true,
        '上次同步: $lastSync, 需要同步: $needsSync',
      );
    } catch (e) {
      _addResult(
        '同步引擎 - 版本检查',
        false,
        '检查失败: ${e.toString()}',
      );
    }
  }

  Future<void> _testSyncFull() async {
    try {
      final db = AppDatabase();
      final client = SupabaseClientManager.client;
      final syncEngine = SyncEngine(localDb: db, remoteDb: client);
      
      final result = await syncEngine.syncTasks();
      
      await db.close();
      
      if (result.success) {
        _addResult(
          '同步引擎 - 完整同步',
          true,
          '拉取: ${result.pulled}, 推送: ${result.pushed}, 冲突: ${result.conflicts}',
        );
      } else {
        _addResult(
          '同步引擎 - 完整同步',
          false,
          '同步失败: ${result.errors.join(", ")}',
        );
      }
    } catch (e) {
      _addResult(
        '同步引擎 - 完整同步',
        false,
        '同步失败: ${e.toString()}',
      );
    }
  }

  Future<void> _testTaskRepository() async {
    try {
      final repository = TaskRepository();
      final now = DateTime.now();
      final testTaskId = const Uuid().v4();

      final testTask = models.Task(
        id: testTaskId,
        householdId: 'test-household',
        title: '集成测试任务 ${now.hour}:${now.minute}:${now.second}',
        description: '这是一个集成测试任务',
        recurrence: models.TaskRecurrence.none,
        status: models.TaskStatus.pending,
        createdBy: 'test-user',
        createdAt: now,
        updatedAt: now,
      );

      final created = await repository.createTask(testTask);
      _addResult(
        'TaskRepository - 创建',
        true,
        '创建成功: ${created.title}',
      );

      final fetched = await repository.getTaskById(testTaskId);
      if (fetched != null && fetched.title == testTask.title) {
        _addResult(
          'TaskRepository - 查询',
          true,
          '查询成功: ${fetched.title}',
        );
      } else {
        _addResult(
          'TaskRepository - 查询',
          false,
          '查询失败: 未找到任务',
        );
      }

      final toggled = await repository.toggleTaskStatus(testTaskId, true);
      if (toggled.status == models.TaskStatus.completed) {
        _addResult(
          'TaskRepository - 切换状态',
          true,
          '状态切换成功: ${toggled.status.name}',
        );
      } else {
        _addResult(
          'TaskRepository - 切换状态',
          false,
          '状态切换失败',
        );
      }

      await repository.deleteTask(testTaskId);
      final deleted = await repository.getTaskById(testTaskId);
      if (deleted == null || deleted.isDeleted) {
        _addResult(
          'TaskRepository - 删除',
          true,
          '删除成功（软删除）',
        );
      } else {
        _addResult(
          'TaskRepository - 删除',
          false,
          '删除失败: 任务未被标记为删除',
        );
      }
    } catch (e) {
      _addResult(
        'TaskRepository - 集成测试',
        false,
        '测试失败: ${e.toString()}',
      );
    }
  }

  Future<void> _testSoftDelete() async {
    try {
      final repository = TaskRepository();
      final now = DateTime.now();
      final testTaskId = const Uuid().v4();

      final client = SupabaseClientManager.client;
      final userId = client.auth.currentUser?.id;
      
      String householdId = 'test-household';
      try {
        final memberRes = await client
            .from('members')
            .select('household_id')
            .eq('user_id', userId!)
            .limit(1)
            .maybeSingle();
        
        if (memberRes != null) {
          householdId = memberRes['household_id'];
        }
      } catch (e) {}

      final testTask = models.Task(
        id: testTaskId,
        householdId: householdId,
        title: '软删除测试任务 ${now.hour}:${now.minute}:${now.second}',
        description: '这是一个软删除测试任务',
        recurrence: models.TaskRecurrence.none,
        status: models.TaskStatus.pending,
        createdBy: userId ?? 'test-user',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createTask(testTask);
      _addResult(
        '软删除 - 创建任务',
        true,
        '创建成功: ${testTask.title}',
      );

      await repository.deleteTask(testTaskId);
      _addResult(
        '软删除 - 删除任务',
        true,
        '删除成功（软删除）',
      );

      final deletedTasks = await repository.getDeletedTasks(householdId);
      final isDeleted = deletedTasks.any((t) => t.id == testTaskId);
      if (isDeleted) {
        _addResult(
          '软删除 - 查询已删除',
          true,
          '已删除任务查询成功',
        );
      } else {
        _addResult(
          '软删除 - 查询已删除',
          false,
          '未找到已删除任务',
        );
      }

      await repository.restoreTask(testTaskId);
      _addResult(
        '软删除 - 恢复任务',
        true,
        '恢复成功',
      );

      final restoredTask = await repository.getTaskById(testTaskId);
      if (restoredTask != null && !restoredTask.isDeleted) {
        _addResult(
          '软删除 - 验证恢复',
          true,
          '任务已恢复: ${restoredTask.title}',
        );
      } else {
        _addResult(
          '软删除 - 验证恢复',
          false,
          '恢复失败: ${restoredTask?.isDeleted ?? true}',
        );
      }

      await repository.deleteTask(testTaskId);
    } catch (e) {
      _addResult(
        '软删除 - 测试',
        false,
        '测试失败: ${e.toString()}',
      );
    }
  }

  void _addResult(String testName, bool success, String message) {
    setState(() {
      _results.add(TestResult(
        testName: testName,
        success: success,
        message: message,
        timestamp: DateTime.now(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据库测试'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _isTesting ? null : _runTests,
                icon: _isTesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isTesting ? '测试中...' : '运行测试'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 80,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '点击上方按钮开始测试',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: result.success
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                result.success
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: result.success
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            title: Text(
                              result.testName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(result.message),
                            trailing: Text(
                              _formatTime(result.timestamp),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}

class TestResult {
  final String testName;
  final bool success;
  final String message;
  final DateTime timestamp;

  TestResult({
    required this.testName,
    required this.success,
    required this.message,
    required this.timestamp,
  });
}
