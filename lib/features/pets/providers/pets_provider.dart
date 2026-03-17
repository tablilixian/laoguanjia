import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_skill.dart';
import 'package:home_manager/data/repositories/pet_repository.dart';
import 'package:home_manager/data/repositories/pet_ai_repository.dart';
import 'package:home_manager/data/supabase/supabase_client.dart';
import 'package:home_manager/features/household/providers/household_provider.dart';
import 'package:home_manager/core/services/skill_generator.dart';

final petRepositoryProvider = Provider((ref) => PetRepository());

final petsProvider = FutureProvider<List<Pet>>((ref) async {
  final household = ref.watch(householdProvider).currentHousehold;
  if (household == null) {
    return [];
  }
  return ref.watch(petRepositoryProvider).getPets(household.id);
});

final currentPetProvider = StateProvider<Pet?>((ref) => null);

class PetNotifier extends Notifier<Pet?> {
  @override
  Pet? build() {
    return null;
  }

  Future<void> createPet(Pet pet, {PetSkill? userSelectedSkill}) async {
    final supabase = SupabaseClientManager.client;
    final userId = supabase.auth.currentUser?.id;

    final petWithOwner = pet.copyWith(ownerId: userId);
    final createdPet = await ref
        .read(petRepositoryProvider)
        .createPet(petWithOwner);

    if (userId != null) {
      final aiRepository = PetAIRepository();
      final personality = await aiRepository.getPersonality(createdPet.id);

      if (personality == null) {
        final skills = SkillGenerator.generateSkills(
          userSelectedSkill: userSelectedSkill,
          intimacyLevel: 0,
        );
        await aiRepository.updatePetSkills(createdPet.id, skills);
        await aiRepository.updatePetMood(
          createdPet.id,
          'neutral',
          '刚来到新家，有点紧张',
        );
        await aiRepository.createRelationship(createdPet.id);
      }
    }

    state = createdPet;
    ref.invalidate(petsProvider);
  }

  Future<void> updatePet(Pet pet) async {
    final updatedPet = await ref.read(petRepositoryProvider).updatePet(pet);
    state = updatedPet;
    ref.invalidate(petsProvider);
  }

  Future<void> deletePet(String petId) async {
    await ref.read(petRepositoryProvider).deletePet(petId);
    state = null;
    ref.invalidate(petsProvider);
  }

  Future<Pet> interactWithPet(String interactionType) async {
    if (state == null) {
      throw Exception('No pet selected');
    }
    final updatedPet = await ref
        .read(petRepositoryProvider)
        .interactWithPet(state!.id, interactionType);
    state = updatedPet;
    ref.invalidate(petsProvider);
    return updatedPet;
  }
}

final petNotifierProvider = NotifierProvider<PetNotifier, Pet?>(
  PetNotifier.new,
);
