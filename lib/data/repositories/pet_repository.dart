import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/supabase/supabase_client.dart';

class PetRepository {
  final supabase = SupabaseClientManager.client;

  Future<List<Pet>> getPets(String householdId) async {
    try {
      final data = await supabase
          .from('pets')
          .select()
          .eq('household_id', householdId);

      return (data as List)
          .map((json) => Pet.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get pets: $e');
    }
  }

  Future<Pet> createPet(Pet pet) async {
    try {
      final data = await supabase
          .from('pets')
          .insert({
            'household_id': pet.householdId,
            'name': pet.name,
            'type': pet.type,
            'breed': pet.breed,
            'hunger': pet.hunger,
            'happiness': pet.happiness,
            'cleanliness': pet.cleanliness,
            'health': pet.health,
            'level': pet.level,
            'experience': pet.experience,
          })
          .select()
          .single();

      return Pet.fromJson(data);
    } catch (e) {
      throw Exception('Failed to create pet: $e');
    }
  }

  Future<Pet> updatePet(Pet pet) async {
    try {
      final data = await supabase
          .from('pets')
          .update({
            'name': pet.name,
            'type': pet.type,
            'breed': pet.breed,
            'hunger': pet.hunger,
            'happiness': pet.happiness,
            'cleanliness': pet.cleanliness,
            'health': pet.health,
            'level': pet.level,
            'experience': pet.experience,
          })
          .eq('id', pet.id)
          .select()
          .single();

      return Pet.fromJson(data);
    } catch (e) {
      throw Exception('Failed to update pet: $e');
    }
  }

  Future<void> deletePet(String petId) async {
    try {
      await supabase
          .from('pets')
          .delete()
          .eq('id', petId);
    } catch (e) {
      throw Exception('Failed to delete pet: $e');
    }
  }

  Future<Pet> interactWithPet(String petId, String interactionType) async {
    // 定义不同互动类型的影响值
    final interactionEffects = {
      'feed': {'hunger': 20, 'happiness': 5, 'experience': 5},
      'play': {'happiness': 20, 'hunger': -5, 'experience': 10},
      'bath': {'cleanliness': 30, 'happiness': -5, 'experience': 5},
      'train': {'happiness': 10, 'hunger': -10, 'experience': 15},
    };

    final effects = interactionEffects[interactionType]!;

    try {
      // 获取当前宠物状态
      final petData = await supabase
          .from('pets')
          .select()
          .eq('id', petId)
          .single();

      final pet = Pet.fromJson(petData);

      // 计算新状态
      int newHunger = pet.hunger + (effects['hunger'] ?? 0);
      int newHappiness = pet.happiness + (effects['happiness'] ?? 0);
      int newCleanliness = pet.cleanliness + (effects['cleanliness'] ?? 0);
      int newExperience = pet.experience + (effects['experience'] ?? 0);

      // 确保值在合理范围内
      newHunger = newHunger.clamp(0, 100);
      newHappiness = newHappiness.clamp(0, 100);
      newCleanliness = newCleanliness.clamp(0, 100);

      // 计算等级提升
      int newLevel = pet.level;
      while (newExperience >= newLevel * 100) {
        newExperience -= newLevel * 100;
        newLevel++;
      }

      // 更新宠物状态
      final updatedPet = await updatePet(pet.copyWith(
        hunger: newHunger,
        happiness: newHappiness,
        cleanliness: newCleanliness,
        level: newLevel,
        experience: newExperience,
      ));

      // 记录互动
      final nonZeroValues = effects.values.where((v) => v != 0).toList();
      await supabase.from('pet_interactions').insert({
        'pet_id': petId,
        'type': interactionType,
        'value': nonZeroValues.isNotEmpty ? nonZeroValues.first : 0,
      });

      return updatedPet;
    } catch (e) {
      throw Exception('Failed to interact with pet: $e');
    }
  }

  Future<List<PetInteraction>> getPetInteractions(String petId) async {
    try {
      final data = await supabase
          .from('pet_interactions')
          .select()
          .eq('pet_id', petId)
          .order('created_at', ascending: false);

      return (data as List)
          .map((json) => PetInteraction.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get interactions: $e');
    }
  }
}
