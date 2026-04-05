import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/household_items.dart';

part 'items_dao.g.dart';

/// 物品概览统计结果
class ItemOverviewStats {
  final int total;
  final int newThisMonth;
  final int attentionNeeded;

  const ItemOverviewStats({
    required this.total,
    required this.newThisMonth,
    required this.attentionNeeded,
  });
}

/// 按类型统计结果
class TypeCount {
  final String typeKey;
  final int count;

  const TypeCount({required this.typeKey, required this.count});
}

/// 按归属人统计结果
class OwnerCount {
  final String? ownerId;
  final int count;

  const OwnerCount({this.ownerId, required this.count});
}

/// 按位置统计结果
class LocationCount {
  final String? locationId;
  final int count;

  const LocationCount({this.locationId, required this.count});
}

@DriftAccessor(tables: [HouseholdItems])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  Future<List<HouseholdItem>> getAll() => select(householdItems).get();

  Future<HouseholdItem?> getById(String id) =>
      (select(householdItems)..where((i) => i.id.equals(id))).getSingleOrNull();

  Stream<List<HouseholdItem>> watchAll() => select(householdItems).watch();

  Stream<HouseholdItem?> watchById(String id) => (select(
    householdItems,
  )..where((i) => i.id.equals(id))).watchSingleOrNull();

  Future<int> getAllCount() =>
      select(householdItems).get().then((list) => list.length);

  Future<int> deleteAll() => delete(householdItems).go();

  Future<int> insertItem(HouseholdItemsCompanion item) =>
      into(householdItems).insert(item);

  Future<int> updateItem(HouseholdItemsCompanion item) => (update(
    householdItems,
  )..where((i) => i.id.equals(item.id.value))).write(item);

  Future<int> deleteItem(String id) =>
      (delete(householdItems)..where((i) => i.id.equals(id))).go();

  Future<List<HouseholdItem>> getSyncPending() =>
      (select(householdItems)..where(
            (i) => i.syncPending.equals(true) | i.syncStatus.equals('pending'),
          ))
          .get();

  Future<int> markSynced(String id) async {
    final result = await (update(householdItems)..where((i) => i.id.equals(id)))
        .write(
          HouseholdItemsCompanion(
            syncPending: const Value(false),
            syncStatus: const Value('synced'),
            updatedAt: Value(DateTime.now()),
          ),
        );
    print('🔄 [本地DB] markSynced: $id, 影响行数=$result');
    return result;
  }

  Future<void> upsertItemFromRemote(Map<String, dynamic> remoteItem) async {
    final existing = await getById(remoteItem['id']);

    // 解析 tags_mask：远程可能是 int 或字符串
    int tagsMaskValue = 0;
    if (remoteItem['tags_mask'] != null) {
      if (remoteItem['tags_mask'] is int) {
        tagsMaskValue = remoteItem['tags_mask'] as int;
      } else if (remoteItem['tags_mask'] is String) {
        tagsMaskValue = int.tryParse(remoteItem['tags_mask'] as String) ?? 0;
      }
    }

    final companion = HouseholdItemsCompanion(
      id: Value(remoteItem['id']),
      householdId: Value(remoteItem['household_id']),
      name: Value(remoteItem['name']),
      description: Value(remoteItem['description']),
      itemType: Value(remoteItem['item_type']),
      locationId: Value(remoteItem['location_id']),
      ownerId: Value(remoteItem['owner_id']),
      quantity: Value(remoteItem['quantity'] ?? 1),
      brand: Value(remoteItem['brand']),
      model: Value(remoteItem['model']),
      purchaseDate: remoteItem['purchase_date'] != null
          ? Value(DateTime.parse(remoteItem['purchase_date']))
          : const Value.absent(),
      purchasePrice: remoteItem['purchase_price'] != null
          ? Value((remoteItem['purchase_price'] as num).toDouble())
          : const Value.absent(),
      warrantyExpiry: remoteItem['warranty_expiry'] != null
          ? Value(DateTime.parse(remoteItem['warranty_expiry']))
          : const Value.absent(),
      condition: Value(remoteItem['condition'] ?? 'good'),
      imageUrl: Value(remoteItem['image_url']),
      thumbnailUrl: Value(remoteItem['thumbnail_url']),
      notes: Value(remoteItem['notes']),
      syncStatus: const Value('synced'),
      remoteId: const Value.absent(),
      createdBy: Value(remoteItem['created_by']),
      createdAt: Value(DateTime.parse(remoteItem['created_at'])),
      updatedAt: Value(DateTime.parse(remoteItem['updated_at'])),
      deletedAt: remoteItem['deleted_at'] != null
          ? Value(DateTime.parse(remoteItem['deleted_at']))
          : (existing?.deletedAt != null
                ? Value(existing!.deletedAt!)
                : const Value.absent()),
      version: Value(remoteItem['version'] ?? 1),
      syncPending: const Value(false),
      tagsMask: Value(tagsMaskValue),
      slotPosition: Value(remoteItem['slot_position']?.toString()),
    );

    if (existing == null) {
      await into(householdItems).insert(companion);
    } else {
      await (update(
        householdItems,
      )..where((i) => i.id.equals(remoteItem['id']))).write(companion);
    }
  }

  Future<List<HouseholdItem>> getByHousehold(String householdId) => (select(
    householdItems,
  )..where((i) => i.householdId.equals(householdId))).get();

  /// 分页获取家庭物品（支持筛选和排序）
  Future<List<HouseholdItem>> getByHouseholdPaginated(
    String householdId, {
    required int limit,
    required int offset,
    String? searchQuery,
    String? itemType,
    String? locationId,
    List<String>? locationIds, // 包含子位置的ID列表
    String? ownerId,
    int? tagIndex, // 标签索引（用于位图过滤）
    String sortBy = 'updatedAt',
    bool ascending = false,
  }) {
    final query = select(householdItems)
      ..where((i) => i.householdId.equals(householdId) & i.deletedAt.isNull());

    // 添加筛选条件
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowerQuery = '%${searchQuery.toLowerCase()}%';
      query.where(
        (i) =>
            i.name.lower().like(lowerQuery) |
            i.brand.lower().like(lowerQuery) |
            i.model.lower().like(lowerQuery),
      );
    }
    if (itemType != null && itemType.isNotEmpty) {
      query.where((i) => i.itemType.equals(itemType));
    }
    if (locationIds != null && locationIds.isNotEmpty) {
      // 使用 IN 查询，包含父位置及其所有子位置
      query.where((i) => i.locationId.isIn(locationIds));
    } else if (locationId != null && locationId.isNotEmpty) {
      // 兼容旧的单ID查询
      query.where((i) => i.locationId.equals(locationId));
    }
    if (ownerId != null && ownerId.isNotEmpty) {
      query.where((i) => i.ownerId.equals(ownerId));
    }
    if (tagIndex != null) {
      final tagMask = (BigInt.from(1) << tagIndex).toInt();
      query.where(
        (i) => CustomExpression<bool>(
          '(${i.tagsMask.name} & $tagMask) = $tagMask',
        ).equals(true),
      );
    }

    // 排序
    switch (sortBy) {
      case 'name':
        query.orderBy([
          (i) => OrderingTerm(
            expression: i.name,
            mode: ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
        break;
      case 'createdAt':
        query.orderBy([
          (i) => OrderingTerm(
            expression: i.createdAt,
            mode: ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
        break;
      case 'itemType':
        query.orderBy([
          (i) => OrderingTerm(
            expression: i.itemType,
            mode: ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
        break;
      case 'updatedAt':
      default:
        query.orderBy([
          (i) => OrderingTerm(
            expression: i.updatedAt,
            mode: ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
    }

    // 分页
    query.limit(limit, offset: offset);

    return query.get();
  }

  /// 获取筛选后的物品总数（按物品数量计算，不是记录条数）
  Future<int> getCountByHousehold(
    String householdId, {
    String? searchQuery,
    String? itemType,
    String? locationId,
    List<String>? locationIds, // 包含子位置的ID列表
    String? ownerId,
    int? tagIndex, // 标签索引（用于位图过滤）
  }) async {
    final query = select(householdItems)
      ..where((i) => i.householdId.equals(householdId) & i.deletedAt.isNull());

    // 添加筛选条件
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowerQuery = '%${searchQuery.toLowerCase()}%';
      query.where(
        (i) =>
            i.name.lower().like(lowerQuery) |
            i.brand.lower().like(lowerQuery) |
            i.model.lower().like(lowerQuery),
      );
    }
    if (itemType != null && itemType.isNotEmpty) {
      query.where((i) => i.itemType.equals(itemType));
    }
    if (locationIds != null && locationIds.isNotEmpty) {
      // 使用 IN 查询，包含父位置及其所有子位置
      query.where((i) => i.locationId.isIn(locationIds));
    } else if (locationId != null && locationId.isNotEmpty) {
      // 兼容旧的单ID查询
      query.where((i) => i.locationId.equals(locationId));
    }
    if (ownerId != null && ownerId.isNotEmpty) {
      query.where((i) => i.ownerId.equals(ownerId));
    }
    if (tagIndex != null) {
      final tagMask = (BigInt.from(1) << tagIndex).toInt();
      query.where(
        (i) => CustomExpression<bool>(
          '(${i.tagsMask.name} & $tagMask) = $tagMask',
        ).equals(true),
      );
    }

    final items = await query.get();
    return items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 0));
  }

  Stream<List<HouseholdItem>> watchByHousehold(String householdId) => (select(
    householdItems,
  )..where((i) => i.householdId.equals(householdId))).watch();

  Future<List<HouseholdItem>> getByLocation(String locationId) => (select(
    householdItems,
  )..where((i) => i.locationId.equals(locationId))).get();

  Future<List<HouseholdItem>> getByType(String itemType) =>
      (select(householdItems)..where((i) => i.itemType.equals(itemType))).get();

  Future<List<HouseholdItem>> getByOwner(String ownerId) =>
      (select(householdItems)..where((i) => i.ownerId.equals(ownerId))).get();

  Future<int> deleteByHousehold(String householdId) => (delete(
    householdItems,
  )..where((i) => i.householdId.equals(householdId))).go();

  /// 智能搜索（大小写不敏感，多字段）
  Future<List<HouseholdItem>> searchSmart(
    String householdId,
    String query, {
    int limit = 50,
  }) {
    final lowerQuery = '%${query.toLowerCase()}%';

    return (select(householdItems)
          ..where(
            (i) =>
                i.householdId.equals(householdId) &
                i.deletedAt.isNull() &
                (i.name.lower().like(lowerQuery) |
                    i.brand.lower().like(lowerQuery) |
                    i.model.lower().like(lowerQuery) |
                    i.notes.lower().like(lowerQuery)),
          )
          ..orderBy([
            (i) =>
                OrderingTerm(expression: i.updatedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }

  /// 获取搜索结果总数（按数量求和）
  Future<int> getSearchCount(String householdId, String query) {
    final lowerQuery = '%${query.toLowerCase()}%';

    final q = selectOnly(householdItems)
      ..addColumns([householdItems.quantity.sum()])
      ..where(householdItems.householdId.equals(householdId))
      ..where(householdItems.deletedAt.isNull())
      ..where(
        householdItems.name.lower().like(lowerQuery) |
            householdItems.brand.lower().like(lowerQuery) |
            householdItems.model.lower().like(lowerQuery) |
            householdItems.notes.lower().like(lowerQuery),
      );

    return q.map((row) => row.read(householdItems.quantity.sum())!).getSingle();
  }

  Future<void> softDelete(String id, DateTime deletedAt) =>
      (update(householdItems)..where((i) => i.id.equals(id))).write(
        HouseholdItemsCompanion(
          deletedAt: Value(deletedAt),
          syncPending: const Value(true),
          updatedAt: Value(DateTime.now()),
          version: const Value.absent(),
        ),
      );

  Future<void> softDeleteWithVersion(
    String id,
    DateTime deletedAt,
    int newVersion,
  ) => (update(householdItems)..where((i) => i.id.equals(id))).write(
    HouseholdItemsCompanion(
      deletedAt: Value(deletedAt),
      syncPending: const Value(true),
      updatedAt: Value(DateTime.now()),
      version: Value(newVersion),
    ),
  );

  Future<void> updateSyncStatus(String id, bool pending) =>
      (update(householdItems)..where((i) => i.id.equals(id))).write(
        HouseholdItemsCompanion(
          syncPending: Value(pending),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> insertOrUpdateItem(HouseholdItemsCompanion item) async {
    final existing = await getById(item.id.value);
    if (existing == null) {
      await into(householdItems).insert(item);
    } else {
      await (update(
        householdItems,
      )..where((i) => i.id.equals(item.id.value))).write(item);
    }
  }

  // ========== SQL 聚合统计方法 ==========

  /// 获取物品总览统计（使用 SQL 聚合，高效）
  Future<ItemOverviewStats> getOverviewStats(String householdId) async {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final thirtyDaysLater = now.add(const Duration(days: 30));

    // 总数（未删除，按数量求和）
    final totalQuery = selectOnly(householdItems)
      ..addColumns([householdItems.quantity.sum()])
      ..where(householdItems.householdId.equals(householdId))
      ..where(householdItems.deletedAt.isNull());
    final total = await totalQuery
        .map((row) => row.read(householdItems.quantity.sum()) ?? 0)
        .getSingle();

    // 本月新增（按数量求和）
    final newThisMonthQuery = selectOnly(householdItems)
      ..addColumns([householdItems.quantity.sum()])
      ..where(householdItems.householdId.equals(householdId))
      ..where(householdItems.deletedAt.isNull())
      ..where(householdItems.createdAt.isBiggerThanValue(thisMonth));
    final newThisMonth = await newThisMonthQuery
        .map((row) => row.read(householdItems.quantity.sum()) ?? 0)
        .getSingle();

    // 需关注（保修 30 天内到期，按数量求和）
    final attentionQuery = selectOnly(householdItems)
      ..addColumns([householdItems.quantity.sum()])
      ..where(householdItems.householdId.equals(householdId))
      ..where(householdItems.deletedAt.isNull())
      ..where(householdItems.warrantyExpiry.isNotNull())
      ..where(
        householdItems.warrantyExpiry.isSmallerOrEqualValue(thirtyDaysLater),
      );
    final attentionNeeded = await attentionQuery
        .map((row) => row.read(householdItems.quantity.sum()) ?? 0)
        .getSingle();

    return ItemOverviewStats(
      total: total,
      newThisMonth: newThisMonth,
      attentionNeeded: attentionNeeded,
    );
  }

  /// 按类型统计（SQL GROUP BY，高效）
  Future<List<TypeCount>> getCountByType(String householdId) async {
    final query = selectOnly(householdItems)
      ..addColumns([householdItems.itemType, householdItems.quantity.sum()])
      ..where(householdItems.householdId.equals(householdId))
      ..where(householdItems.deletedAt.isNull())
      ..groupBy([householdItems.itemType])
      ..orderBy([OrderingTerm.desc(householdItems.quantity.sum())]);

    return query
        .map(
          (row) => TypeCount(
            typeKey: row.read(householdItems.itemType) ?? '未分类',
            count: row.read(householdItems.quantity.sum())!,
          ),
        )
        .get();
  }

  /// 按归属人统计（SQL GROUP BY，高效）
  Future<List<OwnerCount>> getCountByOwner(String householdId) async {
    final query = selectOnly(householdItems)
      ..addColumns([householdItems.ownerId, householdItems.quantity.sum()])
      ..where(householdItems.householdId.equals(householdId))
      ..where(householdItems.deletedAt.isNull())
      ..groupBy([householdItems.ownerId])
      ..orderBy([OrderingTerm.desc(householdItems.quantity.sum())]);

    return query
        .map(
          (row) => OwnerCount(
            ownerId: row.read(householdItems.ownerId),
            count: row.read(householdItems.quantity.sum())!,
          ),
        )
        .get();
  }

  /// 按位置统计（SQL GROUP BY，高效）
  Future<List<LocationCount>> getCountByLocation(String householdId) async {
    final query = selectOnly(householdItems)
      ..addColumns([householdItems.locationId, householdItems.quantity.sum()])
      ..where(householdItems.householdId.equals(householdId))
      ..where(householdItems.deletedAt.isNull())
      ..groupBy([householdItems.locationId])
      ..orderBy([OrderingTerm.desc(householdItems.quantity.sum())]);

    return query
        .map(
          (row) => LocationCount(
            locationId: row.read(householdItems.locationId),
            count: row.read(householdItems.quantity.sum())!,
          ),
        )
        .get();
  }

  /// 获取活跃物品总数（按数量求和，高效）
  Future<int> getActiveCount(String householdId) async {
    final query = selectOnly(householdItems)
      ..addColumns([householdItems.quantity.sum()])
      ..where(householdItems.householdId.equals(householdId))
      ..where(householdItems.deletedAt.isNull());
    return query
        .map((row) => row.read(householdItems.quantity.sum())!)
        .getSingle();
  }

  /// 根据标签ID获取物品（位图查询）
  Future<List<HouseholdItem>> getByTag(String householdId, int tagId) async {
    final tagMask = 1 << tagId;
    final items = await getByHousehold(householdId);
    return items.where((item) => (item.tagsMask & tagMask) != 0).toList();
  }

  /// 根据多个标签ID获取物品（OR查询）
  Future<List<HouseholdItem>> getByAnyTag(
    String householdId,
    List<int> tagIds,
  ) async {
    if (tagIds.isEmpty) {
      return getByHousehold(householdId);
    }

    int combinedMask = 0;
    for (final tagId in tagIds) {
      combinedMask |= (1 << tagId);
    }

    final items = await getByHousehold(householdId);
    return items.where((item) => (item.tagsMask & combinedMask) != 0).toList();
  }

  /// 根据多个标签ID获取物品（AND查询）
  Future<List<HouseholdItem>> getByAllTags(
    String householdId,
    List<int> tagIds,
  ) async {
    if (tagIds.isEmpty) {
      return getByHousehold(householdId);
    }

    int combinedMask = 0;
    for (final tagId in tagIds) {
      combinedMask |= (1 << tagId);
    }

    final items = await getByHousehold(householdId);
    return items
        .where((item) => (item.tagsMask & combinedMask) == combinedMask)
        .toList();
  }
}
