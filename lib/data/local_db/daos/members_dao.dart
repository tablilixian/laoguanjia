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
}
