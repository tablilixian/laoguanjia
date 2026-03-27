import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../app_database.dart' as db;

QueryExecutor openConnection() {
  return driftDatabase(name: 'home_manager');
}

db.AppDatabase? _databaseInstance;

db.AppDatabase getDatabase() {
  _databaseInstance ??= db.AppDatabase();
  return _databaseInstance!;
}
