import 'package:flutter_test/flutter_test.dart';
import 'package:home_manager/core/services/pet_memory_local_storage.dart';
import 'package:home_manager/data/models/pet_memory.dart';

void main() {
  group('PetMemoryLocalStorage Tests', () {
    test('Memory Storage Config Test', () {
      // 测试存储配置
      expect(MemoryStorageConfig.limits[1]!.maxCount, equals(200));
      expect(MemoryStorageConfig.limits[2]!.maxCount, equals(300));
      expect(MemoryStorageConfig.limits[3]!.maxCount, equals(600));
      expect(MemoryStorageConfig.limits[4]!.maxCount, equals(-1)); // 永久保存
      expect(MemoryStorageConfig.limits[5]!.maxCount, equals(-1)); // 永久保存
      
      // 测试云端同步配置
      expect(MemoryStorageConfig.cloudSyncImportance.contains(4), isTrue);
      expect(MemoryStorageConfig.cloudSyncImportance.contains(5), isTrue);
      expect(MemoryStorageConfig.cloudSyncImportance.contains(1), isFalse);
    });

    test('Memory Limit Cleanup Test', () {
      // 测试清理逻辑
      final limit1 = MemoryLimit(maxCount: 200, deleteCount: 100);
      expect(limit1.needsCleanup(150), isFalse);
      expect(limit1.needsCleanup(201), isTrue);
      
      final limit4 = MemoryLimit(maxCount: -1, deleteCount: 0);
      expect(limit4.needsCleanup(1000), isFalse); // 永久保存
    });

    test('PetMemory Model Test', () {
      // 测试记忆模型
      final memory = PetMemory(
        id: 'test-id',
        petId: 'test-pet-id',
        memoryType: 'interaction',
        title: '测试记忆',
        description: '这是一个测试记忆',
        emotion: 'joy',
        participants: ['主人', '我'],
        importance: 3,
        isSummarized: false,
        occurredAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(memory.id, equals('test-id'));
      expect(memory.importance, equals(3));
      expect(memory.memoryType, equals('interaction'));
      
      // 测试 JSON 序列化
      final json = memory.toJson();
      final fromJson = PetMemory.fromJson(json);
      expect(fromJson.id, equals(memory.id));
      expect(fromJson.importance, equals(memory.importance));
    });
  });
}
