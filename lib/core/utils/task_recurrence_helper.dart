import '../../data/models/task.dart';

class TaskRecurrenceHelper {
  static bool shouldResetTask(Task task) {
    if (task.recurrence == TaskRecurrence.none) {
      return false;
    }

    if (!task.isCompleted || task.dueDate == null) {
      return false;
    }

    final now = DateTime.now();
    final dueDate = task.dueDate!;
    final completedAt = task.completedAt ?? task.createdAt;

    switch (task.recurrence) {
      case TaskRecurrence.daily:
        return _shouldResetDaily(now, dueDate, completedAt);
      case TaskRecurrence.weekly:
        return _shouldResetWeekly(now, dueDate, completedAt);
      case TaskRecurrence.monthly:
        return _shouldResetMonthly(now, dueDate, completedAt);
      case TaskRecurrence.none:
        return false;
    }
  }

  static DateTime? calculateNextDueDate(Task task) {
    if (task.dueDate == null) return null;

    final dueDate = task.dueDate!;
    final now = DateTime.now();

    switch (task.recurrence) {
      case TaskRecurrence.daily:
        final nextDate = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day + 1,
          dueDate.hour,
          dueDate.minute,
        );
        if (nextDate.isBefore(now)) {
          return DateTime(
            now.year,
            now.month,
            now.day + 1,
            dueDate.hour,
            dueDate.minute,
          );
        }
        return nextDate;
      case TaskRecurrence.weekly:
        final nextDate = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day + 7,
          dueDate.hour,
          dueDate.minute,
        );
        if (nextDate.isBefore(now)) {
          return DateTime(
            now.year,
            now.month,
            now.day + 7,
            dueDate.hour,
            dueDate.minute,
          );
        }
        return nextDate;
      case TaskRecurrence.monthly:
        final nextDate = DateTime(
          dueDate.year,
          dueDate.month + 1,
          dueDate.day,
          dueDate.hour,
          dueDate.minute,
        );
        if (nextDate.isBefore(now)) {
          return DateTime(
            now.year,
            now.month + 1,
            dueDate.day,
            dueDate.hour,
            dueDate.minute,
          );
        }
        return nextDate;
      case TaskRecurrence.none:
        return null;
    }
  }

  static Task resetTask(Task task) {
    if (!shouldResetTask(task)) {
      return task;
    }

    final nextDueDate = calculateNextDueDate(task);

    return task.copyWith(
      status: TaskStatus.pending,
      dueDate: nextDueDate,
      completedAt: null,
      updatedAt: DateTime.now(),
    );
  }

  static List<Task> resetTasksIfNeeded(List<Task> tasks) {
    return tasks.map((task) {
      if (shouldResetTask(task)) {
        return resetTask(task);
      }
      return task;
    }).toList();
  }

  static bool _shouldResetDaily(DateTime now, DateTime dueDate, DateTime completedAt) {
    final nowDate = DateTime(now.year, now.month, now.day);
    final completedDate = DateTime(completedAt.year, completedAt.month, completedAt.day);

    return nowDate.isAfter(completedDate);
  }

  static bool _shouldResetWeekly(DateTime now, DateTime dueDate, DateTime completedAt) {
    final nowWeek = _getWeekNumber(now);
    final dueWeek = _getWeekNumber(dueDate);
    final completedWeek = _getWeekNumber(completedAt);

    return nowWeek > dueWeek && nowWeek > completedWeek;
  }

  static bool _shouldResetMonthly(DateTime now, DateTime dueDate, DateTime completedAt) {
    final nowMonth = now.year * 12 + now.month;
    final dueMonth = dueDate.year * 12 + dueDate.month;
    final completedMonth = completedAt.year * 12 + completedAt.month;

    return nowMonth > dueMonth && nowMonth > completedMonth;
  }

  static int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays;
    return (dayOfYear / 7).floor() + 1;
  }

  static String getRecurrenceLabel(TaskRecurrence recurrence) {
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

  static String getRecurrenceDescription(TaskRecurrence recurrence) {
    switch (recurrence) {
      case TaskRecurrence.none:
        return '任务完成后不会重复';
      case TaskRecurrence.daily:
        return '任务完成后，每天重复';
      case TaskRecurrence.weekly:
        return '任务完成后，每周重复';
      case TaskRecurrence.monthly:
        return '任务完成后，每月重复';
    }
  }
}
