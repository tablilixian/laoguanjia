import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../household/providers/household_provider.dart';
import '../providers/tasks_provider.dart';
import '../../../data/models/task.dart';
import '../../../data/models/member.dart';

class TaskDetailPage extends ConsumerWidget {
  final String taskId;

  const TaskDetailPage({
    super.key,
    required this.taskId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksProvider);
    final householdState = ref.watch(householdProvider);
    final theme = Theme.of(context);

    final task = tasksState.tasks.where((t) => t.id == taskId).firstOrNull;

    if (task == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('任务详情'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                '任务不存在',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/home/tasks'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    final assignedMember = householdState.members.firstWhere(
      (m) => m.id == task.assignedTo,
      orElse: () => householdState.members.first,
    );

    final createdByMember = householdState.members.firstWhere(
      (m) => m.id == task.createdBy,
      orElse: () => householdState.members.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home/tasks'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/home/tasks/create', extra: task.id),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outlined),
            color: Colors.red,
            onPressed: () => _showDeleteConfirmDialog(context, ref, task),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleSection(context, task, theme),
            const SizedBox(height: 24),
            _buildStatusSection(context, ref, task, theme),
            const SizedBox(height: 24),
            _buildInfoSection(context, task, assignedMember, createdByMember, theme),
            const SizedBox(height: 24),
            _buildDescriptionSection(context, task, theme),
            const SizedBox(height: 24),
            _buildMetaSection(context, task, theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection(
    BuildContext context,
    Task task,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.task_alt_outlined,
            color: theme.colorScheme.onPrimaryContainer,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              task.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    WidgetRef ref,
    Task task,
    ThemeData theme,
  ) {
    final isOverdue = task.isOverdue && !task.isCompleted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.shade50
            : task.isCompleted
                ? Colors.green.shade50
                : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? Colors.red.shade200
              : task.isCompleted
                  ? Colors.green.shade200
                  : theme.colorScheme.outline,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            task.isCompleted
                ? Icons.check_circle
                : (isOverdue ? Icons.warning : Icons.pending_outlined),
            color: task.isCompleted
                ? Colors.green
                : (isOverdue ? Colors.red : theme.colorScheme.primary),
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.isCompleted ? '已完成' : (isOverdue ? '已过期' : '待办'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: task.isCompleted
                        ? Colors.green.shade700
                        : (isOverdue ? Colors.red.shade700 : theme.colorScheme.primary),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (task.completedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '完成时间：${_formatDateTime(task.completedAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!task.isCompleted)
            FilledButton.icon(
              onPressed: () {
                ref.read(tasksProvider.notifier).toggleTaskStatus(task.id);
              },
              icon: const Icon(Icons.check),
              label: const Text('标记完成'),
              style: FilledButton.styleFrom(
                backgroundColor: task.isCompleted
                    ? Colors.green
                    : theme.colorScheme.primary,
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () {
                ref.read(tasksProvider.notifier).toggleTaskStatus(task.id);
              },
              icon: const Icon(Icons.undo),
              label: const Text('撤销完成'),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    Task task,
    Member assignedMember,
    Member createdByMember,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            context,
            Icons.calendar_today_outlined,
            '截止日期',
            task.dueDate != null
                ? _formatDateTime(task.dueDate!)
                : '无截止日期',
            theme,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.person_outline,
            '指派给',
            assignedMember.name,
            theme,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.create_outlined,
            '创建人',
            createdByMember.name,
            theme,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.access_time,
            '创建时间',
            _formatDateTime(task.createdAt),
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          '$label：',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(
    BuildContext context,
    Task task,
    ThemeData theme,
  ) {
    if (task.description == null || task.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '描述',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            task.description!,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaSection(
    BuildContext context,
    Task task,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetaRow(
            context,
            Icons.repeat,
            '重复规则',
            _getRecurrenceLabel(task.recurrence),
            theme,
          ),
          const SizedBox(height: 12),
          _buildMetaRow(
            context,
            Icons.info_outline,
            '状态',
            task.status.name == 'completed' ? '已完成' : '待办',
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          '$label：',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    Task task,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.go('/home/tasks'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push('/home/tasks/create', extra: task.id),
            icon: const Icon(Icons.edit),
            label: const Text('编辑'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getRecurrenceLabel(TaskRecurrence recurrence) {
    switch (recurrence) {
      case TaskRecurrence.none:
        return '不重复';
      case TaskRecurrence.daily:
        return '每天';
      case TaskRecurrence.weekly:
        return '每周';
      case TaskRecurrence.monthly:
        return '每月';
    }
  }

  Future<void> _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除"${task.title}"吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref.read(tasksProvider.notifier).deleteTask(task.id);
      if (context.mounted) {
        context.go('/home/tasks');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('任务已删除'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
