import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/repositories/pet_repository.dart';
import 'package:home_manager/features/household/providers/household_provider.dart';

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

  Future<void> createPet(Pet pet) async {
    final createdPet = await ref.read(petRepositoryProvider).createPet(pet);
    state = createdPet;
    // 强制刷新宠物列表
    ref.invalidate(petsProvider);
  }

  Future<void> updatePet(Pet pet) async {
    final updatedPet = await ref.read(petRepositoryProvider).updatePet(pet);
    state = updatedPet;
    // 强制刷新宠物列表
    ref.invalidate(petsProvider);
  }

  Future<void> deletePet(String petId) async {
    await ref.read(petRepositoryProvider).deletePet(petId);
    state = null;
    // 强制刷新宠物列表
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
    // 强制刷新宠物列表
    ref.invalidate(petsProvider);
    return updatedPet;
  }
}

final petNotifierProvider = NotifierProvider<PetNotifier, Pet?>(PetNotifier.new);
