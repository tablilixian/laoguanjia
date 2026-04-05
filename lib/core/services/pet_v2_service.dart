import 'dart:convert';
import 'package:home_manager/data/models/pet_meta.dart';
import 'package:home_manager/data/models/pet_local_data.dart';
import 'package:home_manager/data/repositories/pet_meta_repository.dart';
import 'package:home_manager/data/repositories/pet_local_repository.dart';
import 'package:home_manager/core/services/pet_local_storage_v2.dart';

/// 宠物管家 V2 统一业务逻辑层
///
/// 组合云端元数据仓库和本地数据仓库，提供完整的宠物管理 API。
/// 所有互动操作走本地，仅身份关联走云端。
class PetV2Service {
  final PetMetaRepository _metaRepo;
  final PetLocalRepository _localRepo;
  final PetLocalStorageV2 _localStorage;

  PetV2Service({
    PetMetaRepository? metaRepo,
    PetLocalRepository? localRepo,
    PetLocalStorageV2? localStorage,
  })  : _metaRepo = metaRepo ?? PetMetaRepository(),
        _localRepo = localRepo ?? PetLocalRepository(),
        _localStorage = localStorage ?? PetLocalStorageV2();

  /// 创建宠物: 云端写元数据 + 本地初始化完整数据
  Future<PetLocalData> createPet({
    required String householdId,
    String? ownerId,
    required String name,
    required String type,
    String? breed,
  }) async {
    // 1. 云端: 写元数据
    final meta = await _metaRepo.createMeta(PetMeta(
      householdId: householdId,
      ownerId: ownerId,
      name: name,
      type: type,
      breed: breed,
    ));

    // 2. 本地: 初始化完整数据
    final localData = PetLocalData.empty(meta.id);
    await _localRepo.saveData(localData);

    return localData;
  }

  /// 获取家庭下所有宠物元数据
  Future<List<PetMeta>> getPetMetas(String householdId) async {
    return _metaRepo.getMetas(householdId);
  }

  /// 获取宠物完整本地数据
  Future<PetLocalData?> getPetData(String petId) async {
    return _localRepo.loadData(petId);
  }

  /// 互动: 纯本地操作，零云端写入
  Future<PetLocalData> interact(String petId, String type) async {
    final effects = _getInteractionEffects(type);
    final value = effects.values.isNotEmpty ? effects.values.first : 0;
    return _localStorage.addInteraction(petId, type: type, value: value);
  }

  /// 更新宠物心情
  Future<PetLocalData> updateMood(
    String petId,
    String mood,
    String? moodText,
  ) async {
    return _localRepo.update(petId, (data) {
      return data.copyWith(
        state: data.state.copyWith(
          currentMood: mood,
          moodText: moodText,
        ),
      );
    });
  }

  /// 更新宠物技能
  Future<PetLocalData> updateSkills(
    String petId,
    List<PetSkillData> skills,
  ) async {
    return _localRepo.update(petId, (data) {
      return data.copyWith(
        state: data.state.copyWith(skills: skills),
      );
    });
  }

  /// 保存对话
  Future<void> saveConversation(
    String petId,
    String role,
    String content,
  ) async {
    await _localStorage.addConversation(petId, role: role, content: content);
  }

  /// 获取最近对话
  Future<List<PetConversationData>> getConversations(
    String petId, {
    int limit = 50,
  }) async {
    return _localStorage.getRecentConversations(petId, limit: limit);
  }

  /// 清空对话
  Future<void> clearConversations(String petId) async {
    await _localStorage.clearConversations(petId);
  }

  /// 添加记忆
  Future<void> addMemory(String petId, PetMemoryData memory) async {
    await _localStorage.addMemory(petId, memory);
  }

  /// 同步状态快照到云端 (可选)
  Future<void> syncSnapshot(String petId) async {
    final data = await _localRepo.loadData(petId);
    if (data == null) return;

    final meta = await _metaRepo.getMeta(petId);
    if (meta == null) return;

    await _metaRepo.updateMeta(meta, snapshot: data.state.toJson());
  }

  /// 删除宠物 (云端 + 本地)
  Future<void> deletePet(String petId) async {
    await _metaRepo.deleteMeta(petId);
    await _localRepo.deleteData(petId);
    await _localStorage.deleteData(petId);
  }

  /// 导出宠物完整数据为 JSON 字符串
  Future<String> exportPet(String petId) async {
    final data = await _localRepo.loadData(petId);
    if (data == null) throw Exception('Pet data not found');
    return jsonEncode(data.toJson());
  }

  /// 从 JSON 字符串导入宠物数据
  Future<PetLocalData> importPet(String jsonData, String householdId) async {
    final json = jsonDecode(jsonData) as Map<String, dynamic>;
    final data = PetLocalData.fromJson(json);

    // 确保 petId 与云端元数据一致
    final meta = await _metaRepo.getMeta(data.petId);
    if (meta == null) {
      // 云端无元数据，创建新的
      await _metaRepo.createMeta(PetMeta(
        id: data.petId,
        householdId: householdId,
        name: data.state.currentMood,
        type: 'other',
      ));
    }

    await _localRepo.saveData(data);
    return data;
  }

  Map<String, int> _getInteractionEffects(String type) {
    const effects = {
      'feed': {'hunger': 20, 'happiness': 5, 'experience': 5},
      'play': {'happiness': 20, 'hunger': -5, 'experience': 10},
      'bath': {'cleanliness': 30, 'happiness': -5, 'experience': 5},
      'train': {'happiness': 10, 'hunger': -10, 'experience': 15},
    };
    return effects[type] ?? {};
  }
}
