import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';

class DirectSupabaseTestPage extends StatefulWidget {
  const DirectSupabaseTestPage({super.key});

  @override
  State<DirectSupabaseTestPage> createState() => _DirectSupabaseTestPageState();
}

class _DirectSupabaseTestPageState extends State<DirectSupabaseTestPage> {
  final List<TestResult> _results = [];
  bool _isTesting = false;
  
  // 直接使用 Supabase 客户端
  final SupabaseClient _directClient = SupabaseClient(
    'https://tkllhxskjgbreqdswvcj.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrbGxoeHNramdicmVxZHN3dmNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3ODExNjEsImV4cCI6MjA4ODM1NzE2MX0.20vFkV_nOfY1jZNBFRimksy_hj4aQ0XXhPk3-RHnSyE',
  );

  Future<void> _runTests() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    await _testDirectConnection();
    await _testHouseholdsTable();
    await _testMembersTable();

    setState(() {
      _isTesting = false;
    });
  }

  Future<void> _testDirectConnection() async {
    try {
      // 测试基本连接
      final response = await _directClient.from('households').select('id').limit(1);
      _addResult(
        '直接连接测试',
        true,
        '连接成功: ${response.toString()}',
      );
    } catch (e) {
      _addResult(
        '直接连接测试',
        false,
        '错误: ${e.toString()}',
      );
    }
  }

  Future<void> _testHouseholdsTable() async {
    try {
      final response = await _directClient.from('households').select('*').limit(3);
      _addResult(
        'households 表',
        true,
        '查询成功: ${response.length} 条记录',
      );
    } catch (e) {
      _addResult(
        'households 表',
        false,
        '错误: ${e.toString()}',
      );
    }
  }

  Future<void> _testMembersTable() async {
    try {
      final response = await _directClient.from('members').select('*').limit(3);
      _addResult(
        'members 表',
        true,
        '查询成功: ${response.length} 条记录',
      );
    } catch (e) {
      _addResult(
        'members 表',
        false,
        '错误: ${e.toString()}',
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
        title: const Text('直接 Supabase 测试'),
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
                    : const Icon(Icons.send),
                label: Text(_isTesting ? '测试中...' : '运行直接测试'),
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
                            Icons.directions_run,
                            size: 80,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '点击上方按钮运行直接测试',
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
