import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local_db/app_database.dart';
import '../../data/local_db/task_extensions.dart';
import '../../data/local_db/item_extensions.dart';
import '../utils/datetime_utils.dart';

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

/// 本地同步时间戳存储键
const _kLastSyncItems = 'last_sync_items';
const _kLastSyncLocations = 'last_sync_locations';
const _kLastSyncTags = 'last_sync_tags';
const _kLastSyncTypes = 'last_sync_types';
const _kLastSyncMembers = 'last_sync_members';
const _kLastSyncTasks = 'last_sync_tasks';

class SyncEngine {
  final AppDatabase localDb;
  final SupabaseClient remoteDb;

  SyncEngine({
    required this.localDb,
    required this.remoteDb,
  });

  // ==================== 本地同步时间戳管理 ====================

  /// 获取上次同步时间（本地存储，UTC）
  Future<DateTime> getLastSyncTime(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(key) ?? 0;
    // 返回 UTC 时间，确保时区一致性
    return millis > 0 
        ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
        : DateTime.utc(2000);
  }

  /// 保存同步时间（本地存储，UTC）
  Future<void> setLastSyncTime(String key, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    // 存储 UTC 毫秒时间戳，确保时区一致性
    await prefs.setInt(key, time.toUtc().millisecondsSinceEpoch);
  }

  /// 检查是否需要同步（远端有更新）
  Future<bool> needsSync(String tableName, DateTime lastSync) async {
    try {
      // 查询是否有 updated_at > lastSync 的记录
      // 使用 UTC 时间进行比较，确保时区一致性
      final result = await remoteDb
          .from(tableName)
          .select('updated_at')
          .gt('updated_at', lastSync.toUtc().toIso8601String())
          .limit(1);
      return (result as List).isNotEmpty;
    } catch (e) {
      return true; // 出错时保守处理，执行同步
    }
  }

  Future<SyncResult> syncTasks() async {
    try {
      int pulled = 0;
      int pushed = 0;
      int conflicts = 0;
      final errors = <String>[];

      // 增量拉取：updated_at > lastSyncTime
      final lastSync = await getLastSyncTime(_kLastSyncTasks);
      print('📋 [SyncEngine] syncTasks: lastSync=$lastSync');

      final remoteTasks = await remoteDb
          .from('tasks')
          .select()
          .gt('updated_at', lastSync.toIso8601String())
          .order('updated_at');

      print('📥 [SyncEngine] 远程 Tasks 变化数量: ${remoteTasks.length}');
      for (final remoteTask in remoteTasks) {
        await localDb.tasksDao.upsertTaskFromRemote(remoteTask);
        pulled++;
      }

      // 推送本地变更
      final pushResult = await pushTasks();
      pushed = pushResult.pushed;
      conflicts = pushResult.conflicts;
      errors.addAll(pushResult.errors);

      // 更新本地同步时间
      if (errors.isEmpty) {
        await setLastSyncTime(_kLastSyncTasks, DateTimeUtils.nowUtc());
        print('✅ [SyncEngine] Tasks 同步完成: pulled=$pulled, pushed=$pushed');
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

  Future<SyncResult> pushTasks() async {
    final pendingTasks = await localDb.tasksDao.getSyncPending();
    
    int pushed = 0;
    final errors = <String>[];

    for (final localTask in pendingTasks) {
      try {
        final remoteTask = await remoteDb
            .from('tasks')
            .select('id')
            .eq('id', localTask.id)
            .maybeSingle();

        if (remoteTask == null) {
          await remoteDb.from('tasks').insert(localTask.toRemoteJson());
          await localDb.tasksDao.markSynced(localTask.id);
          pushed++;
        } else {
          await remoteDb.from('tasks').update(localTask.toRemoteJson(forUpdate: true)).eq('id', localTask.id);
          
          final updatedRemoteTask = await remoteDb
              .from('tasks')
              .select('updated_at')
              .eq('id', localTask.id)
              .single();
          
          final newUpdatedAt = DateTimeUtils.parseIso8601(updatedRemoteTask['updated_at']);
          await localDb.tasksDao.markSynced(localTask.id, updatedAt: newUpdatedAt);
          pushed++;
        }
      } catch (e) {
        errors.add('任务 ${localTask.id} 同步失败: ${e.toString()}');
      }
    }

    return SyncResult(
      success: errors.isEmpty,
      pushed: pushed,
      conflicts: 0,
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

  /// 全量同步：从远端拉取所有数据（Tasks + Items + Locations + Tags + Types）
  ///
  /// 用于用户手动触发"从云端拉取最新数据"的场景
  Future<SyncResult> forceFullSync({
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      int pulled = 0;
      final errors = <String>[];

      // 1. 全量同步 Tasks
      print('🔄 [SyncEngine] 全量同步 Tasks...');
      await setLastSyncTime(_kLastSyncTasks, DateTime.utc(2000));

      final remoteTasks = await remoteDb
          .from('tasks')
          .select()
          .order('updated_at');

      print('📥 [SyncEngine] 远程 Tasks 数量: ${remoteTasks.length}');
      int total = remoteTasks.length;

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

      await setLastSyncTime(_kLastSyncTasks, DateTimeUtils.nowUtc());
      print('✅ [SyncEngine] Tasks 同步完成: $pulled');

      // 2. 全量同步 Items
      try {
        print('🔄 [SyncEngine] 全量同步 Items...');
        await setLastSyncTime(_kLastSyncItems, DateTime.utc(2000));
        final remoteItems = await remoteDb
            .from('household_items')
            .select('id, household_id, name, description, item_type, location_id, owner_id, quantity, brand, model, purchase_date, purchase_price, warranty_expiry, condition, image_url, thumbnail_url, notes, created_by, created_at, updated_at, deleted_at, version, tags_mask, slot_position')
            .order('version');

        print('📥 [SyncEngine] 远程 Items 数量: ${remoteItems.length}');
        total = remoteItems.length;
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
          await setLastSyncTime(_kLastSyncItems, DateTimeUtils.nowUtc());
        }
        print('✅ [SyncEngine] Items 同步完成: $pulled');
      } catch (e) {
        errors.add('物品全量同步失败: ${e.toString()}');
      }

      // 3. 全量同步 Locations / Tags / Types / Members
      print('🔄 [SyncEngine] 开始同步 Locations/Tags/Types/Members...');
      await syncLocations();
      await syncTags();
      await syncTypes();
      await syncMembers();
      print('✅ [SyncEngine] Locations/Tags/Types/Members 同步完成');

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

  /// 重置本地所有表数据及同步时间戳
  ///
  /// 用于"清空本地 → 从云端全量拉取"的场景
  Future<void> resetLocalData() async {
    await localDb.resetDatabase();
    // 重置所有业务表的同步时间戳，确保全量同步能拉取远端全部数据
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastSyncTasks);
    await prefs.remove(_kLastSyncItems);
    await prefs.remove(_kLastSyncLocations);
    await prefs.remove(_kLastSyncTags);
    await prefs.remove(_kLastSyncTypes);
    await prefs.remove(_kLastSyncMembers);
  }

  Future<SyncResult> syncItems() async {
    try {
      int pulled = 0;
      int pushed = 0;
      int conflicts = 0;
      final errors = <String>[];

      // 增量拉取：updated_at > lastSyncTime
      final lastSync = await getLastSyncTime(_kLastSyncItems);
      print('🔄 [SyncEngine] 开始同步物品: lastSync=$lastSync');

      final pushResult = await pushItems();
      pushed = pushResult.pushed;
      conflicts = pushResult.conflicts;
      errors.addAll(pushResult.errors);
      
      print('📤 [SyncEngine] 推送结果: pushed=$pushed, conflicts=$conflicts, errors=${errors.length}');

      // 拉取远端变更
      final remoteItems = await remoteDb
          .from('household_items')
          .select('id, household_id, name, description, item_type, location_id, owner_id, quantity, brand, model, purchase_date, purchase_price, warranty_expiry, condition, image_url, thumbnail_url, notes, created_by, created_at, updated_at, deleted_at, version, tags_mask, slot_position')
          .gt('updated_at', lastSync.toIso8601String())
          .order('updated_at');

      print('📥 [SyncEngine] 远端物品变化数量: ${remoteItems.length}');
      for (final remoteItem in remoteItems) {
        await localDb.itemsDao.upsertItemFromRemote(remoteItem);
        pulled++;
      }

      // 同步关联数据
      await syncLocations();
      await syncTags();
      await syncTypes();
      await syncMembers();

      if (errors.isEmpty) {
        await setLastSyncTime(_kLastSyncItems, DateTimeUtils.nowUtc());
        print('✅ [SyncEngine] 物品同步完成: pulled=$pulled, pushed=$pushed');
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
    final errors = <String>[];

    for (final localItem in pendingItems) {
      try {
        final remoteItem = await remoteDb
            .from('household_items')
            .select('id')
            .eq('id', localItem.id)
            .maybeSingle();

        if (remoteItem == null) {
          await remoteDb.from('household_items').insert(localItem.toRemoteJson());
          await localDb.itemsDao.markSynced(localItem.id);
          pushed++;
        } else {
          await remoteDb.from('household_items').update(localItem.toRemoteJson(forUpdate: true)).eq('id', localItem.id);
          
          final updatedRemoteItem = await remoteDb
              .from('household_items')
              .select('updated_at')
              .eq('id', localItem.id)
              .single();
          
          final newUpdatedAt = DateTimeUtils.parseIso8601(updatedRemoteItem['updated_at']);
          await localDb.itemsDao.markSynced(localItem.id, updatedAt: newUpdatedAt);
          pushed++;
        }
      } catch (e) {
        errors.add('物品 ${localItem.id} 推送失败: ${e.toString()}');
      }
    }

    print('✅ [SyncEngine] 推送完成: pushed=$pushed, errors=${errors.length}');
    return SyncResult(
      success: errors.isEmpty,
      pushed: pushed,
      conflicts: 0,
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
    final lastSync = await getLastSyncTime(_kLastSyncLocations);
    print('📍 [SyncEngine] syncLocations: lastSync=$lastSync');

    final remoteLocations = await remoteDb
        .from('item_locations')
        .select()
        .gt('updated_at', lastSync.toIso8601String())
        .order('updated_at');

    print('📥 [SyncEngine] 远程 Locations 变化数量: ${remoteLocations.length}');
    for (final remoteLocation in remoteLocations) {
      await localDb.locationsDao.upsertLocationFromRemote(remoteLocation);
    }

    final pendingLocations = await localDb.locationsDao.getSyncPending();
    for (final localLocation in pendingLocations) {
      try {
        final remoteLocation = await remoteDb
            .from('item_locations')
            .select('id')
            .eq('id', localLocation.id)
            .maybeSingle();

        if (remoteLocation == null) {
          await remoteDb.from('item_locations').insert(localLocation.toRemoteJson());
          await localDb.locationsDao.markSynced(localLocation.id);
        } else {
          await remoteDb.from('item_locations').update(localLocation.toRemoteJson(forUpdate: true)).eq('id', localLocation.id);
          
          final updatedRemoteLocation = await remoteDb
              .from('item_locations')
              .select('updated_at')
              .eq('id', localLocation.id)
              .single();
          
          final newUpdatedAt = DateTimeUtils.parseIso8601(updatedRemoteLocation['updated_at']);
          await localDb.locationsDao.markSynced(localLocation.id, updatedAt: newUpdatedAt);
        }
      } catch (e) {
        // Silently handle location sync errors
      }
    }

    await setLastSyncTime(_kLastSyncLocations, DateTimeUtils.nowUtc());
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
    final lastSync = await getLastSyncTime(_kLastSyncTags);
    print('🏷️ [SyncEngine] syncTags: lastSync=$lastSync');

    final remoteTags = await remoteDb
        .from('item_tags')
        .select('id, household_id, name, color, icon, category, applicable_types, created_at, updated_at, deleted_at, version, tag_index')
        .gt('updated_at', lastSync.toIso8601String())
        .order('updated_at');

    print('📥 [SyncEngine] 远程 Tags 变化数量: ${remoteTags.length}');
    for (final remoteTag in remoteTags) {
      await localDb.tagsDao.upsertTagFromRemote(remoteTag);
    }

    final pendingTags = await localDb.tagsDao.getSyncPending();
    print('📤 [SyncEngine] 待同步 Tags 数量: ${pendingTags.length}');
    for (final localTag in pendingTags) {
      try {
        final remoteTag = await remoteDb
            .from('item_tags')
            .select('id')
            .eq('id', localTag.id)
            .maybeSingle();

        if (remoteTag == null) {
          await remoteDb.from('item_tags').insert(localTag.toRemoteJson());
          await localDb.tagsDao.markSynced(localTag.id);
        } else {
          await remoteDb.from('item_tags').update(localTag.toRemoteJson(forUpdate: true)).eq('id', localTag.id);
          
          final updatedRemoteTag = await remoteDb
              .from('item_tags')
              .select('updated_at')
              .eq('id', localTag.id)
              .single();
          
          final newUpdatedAt = DateTimeUtils.parseIso8601(updatedRemoteTag['updated_at']);
          await localDb.tagsDao.markSynced(localTag.id, updatedAt: newUpdatedAt);
        }
      } catch (e) {
        // Silently handle tag sync errors
      }
    }

    await setLastSyncTime(_kLastSyncTags, DateTimeUtils.nowUtc());
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
    final lastSync = await getLastSyncTime(_kLastSyncTypes);
    print('📋 [SyncEngine] syncTypes: lastSync=$lastSync');

    final remoteTypes = await remoteDb
        .from('item_type_configs')
        .select()
        .gt('updated_at', lastSync.toIso8601String())
        .order('updated_at');

    print('📥 [SyncEngine] 远程 Types 变化数量: ${remoteTypes.length}');
    for (final remoteType in remoteTypes) {
      await localDb.typesDao.upsertTypeFromRemote(remoteType);
    }

    final pendingTypes = await localDb.typesDao.getSyncPending();
    for (final localType in pendingTypes) {
      try {
        final remoteType = await remoteDb
            .from('item_type_configs')
            .select('id')
            .eq('id', localType.id)
            .maybeSingle();

        if (remoteType == null) {
          await remoteDb.from('item_type_configs').insert(localType.toRemoteJson());
          await localDb.typesDao.markSynced(localType.id);
        } else {
          await remoteDb.from('item_type_configs').update(localType.toRemoteJson(forUpdate: true)).eq('id', localType.id);
          
          final updatedRemoteType = await remoteDb
              .from('item_type_configs')
              .select('updated_at')
              .eq('id', localType.id)
              .single();
          
          final newUpdatedAt = DateTimeUtils.parseIso8601(updatedRemoteType['updated_at']);
          await localDb.typesDao.markSynced(localType.id, updatedAt: newUpdatedAt);
        }
      } catch (e) {
        // Silently handle type sync errors
      }
    }

    await setLastSyncTime(_kLastSyncTypes, DateTimeUtils.nowUtc());
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

  // ==================== Members 同步 ====================

  /// 同步家庭成员
  Future<void> syncMembers() async {
    final lastSync = await getLastSyncTime(_kLastSyncMembers);
    print('👥 [SyncEngine] syncMembers: lastSync=$lastSync');

    List<dynamic> remoteMembers;
    try {
      remoteMembers = await remoteDb
          .from('members')
          .select()
          .gt('updated_at', lastSync.toIso8601String())
          .order('updated_at');
    } catch (e) {
      // members 表可能没有 updated_at 字段，降级为全量拉取
      print('⚠️ [SyncEngine] members 增量同步失败，降级为全量拉取: $e');
      remoteMembers = await remoteDb
          .from('members')
          .select()
          .order('created_at');
    }

    print('📥 [SyncEngine] 远程 Members 变化数量: ${remoteMembers.length}');
    for (final remoteMember in remoteMembers) {
      await localDb.membersDao.upsertFromRemote(remoteMember);
    }

    final pendingMembers = await localDb.membersDao.getSyncPending();
    for (final localMember in pendingMembers) {
      try {
        final remoteMember = await remoteDb
            .from('members')
            .select('id')
            .eq('id', localMember.id)
            .maybeSingle();

        if (remoteMember == null) {
          await remoteDb.from('members').insert({
            'id': localMember.id,
            'household_id': localMember.householdId,
            'name': localMember.name,
            'avatar_url': localMember.avatarUrl,
            'role': localMember.role,
            'user_id': localMember.userId,
            'created_at': localMember.createdAt.toIso8601String(),
            'updated_at': localMember.updatedAt.toIso8601String(),
          });
          await localDb.membersDao.markSynced(localMember.id);
        } else {
          await remoteDb.from('members').update({
            'name': localMember.name,
            'avatar_url': localMember.avatarUrl,
            'role': localMember.role,
          }).eq('id', localMember.id);
          
          final updatedRemoteMember = await remoteDb
              .from('members')
              .select('updated_at')
              .eq('id', localMember.id)
              .single();
          
          final newUpdatedAt = DateTimeUtils.parseIso8601(updatedRemoteMember['updated_at']);
          await localDb.membersDao.markSynced(localMember.id, updatedAt: newUpdatedAt);
        }
      } catch (e) {
        // Silently handle member sync errors
      }
    }

    await setLastSyncTime(_kLastSyncMembers, DateTimeUtils.nowUtc());
  }

  /// 拉取单个成员
  Future<void> pullSingleMember(String memberId) async {
    final remoteMember = await remoteDb
        .from('members')
        .select()
        .eq('id', memberId)
        .maybeSingle();
    
    if (remoteMember != null) {
      await localDb.membersDao.upsertFromRemote(remoteMember);
    }
  }

  Future<SyncResult> forceFullSyncItems({
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      int pulled = 0;
      final errors = <String>[];

      print('🔄 [SyncEngine] 全量同步 Items...');
      // 重置同步时间戳，确保全量拉取
      await setLastSyncTime(_kLastSyncItems, DateTime.utc(2000));

      final remoteItems = await remoteDb
          .from('household_items')
          .select('id, household_id, name, description, item_type, location_id, owner_id, quantity, brand, model, purchase_date, purchase_price, warranty_expiry, condition, image_url, thumbnail_url, notes, created_by, created_at, updated_at, deleted_at, version, tags_mask, slot_position')
          .order('updated_at');

      final total = remoteItems.length;
      print('📥 [SyncEngine] 远程 Items 数量: $total');

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

      // 全量同步后更新同步时间
      await setLastSyncTime(_kLastSyncItems, DateTime.now().toUtc());

      // 全量同步关联数据
      print('🔄 [SyncEngine] 全量同步 Locations/Tags/Types/Members...');
      await setLastSyncTime(_kLastSyncLocations, DateTime.utc(2000));
      await setLastSyncTime(_kLastSyncTags, DateTime.utc(2000));
      await setLastSyncTime(_kLastSyncTypes, DateTime.utc(2000));
      await setLastSyncTime(_kLastSyncMembers, DateTime.utc(2000));
      await syncLocations();
      await syncTags();
      await syncTypes();
      await syncMembers();

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
