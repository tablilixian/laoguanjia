import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart';

import 'package:home_manager/data/local_db/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late AppDatabase database;

  setUp(() {
    database = AppDatabase();
  });

  tearDown(() async {
    await database.close();
  });

  group('本地数据库测试', () {
    test('插入和查询任务', () async {
      final now = DateTime.now();
      final task = TasksCompanion(
        id: const Value('test-001'),
        householdId: const Value('household-001'),
        title: const Value('测试任务'),
        description: const Value('这是一个测试任务'),
        recurrence: const Value('none'),
        status: const Value('pending'),
        createdBy: const Value('user-001'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await database.tasksDao.insertTask(task);

      final retrieved = await database.tasksDao.getById('test-001');

      expect(retrieved, isNot(equals(null)));
      expect(retrieved!.id, equals('test-001'));
      expect(retrieved.title, equals('测试任务'));
      expect(retrieved.version, equals(1));
      expect(retrieved.syncPending, equals(false));
    });

    test('更新任务', () async {
      final now = DateTime.now();
      final task = TasksCompanion(
        id: const Value('test-002'),
        householdId: const Value('household-001'),
        title: const Value('原始标题'),
        recurrence: const Value('none'),
        status: const Value('pending'),
        createdBy: const Value('user-001'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await database.tasksDao.insertTask(task);

      final updated = TasksCompanion(
        id: const Value('test-002'),
        title: const Value('更新后的标题'),
        updatedAt: Value(DateTime.now()),
      );

      await database.tasksDao.updateTask(updated);

      final retrieved = await database.tasksDao.getById('test-002');

      expect(retrieved, isNot(equals(null)));
      expect(retrieved!.title, equals('更新后的标题'));
    });

    test('删除任务', () async {
      final now = DateTime.now();
      final task = TasksCompanion(
        id: const Value('test-003'),
        householdId: const Value('household-001'),
        title: const Value('待删除任务'),
        recurrence: const Value('none'),
        status: const Value('pending'),
        createdBy: const Value('user-001'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await database.tasksDao.insertTask(task);

      var retrieved = await database.tasksDao.getById('test-003');
      expect(retrieved, isNot(equals(null)));

      await database.tasksDao.deleteTask('test-003');

      retrieved = await database.tasksDao.getById('test-003');
      expect(retrieved, equals(null));
    });

    test('查询待同步任务', () async {
      final now = DateTime.now();

      final task1 = TasksCompanion(
        id: const Value('test-004'),
        householdId: const Value('household-001'),
        title: const Value('已同步任务'),
        recurrence: const Value('none'),
        status: const Value('pending'),
        createdBy: const Value('user-001'),
        createdAt: Value(now),
        updatedAt: Value(now),
        syncPending: const Value(false),
      );

      final task2 = TasksCompanion(
        id: const Value('test-005'),
        householdId: const Value('household-001'),
        title: const Value('待同步任务'),
        recurrence: const Value('none'),
        status: const Value('pending'),
        createdBy: const Value('user-001'),
        createdAt: Value(now),
        updatedAt: Value(now),
        syncPending: const Value(true),
      );

      await database.tasksDao.insertTask(task1);
      await database.tasksDao.insertTask(task2);

      final pending = await database.tasksDao.getSyncPending();

      expect(pending.length, equals(1));
      expect(pending.first.id, equals('test-005'));
    });

    test('标记任务已同步', () async {
      final now = DateTime.now();
      final task = TasksCompanion(
        id: const Value('test-006'),
        householdId: const Value('household-001'),
        title: const Value('待同步任务'),
        recurrence: const Value('none'),
        status: const Value('pending'),
        createdBy: const Value('user-001'),
        createdAt: Value(now),
        updatedAt: Value(now),
        syncPending: const Value(true),
      );

      await database.tasksDao.insertTask(task);

      var retrieved = await database.tasksDao.getById('test-006');
      expect(retrieved!.syncPending, equals(true));

      await database.tasksDao.markSynced('test-006');

      retrieved = await database.tasksDao.getById('test-006');
      expect(retrieved!.syncPending, equals(false));
    });

    test('按家庭ID查询任务', () async {
      final now = DateTime.now();

      final task1 = TasksCompanion(
        id: const Value('test-007'),
        householdId: const Value('household-A'),
        title: const Value('家庭A的任务1'),
        recurrence: const Value('none'),
        status: const Value('pending'),
        createdBy: const Value('user-001'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      final task2 = TasksCompanion(
        id: const Value('test-008'),
        householdId: const Value('household-A'),
        title: const Value('家庭A的任务2'),
        recurrence: const Value('none'),
        status: const Value('completed'),
        createdBy: const Value('user-001'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      final task3 = TasksCompanion(
        id: const Value('test-009'),
        householdId: const Value('household-B'),
        title: const Value('家庭B的任务'),
        recurrence: const Value('none'),
        status: const Value('pending'),
        createdBy: const Value('user-001'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await database.tasksDao.insertTask(task1);
      await database.tasksDao.insertTask(task2);
      await database.tasksDao.insertTask(task3);

      final householdATasks = await database.tasksDao.getByHousehold('household-A');

      expect(householdATasks.length, equals(2));
      expect(householdATasks.every((t) => t.householdId == 'household-A'), isTrue);
    });
  });
}
