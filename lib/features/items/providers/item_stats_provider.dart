import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/item_repository.dart';
import '../../household/providers/household_provider.dart';

/// 物品概览统计
class ItemOverview {
  final int total;
  final int newThisMonth;
  final int attentionNeeded;
  final List<Map<String, dynamic>> byType;

  ItemOverview({
    required this.total,
    required this.newThisMonth,
    required this.attentionNeeded,
    required this.byType,
  });
}

/// 物品概览统计 Provider
final itemOverviewProvider = FutureProvider.autoDispose<ItemOverview>((
  ref,
) async {
  final repository = ItemRepository();
  final householdState = ref.watch(householdProvider);
  final householdId = householdState.currentHousehold?.id;

  if (householdId == null) {
    return ItemOverview(
      total: 0,
      newThisMonth: 0,
      attentionNeeded: 0,
      byType: [],
    );
  }

  final result = await repository.getItemOverview(householdId);
  return ItemOverview(
    total: result['total'] as int,
    newThisMonth: result['newThisMonth'] as int,
    attentionNeeded: result['attentionNeeded'] as int,
    byType: result['byType'] as List<Map<String, dynamic>>,
  );
});

/// 按类型统计 Provider
final itemStatsByTypeProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repository = ItemRepository();
      final householdState = ref.watch(householdProvider);
      final householdId = householdState.currentHousehold?.id;

      if (householdId == null) return [];
      return repository.getItemCountByType(householdId);
    });

/// 按位置统计 Provider
final itemStatsByLocationProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repository = ItemRepository();
      final householdState = ref.watch(householdProvider);
      final householdId = householdState.currentHousehold?.id;

      if (householdId == null) return [];
      return repository.getItemCountByLocation(householdId);
    });

/// 按成员统计 Provider
final itemStatsByOwnerProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repository = ItemRepository();
      final householdState = ref.watch(householdProvider);
      final householdId = householdState.currentHousehold?.id;

      if (householdId == null) return [];
      return repository.getItemCountByOwner(householdId);
    });
