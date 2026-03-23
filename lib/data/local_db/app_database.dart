import 'package:drift/drift.dart';

import 'tables/tasks.dart';
import 'daos/tasks_dao.dart';
import 'tables/household_items.dart';
import 'tables/item_locations.dart';
import 'tables/item_tags.dart';
import 'tables/item_type_configs.dart';
import 'tables/item_tag_relations.dart';
import 'daos/items_dao.dart';
import 'daos/locations_dao.dart';
import 'daos/tags_dao.dart';
import 'daos/types_dao.dart';
import 'daos/item_tag_relations_dao.dart';
import 'connection/connection.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Tasks,
    HouseholdItems,
    ItemLocations,
    ItemTags,
    ItemTypeConfigs,
    ItemTagRelations,
  ],
  daos: [
    TasksDao,
    ItemsDao,
    LocationsDao,
    TagsDao,
    TypesDao,
    ItemTagRelationsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());
  
  @override
  int get schemaVersion => 2;
  
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(householdItems);
        await m.createTable(itemLocations);
        await m.createTable(itemTags);
        await m.createTable(itemTypeConfigs);
        await m.createTable(itemTagRelations);
      }
    },
  );

  Future<void> resetDatabase() async {
    await transaction(() async {
      await delete(tasks).go();
      await delete(householdItems).go();
      await delete(itemLocations).go();
      await delete(itemTags).go();
      await delete(itemTypeConfigs).go();
      await delete(itemTagRelations).go();
    });
  }
}
