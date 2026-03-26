import 'package:drift/drift.dart';

class ItemTags extends Table {
  TextColumn get id => text()();
  
  TextColumn get householdId => text()();
  
  TextColumn get name => text()();
  
  TextColumn get color => text().withDefault(const Constant('#6B7280'))();
  
  TextColumn get icon => text().nullable()();
  
  TextColumn get category => text().withDefault(const Constant('other'))();
  
  TextColumn get applicableTypes => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime()();
  
  DateTimeColumn get updatedAt => dateTime()();
  
  IntColumn get version => integer().withDefault(const Constant(1))();
  
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  
  /// 标签序号（用于位图，0-62）
  IntColumn get tagIndex => integer().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}
