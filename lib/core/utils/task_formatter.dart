import 'package:intl/intl.dart';
import '../../data/models/task.dart';
import '../../data/models/member.dart';

class TaskFormatter {
  static String formatTasksForAI(List<Task> tasks, List<Member> members) {
    if (tasks.isEmpty) {
      return '当前没有待完成的任务';
    }

    final memberMap = {for (var m in members) m.id: m.name};
    final pendingTasks = tasks.where((t) => !t.isCompleted).toList();

    if (pendingTasks.isEmpty) {
      return '太棒了！所有任务都已完成！';
    }

    final buffer = StringBuffer();
    buffer.writeln('以下是家庭成员需要完成的任务：');
    buffer.writeln('');

    for (int i = 0; i < pendingTasks.length; i++) {
      final task = pendingTasks[i];
      final taskInfo = _formatSingleTask(task, memberMap);
      buffer.writeln('任务${i + 1}：$taskInfo');
    }

    return buffer.toString();
  }

  static String _formatSingleTask(Task task, Map<String, String> memberMap) {
    final parts = <String>[];

    parts.add('任务内容：${task.title}');
    if (task.description != null && task.description!.isNotEmpty) {
      parts.add('详细说明：${task.description}');
    }

    if (task.assignedTo != null && task.assignedTo!.isNotEmpty) {
      final assigneeName = memberMap[task.assignedTo] ?? task.assignedTo;
      parts.add('负责人：$assigneeName');
    }

    if (task.dueDate != null) {
      parts.add('截止时间：${_formatDueDate(task.dueDate!)}');
    }

    if (task.recurrence != TaskRecurrence.none) {
      parts.add('重复类型：${_formatRecurrence(task.recurrence)}');
    }

    return parts.join('，');
  }

  static String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    final timeStr = DateFormat('HH:mm').format(dueDate);

    if (due == today) {
      return '今天 $timeStr';
    } else if (due == today.add(const Duration(days: 1))) {
      return '明天 $timeStr';
    } else if (due == today.subtract(const Duration(days: 1))) {
      return '昨天 $timeStr';
    } else if (due.isBefore(today)) {
      return '已过期 ${DateFormat('MM月dd日').format(due)} $timeStr';
    } else {
      return '${DateFormat('MM月dd日').format(due)} $timeStr';
    }
  }

  static String _formatRecurrence(TaskRecurrence recurrence) {
    switch (recurrence) {
      case TaskRecurrence.daily:
        return '每天';
      case TaskRecurrence.weekly:
        return '每周';
      case TaskRecurrence.monthly:
        return '每月';
      case TaskRecurrence.none:
        return '不重复';
    }
  }
}
