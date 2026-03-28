import 'package:drift/drift.dart';

/// 家庭成员表
class Members extends Table {
  /// 成员ID
  TextColumn get id => text()();
  
  /// 家庭ID
  TextColumn get householdId => text()();
  
  /// 成员名称
  TextColumn get name => text()();
  
  /// 头像URL
  TextColumn get avatarUrl => text().nullable()();
  
  /// 角色 (admin, member)
  TextColumn get role => text().withDefault(const Constant('member'))();
  
  /// 用户ID（关联 auth.users）
  TextColumn get userId => text().nullable()();
  
  /// 创建时间
  DateTimeColumn get createdAt => dateTime()();
  
  /// 更新时间
  DateTimeColumn get updatedAt => dateTime()();
  
  /// 同步状态
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
