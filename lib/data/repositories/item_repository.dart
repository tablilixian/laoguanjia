import '../models/household_item.dart';
import '../models/item_location.dart';
import '../models/item_tag.dart';
import '../models/item_type_config.dart';
import '../supabase/supabase_client.dart';

class ItemRepository {
  final _client = SupabaseClientManager.client;

  // ========== 辅助方法：构建位置层级路径 ==========

  /// 从位置ID构建层级路径名称，如 "主卧-》衣柜-》第三个格子"
  Future<String?> buildLocationPath(String? locationId) async {
    if (locationId == null) return null;

    final pathParts = <String>[];
    String? currentId = locationId;

    // 循环向上查找父级位置
    while (currentId != null) {
      final location = await _client
          .from('item_locations')
          .select('id, name, parent_id')
          .eq('id', currentId)
          .maybeSingle();

      if (location == null) break;

      pathParts.insert(0, location['name'] as String);
      currentId = location['parent_id'] as String?;
    }

    return pathParts.isEmpty ? null : pathParts.join('-》');
  }

  /// 批量构建位置路径（优化性能）
  Future<Map<String, String>> buildLocationPaths(
    List<String> locationIds,
  ) async {
    if (locationIds.isEmpty) return {};

    // 查询所有位置
    final locations = await _client
        .from('item_locations')
        .select('id, name, parent_id')
        .inFilter('id', locationIds);

    final result = <String, String>{};

    for (final loc in locations) {
      final pathParts = <String>[];
      String? currentId = loc['id'] as String;

      while (currentId != null) {
        final location = locations.firstWhere(
          (l) => l['id'] == currentId,
          orElse: () => {'name': '未知', 'parent_id': null},
        );

        pathParts.insert(0, location['name'] as String);
        currentId = location['parent_id'] as String?;
      }

      if (pathParts.isNotEmpty) {
        result[loc['id'] as String] = pathParts.join('-》');
      }
    }

    return result;
  }

  // ========== 物品 CRUD ==========

  Future<List<HouseholdItem>> getItems(String householdId) async {
    final response = await _client
        .from('household_items')
        .select('''
          *,
          item_locations(name, icon, path),
          members!owner_id(name)
        ''')
        .eq('household_id', householdId)
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false);

    // 获取所有位置ID以批量构建路径
    final locationIds = response
        .where((e) => e['location_id'] != null)
        .map((e) => e['location_id'] as String)
        .toSet()
        .toList();

    final locationPaths = await buildLocationPaths(locationIds);

    return (response as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      if (e['item_locations'] != null) {
        map['location_name'] = e['item_locations']['name'];
        map['location_icon'] = e['item_locations']['icon'];
      }
      if (e['members'] != null) {
        map['owner_name'] = e['members']['name'];
      }
      // 添加位置路径
      final locId = e['location_id'] as String?;
      if (locId != null && locationPaths.containsKey(locId)) {
        map['location_path'] = locationPaths[locId];
      }
      // 标签在列表中不需要，这里传空列表以避免null
      map['tags'] = <Map<String, dynamic>>[];
      return HouseholdItem.fromMap(map);
    }).toList();
  }

  Future<HouseholdItem?> getItemById(String itemId) async {
    final response = await _client
        .from('household_items')
        .select('''
          *,
          item_locations(name, icon, path),
          members!owner_id(name)
        ''')
        .eq('id', itemId)
        .maybeSingle();

    if (response == null) return null;

    final map = Map<String, dynamic>.from(response);
    if (response['item_locations'] != null) {
      map['location_name'] = response['item_locations']['name'];
      map['location_icon'] = response['item_locations']['icon'];
    }
    if (response['members'] != null) {
      map['owner_name'] = response['members']['name'];
    }

    // 构建位置层级路径
    final locationId = response['location_id'] as String?;
    if (locationId != null) {
      final locationPath = await buildLocationPath(locationId);
      map['location_path'] = locationPath;
    }

    // 获取标签
    final tags = await getItemTags(itemId);
    map['tags'] = tags.map((t) => t.toMap()).toList();

    return HouseholdItem.fromMap(map);
  }

  Future<HouseholdItem> createItem(HouseholdItem item) async {
    final response = await _client
        .from('household_items')
        .insert({
          'household_id': item.householdId,
          'name': item.name,
          'description': item.description,
          'item_type': item.itemType,
          'location_id': item.locationId,
          'owner_id': item.ownerId,
          'quantity': item.quantity,
          'brand': item.brand,
          'model': item.model,
          'purchase_date': item.purchaseDate?.toIso8601String(),
          'purchase_price': item.purchasePrice,
          'warranty_expiry': item.warrantyExpiry?.toIso8601String(),
          'condition': item.condition.dbValue,
          'image_url': item.imageUrl,
          'thumbnail_url': item.thumbnailUrl,
          'notes': item.notes,
          'created_by': item.createdBy,
        })
        .select()
        .single();

    return HouseholdItem.fromMap(response);
  }

  Future<HouseholdItem> updateItem(HouseholdItem item) async {
    final response = await _client
        .from('household_items')
        .update({
          'name': item.name,
          'description': item.description,
          'item_type': item.itemType,
          'location_id': item.locationId,
          'owner_id': item.ownerId,
          'quantity': item.quantity,
          'brand': item.brand,
          'model': item.model,
          'purchase_date': item.purchaseDate?.toIso8601String(),
          'purchase_price': item.purchasePrice,
          'warranty_expiry': item.warrantyExpiry?.toIso8601String(),
          'condition': item.condition.dbValue,
          'image_url': item.imageUrl,
          'thumbnail_url': item.thumbnailUrl,
          'notes': item.notes,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', item.id)
        .select()
        .single();

    return HouseholdItem.fromMap(response);
  }

  Future<void> deleteItem(String itemId) async {
    await _client
        .from('household_items')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', itemId);
  }

  Future<List<HouseholdItem>> searchItems(
    String householdId,
    String query,
  ) async {
    final response = await _client
        .from('household_items')
        .select('''
          *,
          item_locations(name, icon, path),
          members!owner_id(name)
        ''')
        .eq('household_id', householdId)
        .isFilter('deleted_at', null)
        .ilike('name', '%$query%')
        .order('updated_at', ascending: false);

    // 获取所有位置ID以批量构建路径
    final locationIds = response
        .where((e) => e['location_id'] != null)
        .map((e) => e['location_id'] as String)
        .toSet()
        .toList();

    final locationPaths = await buildLocationPaths(locationIds);

    return (response as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      if (e['item_locations'] != null) {
        map['location_name'] = e['item_locations']['name'];
        map['location_icon'] = e['item_locations']['icon'];
      }
      if (e['members'] != null) {
        map['owner_name'] = e['members']['name'];
      }
      // 添加位置路径
      final locId = e['location_id'] as String?;
      if (locId != null && locationPaths.containsKey(locId)) {
        map['location_path'] = locationPaths[locId];
      }
      // 搜索结果不包含标签详情
      map['tags'] = <Map<String, dynamic>>[];
      return HouseholdItem.fromMap(map);
    }).toList();
  }

  // ========== 位置 CRUD ==========

  Future<List<ItemLocation>> getLocations(String householdId) async {
    final response = await _client
        .from('item_locations')
        .select()
        .eq('household_id', householdId)
        .order('depth')
        .order('sort_order');

    return (response as List).map((e) => ItemLocation.fromMap(e)).toList();
  }

  Future<ItemLocation> createLocation(ItemLocation location) async {
    final response = await _client
        .from('item_locations')
        .insert({
          'household_id': location.householdId,
          'name': location.name,
          'description': location.description,
          'icon': location.icon,
          'color': location.color,
          'parent_id': location.parentId,
          'depth': location.depth,
          'path': location.path,
          'sort_order': location.sortOrder,
        })
        .select()
        .single();

    return ItemLocation.fromMap(response);
  }

  Future<ItemLocation> updateLocation(ItemLocation location) async {
    final response = await _client
        .from('item_locations')
        .update({
          'name': location.name,
          'description': location.description,
          'icon': location.icon,
          'color': location.color,
          'parent_id': location.parentId,
          'sort_order': location.sortOrder,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', location.id)
        .select()
        .single();

    return ItemLocation.fromMap(response);
  }

  Future<void> deleteLocation(String locationId) async {
    await _client.from('item_locations').delete().eq('id', locationId);
  }

  // ========== 标签 CRUD ==========

  Future<List<ItemTag>> getTags(String householdId) async {
    final response = await _client
        .from('item_tags')
        .select()
        .eq('household_id', householdId)
        .order('category')
        .order('name');

    return (response as List).map((e) => ItemTag.fromMap(e)).toList();
  }

  Future<ItemTag> createTag(ItemTag tag) async {
    final response = await _client
        .from('item_tags')
        .insert({
          'household_id': tag.householdId,
          'name': tag.name,
          'color': tag.color,
          'icon': tag.icon,
          'category': tag.category,
          'applicable_types': tag.applicableTypes,
        })
        .select()
        .single();

    return ItemTag.fromMap(response);
  }

  Future<ItemTag> updateTag(ItemTag tag) async {
    final response = await _client
        .from('item_tags')
        .update({
          'name': tag.name,
          'color': tag.color,
          'icon': tag.icon,
          'category': tag.category,
          'applicable_types': tag.applicableTypes,
        })
        .eq('id', tag.id)
        .select()
        .single();

    return ItemTag.fromMap(response);
  }

  Future<void> deleteTag(String tagId) async {
    await _client.from('item_tags').delete().eq('id', tagId);
  }

  // ========== 标签关联 ==========

  Future<void> addTagToItem(String itemId, String tagId) async {
    await _client.from('item_tag_relations').insert({
      'item_id': itemId,
      'tag_id': tagId,
    });
  }

  Future<void> removeTagFromItem(String itemId, String tagId) async {
    await _client
        .from('item_tag_relations')
        .delete()
        .eq('item_id', itemId)
        .eq('tag_id', tagId);
  }

  Future<List<ItemTag>> getItemTags(String itemId) async {
    final response = await _client
        .from('item_tag_relations')
        .select('item_tags(*)')
        .eq('item_id', itemId);

    return (response as List)
        .map((e) => ItemTag.fromMap(e['item_tags'] as Map<String, dynamic>))
        .toList();
  }

  // ========== 类型配置 ==========

  Future<List<ItemTypeConfig>> getItemTypes(String? householdId) async {
    final query = _client
        .from('item_type_configs')
        .select()
        .eq('is_active', true);

    if (householdId != null) {
      query.or('household_id.is.null,household_id.eq.$householdId');
    } else {
      query.isFilter('household_id', null);
    }

    final response = await query.order('sort_order');
    return (response as List).map((e) => ItemTypeConfig.fromMap(e)).toList();
  }

  // 获取所有类型（包括停用的），用于管理页面
  Future<List<ItemTypeConfig>> getAllItemTypes(String? householdId) async {
    final query = _client.from('item_type_configs').select();

    if (householdId != null) {
      query.or('household_id.is.null,household_id.eq.$householdId');
    } else {
      query.isFilter('household_id', null);
    }

    final response = await query.order('sort_order');
    return (response as List).map((e) => ItemTypeConfig.fromMap(e)).toList();
  }

  Future<ItemTypeConfig> createItemType(ItemTypeConfig typeConfig) async {
    final response = await _client
        .from('item_type_configs')
        .insert({
          'household_id': typeConfig.householdId,
          'type_key': typeConfig.typeKey,
          'type_label': typeConfig.typeLabel,
          'icon': typeConfig.icon,
          'color': typeConfig.color,
          'sort_order': typeConfig.sortOrder,
        })
        .select()
        .single();

    return ItemTypeConfig.fromMap(response);
  }

  Future<void> deactivateItemType(String typeId) async {
    await _client
        .from('item_type_configs')
        .update({'is_active': false})
        .eq('id', typeId);
  }

  Future<ItemTypeConfig> updateItemTypeConfig(ItemTypeConfig typeConfig) async {
    final response = await _client
        .from('item_type_configs')
        .update({
          'type_label': typeConfig.typeLabel,
          'icon': typeConfig.icon,
          'color': typeConfig.color,
          'is_active': typeConfig.isActive,
        })
        .eq('id', typeConfig.id)
        .select()
        .single();

    return ItemTypeConfig.fromMap(response);
  }

  Future<void> deleteItemType(String typeId) async {
    await _client.from('item_type_configs').delete().eq('id', typeId);
  }

  Future<ItemLocation?> findLocationByName(
    String householdId,
    String name,
  ) async {
    final response = await _client
        .from('item_locations')
        .select()
        .eq('household_id', householdId)
        .ilike('name', '%$name%')
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return ItemLocation.fromMap(response);
  }

  Future<List<HouseholdItem>> createItemsBatch(
    List<HouseholdItem> items,
  ) async {
    if (items.isEmpty) return [];

    final data = items
        .map(
          (item) => {
            'household_id': item.householdId,
            'name': item.name,
            'description': item.description,
            'item_type': item.itemType,
            'location_id': item.locationId,
            'owner_id': item.ownerId,
            'quantity': item.quantity,
            'brand': item.brand,
            'model': item.model,
            'condition': item.condition.dbValue,
            'sync_status': 'synced',
          },
        )
        .toList();

    final response = await _client
        .from('household_items')
        .insert(data)
        .select();

    return (response as List).map((e) => HouseholdItem.fromMap(e)).toList();
  }

  Future<int> getLocationItemCount(String locationId) async {
    final response = await _client
        .from('household_items')
        .select('id')
        .eq('location_id', locationId)
        .isFilter('deleted_at', null);

    return (response as List).length;
  }

  Future<Map<String, int>> getAllLocationItemCounts(String householdId) async {
    final locations = await _client
        .from('item_locations')
        .select('id')
        .eq('household_id', householdId);

    final counts = <String, int>{};
    for (final loc in locations) {
      final count = await getLocationItemCount(loc['id'] as String);
      counts[loc['id'] as String] = count;
    }
    return counts;
  }

  // ========== 统计方法 ==========

  /// 获取物品总数
  Future<int> getTotalItemCount(String householdId) async {
    final response = await _client
        .from('household_items')
        .select('id')
        .eq('household_id', householdId)
        .isFilter('deleted_at', null);
    return (response as List).length;
  }

  /// 获取本月新增物品数量
  Future<int> getNewItemCountThisMonth(String householdId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final response = await _client
        .from('household_items')
        .select('id')
        .eq('household_id', householdId)
        .gte('created_at', startOfMonth.toIso8601String())
        .isFilter('deleted_at', null);
    return (response as List).length;
  }

  /// 获取需要关注的物品数量（需要维修、已损坏等）
  Future<int> getAttentionNeededCount(String householdId) async {
    final response = await _client
        .from('household_items')
        .select('id')
        .eq('household_id', householdId)
        .inFilter('condition', ['fair', 'poor'])
        .isFilter('deleted_at', null);
    return (response as List).length;
  }

  /// 按类型统计物品数量
  Future<List<Map<String, dynamic>>> getItemCountByType(
    String householdId,
  ) async {
    final response = await _client
        .from('household_items')
        .select('item_type')
        .eq('household_id', householdId)
        .isFilter('deleted_at', null);

    final counts = <String, int>{};
    for (final item in response) {
      final type = item['item_type'] as String? ?? 'other';
      counts[type] = (counts[type] ?? 0) + 1;
    }

    final result = counts.entries
        .map((e) => {'type_key': e.key, 'count': e.value})
        .toList();
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  /// 按位置统计物品数量
  Future<List<Map<String, dynamic>>> getItemCountByLocation(
    String householdId,
  ) async {
    final response = await _client
        .from('household_items')
        .select('location_id')
        .eq('household_id', householdId)
        .isFilter('deleted_at', null);

    final counts = <String, int>{};
    for (final item in response) {
      final locationId = item['location_id'] as String?;
      if (locationId != null) {
        counts[locationId] = (counts[locationId] ?? 0) + 1;
      }
    }

    final locations = await _client
        .from('item_locations')
        .select('id, name, icon')
        .eq('household_id', householdId);

    final result = <Map<String, dynamic>>[];
    for (final entry in counts.entries) {
      final location = locations.firstWhere(
        (l) => l['id'] == entry.key,
        orElse: () => {'name': '未知', 'icon': '📍'},
      );
      result.add({
        'location_id': entry.key,
        'name': location['name'],
        'icon': location['icon'] ?? '📍',
        'count': entry.value,
      });
    }
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  /// 按成员统计物品数量
  Future<List<Map<String, dynamic>>> getItemCountByOwner(
    String householdId,
  ) async {
    final response = await _client
        .from('household_items')
        .select('owner_id')
        .eq('household_id', householdId)
        .isFilter('deleted_at', null);

    final counts = <String, int>{};
    for (final item in response) {
      final ownerId = item['owner_id'] as String?;
      if (ownerId != null) {
        counts[ownerId] = (counts[ownerId] ?? 0) + 1;
      }
    }

    final members = await _client
        .from('members')
        .select('id, name, avatar_url')
        .eq('household_id', householdId);

    final result = <Map<String, dynamic>>[];
    for (final entry in counts.entries) {
      final member = members.firstWhere(
        (m) => m['id'] == entry.key,
        orElse: () => {'name': '未知', 'avatar_url': null},
      );
      result.add({
        'owner_id': entry.key,
        'name': member['name'],
        'avatar_url': member['avatar_url'],
        'count': entry.value,
      });
    }
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  /// 获取物品概览统计
  Future<Map<String, dynamic>> getItemOverview(String householdId) async {
    final total = await getTotalItemCount(householdId);
    final newThisMonth = await getNewItemCountThisMonth(householdId);
    final attentionNeeded = await getAttentionNeededCount(householdId);
    final byType = await getItemCountByType(householdId);

    return {
      'total': total,
      'newThisMonth': newThisMonth,
      'attentionNeeded': attentionNeeded,
      'byType': byType,
    };
  }
}
