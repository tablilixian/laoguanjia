import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local_db/app_database.dart';
import '../../data/local_db/task_extensions.dart';

class SyncResult {
  final bool success;
  final int pulled;
  final int pushed;
  final int conflicts;
  final List<String> errors;

  SyncResult({
    required this.success,
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
    this.errors = const [],
  });

  @override
  String toString() {
    return 'SyncResult(success: $success, pulled: $pulled, pushed: $pushed, conflicts: $conflicts)';
  }
}

class SyncEngine {
  final AppDatabase localDb;
  final SupabaseClient remoteDb;

  SyncEngine({
    required this.localDb,
    required this.remoteDb,
  });

  Future<int> getRemoteVersion(String tableName) async {
    try {
      final result = await remoteDb
          .from('sync_versions')
          .select('max_version')
          .eq('table_name', tableName)
          .maybeSingle();
      
      return result?['max_version'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getLocalVersion(String tableName) async {
    try {
      final result = await remoteDb
          .from('sync_versions')
          .select('max_version')
          .eq('table_name', '${tableName}_local')
          .maybeSingle();
      
      return result?['max_version'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> setLocalVersion(String tableName, int version) async {
    await remoteDb.from('sync_versions').upsert({
      'table_name': '${tableName}_local',
      'max_version': version,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> needsSync(String tableName) async {
    final remoteVersion = await getRemoteVersion(tableName);
    final localVersion = await getLocalVersion(tableName);
    return remoteVersion > localVersion;
  }

  Future<SyncResult> syncTasks() async {
    try {
      int pulled = 0;
      int pushed = 0;
      int conflicts = 0;
      final errors = <String>[];

      final localVersion = await getLocalVersion('tasks');
      final remoteVersion = await getRemoteVersion('tasks');

      if (remoteVersion > localVersion) {
        pulled = await pullTasks(localVersion);
      }

      final pushResult = await pushTasks();
      pushed = pushResult.pushed;
      conflicts = pushResult.conflicts;
      errors.addAll(pushResult.errors);

      if (errors.isEmpty) {
        await setLocalVersion('tasks', remoteVersion);
      }

      return SyncResult(
        success: errors.isEmpty,
        pulled: pulled,
        pushed: pushed,
        conflicts: conflicts,
        errors: errors,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        errors: ['同步失败: ${e.toString()}'],
      );
    }
  }

  Future<int> pullTasks(int localVersion) async {
    final remoteTasks = await remoteDb
        .from('tasks')
        .select()
        .gt('version', localVersion)
        .order('version');

    int count = 0;
    for (final remoteTask in remoteTasks) {
      await localDb.tasksDao.upsertTaskFromRemote(remoteTask);
      count++;
    }
    return count;
  }

  Future<SyncResult> pushTasks() async {
    final pendingTasks = await localDb.tasksDao.getSyncPending();
    
    int pushed = 0;
    int conflicts = 0;
    final errors = <String>[];

    for (final localTask in pendingTasks) {
      try {
        final remoteTask = await remoteDb
            .from('tasks')
            .select('updated_at, version')
            .eq('id', localTask.id)
            .maybeSingle();

        if (remoteTask == null) {
          await remoteDb.from('tasks').insert(localTask.toRemoteJson());
          await localDb.tasksDao.markSynced(localTask.id);
          pushed++;
        } else {
          final remoteUpdatedAt = DateTime.parse(remoteTask['updated_at']);
          if (localTask.updatedAt.isAfter(remoteUpdatedAt)) {
            await remoteDb.from('tasks').update(localTask.toRemoteJson()).eq('id', localTask.id);
            await localDb.tasksDao.markSynced(localTask.id);
            pushed++;
          } else {
            await pullSingleTask(localTask.id);
            conflicts++;
          }
        }
      } catch (e) {
        errors.add('任务 ${localTask.id} 同步失败: ${e.toString()}');
      }
    }

    return SyncResult(
      success: errors.isEmpty,
      pushed: pushed,
      conflicts: conflicts,
      errors: errors,
    );
  }

  Future<void> pullSingleTask(String taskId) async {
    final remoteTask = await remoteDb
        .from('tasks')
        .select()
        .eq('id', taskId)
        .maybeSingle();
    
    if (remoteTask != null) {
      await localDb.tasksDao.upsertTaskFromRemote(remoteTask);
    }
  }
}
