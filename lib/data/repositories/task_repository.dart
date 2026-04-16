import 'package:drift/drift.dart' hide Column;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../supabase/supabase_client.dart';
import '../local_db/app_database.dart' as db;
import '../local_db/task_extensions.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/utils/datetime_utils.dart';

class TaskRepository {
  /// 懒加载 Supabase 客户端
  SupabaseClient get _client => SupabaseClientManager.client;
  final db.AppDatabase _localDb = db.AppDatabase();
  late final SyncEngine _syncEngine;

  TaskRepository() {
    _syncEngine = SyncEngine(localDb: _localDb, remoteDb: _client);
  }

  Future<List<Task>> getTasks(String householdId) async {
    try {
      final localTasks = await _localDb.tasksDao.getByHousehold(householdId);
      final activeTasks = localTasks.where((t) => t.deletedAt == null).toList();
      if (activeTasks.isNotEmpty) {
        return activeTasks.map((t) => t.toTaskModel()).toList();
      }
    } catch (e) {}

    final response = await _client
        .from('tasks')
        .select()
        .eq('household_id', householdId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    final tasks = (response as List).map((e) => Task.fromMap(e)).toList();
    
    for (final task in tasks) {
      await _syncTaskToLocal(task);
    }

    return tasks;
  }

  Future<List<Task>> getTasksByStatus(String householdId, String status) async {
    try {
      final allTasks = await _localDb.tasksDao.getByHousehold(householdId);
      final filtered = allTasks
          .where((t) => t.status == status && t.deletedAt == null)
          .toList();
      if (filtered.isNotEmpty) {
        return filtered.map((t) => t.toTaskModel()).toList();
      }
    } catch (e) {}

    final response = await _client
        .from('tasks')
        .select()
        .eq('household_id', householdId)
        .eq('status', status)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return (response as List).map((e) => Task.fromMap(e)).toList();
  }

  Future<Task?> getTaskById(String taskId) async {
    try {
      final localTask = await _localDb.tasksDao.getById(taskId);
      if (localTask != null) {
        return localTask.toTaskModel();
      }
    } catch (e) {}

    final response = await _client
        .from('tasks')
        .select()
        .eq('id', taskId)
        .maybeSingle();

    if (response == null) return null;

    return Task.fromMap(response);
  }

  Future<Task> createTask(Task task) async {
    final now = DateTimeUtils.nowUtc();
    final companion = db.TasksCompanion(
      id: Value(task.id),
      householdId: Value(task.householdId),
      title: Value(task.title),
      description: Value(task.description),
      assignedTo: Value(task.assignedTo),
      dueDate: task.dueDate != null ? Value(task.dueDate!) : const Value.absent(),
      recurrence: Value(task.recurrence.name),
      status: Value(task.status.name),
      createdBy: Value(task.createdBy),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncPending: const Value(true),
    );

    await _localDb.tasksDao.insertTask(companion);

    try {
      await _client.from('tasks').insert({
        'id': task.id,
        'household_id': task.householdId,
        'title': task.title,
        'description': task.description,
        'assigned_to': task.assignedTo,
        'due_date': task.dueDate?.toIso8601String(),
        'recurrence': task.recurrence.name,
        'status': task.status.name,
        'created_by': task.createdBy,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await _localDb.tasksDao.markSynced(task.id);
    } catch (e) {}

    return task.copyWith(createdAt: now, updatedAt: now);
  }

  Future<Task> updateTask(Task task) async {
    final now = DateTimeUtils.nowUtc();
    final companion = db.TasksCompanion(
      id: Value(task.id),
      title: Value(task.title),
      description: Value(task.description),
      assignedTo: Value(task.assignedTo),
      dueDate: task.dueDate != null ? Value(task.dueDate!) : const Value.absent(),
      recurrence: Value(task.recurrence.name),
      status: Value(task.status.name),
      completedAt: task.completedAt != null ? Value(task.completedAt!) : const Value.absent(),
      updatedAt: Value(now),
      syncPending: const Value(true),
    );

    await _localDb.tasksDao.updateTask(companion);

    try {
      await _client
          .from('tasks')
          .update({
            'title': task.title,
            'description': task.description,
            'assigned_to': task.assignedTo,
            'due_date': task.dueDate?.toIso8601String(),
            'recurrence': task.recurrence.name,
            'status': task.status.name,
            'completed_at': task.completedAt?.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', task.id);

      await _localDb.tasksDao.markSynced(task.id);
    } catch (e) {}

    return task.copyWith(updatedAt: now);
  }

  Future<Task> toggleTaskStatus(String taskId, bool isCompleted) async {
    final now = DateTimeUtils.nowUtc();
    final completedAt = isCompleted ? now : null;
    final status = isCompleted ? 'completed' : 'pending';

    final companion = db.TasksCompanion(
      id: Value(taskId),
      status: Value(status),
      completedAt: completedAt != null ? Value(completedAt) : const Value.absent(),
      updatedAt: Value(now),
      syncPending: const Value(true),
    );

    await _localDb.tasksDao.updateTask(companion);

    try {
      await _client
          .from('tasks')
          .update({
            'status': status,
            'completed_at': completedAt?.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', taskId);

      await _localDb.tasksDao.markSynced(taskId);
    } catch (e) {}

    final updated = await _localDb.tasksDao.getById(taskId);
    return updated!.toTaskModel();
  }

  Future<void> deleteTask(String taskId) async {
    final now = DateTimeUtils.nowUtc();
    
    final companion = db.TasksCompanion(
      id: Value(taskId),
      deletedAt: Value(now),
      updatedAt: Value(now),
      syncPending: const Value(true),
    );

    await _localDb.tasksDao.updateTask(companion);

    try {
      await _client
          .from('tasks')
          .update({
            'deleted_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', taskId);

      await _localDb.tasksDao.markSynced(taskId);
    } catch (e) {}
  }

  Future<List<Task>> searchTasks(String householdId, String query) async {
    try {
      final allTasks = await _localDb.tasksDao.getByHousehold(householdId);
      final filtered = allTasks
          .where((t) =>
              t.title.toLowerCase().contains(query.toLowerCase()) &&
              t.deletedAt == null)
          .toList();
      if (filtered.isNotEmpty) {
        return filtered.map((t) => t.toTaskModel()).toList();
      }
    } catch (e) {}

    final response = await _client
        .from('tasks')
        .select()
        .eq('household_id', householdId)
        .ilike('title', '%$query%')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return (response as List).map((e) => Task.fromMap(e)).toList();
  }

  Future<List<Task>> getDeletedTasks(String householdId) async {
    try {
      final allTasks = await _localDb.tasksDao.getByHousehold(householdId);
      final deletedTasks = allTasks.where((t) => t.deletedAt != null).toList();
      return deletedTasks.map((t) => t.toTaskModel()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> restoreTask(String taskId) async {
    final companion = db.TasksCompanion(
      id: Value(taskId),
      deletedAt: const Value(null),
      updatedAt: Value(DateTimeUtils.nowUtc()),
      syncPending: const Value(true),
    );

    await _localDb.tasksDao.updateTask(companion);

    try {
      await _client
          .from('tasks')
          .update({
            'deleted_at': null,
            'updated_at': DateTimeUtils.nowUtc().toIso8601String(),
          })
          .eq('id', taskId);

      await _localDb.tasksDao.markSynced(taskId);
    } catch (e) {}
  }

  Future<void> _syncTaskToLocal(Task task) async {
    final companion = db.TasksCompanion(
      id: Value(task.id),
      householdId: Value(task.householdId),
      title: Value(task.title),
      description: Value(task.description),
      assignedTo: Value(task.assignedTo),
      dueDate: task.dueDate != null ? Value(task.dueDate!) : const Value.absent(),
      recurrence: Value(task.recurrence.name),
      status: Value(task.status.name),
      createdBy: Value(task.createdBy),
      createdAt: Value(task.createdAt),
      completedAt: task.completedAt != null ? Value(task.completedAt!) : const Value.absent(),
      updatedAt: Value(task.updatedAt ?? DateTimeUtils.nowUtc()),
      syncPending: const Value(false),
    );

    final existing = await _localDb.tasksDao.getById(task.id);
    if (existing == null) {
      await _localDb.tasksDao.insertTask(companion);
    } else {
      await _localDb.tasksDao.updateTask(companion);
    }
  }

  Future<SyncResult> sync() async {
    return await _syncEngine.syncTasks();
  }
}
