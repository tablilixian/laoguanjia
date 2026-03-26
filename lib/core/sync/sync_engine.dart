import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local_db/app_database.dart';
import '../../data/local_db/task_extensions.dart';
import '../../data/local_db/item_extensions.dart';

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

  Future<SyncResult> forceFullSync({
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      int pulled = 0;
      final errors = <String>[];

      await setLocalVersion('tasks', 0);

      final remoteTasks = await remoteDb
          .from('tasks')
          .select()
          .order('version');

      final total = remoteTasks.length;

      for (int i = 0; i < remoteTasks.length; i++) {
        final remoteTask = remoteTasks[i];
        try {
          await localDb.tasksDao.upsertTaskFromRemote(remoteTask);
          pulled++;
          onProgress?.call(pulled, total);
        } catch (e) {
          errors.add('任务 ${remoteTask['id']} 同步失败: ${e.toString()}');
        }
      }

      if (remoteTasks.isNotEmpty) {
        final maxVersion = remoteTasks
            .map((t) => t['version'] as int? ?? 0)
            .reduce((a, b) => a > b ? a : b);
        await setLocalVersion('tasks', maxVersion);
      }

      return SyncResult(
        success: errors.isEmpty,
        pulled: pulled,
        errors: errors,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        errors: ['全量同步失败: ${e.toString()}'],
      );
    }
  }

  Future<void> resetLocalData() async {
    await localDb.resetDatabase();
    await setLocalVersion('tasks', 0);
  }

  Future<SyncResult> syncItems() async {
    try {
      int pulled = 0;
      int pushed = 0;
      int conflicts = 0;
      final errors = <String>[];

      final localVersion = await getLocalVersion('household_items');
      final remoteVersion = await getRemoteVersion('household_items');

      print('🔄 [SyncEngine] 开始同步物品: localVersion=$localVersion, remoteVersion=$remoteVersion');

      final pushResult = await pushItems();
      pushed = pushResult.pushed;
      conflicts = pushResult.conflicts;
      errors.addAll(pushResult.errors);
      
      print('📤 [SyncEngine] 推送结果: pushed=$pushed, conflicts=$conflicts, errors=${errors.length}');

      if (remoteVersion > localVersion) {
        pulled = await pullItems(localVersion);
        print('📥 [SyncEngine] 拉取了 $pulled 个物品');
      }

      await syncLocations();
      await syncTags();
      await syncTypes();

      if (errors.isEmpty) {
        await setLocalVersion('household_items', remoteVersion);
        print('✅ [SyncEngine] 物品同步成功，更新版本为 $remoteVersion');
      } else {
        print('❌ [SyncEngine] 物品同步失败: ${errors.join(', ')}');
      }

      return SyncResult(
        success: errors.isEmpty,
        pulled: pulled,
        pushed: pushed,
        conflicts: conflicts,
        errors: errors,
      );
    } catch (e) {
      print('❌ [SyncEngine] 物品同步异常: $e');
      return SyncResult(
        success: false,
        errors: ['物品同步失败: ${e.toString()}'],
      );
    }
  }

  Future<int> pullItems(int localVersion) async {
    final remoteItems = await remoteDb
        .from('household_items')
        .select('id, household_id, name, description, item_type, location_id, owner_id, quantity, brand, model, purchase_date, purchase_price, warranty_expiry, condition, image_url, thumbnail_url, notes, created_by, created_at, updated_at, deleted_at, version, tags_mask, slot_position')
        .gt('version', localVersion)
        .order('version');

    int count = 0;
    for (final remoteItem in remoteItems) {
      await localDb.itemsDao.upsertItemFromRemote(remoteItem);
      count++;
    }
    return count;
  }

  Future<SyncResult> pushItems() async {
    final pendingItems = await localDb.itemsDao.getSyncPending();
    print('📋 [SyncEngine] 待同步物品数量: ${pendingItems.length}');
    
    if (pendingItems.isEmpty) {
      return SyncResult(
        success: true,
        pushed: 0,
        conflicts: 0,
        errors: [],
      );
    }

    int pushed = 0;
    int conflicts = 0;
    final errors = <String>[];

    final itemIds = pendingItems.map((i) => i.id).toList();
    
    print('📤 [SyncEngine] 批量查询远程物品状态...');
    final remoteItems = await remoteDb
        .from('household_items')
        .select('id, updated_at, version, deleted_at')
        .or('id.in.(${itemIds.join(',')})');
    
    final remoteItemMap = {for (var item in remoteItems) item['id']: item};

    final itemsToInsert = <Map<String, dynamic>>[];
    final itemsToUpdate = <Map<String, dynamic>>[];
    final itemsToDelete = <String>[];
    final itemsToPull = <String>[];

    for (final localItem in pendingItems) {
      final remoteItem = remoteItemMap[localItem.id];

      if (localItem.deletedAt != null) {
        if (remoteItem != null && remoteItem['deleted_at'] == null) {
          itemsToDelete.add(localItem.id);
        }
        continue;
      }

      if (remoteItem == null) {
        print('➕ [SyncEngine] 物品 ${localItem.name} (${localItem.id}) 远程不存在，准备插入');
        itemsToInsert.add(localItem.toRemoteJson());
      } else {
        final remoteUpdatedAt = DateTime.parse(remoteItem['updated_at']);
        final remoteVersion = remoteItem['version'] as int? ?? 0;
        
        print('🔍 [SyncEngine] 物品 ${localItem.name} (${localItem.id}):');
        print('   本地: version=${localItem.version}, updatedAt=${localItem.updatedAt.toIso8601String()}');
        print('   远程: version=$remoteVersion, updatedAt=${remoteUpdatedAt.toIso8601String()}');
        
        final shouldPush = localItem.version > remoteVersion;
        
        if (shouldPush) {
          print('   ✅ 本地版本更新，准备推送到远程');
          itemsToUpdate.add(localItem.toRemoteJson());
        } else {
          print('   ⚠️ 远程版本更新或相同，准备拉取到本地');
          itemsToPull.add(localItem.id);
        }
      }
    }

    if (itemsToDelete.isNotEmpty) {
      print('🗑️ [SyncEngine] 批量删除 ${itemsToDelete.length} 个物品...');
      try {
        for (final itemId in itemsToDelete) {
          await remoteDb.from('household_items').update({'deleted_at': DateTime.now().toIso8601String()}).eq('id', itemId);
          await localDb.itemsDao.markSynced(itemId);
        }
        pushed += itemsToDelete.length;
      } catch (e) {
        print('❌ [SyncEngine] 批量删除失败: $e');
        errors.add('批量删除失败: ${e.toString()}');
      }
    }

    if (itemsToInsert.isNotEmpty) {
      print('➕ [SyncEngine] 批量插入 ${itemsToInsert.length} 个新物品...');
      try {
        await remoteDb.from('household_items').insert(itemsToInsert);
        for (final item in itemsToInsert) {
          await localDb.itemsDao.markSynced(item['id']);
        }
        pushed += itemsToInsert.length;
      } catch (e) {
        print('❌ [SyncEngine] 批量插入失败: $e');
        errors.add('批量插入失败: ${e.toString()}');
      }
    }

    if (itemsToUpdate.isNotEmpty) {
      print('🔄 [SyncEngine] 批量更新 ${itemsToUpdate.length} 个物品...');
      try {
        for (final item in itemsToUpdate) {
          await remoteDb.from('household_items').update(item).eq('id', item['id']);
          await localDb.itemsDao.markSynced(item['id']);
        }
        pushed += itemsToUpdate.length;
      } catch (e) {
        print('❌ [SyncEngine] 批量更新失败: $e');
        errors.add('批量更新失败: ${e.toString()}');
      }
    }

    if (itemsToPull.isNotEmpty) {
      print('⚠️ [SyncEngine] 拉取 ${itemsToPull.length} 个远程物品...');
      for (final itemId in itemsToPull) {
        try {
          await pullSingleItem(itemId);
          conflicts++;
        } catch (e) {
          errors.add('拉取物品 $itemId 失败: ${e.toString()}');
        }
      }
    }

    print('✅ [SyncEngine] 推送完成: pushed=$pushed, conflicts=$conflicts, errors=${errors.length}');
    return SyncResult(
      success: errors.isEmpty,
      pushed: pushed,
      conflicts: conflicts,
      errors: errors,
    );
  }

  Future<void> pullSingleItem(String itemId) async {
    final remoteItem = await remoteDb
        .from('household_items')
        .select('id, household_id, name, description, item_type, location_id, owner_id, quantity, brand, model, purchase_date, purchase_price, warranty_expiry, condition, image_url, thumbnail_url, notes, created_by, created_at, updated_at, deleted_at, version, tags_mask, slot_position')
        .eq('id', itemId)
        .maybeSingle();
    
    if (remoteItem != null) {
      await localDb.itemsDao.upsertItemFromRemote(remoteItem);
    }
  }

  Future<void> syncLocations() async {
    final localVersion = await getLocalVersion('item_locations');
    final remoteVersion = await getRemoteVersion('item_locations');

    if (remoteVersion > localVersion) {
      final remoteLocations = await remoteDb
          .from('item_locations')
          .select()
          .gt('version', localVersion)
          .order('version');

      for (final remoteLocation in remoteLocations) {
        await localDb.locationsDao.upsertLocationFromRemote(remoteLocation);
      }
    }

    final pendingLocations = await localDb.locationsDao.getSyncPending();
    for (final localLocation in pendingLocations) {
      try {
        final remoteLocation = await remoteDb
            .from('item_locations')
            .select('updated_at, version')
            .eq('id', localLocation.id)
            .maybeSingle();

        if (remoteLocation == null) {
          await remoteDb.from('item_locations').insert(localLocation.toRemoteJson());
          await localDb.locationsDao.markSynced(localLocation.id);
        } else {
          final remoteUpdatedAt = DateTime.parse(remoteLocation['updated_at']);
          if (localLocation.updatedAt.isAfter(remoteUpdatedAt)) {
            await remoteDb.from('item_locations').update(localLocation.toRemoteJson()).eq('id', localLocation.id);
            await localDb.locationsDao.markSynced(localLocation.id);
          } else {
            await pullSingleLocation(localLocation.id);
          }
        }
      } catch (e) {
        // Silently handle location sync errors
      }
    }
  }

  Future<void> pullSingleLocation(String locationId) async {
    final remoteLocation = await remoteDb
        .from('item_locations')
        .select()
        .eq('id', locationId)
        .maybeSingle();
    
    if (remoteLocation != null) {
      await localDb.locationsDao.upsertLocationFromRemote(remoteLocation);
    }
  }

  Future<void> syncTags() async {
    final localVersion = await getLocalVersion('item_tags');
    final remoteVersion = await getRemoteVersion('item_tags');

    if (remoteVersion > localVersion) {
      final remoteTags = await remoteDb
          .from('item_tags')
          .select('id, household_id, name, color, icon, category, applicable_types, created_at, updated_at, version, tag_index')
          .gt('version', localVersion)
          .order('version');

      for (final remoteTag in remoteTags) {
        await localDb.tagsDao.upsertTagFromRemote(remoteTag);
      }
    }

    final pendingTags = await localDb.tagsDao.getSyncPending();
    for (final localTag in pendingTags) {
      try {
        final remoteTag = await remoteDb
            .from('item_tags')
            .select('updated_at, version')
            .eq('id', localTag.id)
            .maybeSingle();

        if (remoteTag == null) {
          await remoteDb.from('item_tags').insert(localTag.toRemoteJson());
          await localDb.tagsDao.markSynced(localTag.id);
        } else {
          final remoteUpdatedAt = DateTime.parse(remoteTag['updated_at']);
          if (localTag.updatedAt.isAfter(remoteUpdatedAt)) {
            await remoteDb.from('item_tags').update(localTag.toRemoteJson()).eq('id', localTag.id);
            await localDb.tagsDao.markSynced(localTag.id);
          } else {
            await pullSingleTag(localTag.id);
          }
        }
      } catch (e) {
        // Silently handle tag sync errors
      }
    }
  }

  Future<void> pullSingleTag(String tagId) async {
    final remoteTag = await remoteDb
        .from('item_tags')
        .select()
        .eq('id', tagId)
        .maybeSingle();
    
    if (remoteTag != null) {
      await localDb.tagsDao.upsertTagFromRemote(remoteTag);
    }
  }

  Future<void> syncTypes() async {
    final localVersion = await getLocalVersion('item_type_configs');
    final remoteVersion = await getRemoteVersion('item_type_configs');

    if (remoteVersion > localVersion) {
      final remoteTypes = await remoteDb
          .from('item_type_configs')
          .select()
          .gt('version', localVersion)
          .order('version');

      for (final remoteType in remoteTypes) {
        await localDb.typesDao.upsertTypeFromRemote(remoteType);
      }
    }

    final pendingTypes = await localDb.typesDao.getSyncPending();
    for (final localType in pendingTypes) {
      try {
        final remoteType = await remoteDb
            .from('item_type_configs')
            .select('updated_at, version')
            .eq('id', localType.id)
            .maybeSingle();

        if (remoteType == null) {
          await remoteDb.from('item_type_configs').insert(localType.toRemoteJson());
          await localDb.typesDao.markSynced(localType.id);
        } else {
          final remoteUpdatedAt = DateTime.parse(remoteType['updated_at']);
          if (localType.updatedAt.isAfter(remoteUpdatedAt)) {
            await remoteDb.from('item_type_configs').update(localType.toRemoteJson()).eq('id', localType.id);
            await localDb.typesDao.markSynced(localType.id);
          } else {
            await pullSingleType(localType.id);
          }
        }
      } catch (e) {
        // Silently handle type sync errors
      }
    }
  }

  Future<void> pullSingleType(String typeId) async {
    final remoteType = await remoteDb
        .from('item_type_configs')
        .select()
        .eq('id', typeId)
        .maybeSingle();
    
    if (remoteType != null) {
      await localDb.typesDao.upsertTypeFromRemote(remoteType);
    }
  }

  Future<SyncResult> forceFullSyncItems({
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      int pulled = 0;
      final errors = <String>[];

      await setLocalVersion('household_items', 0);

      final remoteItems = await remoteDb
          .from('household_items')
          .select('id, household_id, name, description, item_type, location_id, owner_id, quantity, brand, model, purchase_date, purchase_price, warranty_expiry, condition, image_url, thumbnail_url, notes, created_by, created_at, updated_at, deleted_at, version, tags_mask, slot_position')
          .order('version');

      final total = remoteItems.length;

      for (int i = 0; i < remoteItems.length; i++) {
        final remoteItem = remoteItems[i];
        try {
          await localDb.itemsDao.upsertItemFromRemote(remoteItem);
          pulled++;
          onProgress?.call(pulled, total);
        } catch (e) {
          errors.add('物品 ${remoteItem['id']} 同步失败: ${e.toString()}');
        }
      }

      if (remoteItems.isNotEmpty) {
        final maxVersion = remoteItems
            .map((t) => t['version'] as int? ?? 0)
            .reduce((a, b) => a > b ? a : b);
        await setLocalVersion('household_items', maxVersion);
      }

      await syncLocations();
      await syncTags();
      await syncTypes();

      return SyncResult(
        success: errors.isEmpty,
        pulled: pulled,
        errors: errors,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        errors: ['物品全量同步失败: ${e.toString()}'],
      );
    }
  }
}
