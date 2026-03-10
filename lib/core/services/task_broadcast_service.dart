import 'package:intl/intl.dart';
import '../../data/models/task.dart';
import '../../data/models/member.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/ai/ai_service.dart';

class TaskBroadcastService {
  final TaskRepository _taskRepo = TaskRepository();
  final AIService _aiService;

  TaskBroadcastService(this._aiService);

  Future<String> generateBroadcastText(String householdId, List<Member> members) async {
    final tasks = await _taskRepo.getTasks(householdId);

    final formattedTasks = _formatTasksForBroadcast(tasks, members);
    final prompt = _buildBroadcastPrompt(formattedTasks);

    final result = await _aiService.sendMessage(prompt, []);
    return result;
  }

  String _formatTasksForBroadcast(List<Task> tasks, List<Member> members) {
    final memberMap = {for (var m in members) m.id: m.name};
    final pendingTasks = tasks.where((t) => !t.isCompleted).toList();

    if (pendingTasks.isEmpty) {
      return '当前没有任何待完成的任务';
    }

    final buffer = StringBuffer();

    for (int i = 0; i < pendingTasks.length; i++) {
      final task = pendingTasks[i];
      final assignee = task.assignedTo != null
          ? memberMap[task.assignedTo] ?? '未指定'
          : '未指定';
      
      final dueDate = task.dueDate != null
          ? _formatDateTime(task.dueDate!)
          : '未指定';

      buffer.writeln('任务${i + 1}：${task.title}');
      buffer.writeln('  - 负责人：$assignee');
      buffer.writeln('  - 截止时间：$dueDate');
      if (task.description != null && task.description!.isNotEmpty) {
        buffer.writeln('  - 说明：${task.description}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dt.year, dt.month, dt.day);

    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (due == today) {
      return '今天 $timeStr';
    } else if (due == today.add(const Duration(days: 1))) {
      return '明天 $timeStr';
    } else if (due.isBefore(today)) {
      return '已过期';
    } else {
      return '${dt.month}月${dt.day}日 $timeStr';
    }
  }

  String _buildBroadcastPrompt(String formattedTasks) {
    return '''
你是一个温暖的家庭助手。请将以下任务列表转换成自然、流畅的口语化播报。

要求：
1. 开头有友好的问候语
2. 清晰说明每个任务：任务内容、负责人、截止时间
3. 语气亲切，鼓励家庭成员完成任务
4. 如果没有任务，要表现得开心和鼓励
5. 播报长度适中，不要太啰嗦
6. 直接输出播报内容，不要添加格式符号（如星号等）

任务列表：
$formattedTasks

请生成播报内容：
''';
  }
}
