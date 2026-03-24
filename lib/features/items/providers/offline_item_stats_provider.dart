import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item_location.dart';
import '../../../data/repositories/offline_item_repository.dart';
import '../../household/providers/household_provider.dart';
import 'offline_items_provider.dart';

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

/// 物品概览统计 Provider（本地优先，缓存优化）
final itemOverviewProvider = FutureProvider.autoDispose<ItemOverview>((
  ref,
) async {
  final itemsState = ref.watch(offlineItemsProvider);
  final repository = ref.watch(offlineItemRepositoryProvider);
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

/// 按类型统计 Provider（本地优先，缓存优化）
final itemStatsByTypeProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repository = ref.watch(offlineItemRepositoryProvider);
      final householdState = ref.watch(householdProvider);
      final householdId = householdState.currentHousehold?.id;

      if (householdId == null) return [];
      return repository.getItemCountByType(householdId);
    });

/// 按位置统计 Provider（本地优先，缓存优化，性能优化）
final itemStatsByLocationProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repository = ref.watch(offlineItemRepositoryProvider);
      final householdState = ref.watch(householdProvider);
      final householdId = householdState.currentHousehold?.id;

      if (householdId == null) return [];

      final locations = await repository.getLocations(householdId);
      final itemCounts = await repository.getAllLocationItemCounts(householdId);

      final rootLocations = locations.where((l) => l.depth == 0).toList();

      final result = <Map<String, dynamic>>[];

      for (final location in rootLocations) {
        final totalCount = _calculateTotalCountOptimized(
          location.id,
          locations,
          itemCounts,
        );
        if (totalCount > 0) {
          result.add({
            'location_id': location.id,
            'name': location.name,
            'icon': location.icon,
            'count': totalCount,
          });
        }
      }

      result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return result;
    });

/// 按成员统计 Provider（本地优先，缓存优化）
final itemStatsByOwnerProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repository = ref.watch(offlineItemRepositoryProvider);
      final householdState = ref.watch(householdProvider);
      final householdId = householdState.currentHousehold?.id;

      if (householdId == null) return [];
      return repository.getItemCountByOwner(householdId);
    });

/// 计算位置的总物品数（优化版：使用动态规划，避免重复计算）
int _calculateTotalCountOptimized(
  String locationId,
  List<ItemLocation> allLocations,
  Map<String, int> itemCounts,
) {
  final cache = <String, int>{};

  int calculate(String id) {
    if (cache.containsKey(id)) {
      return cache[id]!;
    }

    int total = itemCounts[id] ?? 0;

    final children = allLocations.where((l) => l.parentId == id).toList();
    for (final child in children) {
      total += calculate(child.id);
    }

    cache[id] = total;
    return total;
  }

  return calculate(locationId);
}

/// OfflineItemRepository 单例 Provider
final offlineItemRepositoryProvider = Provider<OfflineItemRepository>((ref) {
  return OfflineItemRepository();
});
