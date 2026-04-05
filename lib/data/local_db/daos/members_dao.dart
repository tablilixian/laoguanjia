import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/members.dart';

part 'members_dao.g.dart';

@DriftAccessor(tables: [Members])
class MembersDao extends DatabaseAccessor<AppDatabase> with _$MembersDaoMixin {
  MembersDao(super.db);

  /// 获取家庭所有成员
  Future<List<Member>> getByHousehold(String householdId) =>
      (select(members)..where((m) => m.householdId.equals(householdId))).get();

  /// 获取单个成员
  Future<Member?> getById(String id) =>
      (select(members)..where((m) => m.id.equals(id))).getSingleOrNull();

  /// 监听家庭所有成员变化
  Stream<List<Member>> watchByHousehold(String householdId) =>
      (select(members)..where((m) => m.householdId.equals(householdId))).watch();

  /// 插入或更新成员
  Future<void> insertOrUpdate(Member member) async {
    final existing = await getById(member.id);
    if (existing == null) {
      await into(members).insert(member);
    } else {
      await (update(members)..where((m) => m.id.equals(member.id))).write(member);
    }
  }

  /// 批量插入或更新成员
  Future<void> batchInsertOrUpdate(List<Member> memberList) async {
    for (final member in memberList) {
      await insertOrUpdate(member);
    }
  }

  /// 删除家庭所有成员
  Future<void> deleteByHousehold(String householdId) =>
      (delete(members)..where((m) => m.householdId.equals(householdId))).go();

  /// 获取成员数量
  Future<int> getCountByHousehold(String householdId) async {
    final result = await (selectOnly(members)
          ..addColumns([members.id.count()])
          ..where(members.householdId.equals(householdId)))
        .getSingle();
    return result.read(members.id.count()) ?? 0;
  }

  // ==================== 同步方法 ====================

  /// 获取待同步的成员
  Future<List<Member>> getSyncPending() =>
      (select(members)..where((m) => m.syncPending.equals(true))).get();

  /// 标记成员已同步
  Future<int> markSynced(String id) =>
      (update(members)..where((m) => m.id.equals(id))).write(
        MembersCompanion(
          syncPending: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// 从远程数据插入或更新成员（用于同步）
  Future<void> upsertFromRemote(Map<String, dynamic> remoteMember) async {
    final companion = MembersCompanion(
      id: Value(remoteMember['id'] as String),
      householdId: Value(remoteMember['household_id'] as String),
      name: Value(remoteMember['name'] as String? ?? '未知'),
      avatarUrl: Value(remoteMember['avatar_url'] as String?),
      role: Value(remoteMember['role'] as String? ?? 'member'),
      userId: Value(remoteMember['user_id'] as String?),
      createdAt: Value(DateTime.parse(remoteMember['created_at'] as String)),
      updatedAt: Value(DateTime.now()),
      syncPending: const Value(false),
    );

    final existing = await getById(remoteMember['id'] as String);
    if (existing == null) {
      await into(members).insert(companion);
    } else {
      await (update(members)..where((m) => m.id.equals(companion.id.value))).write(companion);
    }
  }

  /// 删除所有成员（用于重置）
  Future<int> deleteAll() => delete(members).go();
}
