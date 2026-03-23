import 'package:drift/drift.dart';

class ItemTagRelations extends Table {
  TextColumn get itemId => text()();
  
  TextColumn get tagId => text()();
  
  DateTimeColumn get createdAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {itemId, tagId};
}
