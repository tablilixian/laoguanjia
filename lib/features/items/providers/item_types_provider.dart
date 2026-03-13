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
