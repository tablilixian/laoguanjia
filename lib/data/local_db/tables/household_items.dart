import 'package:drift/drift.dart';

class HouseholdItems extends Table {
  TextColumn get id => text()();
  
  TextColumn get householdId => text()();
  
  TextColumn get name => text()();
  
  TextColumn get description => text().nullable()();
  
  TextColumn get itemType => text()();
  
  TextColumn get locationId => text().nullable()();
  
  TextColumn get ownerId => text().nullable()();
  
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  
  TextColumn get brand => text().nullable()();
  
  TextColumn get model => text().nullable()();
  
  DateTimeColumn get purchaseDate => dateTime().nullable()();
  
  RealColumn get purchasePrice => real().nullable()();
  
  DateTimeColumn get warrantyExpiry => dateTime().nullable()();
  
  TextColumn get condition => text().withDefault(const Constant('good'))();
  
  TextColumn get imageUrl => text().nullable()();
  
  TextColumn get thumbnailUrl => text().nullable()();
  
  TextColumn get notes => text().nullable()();
  
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  
  TextColumn get remoteId => text().nullable()();
  
  TextColumn get createdBy => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime()();
  
  DateTimeColumn get updatedAt => dateTime()();
  
  DateTimeColumn get deletedAt => dateTime().nullable()();
  
  IntColumn get version => integer().withDefault(const Constant(1))();
  
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  
  TextColumn get slotPosition => text().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}
