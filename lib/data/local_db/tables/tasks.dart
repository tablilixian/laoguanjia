import 'package:drift/drift.dart';

class Tasks extends Table {
  TextColumn get id => text()();
  
  TextColumn get householdId => text()();
  
  TextColumn get title => text()();
  
  TextColumn get description => text().nullable()();
  
  TextColumn get assignedTo => text().nullable()();
  
  DateTimeColumn get dueDate => dateTime().nullable()();
  
  TextColumn get recurrence => text()();
  
  TextColumn get status => text()();
  
  TextColumn get createdBy => text()();
  
  DateTimeColumn get createdAt => dateTime()();
  
  DateTimeColumn get completedAt => dateTime().nullable()();
  
  DateTimeColumn get updatedAt => dateTime()();
  
  DateTimeColumn get deletedAt => dateTime().nullable()();
  
  IntColumn get version => integer().withDefault(const Constant(1))();
  
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  
  @override
  Set<Column> get primaryKey => {id};
}
