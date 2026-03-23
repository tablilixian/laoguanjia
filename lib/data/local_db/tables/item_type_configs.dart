import 'package:drift/drift.dart';

class ItemTypeConfigs extends Table {
  TextColumn get id => text()();
  
  TextColumn get householdId => text().nullable()();
  
  TextColumn get typeKey => text()();
  
  TextColumn get typeLabel => text()();
  
  TextColumn get icon => text().withDefault(const Constant('📦'))();
  
  TextColumn get color => text().withDefault(const Constant('#6B7280'))();
  
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  
  DateTimeColumn get createdAt => dateTime()();
  
  DateTimeColumn get updatedAt => dateTime()();
  
  IntColumn get version => integer().withDefault(const Constant(1))();
  
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  
  @override
  Set<Column> get primaryKey => {id};
}
