import 'app_database.dart';

extension HouseholdItemExtensions on HouseholdItem {
  Map<String, dynamic> toRemoteJson() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'description': description,
      'item_type': itemType,
      'location_id': locationId,
      'owner_id': ownerId,
      'quantity': quantity,
      'brand': brand,
      'model': model,
      'purchase_date': purchaseDate?.toIso8601String(),
      'purchase_price': purchasePrice,
      'warranty_expiry': warrantyExpiry?.toIso8601String(),
      'condition': condition,
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'notes': notes,
      'sync_status': syncStatus,
      'remote_id': remoteId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'version': version,
      'slot_position': slotPosition,
    };
  }
}

extension ItemLocationExtensions on ItemLocation {
  Map<String, dynamic> toRemoteJson() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'parent_id': parentId,
      'depth': depth,
      'path': path,
      'sort_order': sortOrder,
      'template_type': templateType,
      'template_config': templateConfig != null ? templateConfig.toString() : null,
      'position_in_parent': positionInParent?.toString(),
      'position_description': positionDescription,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'version': version,
    };
  }
}

extension ItemTagExtensions on ItemTag {
  Map<String, dynamic> toRemoteJson() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'color': color,
      'icon': icon,
      'category': category,
      'applicable_types': applicableTypes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'version': version,
    };
  }
}

extension ItemTypeConfigExtensions on ItemTypeConfig {
  Map<String, dynamic> toRemoteJson() {
    return {
      'id': id,
      'household_id': householdId,
      'type_key': typeKey,
      'type_label': typeLabel,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'version': version,
    };
  }
}
