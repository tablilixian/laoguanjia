import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/core/services/pet_butler_service.dart';
import 'package:home_manager/data/models/task.dart';
import 'package:home_manager/features/household/providers/household_provider.dart';

/// 任务管家页
///
/// 展示任务提醒、智能建议、完成庆祝。
class PetV2TasksPage extends ConsumerStatefulWidget {
  const PetV2TasksPage({super.key});

  @override
  ConsumerState<PetV2TasksPage> createState() => _PetV2TasksPageState();
}

class _PetV2TasksPageState extends ConsumerState<PetV2TasksPage> {
  List<TaskAlert> _alerts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final household = ref.read(householdProvider).currentHousehold;
      if (household == null) {
        setState(() {
          _error = '请先加入或创建一个家庭';
          _isLoading = false;
        });
        return;
      }

      final butler = PetButlerService();
      final briefing = await butler.generateBriefing(
        householdId: household.id,
        petName: '管家',
      );

      setState(() {
        _alerts = briefing.taskAlerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'urgent':
        return const Color(0xFFFF5252);
      case 'today':
        return const Color(0xFFFF9800);
      case 'tomorrow':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  String _getUrgencyIcon(String urgency) {
    switch (urgency) {
      case 'urgent':
        return '🔴';
      case 'today':
        return '🟡';
      case 'tomorrow':
        return '🟢';
      default:
        return '⚪';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '任务管家',
          style: TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF5D4037)),
            onPressed: _isLoading ? null : _loadTasks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🎉', style: TextStyle(fontSize: 64)),
                          const SizedBox(height: 16),
                          const Text(
                            '太棒了！没有待办任务',
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF5D4037),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '好好享受悠闲时光吧~',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _alerts.length,
                      itemBuilder: (context, index) {
                        final alert = _alerts[index];
                        return _buildTaskCard(alert);
                      },
                    ),
    );
  }

  Widget _buildTaskCard(TaskAlert alert) {
    final task = alert.task;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getUrgencyColor(alert.urgency).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_getUrgencyIcon(alert.urgency),
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    alert.urgency == 'urgent'
                        ? '紧急'
                        : alert.urgency == 'today'
                            ? '今天'
                            : '明天',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: _getUrgencyColor(alert.urgency),
                  padding: EdgeInsets.zero,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description!,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
            if (task.dueDate != null) ...[
              const SizedBox(height: 8),
              Text(
                '⏰ ${_formatDueDate(task.dueDate!)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            if (task.assignedTo != null) ...[
              const SizedBox(height: 4),
              Text(
                '👤 负责人: ${task.assignedTo}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('延期'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _completeTask(task),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDueDate(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final diff = dueDay.difference(today).inDays;

    final timeStr =
        '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';

    if (diff == 0) return '今天 $timeStr';
    if (diff == 1) return '明天 $timeStr';
    if (diff < 0) return '已逾期';
    return '${due.month}月${due.day}日 $timeStr';
  }

  void _completeTask(Task task) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 任务「${task.title}」完成了！真棒！'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
