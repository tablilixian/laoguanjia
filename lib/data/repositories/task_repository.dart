import '../models/task.dart';
import '../supabase/supabase_client.dart';

class TaskRepository {
  final _client = SupabaseClientManager.client;

  Future<List<Task>> getTasks(String householdId) async {
    final response = await _client
        .from('tasks')
        .select()
        .eq('household_id', householdId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => Task.fromMap(e))
        .toList();
  }

  Future<List<Task>> getTasksByStatus(
    String householdId,
    String status,
  ) async {
    final response = await _client
        .from('tasks')
        .select()
        .eq('household_id', householdId)
        .eq('status', status)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => Task.fromMap(e))
        .toList();
  }

  Future<Task?> getTaskById(String taskId) async {
    final response = await _client
        .from('tasks')
        .select()
        .eq('id', taskId)
        .maybeSingle();

    if (response == null) return null;

    return Task.fromMap(response);
  }

  Future<Task> createTask(Task task) async {
    print('=== TaskRepository.createTask 开始 ===');
    print('插入数据: ${task.toMap()}');
    
    final response = await _client.from('tasks').insert({
      'household_id': task.householdId,
      'title': task.title,
      'description': task.description,
      'assigned_to': task.assignedTo,
      'due_date': task.dueDate?.toIso8601String(),
      'recurrence': task.recurrence.name,
      'status': task.status.name,
      'created_by': task.createdBy,
    }).select()
        .single();

    print('插入成功，返回数据: $response');
    return Task.fromMap(response);
  }

  Future<Task> updateTask(Task task) async {
    final response = await _client
        .from('tasks')
        .update({
          'title': task.title,
          'description': task.description,
          'assigned_to': task.assignedTo,
          'due_date': task.dueDate?.toIso8601String(),
          'recurrence': task.recurrence.name,
          'status': task.status.name,
          'completed_at': task.completedAt?.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', task.id)
        .select()
        .single();

    return Task.fromMap(response);
  }

  Future<Task> toggleTaskStatus(String taskId, bool isCompleted) async {
    print('=== TaskRepository.toggleTaskStatus 开始 ===');
    print('taskId: $taskId');
    print('isCompleted: $isCompleted');
    
    final completedAt = isCompleted ? DateTime.now() : null;
    final status = isCompleted ? 'completed' : 'pending';
    
    print('更新数据: status=$status, completed_at=$completedAt');

    final response = await _client
        .from('tasks')
        .update({
          'status': status,
          'completed_at': completedAt?.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', taskId)
        .select()
        .single();

    print('更新成功，返回数据: $response');
    return Task.fromMap(response);
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }

  Future<List<Task>> searchTasks(
    String householdId,
    String query,
  ) async {
    final response = await _client
        .from('tasks')
        .select()
        .eq('household_id', householdId)
        .ilike('title', '%$query%')
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => Task.fromMap(e))
        .toList();
  }
}
