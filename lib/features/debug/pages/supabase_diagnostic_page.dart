import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/supabase/supabase_client.dart';

class SupabaseDiagnosticPage extends StatefulWidget {
  const SupabaseDiagnosticPage({super.key});

  @override
  State<SupabaseDiagnosticPage> createState() => _SupabaseDiagnosticPageState();
}

class _SupabaseDiagnosticPageState extends State<SupabaseDiagnosticPage> {
  final List<DiagnosticResult> _results = [];
  bool _isTesting = false;

  Future<void> _runDiagnostics() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    await _testSupabaseInit();
    await _testAuthState();
    await _testApiKey();
    await _testTables();

    setState(() {
      _isTesting = false;
    });
  }

  Future<void> _testSupabaseInit() async {
    try {
      final isInitialized = SupabaseClientManager.isInitialized;
      _addResult(
        'Supabase 初始化',
        isInitialized,
        isInitialized ? '已初始化' : '未初始化',
      );
    } catch (e) {
      _addResult(
        'Supabase 初始化',
        false,
        '错误: ${e.toString()}',
      );
    }
  }

  Future<void> _testAuthState() async {
    try {
      final client = SupabaseClientManager.client;
      final user = client.auth.currentUser;
      _addResult(
        '认证状态',
        user != null,
        user != null ? '已登录: ${user.email}' : '未登录',
      );
    } catch (e) {
      _addResult(
        '认证状态',
        false,
        '错误: ${e.toString()}',
      );
    }
  }

  Future<void> _testApiKey() async {
    try {
      final client = SupabaseClientManager.client;
      // 尝试一个简单的请求来验证 API key
      await client.from('households').select().limit(1);
      _addResult(
        'API Key 验证',
        true,
        'API Key 有效',
      );
    } catch (e) {
      _addResult(
        'API Key 验证',
        false,
        '错误: ${e.toString()}',
      );
    }
  }

  Future<void> _testTables() async {
    try {
      final client = SupabaseClientManager.client;
      
      // 测试 households 表
      try {
        await client.from('households').select('id').limit(1);
        _addResult(
          'households 表',
          true,
          '表存在且可访问',
        );
      } catch (e) {
        _addResult(
          'households 表',
          false,
          '错误: ${e.toString()}',
        );
      }
      
      // 测试 members 表
      try {
        await client.from('members').select('id').limit(1);
        _addResult(
          'members 表',
          true,
          '表存在且可访问',
        );
      } catch (e) {
        _addResult(
          'members 表',
          false,
          '错误: ${e.toString()}',
        );
      }
    } catch (e) {
      _addResult(
        '表测试',
        false,
        '错误: ${e.toString()}',
      );
    }
  }

  void _addResult(String testName, bool success, String message) {
    setState(() {
      _results.add(DiagnosticResult(
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
        title: const Text('Supabase 诊断'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _isTesting ? null : _runDiagnostics,
                icon: _isTesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bug_report_outlined),
                label: Text(_isTesting ? '诊断中...' : '运行诊断'),
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
                            Icons.system_update_tv_outlined,
                            size: 80,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '点击上方按钮运行诊断',
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

class DiagnosticResult {
  final String testName;
  final bool success;
  final String message;
  final DateTime timestamp;

  DiagnosticResult({
    required this.testName,
    required this.success,
    required this.message,
    required this.timestamp,
  });
}
