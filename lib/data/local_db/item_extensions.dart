import 'dart:convert';
import 'app_database.dart' as db;
import '../models/household_item.dart';
import '../models/item_location.dart';
import '../models/item_tag.dart';
import '../models/item_type_config.dart';

extension HouseholdItemExtensions on db.HouseholdItem {
  HouseholdItem toHouseholdItemModel() {
    Map<String, dynamic>? slotPositionMap;
    if (slotPosition != null && slotPosition!.isNotEmpty) {
      try {
        slotPositionMap = jsonDecode(slotPosition!) as Map<String, dynamic>;
      } catch (e) {
        slotPositionMap = null;
      }
    }
    
    return HouseholdItem(
      id: id,
      householdId: householdId,
      name: name,
      description: description,
      itemType: itemType,
      locationId: locationId,
      ownerId: ownerId,
      quantity: quantity,
      brand: brand,
      model: model,
      purchaseDate: purchaseDate,
      purchasePrice: purchasePrice,
      warrantyExpiry: warrantyExpiry,
      condition: ItemCondition.fromString(condition),
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      notes: notes,
      syncStatus: SyncStatus.fromString(syncStatus),
      remoteId: remoteId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      slotPosition: slotPositionMap,
    );
  }

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
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'version': version,
      'slot_position': slotPosition,
    };
  }
}

extension ItemLocationExtensions on db.ItemLocation {
  ItemLocation toItemLocationModel() {
    Map<String, dynamic>? templateConfigMap;
    if (templateConfig != null && templateConfig!.isNotEmpty) {
      try {
        templateConfigMap = jsonDecode(templateConfig!) as Map<String, dynamic>;
      } catch (e) {
        templateConfigMap = null;
      }
    }
    
    Map<String, dynamic>? positionInParentMap;
    if (positionInParent != null && positionInParent!.isNotEmpty) {
      try {
        positionInParentMap = jsonDecode(positionInParent!) as Map<String, dynamic>;
      } catch (e) {
        positionInParentMap = null;
      }
    }
    
    return ItemLocation(
      id: id,
      householdId: householdId,
      name: name,
      description: description,
      icon: icon,
      color: color,
      parentId: parentId,
      depth: depth,
      path: path,
      sortOrder: sortOrder,
      templateType: templateType != null ? LocationTemplateType.fromString(templateType!) : null,
      templateConfig: templateConfigMap,
      positionInParent: positionInParentMap,
      positionDescription: positionDescription,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

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
      'template_config': templateConfig,
      'position_in_parent': positionInParent,
      'position_description': positionDescription,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'version': version,
    };
  }
}

extension ItemTagExtensions on db.ItemTag {
  ItemTag toItemTagModel() {
    List<String> applicableTypesList;
    try {
      if (applicableTypes == null || applicableTypes!.isEmpty) {
        applicableTypesList = [];
      } else {
        final typesStr = applicableTypes!;
        if (typesStr.startsWith('[') && typesStr.endsWith(']')) {
          final parts = typesStr.substring(1, typesStr.length - 1).split(',');
          applicableTypesList = parts.map((e) => e.trim().replaceAll("'", "")).toList();
        } else {
          applicableTypesList = [];
        }
      }
    } catch (e) {
      applicableTypesList = [];
    }
    
    return ItemTag(
      id: id,
      householdId: householdId,
      name: name,
      color: color,
      icon: icon,
      category: category,
      applicableTypes: applicableTypesList,
      createdAt: createdAt,
    );
  }

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

extension ItemTypeConfigExtensions on db.ItemTypeConfig {
  ItemTypeConfig toItemTypeConfigModel() {
    return ItemTypeConfig(
      id: id,
      householdId: householdId,
      typeKey: typeKey,
      typeLabel: typeLabel,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

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
