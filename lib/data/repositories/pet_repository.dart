import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_memory.dart';
import 'package:home_manager/data/supabase/supabase_client.dart';
import 'package:home_manager/core/services/local_storage_service.dart';
import 'package:home_manager/core/services/pet_local_storage.dart';
import 'package:home_manager/data/repositories/pet_ai_repository.dart';

class PetRepository {
  final supabase = SupabaseClientManager.client;
  final PetInteractionLocalStorage _localStorage = PetInteractionLocalStorage();
  final PetAIRepository _aiRepository = PetAIRepository();

  PetRepository() {
    _initLocalStorage();
  }

  Future<void> _initLocalStorage() async {
    await LocalStorageService.instance.init();
  }

  Future<List<Pet>> getPets(String householdId) async {
    try {
      final data = await supabase
          .from('pets')
          .select()
          .eq('household_id', householdId);

      return (data as List).map((json) => Pet.fromJson(json)).toList();
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
      await supabase.from('pets').delete().eq('id', petId);
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
      final updatedPet = await updatePet(
        pet.copyWith(
          hunger: newHunger,
          happiness: newHappiness,
          cleanliness: newCleanliness,
          level: newLevel,
          experience: newExperience,
        ),
      );

      // 记录互动（仅保存到本地）
      final nonZeroValues = effects.values.where((v) => v != 0).toList();

      // 保存到本地（用于日志记录）
      try {
        final interaction = PetInteraction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          petId: petId,
          type: interactionType,
          value: nonZeroValues.isNotEmpty ? nonZeroValues.first : 0,
          createdAt: DateTime.now(),
        );
        await _localStorage.saveInteraction(interaction);
      } catch (e) {
        // 本地保存失败不影响主流程
      }

      // 创建互动记忆
      await _createInteractionMemory(petId, interactionType);

      return updatedPet;
    } catch (e) {
      throw Exception('Failed to interact with pet: $e');
    }
  }

  Future<List<PetInteraction>> getPetInteractions(String petId) async {
    try {
      return await _localStorage.loadInteractions(petId: petId);
    } catch (e) {
      throw Exception('Failed to get interactions: $e');
    }
  }

  Future<void> _createInteractionMemory(
    String petId,
    String interactionType,
  ) async {
    final memoryData = <String, Map<String, dynamic>>{
      'feed': {
        'title': '享用美食',
        'description': '吃了美味的食物，肚子饱饱的，好开心！',
        'emotion': 'joy',
        'importance': 2,
      },
      'play': {
        'title': '一起玩耍',
        'description': '和主人一起玩游戏，度过了快乐的时光！',
        'emotion': 'joy',
        'importance': 2,
      },
      'bath': {
        'title': '洗澡澡',
        'description': '洗了澡，全身清爽干净！',
        'emotion': 'neutral',
        'importance': 1,
      },
      'train': {
        'title': '训练完成',
        'description': '完成了训练，学会了一些新技能！',
        'emotion': 'joy',
        'importance': 3,
      },
    };

    final data = memoryData[interactionType];
    if (data == null) return;

    try {
      // 使用 PetAIRepository 创建记忆（自动处理本地和云端存储）
      await _aiRepository.createMemory(
        PetMemory(
          id: '',
          petId: petId,
          memoryType: 'interaction',
          title: data['title'] as String,
          description: data['description'] as String,
          emotion: data['emotion'] as String?,
          participants: ['主人', '我'],
          importance: data['importance'] as int,
          isSummarized: false,
          occurredAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      // 记忆创建失败不影响主流程
    }
  }
}
