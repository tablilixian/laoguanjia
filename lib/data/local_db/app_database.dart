import 'package:drift/drift.dart';

import 'tables/tasks.dart';
import 'daos/tasks_dao.dart';
import 'connection/connection.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Tasks], daos: [TasksDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());
  
  @override
  int get schemaVersion => 1;
  
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
  );

  Future<void> resetDatabase() async {
    await transaction(() async {
      await delete(tasks).go();
    });
  }
}
