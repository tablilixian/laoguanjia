import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../data/local_db/app_database.dart';

class DatabaseDebugNotifier extends StateNotifier<DatabaseDebugState> {
  final AppDatabase _db;

  DatabaseDebugNotifier(this._db) : super(const DatabaseDebugState()) {
    loadTableCounts();
  }

  Future<void> loadTableCounts() async {
    state = const DatabaseDebugState(isLoading: true);

    try {
      final counts = <String, int>{};
      
      final itemsCount = await _db.itemsDao.getAllCount();
      counts['household_items'] = itemsCount;
      
      final locationsCount = await _db.locationsDao.getAllCount();
      counts['item_locations'] = locationsCount;
      
      final tagsCount = await _db.tagsDao.getAllCount();
      counts['item_tags'] = tagsCount;
      
      final relationsCount = await _db.itemTagRelationsDao.getAllCount();
      counts['item_tag_relations'] = relationsCount;
      
      final typesCount = await _db.typesDao.getAllCount();
      counts['item_type_configs'] = typesCount;
      
      final tasksCount = await _db.tasksDao.getAllCount();
      counts['tasks'] = tasksCount;

      state = DatabaseDebugState(
        isLoading: false,
        tableCounts: counts,
      );
    } catch (e) {
      state = DatabaseDebugState(
        isLoading: false,
        errorMessage: '加载表格统计失败: $e',
      );
    }
  }

  Future<void> loadTableData(String tableName) async {
    state = DatabaseDebugState(
      isLoading: true,
      selectedTable: tableName,
      errorMessage: null,
    );

    try {
      List<Map<String, dynamic>> data = [];

      switch (tableName) {
        case 'household_items':
          final items = await _db.itemsDao.getAll();
          data = items.map((item) => item.toJson()).toList();
          break;
        case 'item_locations':
          final locations = await _db.locationsDao.getAll();
          data = locations.map((location) => location.toJson()).toList();
          break;
        case 'item_tags':
          final tags = await _db.tagsDao.getAll();
          data = tags.map((tag) => tag.toJson()).toList();
          break;
        case 'item_tag_relations':
          final relations = await _db.itemTagRelationsDao.getAll();
          data = relations.map((relation) => relation.toJson()).toList();
          break;
        case 'item_type_configs':
          final types = await _db.typesDao.getAll();
          data = types.map((type) => type.toJson()).toList();
          break;
        case 'tasks':
          final tasks = await _db.tasksDao.getAll();
          data = tasks.map((task) => task.toJson()).toList();
          break;
      }

      state = DatabaseDebugState(
        isLoading: false,
        selectedTableData: data,
      );
    } catch (e) {
      state = DatabaseDebugState(
        isLoading: false,
        errorMessage: '加载数据失败: $e',
      );
    }
  }

  Future<void> clearTable(String tableName) async {
    try {
      switch (tableName) {
        case 'household_items':
          await _db.itemsDao.deleteAll();
          break;
        case 'item_locations':
          await _db.locationsDao.deleteAll();
          break;
        case 'item_tags':
          await _db.tagsDao.deleteAll();
          break;
        case 'item_tag_relations':
          await _db.itemTagRelationsDao.deleteAll();
          break;
        case 'item_type_configs':
          await _db.typesDao.deleteAll();
          break;
        case 'tasks':
          await _db.tasksDao.deleteAll();
          break;
      }

      await loadTableCounts();
      if (state.selectedTable == tableName) {
        await loadTableData(tableName);
      }
    } catch (e) {
      state = DatabaseDebugState(
        errorMessage: '清空表格失败: $e',
      );
    }
  }

  Future<String> exportTableAsJson(String tableName) async {
    try {
      List<Map<String, dynamic>> data = [];

      switch (tableName) {
        case 'household_items':
          final items = await _db.itemsDao.getAll();
          data = items.map((item) => item.toJson()).toList();
          break;
        case 'item_locations':
          final locations = await _db.locationsDao.getAll();
          data = locations.map((location) => location.toJson()).toList();
          break;
        case 'item_tags':
          final tags = await _db.tagsDao.getAll();
          data = tags.map((tag) => tag.toJson()).toList();
          break;
        case 'item_tag_relations':
          final relations = await _db.itemTagRelationsDao.getAll();
          data = relations.map((relation) => relation.toJson()).toList();
          break;
        case 'item_type_configs':
          final types = await _db.typesDao.getAll();
          data = types.map((type) => type.toJson()).toList();
          break;
        case 'tasks':
          final tasks = await _db.tasksDao.getAll();
          data = tasks.map((task) => task.toJson()).toList();
          break;
      }

      final encoder = const JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(data);
      return jsonString;
    } catch (e) {
      state = DatabaseDebugState(
        errorMessage: '导出数据失败: $e',
      );
      return '';
    }
  }

  void clearError() {
    state = DatabaseDebugState(
      tableCounts: state.tableCounts,
      selectedTable: state.selectedTable,
      selectedTableData: state.selectedTableData,
    );
  }
}

class DatabaseDebugState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, int> tableCounts;
  final String? selectedTable;
  final List<Map<String, dynamic>> selectedTableData;

  const DatabaseDebugState({
    this.isLoading = false,
    this.errorMessage,
    this.tableCounts = const {},
    this.selectedTable,
    this.selectedTableData = const [],
  });

  DatabaseDebugState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, int>? tableCounts,
    String? selectedTable,
    List<Map<String, dynamic>>? selectedTableData,
  }) {
    return DatabaseDebugState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      tableCounts: tableCounts ?? this.tableCounts,
      selectedTable: selectedTable ?? this.selectedTable,
      selectedTableData: selectedTableData ?? this.selectedTableData,
    );
  }
}

final databaseDebugProvider = StateNotifierProvider<DatabaseDebugNotifier, DatabaseDebugState>((ref) {
  final db = AppDatabase();
  return DatabaseDebugNotifier(db);
});