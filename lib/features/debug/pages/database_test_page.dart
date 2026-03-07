import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/supabase/supabase_client.dart';

class DatabaseTestPage extends StatefulWidget {
  const DatabaseTestPage({super.key});

  @override
  State<DatabaseTestPage> createState() => _DatabaseTestPageState();
}

class _DatabaseTestPageState extends State<DatabaseTestPage> {
  final List<TestResult> _results = [];
  bool _isTesting = false;

  Future<void> _runTests() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    await _testSupabaseConnection();
    await _testTableExists('households');
    await _testTableExists('members');

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
