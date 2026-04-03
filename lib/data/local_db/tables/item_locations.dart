import 'package:drift/drift.dart';

class ItemLocations extends Table {
  TextColumn get id => text()();
  
  TextColumn get householdId => text()();
  
  TextColumn get name => text()();
  
  TextColumn get description => text().nullable()();
  
  TextColumn get icon => text().withDefault(const Constant('📍'))();
  
  TextColumn get color => text().nullable()();
  
  TextColumn get parentId => text().nullable()();
  
  IntColumn get depth => integer().withDefault(const Constant(0))();
  
  TextColumn get path => text().nullable()();
  
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  
  DateTimeColumn get createdAt => dateTime()();
  
  DateTimeColumn get updatedAt => dateTime()();
  
  TextColumn get templateType => text().nullable()();
  
  TextColumn get templateConfig => text().nullable()();
  
  TextColumn get positionInParent => text().nullable()();
  
  TextColumn get positionDescription => text().nullable()();
  
  IntColumn get version => integer().withDefault(const Constant(1))();
  
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  
  DateTimeColumn get deletedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}
