import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/household_item.dart';
import 'offline_item_stats_provider.dart';

/// 物品详情 Provider（本地优先）
final offlineItemDetailProvider =
    FutureProvider.family<HouseholdItem?, String>((ref, itemId) async {
      final repository = ref.watch(offlineItemRepositoryProvider);
      try {
        final item = await repository.getItem(itemId);
        return item;
      } catch (e) {
        print('🔴 [OfflineItemDetailProvider] 获取物品详情失败: $e');
        return null;
      }
    });
