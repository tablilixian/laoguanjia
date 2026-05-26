import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'models/finance_account.dart';
import 'models/finance_data.dart';
import 'models/finance_snapshot.dart';

/// 财务数据存储封装
///
/// 使用 shared_preferences 跨平台存储（Web / macOS / iOS / Android）。
/// 一个家庭一条记录，key = "finance_data_{household_id}"，value = JSON 字符串。
class FinanceStorage {
  static FinanceStorage? _instance;
  static FinanceStorage get instance => _instance ??= FinanceStorage._();

  FinanceStorage._();

  String _key(String householdId) => 'finance_data_$householdId';

  // ==================== 读写 ====================

  /// 加载家庭财务数据
  Future<FinanceData> load(String householdId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key(householdId));
      if (jsonStr == null || jsonStr.isEmpty) {
        return FinanceData.empty();
      }
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return FinanceData.fromJson(json);
    } catch (e) {
      return FinanceData.empty();
    }
  }

  /// 保存家庭财务数据
  Future<void> save(String householdId, FinanceData data) async {
    try {
      data.updatedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(householdId), jsonEncode(data.toJson()));
    } catch (e) {
      rethrow;
    }
  }

  // ==================== 账户操作 ====================

  /// 获取所有账户
  Future<List<FinanceAccount>> getAccounts(String householdId) async {
    final data = await load(householdId);
    return List.unmodifiable(data.accounts);
  }

  /// 获取指定成员的账户
  Future<List<FinanceAccount>> getMemberAccounts(
    String householdId,
    String memberId,
  ) async {
    final data = await load(householdId);
    return data.accounts.where((a) => a.memberId == memberId).toList();
  }

  /// 添加账户
  Future<FinanceAccount> addAccount(
    String householdId,
    FinanceAccount account,
  ) async {
    final data = await load(householdId);
    data.accounts.add(account);
    await save(householdId, data);
    return account;
  }

  /// 更新账户
  Future<void> updateAccount(
    String householdId,
    FinanceAccount account,
  ) async {
    final data = await load(householdId);
    final index = data.accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      data.accounts[index] = account;
      await save(householdId, data);
    }
  }

  /// 删除账户（同时删除该账户的所有快照）
  Future<void> deleteAccount(String householdId, String accountId) async {
    final data = await load(householdId);
    data.accounts.removeWhere((a) => a.id == accountId);
    data.snapshots.removeWhere((s) => s.accountId == accountId);
    await save(householdId, data);
  }

  // ==================== 快照操作 ====================

  /// 获取某个账户的所有快照（按时间倒序）
  Future<List<FinanceSnapshot>> getAccountSnapshots(
    String householdId,
    String accountId,
  ) async {
    final data = await load(householdId);
    final snapshots =
        data.snapshots.where((s) => s.accountId == accountId).toList()
          ..sort((a, b) => b.recordDate.compareTo(a.recordDate));
    return snapshots;
  }

  /// 获取所有快照（按时间倒序）
  Future<List<FinanceSnapshot>> getAllSnapshots(
    String householdId,
  ) async {
    final data = await load(householdId);
    final snapshots = List<FinanceSnapshot>.from(data.snapshots)
      ..sort((a, b) => b.recordDate.compareTo(a.recordDate));
    return snapshots;
  }

  /// 获取某个账户的最新快照
  Future<FinanceSnapshot?> getLatestSnapshot(
    String householdId,
    String accountId,
  ) async {
    final snapshots = await getAccountSnapshots(householdId, accountId);
    return snapshots.isNotEmpty ? snapshots.first : null;
  }

  /// 添加快照
  Future<FinanceSnapshot> addSnapshot(
    String householdId,
    FinanceSnapshot snapshot,
  ) async {
    final data = await load(householdId);
    data.snapshots.add(snapshot);
    await save(householdId, data);
    return snapshot;
  }

  /// 删除快照
  Future<void> deleteSnapshot(
    String householdId,
    String snapshotId,
  ) async {
    final data = await load(householdId);
    data.snapshots.removeWhere((s) => s.id == snapshotId);
    await save(householdId, data);
  }
}
