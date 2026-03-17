import 'dart:convert';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_personality.dart';
import 'package:home_manager/data/models/pet_memory.dart';
import 'package:home_manager/data/models/pet_relationship.dart';
import 'package:home_manager/data/models/pet_skill.dart';
import 'package:home_manager/data/models/pet_export_data.dart';
import 'package:home_manager/data/supabase/supabase_client.dart';

class PetAIRepository {
  final supabase = SupabaseClientManager.client;

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

  Future<List<PetMemory>> getMemories(String petId, {int? limit}) async {
    try {
      var query = supabase
          .from('pet_memories')
          .select()
          .eq('pet_id', petId)
          .order('occurred_at', ascending: false);
      if (limit != null) {
        query = query.limit(limit);
      }
      final data = await query;
      return (data as List).map((m) => PetMemory.fromJson(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<PetMemory> createMemory(PetMemory memory) async {
    final data = await supabase
        .from('pet_memories')
        .insert(memory.toJson())
        .select()
        .single();
    return PetMemory.fromJson(data);
  }

  Future<List<PetMemory>> getImportantMemories(
    String petId, {
    int limit = 3,
  }) async {
    try {
      final data = await supabase
          .from('pet_memories')
          .select()
          .eq('pet_id', petId)
          .gte('importance', 4)
          .order('occurred_at', ascending: false)
          .limit(limit);
      return (data as List).map((m) => PetMemory.fromJson(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<PetMemory>> getRecentMemories(
    String petId, {
    int days = 7,
    int limit = 3,
  }) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final data = await supabase
          .from('pet_memories')
          .select()
          .eq('pet_id', petId)
          .gte('occurred_at', cutoff.toIso8601String())
          .order('occurred_at', ascending: false)
          .limit(limit);
      return (data as List).map((m) => PetMemory.fromJson(m)).toList();
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
}
