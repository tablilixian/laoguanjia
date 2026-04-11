import 'dart:convert';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_personality.dart';
import 'package:home_manager/data/models/pet_memory.dart';
import 'package:home_manager/data/models/pet_relationship.dart';
import 'package:home_manager/data/models/pet_skill.dart';
import 'package:home_manager/data/models/pet_export_data.dart';
import 'package:home_manager/data/supabase/supabase_client.dart';
import 'package:home_manager/core/services/pet_memory_local_storage.dart';

class PetAIRepository {
  final supabase = SupabaseClientManager.client;
  final PetMemoryLocalStorage _localStorage = PetMemoryLocalStorage();

  bool isOwner(Pet pet, String userId) {
    return pet.ownerId == userId;
  }

  Future<PetPersonality?> getPersonality(String petId) async {
    try {
      final data = await supabase
          .from('pet_personalities')
          .select()
          .eq('pet_id', petId)
          .maybeSingle();
      if (data == null) return null;
      return PetPersonality.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<PetPersonality> createPersonality(PetPersonality personality) async {
    final data = await supabase
        .from('pet_personalities')
        .insert(personality.toJson())
        .select()
        .single();
    return PetPersonality.fromJson(data);
  }

  Future<PetPersonality> updatePersonality(PetPersonality personality) async {
    final data = await supabase
        .from('pet_personalities')
        .update({
          'openness': personality.openness,
          'agreeableness': personality.agreeableness,
          'extraversion': personality.extraversion,
          'conscientiousness': personality.conscientiousness,
          'neuroticism': personality.neuroticism,
          'traits': personality.traits,
          'habits': personality.habits,
          'fears': personality.fears,
          'speech_style': personality.speechStyle,
          'origin_description': personality.originDescription,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', personality.id)
        .select()
        .single();
    return PetPersonality.fromJson(data);
  }

  /// 获取宠物记忆
  /// 
  /// 优先读取本地数据，本地没有数据时从云端读取并同步到本地
  Future<List<PetMemory>> getMemories(String petId, {int? limit}) async {
    try {
      // 优先读取本地数据
      final localMemories = await _localStorage.loadMemories(petId);
      
      if (localMemories.isNotEmpty) {
        // 本地有数据，直接返回
        if (limit != null) {
          return localMemories.take(limit).toList();
        }
        return localMemories;
      }
      
      // 本地没有数据，从云端读取
      var query = supabase
          .from('pet_memories')
          .select()
          .eq('pet_id', petId)
          .order('occurred_at', ascending: false);
      if (limit != null) {
        query = query.limit(limit);
      }
      final data = await query;
      final memories = (data as List).map((m) => PetMemory.fromJson(m)).toList();
      
      // 同步到本地
      if (memories.isNotEmpty) {
        await _localStorage.saveMemories(memories);
      }
      
      return memories;
    } catch (e) {
      return [];
    }
  }

  /// 创建记忆
  /// 
  /// 所有记忆都保存到本地，只有重要记忆（4-5星）才同步到云端
  Future<PetMemory> createMemory(PetMemory memory) async {
    // 保存到本地
    await _localStorage.saveMemory(memory);
    
    // 如果是重要记忆（4-5星），同步到云端
    if (MemoryStorageConfig.cloudSyncImportance.contains(memory.importance)) {
      try {
        final data = await supabase
            .from('pet_memories')
            .insert(memory.toJson())
            .select()
            .single();
        return PetMemory.fromJson(data);
      } catch (e) {
        // 云端保存失败不影响本地存储，返回原始记忆
        return memory;
      }
    }
    
    return memory;
  }

  /// 获取重要记忆（importance >= 4）
  /// 
  /// 从本地存储读取
  Future<List<PetMemory>> getImportantMemories(
    String petId, {
    int limit = 3,
  }) async {
    try {
      return await _localStorage.getImportantMemories(petId, limit: limit);
    } catch (e) {
      return [];
    }
  }

  /// 获取最近记忆
  /// 
  /// 从本地存储读取
  Future<List<PetMemory>> getRecentMemories(
    String petId, {
    int days = 7,
    int limit = 3,
  }) async {
    try {
      return await _localStorage.getRecentMemories(
        petId,
        days: days,
        limit: limit,
      );
    } catch (e) {
      return [];
    }
  }

  Future<PetRelationship?> getRelationship(String petId) async {
    try {
      final data = await supabase
          .from('pet_relationship')
          .select()
          .eq('pet_id', petId)
          .maybeSingle();
      if (data == null) return null;
      return PetRelationship.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<PetRelationship> createRelationship(String petId) async {
    final now = DateTime.now();
    final data = await supabase
        .from('pet_relationship')
        .insert({
          'pet_id': petId,
          'trust_level': 0,
          'intimacy_level': 0,
          'total_interactions': 0,
          'feed_count': 0,
          'play_count': 0,
          'chat_count': 0,
          'joy_score': 0,
          'sadness_score': 0,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        })
        .select()
        .single();
    return PetRelationship.fromJson(data);
  }

  Future<PetRelationship> updateRelationship(
    String petId, {
    bool isOwnerInteraction = false,
    String? interactionType,
  }) async {
    if (!isOwnerInteraction) {
      final existing = await getRelationship(petId);
      return existing ?? await createRelationship(petId);
    }

    final existing = await getRelationship(petId);
    final now = DateTime.now();
    int totalInteractions = (existing?.totalInteractions ?? 0) + 1;
    int feedCount = existing?.feedCount ?? 0;
    int playCount = existing?.playCount ?? 0;
    int chatCount = existing?.chatCount ?? 0;

    if (interactionType == 'feed') feedCount++;
    if (interactionType == 'play') playCount++;
    if (interactionType == 'chat') chatCount++;

    int intimacyLevel = PetRelationship.calculateIntimacyLevel(
      totalInteractions,
    );

    double trust = (feedCount * 2 + playCount * 2 + chatCount * 3) * 0.5;
    if (existing != null) {
      trust += (existing.trustLevel * 0.5);
    }
    int trustLevel = trust.clamp(0, 100).round();

    final updateData = {
      'total_interactions': totalInteractions,
      'feed_count': feedCount,
      'play_count': playCount,
      'chat_count': chatCount,
      'intimacy_level': intimacyLevel,
      'trust_level': trustLevel,
      'last_interaction_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    if (existing == null) {
      updateData['pet_id'] = petId;
      updateData['first_interaction_at'] = now.toIso8601String();
      updateData['created_at'] = now.toIso8601String();
    }

    final data = await supabase
        .from('pet_relationship')
        .upsert(updateData)
        .eq('pet_id', petId)
        .select()
        .single();
    return PetRelationship.fromJson(data);
  }

  Future<Pet> updatePetMood(String petId, String mood, String? moodText) async {
    final data = await supabase
        .from('pets')
        .update({
          'current_mood': mood,
          'mood_text': moodText,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', petId)
        .select()
        .single();
    return Pet.fromJson(data);
  }

  Future<Pet> updatePetSkills(String petId, List<PetSkill> skills) async {
    final data = await supabase
        .from('pets')
        .update({
          'skills': skills.map((s) => s.toJson()).toList(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', petId)
        .select()
        .single();
    return Pet.fromJson(data);
  }

  Future<Pet> updatePetPersonalityId(String petId, String personalityId) async {
    final data = await supabase
        .from('pets')
        .update({
          'personality_id': personalityId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', petId)
        .select()
        .single();
    return Pet.fromJson(data);
  }

  Future<String> exportPet(String petId) async {
    final pet = await supabase.from('pets').select().eq('id', petId).single();

    final personality = await getPersonality(petId);
    final memories = await getMemories(petId);
    final relationship = await getRelationship(petId);

    final exportData = PetExportData(
      version: '1.0',
      exportedAt: DateTime.now(),
      pet: Pet.fromJson(pet),
      personality: personality,
      memories: memories,
      relationship: relationship,
    );

    return jsonEncode(exportData.toJson());
  }

  Future<Pet> importPet(String jsonData) async {
    final Map<String, dynamic> json = jsonDecode(jsonData);
    final exportData = PetExportData.fromJson(json);

    final newPet = exportData.pet.copyWith(
      id: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final createdPet = await supabase
        .from('pets')
        .insert(newPet.toJson())
        .select()
        .single();

    final pet = Pet.fromJson(createdPet);

    if (exportData.personality != null) {
      final newPersonality = exportData.personality!.copyWith(
        id: null,
        petId: pet.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await supabase.from('pet_personalities').insert(newPersonality.toJson());
    }

    for (final memory in exportData.memories) {
      final newMemory = memory.copyWith(
        id: null,
        petId: pet.id,
        createdAt: DateTime.now(),
        occurredAt: DateTime.now(),
      );
      await supabase.from('pet_memories').insert(newMemory.toJson());
    }

    if (exportData.relationship != null) {
      final newRelationship = exportData.relationship!.copyWith(
        petId: pet.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await supabase.from('pet_relationship').insert(newRelationship.toJson());
    }

    return pet;
  }

  Future<void> saveConversation(
    String petId,
    String role,
    String content,
  ) async {
    await supabase.from('pet_conversations').insert({
      'pet_id': petId,
      'role': role,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getConversations(
    String petId, {
    int limit = 50,
  }) async {
    final data = await supabase
        .from('pet_conversations')
        .select()
        .eq('pet_id', petId)
        .order('created_at', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> clearConversations(String petId) async {
    await supabase.from('pet_conversations').delete().eq('pet_id', petId);
  }
}
