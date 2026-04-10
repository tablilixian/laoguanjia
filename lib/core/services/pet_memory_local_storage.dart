import 'dart:convert';
import 'package:home_manager/core/services/local_storage_service.dart';
import 'package:home_manager/data/models/pet_memory.dart';

/// 宠物记忆本地存储配置
class MemoryStorageConfig {
  /// 各重要程度的存储限制
  /// key: importance (1-5)
  /// value: MemoryLimit (最大数量, 超过时删除数量)
  static const Map<int, MemoryLimit> limits = {
    1: MemoryLimit(maxCount: 200, deleteCount: 100),
    2: MemoryLimit(maxCount: 300, deleteCount: 150),
    3: MemoryLimit(maxCount: 600, deleteCount: 100),
    4: MemoryLimit(maxCount: -1, deleteCount: 0), // 永久保存
    5: MemoryLimit(maxCount: -1, deleteCount: 0), // 永久保存
  };

  /// 需要云端同步的重要程度
  static const Set<int> cloudSyncImportance = {4, 5};
}

/// 记忆存储限制配置
class MemoryLimit {
  final int maxCount;
  final int deleteCount;

  const MemoryLimit({required this.maxCount, required this.deleteCount});

  /// 是否需要清理
  bool needsCleanup(int currentCount) {
    if (maxCount == -1) return false; // 永久保存
    return currentCount > maxCount;
  }
}

/// 宠物记忆本地存储服务
/// 
/// 功能：
/// 1. 每个宠物一个 JSON 文件存储记忆
/// 2. 按重要性分级管理存储空间
/// 3. 自动清理超过限制的旧记忆
/// 4. 仅同步重要记忆（4-5星）到云端
class PetMemoryLocalStorage {
  final LocalStorageService _storage = LocalStorageService.instance;

  /// 获取宠物记忆文件名
  String _getMemoryFileName(String petId) {
    return 'pet_memories_$petId.json';
  }

  /// 保存记忆到本地
  /// 
  /// 流程：
  /// 1. 读取现有记忆
  /// 2. 添加新记忆
  /// 3. 按重要性清理超限记忆
  /// 4. 保存到本地文件
  Future<void> saveMemory(PetMemory memory) async {
    final fileName = _getMemoryFileName(memory.petId);
    
    // 读取现有记忆
    final memories = await loadMemories(memory.petId);
    
    // 添加新记忆
    memories.add(memory);
    
    // 按重要性清理
    final cleanedMemories = _cleanupMemories(memories);
    
    // 保存到本地
    await _saveToFile(fileName, cleanedMemories);
  }

  /// 批量保存记忆到本地
  Future<void> saveMemories(List<PetMemory> memories) async {
    if (memories.isEmpty) return;
    
    final petId = memories.first.petId;
    final fileName = _getMemoryFileName(petId);
    
    // 读取现有记忆
    final existingMemories = await loadMemories(petId);
    
    // 合并记忆
    existingMemories.addAll(memories);
    
    // 按重要性清理
    final cleanedMemories = _cleanupMemories(existingMemories);
    
    // 保存到本地
    await _saveToFile(fileName, cleanedMemories);
  }

  /// 从本地加载记忆
  /// 
  /// 返回所有记忆，按时间倒序排列
  Future<List<PetMemory>> loadMemories(String petId) async {
    final fileName = _getMemoryFileName(petId);
    
    try {
      final data = await _storage.readJsonFile(fileName);
      if (data == null) return [];
      
      final memoriesJson = data['memories'] as List?;
      if (memoriesJson == null) return [];
      
      return memoriesJson
          .map((json) => PetMemory.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    } catch (e) {
      return [];
    }
  }

  /// 获取指定重要程度的记忆
  Future<List<PetMemory>> getMemoriesByImportance(
    String petId, {
    required int importance,
  }) async {
    final memories = await loadMemories(petId);
    return memories.where((m) => m.importance == importance).toList();
  }

  /// 获取重要记忆（importance >= 4）
  Future<List<PetMemory>> getImportantMemories(
    String petId, {
    int limit = 3,
  }) async {
    final memories = await loadMemories(petId);
    final important = memories.where((m) => m.importance >= 4).toList();
    return important.take(limit).toList();
  }

  /// 获取最近记忆
  Future<List<PetMemory>> getRecentMemories(
    String petId, {
    int days = 7,
    int limit = 3,
  }) async {
    final memories = await loadMemories(petId);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recent = memories.where((m) => m.occurredAt.isAfter(cutoff)).toList();
    return recent.take(limit).toList();
  }

  /// 删除指定记忆
  Future<void> deleteMemory(String petId, String memoryId) async {
    final memories = await loadMemories(petId);
    memories.removeWhere((m) => m.id == memoryId);
    
    final fileName = _getMemoryFileName(petId);
    await _saveToFile(fileName, memories);
  }

  /// 清空宠物的所有记忆
  Future<void> clearMemories(String petId) async {
    final fileName = _getMemoryFileName(petId);
    await _storage.writeJsonFile(fileName, {
      'pet_id': petId,
      'version': '1.0',
      'last_updated': DateTime.now().toIso8601String(),
      'memories': [],
    });
  }

  /// 获取记忆统计信息
  Future<Map<String, dynamic>> getStatistics(String petId) async {
    final memories = await loadMemories(petId);
    
    final byImportance = <int, int>{};
    for (final memory in memories) {
      byImportance[memory.importance] = (byImportance[memory.importance] ?? 0) + 1;
    }
    
    return {
      'total_count': memories.length,
      'by_importance': byImportance,
      'oldest_memory': memories.isNotEmpty ? memories.last.occurredAt : null,
      'newest_memory': memories.isNotEmpty ? memories.first.occurredAt : null,
    };
  }

  /// 按重要性清理记忆
  /// 
  /// 清理规则：
  /// - 1星：超过200条，删除最旧的100条
  /// - 2星：超过300条，删除最旧的150条
  /// - 3星：超过600条，删除最旧的100条
  /// - 4-5星：永久保存
  List<PetMemory> _cleanupMemories(List<PetMemory> memories) {
    final result = <PetMemory>[];
    
    // 按重要性分组
    final grouped = <int, List<PetMemory>>{};
    for (final memory in memories) {
      grouped.putIfAbsent(memory.importance, () => []).add(memory);
    }
    
    // 对每组进行清理
    for (final entry in grouped.entries) {
      final importance = entry.key;
      var groupMemories = entry.value;
      
      // 按时间排序（最新在前）
      groupMemories.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      
      final limit = MemoryStorageConfig.limits[importance];
      if (limit != null && limit.needsCleanup(groupMemories.length)) {
        // 删除最旧的 N 条
        groupMemories = groupMemories.take(limit.maxCount).toList();
      }
      
      result.addAll(groupMemories);
    }
    
    // 最终按时间排序
    result.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    
    return result;
  }

  /// 保存记忆到文件
  Future<void> _saveToFile(String fileName, List<PetMemory> memories) async {
    if (memories.isEmpty) return;
    
    final petId = memories.first.petId;
    
    final data = {
      'pet_id': petId,
      'version': '1.0',
      'last_updated': DateTime.now().toIso8601String(),
      'statistics': {
        'total_count': memories.length,
        'by_importance': _countByImportance(memories),
      },
      'memories': memories.map((m) => m.toJson()).toList(),
    };
    
    await _storage.writeJsonFile(fileName, data);
  }

  /// 统计各重要程度的数量
  Map<String, int> _countByImportance(List<PetMemory> memories) {
    final count = <int, int>{};
    for (final memory in memories) {
      count[memory.importance] = (count[memory.importance] ?? 0) + 1;
    }
    return count.map((key, value) => MapEntry(key.toString(), value));
  }
}
