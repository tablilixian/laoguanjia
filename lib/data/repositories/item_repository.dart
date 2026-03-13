import '../models/household_item.dart';
import '../models/item_location.dart';
import '../models/item_tag.dart';
import '../models/item_type_config.dart';
import '../supabase/supabase_client.dart';

class ItemRepository {
  final _client = SupabaseClientManager.client;

  // ========== 物品 CRUD ==========

  Future<List<HouseholdItem>> getItems(String householdId) async {
    final response = await _client
        .from('household_items')
        .select('''
          *,
          item_locations(name, icon),
          members!owner_id(name)
        ''')
        .eq('household_id', householdId)
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false);

    return (response as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      if (e['item_locations'] != null) {
        map['location_name'] = e['item_locations']['name'];
        map['location_icon'] = e['item_locations']['icon'];
      }
      if (e['members'] != null) {
        map['owner_name'] = e['members']['name'];
      }
      return HouseholdItem.fromMap(map);
    }).toList();
  }

  Future<HouseholdItem?> getItemById(String itemId) async {
    final response = await _client
        .from('household_items')
        .select('''
          *,
          item_locations(name, icon),
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
          item_locations(name, icon),
          members!owner_id(name)
        ''')
        .eq('household_id', householdId)
        .isFilter('deleted_at', null)
        .ilike('name', '%$query%')
        .order('updated_at', ascending: false);

    return (response as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      if (e['item_locations'] != null) {
        map['location_name'] = e['item_locations']['name'];
        map['location_icon'] = e['item_locations']['icon'];
      }
      if (e['members'] != null) {
        map['owner_name'] = e['members']['name'];
      }
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
}
