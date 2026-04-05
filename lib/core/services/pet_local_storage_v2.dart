import 'package:flutter/foundation.dart';
import 'package:home_manager/core/services/local_storage_service.dart';
import 'package:home_manager/data/models/pet_local_data.dart';

/// 宠物本地存储 V2
///
/// 管理单 JSON 文件的读写、归档和拆分。
///
/// 拆分策略:
/// - 按月: 跨月自动创建新文件
/// - 按大小: 文件 > 5MB 时自动归档
/// - 对话滚动: conversations > 200 条时保留最近 100 条
class PetLocalStorageV2 {
  final LocalStorageService _storage;

  PetLocalStorageV2({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService.instance;

  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const int maxConversations = 200;
  static const int retainedConversations = 100;

  /// 读取当月完整数据
  Future<PetLocalData?> loadData(String petId) async {
    final data = await _storage.readJsonFile(_filename(petId));
    if (data == null) return null;
    return PetLocalData.fromJson(data);
  }

  /// 写入完整数据 (覆盖写)，自动检查归档
  Future<void> saveData(PetLocalData data) async {
    await _storage.writeJsonFile(_filename(data.petId), data.toJson());
    await _checkAndArchive(data.petId);
  }

  /// 原子更新: 读取 → 修改 → 写回
  Future<PetLocalData> update(
    String petId,
    PetLocalData Function(PetLocalData) mutator,
  ) async {
    final data = await loadData(petId) ?? PetLocalData.empty(petId);
    final updated = mutator(data);
    await saveData(updated);
    return updated;
  }

  /// 添加互动记录
  Future<PetLocalData> addInteraction(String petId, {
    required String type,
    required int value,
  }) async {
    return update(petId, (data) {
      final now = DateTime.now();
      return data.copyWith(
        state: data.state.applyInteraction(type),
        relationship: data.relationship.recordInteraction(type),
        interactions: [
          ...data.interactions,
          PetInteractionData(
            id: now.millisecondsSinceEpoch.toString(),
            type: type,
            value: value,
            createdAt: now,
          ),
        ],
      );
    });
  }

  /// 添加记忆
  Future<PetLocalData> addMemory(String petId, PetMemoryData memory) async {
    return update(petId, (data) {
      return data.copyWith(memories: [...data.memories, memory]);
    });
  }

  /// 添加对话 (自动滚动清理)
  Future<PetLocalData> addConversation(String petId, {
    required String role,
    required String content,
  }) async {
    return update(petId, (data) {
      final conversations = [
        ...data.conversations,
        PetConversationData(
          role: role,
          content: content,
          createdAt: DateTime.now(),
        ),
      ];

      // 滚动清理: 超过上限保留最近 N 条
      final trimmed = conversations.length > maxConversations
          ? conversations.sublist(conversations.length - retainedConversations)
          : conversations;

      return data.copyWith(conversations: trimmed);
    });
  }

  /// 获取最近 N 条对话
  Future<List<PetConversationData>> getRecentConversations(
    String petId, {
    int limit = 50,
  }) async {
    final data = await loadData(petId);
    if (data == null) return [];
    final sorted = List<PetConversationData>.from(data.conversations)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  /// 清空对话
  Future<void> clearConversations(String petId) async {
    await update(petId, (data) => data.copyWith(conversations: []));
  }

  /// 检查文件大小，超限则归档
  Future<void> _checkAndArchive(String petId) async {
    if (kIsWeb) return; // Web 平台跳过归档检查

    final size = await _storage.getFileSize(_filename(petId));
    if (size > maxFileSize) {
      final data = await loadData(petId);
      if (data != null) {
        await archiveCurrentMonth(petId, data);
      }
    }
  }

  /// 归档当前月数据
  Future<void> archiveCurrentMonth(String petId, PetLocalData data) async {
    final archiveName =
        'pets/archive/pet_${petId}_${data.month}_archived.json';
    await _storage.writeJsonFile(archiveName, data.toJson());
  }

  /// 列出所有本地文件
  Future<List<String>> listFiles() async {
    final files = await _storage.listFiles();
    return files
        .where((f) => f.startsWith('pets/pet_') && f.endsWith('.json'))
        .toList();
  }

  /// 删除宠物本地数据
  Future<void> deleteData(String petId) async {
    await _storage.deleteFile(_filename(petId));
  }

  String _filename(String petId) {
    final now = DateTime.now();
    return 'pets/pet_${petId}_${now.year}-${now.month.toString().padLeft(2, '0')}.json';
  }
}
