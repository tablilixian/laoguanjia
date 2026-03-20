import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item_location.dart';
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

/// 按位置统计 Provider（包含子位置物品，只统计顶层位置）
final itemStatsByLocationProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repository = ItemRepository();
      final householdState = ref.watch(householdProvider);
      final householdId = householdState.currentHousehold?.id;

      if (householdId == null) return [];

      // 获取所有位置和物品数量
      final locations = await repository.getLocations(householdId);
      final itemCounts = await repository.getAllLocationItemCounts(householdId);

      // 只统计顶层位置（depth = 0）
      final rootLocations = locations.where((l) => l.depth == 0).toList();

      // 计算每个顶层位置的包含子位置的总数
      List<ItemLocation> getChildLocations(String parentId) =>
          locations.where((l) => l.parentId == parentId).toList();

      int getTotalCount(String locationId) {
        int total = itemCounts[locationId] ?? 0;
        final children = getChildLocations(locationId);
        for (final child in children) {
          total += getTotalCount(child.id);
        }
        return total;
      }

      final result = <Map<String, dynamic>>[];
      for (final location in rootLocations) {
        final totalCount = getTotalCount(location.id);
        if (totalCount > 0) {
          result.add({
            'location_id': location.id,
            'name': location.name,
            'icon': location.icon,
            'count': totalCount,
          });
        }
      }

      // 按数量降序排序
      result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return result;
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
