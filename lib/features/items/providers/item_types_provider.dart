import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item_type_config.dart';
import '../../../data/repositories/item_repository.dart';
import '../../household/providers/household_provider.dart';

final itemTypesProvider = FutureProvider.autoDispose<List<ItemTypeConfig>>((
  ref,
) async {
  final repository = ItemRepository();
  final householdState = ref.watch(householdProvider);
  final householdId = householdState.currentHousehold?.id;
  return repository.getItemTypes(householdId);
});

// 获取所有类型（包括停用的），用于管理页面
final allItemTypesProvider = FutureProvider.autoDispose<List<ItemTypeConfig>>((
  ref,
) async {
  final repository = ItemRepository();
  final householdState = ref.watch(householdProvider);
  final householdId = householdState.currentHousehold?.id;
  return repository.getAllItemTypes(householdId);
});

final itemTypeByKeyProvider = Provider.family<ItemTypeConfig?, String>((
  ref,
  typeKey,
) {
  final typesAsync = ref.watch(itemTypesProvider);
  return typesAsync.whenOrNull(
    data: (types) {
      try {
        return types.firstWhere((t) => t.typeKey == typeKey);
      } catch (_) {
        return null;
      }
    },
  );
});
