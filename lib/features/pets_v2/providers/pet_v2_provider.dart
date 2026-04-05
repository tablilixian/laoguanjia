import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/core/services/pet_v2_service.dart';
import 'package:home_manager/data/models/pet_local_data.dart';
import 'package:home_manager/data/models/pet_meta.dart';
import 'package:home_manager/features/household/providers/household_provider.dart';

/// V2 宠物服务实例
final petV2ServiceProvider = Provider<PetV2Service>((ref) {
  return PetV2Service();
});

/// 家庭下所有宠物元数据列表
final petV2MetasProvider = FutureProvider<List<PetMeta>>((ref) async {
  final household = ref.watch(householdProvider).currentHousehold;
  if (household == null) return [];
  return ref.watch(petV2ServiceProvider).getPetMetas(household.id);
});

/// 当前选中的宠物 ID
final currentPetV2IdProvider = StateProvider<String?>((ref) => null);

/// 当前选中宠物的完整本地数据
final currentPetV2DataProvider = FutureProvider<PetLocalData?>((ref) async {
  final petId = ref.watch(currentPetV2IdProvider);
  if (petId == null) return null;
  return ref.watch(petV2ServiceProvider).getPetData(petId);
});

/// 当前选中宠物的最近对话
final currentPetV2ConversationsProvider =
    FutureProvider<List<PetConversationData>>((ref) async {
  final petId = ref.watch(currentPetV2IdProvider);
  if (petId == null) return [];
  return ref.watch(petV2ServiceProvider).getConversations(petId);
});
