import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tasks.dart';

part 'tasks_dao.g.dart';

@DriftAccessor(tables: [Tasks])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);
  
  Future<List<Task>> getAll() => select(tasks).get();
  
  Future<Task?> getById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  
  Stream<List<Task>> watchAll() => select(tasks).watch();
  
  Stream<Task?> watchById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).watchSingleOrNull();
  
  Future<int> insertTask(TasksCompanion task) =>
      into(tasks).insert(task);
  
  Future<int> updateTask(TasksCompanion task) =>
      (update(tasks)..where((t) => t.id.equals(task.id.value))).write(task);
  
  Future<int> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();
  
  Future<List<Task>> getSyncPending() =>
      (select(tasks)..where((t) => t.syncPending.equals(true))).get();
  
  Future<int> markSynced(String id) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          syncPending: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
  
  Future<void> upsertTaskFromRemote(Map<String, dynamic> remoteTask) async {
    final existing = await getById(remoteTask['id']);
    
    final companion = TasksCompanion(
      id: Value(remoteTask['id']),
      householdId: Value(remoteTask['household_id']),
      title: Value(remoteTask['title']),
      description: Value(remoteTask['description']),
      assignedTo: Value(remoteTask['assigned_to']),
      dueDate: remoteTask['due_date'] != null
          ? Value(DateTime.parse(remoteTask['due_date']))
          : const Value.absent(),
      recurrence: Value(remoteTask['recurrence']),
      status: Value(remoteTask['status']),
      createdBy: Value(remoteTask['created_by']),
      createdAt: Value(DateTime.parse(remoteTask['created_at'])),
      completedAt: remoteTask['completed_at'] != null
          ? Value(DateTime.parse(remoteTask['completed_at']))
          : const Value.absent(),
      updatedAt: Value(DateTime.parse(remoteTask['updated_at'])),
      version: Value(remoteTask['version'] ?? 1),
      syncPending: const Value(false),
    );
    
    if (existing == null) {
      await into(tasks).insert(companion);
    } else {
      await (update(tasks)..where((t) => t.id.equals(remoteTask['id']))).write(companion);
    }
  }
  
  Future<List<Task>> getByHousehold(String householdId) =>
      (select(tasks)..where((t) => t.householdId.equals(householdId))).get();
  
  Stream<List<Task>> watchByHousehold(String householdId) =>
      (select(tasks)..where((t) => t.householdId.equals(householdId))).watch();
}
