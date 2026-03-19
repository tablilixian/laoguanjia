import 'item_tag.dart';
import 'item_type_config.dart';

enum ItemCondition {
  new_('全新', 'new'),
  good('正常使用', 'good'),
  fair('有些磨损', 'fair'),
  poor('需要维修', 'poor');

  final String label;
  final String dbValue;
  const ItemCondition(this.label, this.dbValue);

  static ItemCondition fromString(String value) {
    return ItemCondition.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => ItemCondition.good,
    );
  }
}

enum SyncStatus {
  pending,
  synced,
  error;

  static SyncStatus fromString(String value) {
    return SyncStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncStatus.pending,
    );
  }
}

class HouseholdItem {
  final String id;
  final String householdId;
  final String name;
  final String? description;
  final String itemType;
  final String? locationId;
  final String? ownerId;
  final int quantity;
  final String? brand;
  final String? model;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final DateTime? warrantyExpiry;
  final ItemCondition condition;
  final String? imageUrl;
  final String? thumbnailUrl;
  final String? notes;
  final SyncStatus syncStatus;
  final String? remoteId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  final String? locationName;
  final String? locationIcon;
  final String? locationPath;
  final String? ownerName;
  final List<ItemTag> tags;
  final ItemTypeConfig? typeConfig;
  final Map<String, dynamic>? slotPosition;

  const HouseholdItem({
    required this.id,
    required this.householdId,
    required this.name,
    this.description,
    this.itemType = 'other',
    this.locationId,
    this.ownerId,
    this.quantity = 1,
    this.brand,
    this.model,
    this.purchaseDate,
    this.purchasePrice,
    this.warrantyExpiry,
    this.condition = ItemCondition.good,
    this.imageUrl,
    this.thumbnailUrl,
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.locationName,
    this.locationIcon,
    this.locationPath,
    this.ownerName,
    this.tags = const [],
    this.typeConfig,
    this.slotPosition,
  });

  bool get isDeleted => deletedAt != null;
  bool get needsSync => syncStatus != SyncStatus.synced;
  bool get isInWarranty =>
      warrantyExpiry != null && warrantyExpiry!.isAfter(DateTime.now());

  factory HouseholdItem.fromMap(Map<String, dynamic> map) {
    return HouseholdItem(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      itemType: map['item_type'] as String? ?? 'other',
      locationId: map['location_id'] as String?,
      ownerId: map['owner_id'] as String?,
      quantity: map['quantity'] as int? ?? 1,
      brand: map['brand'] as String?,
      model: map['model'] as String?,
      purchaseDate: map['purchase_date'] != null
          ? DateTime.parse(map['purchase_date'] as String)
          : null,
      purchasePrice: map['purchase_price'] != null
          ? (map['purchase_price'] as num).toDouble()
          : null,
      warrantyExpiry: map['warranty_expiry'] != null
          ? DateTime.parse(map['warranty_expiry'] as String)
          : null,
      condition: ItemCondition.fromString(
        map['condition'] as String? ?? 'good',
      ),
      imageUrl: map['image_url'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      notes: map['notes'] as String?,
      syncStatus: SyncStatus.fromString(
        map['sync_status'] as String? ?? 'pending',
      ),
      remoteId: map['remote_id'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
      locationName: map['location_name'] as String?,
      locationIcon: map['location_icon'] as String?,
      locationPath: map['location_path'] as String?,
      ownerName: map['owner_name'] as String?,
      tags:
          (map['tags'] as List<dynamic>?)
              ?.map((e) => ItemTag.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      slotPosition: map['slot_position'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
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
      'condition': condition.dbValue,
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'notes': notes,
      'sync_status': syncStatus.name,
      'remote_id': remoteId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'slot_position': slotPosition,
    };
  }

  HouseholdItem copyWith({
    String? id,
    String? householdId,
    String? name,
    String? description,
    String? itemType,
    String? locationId,
    String? ownerId,
    int? quantity,
    String? brand,
    String? model,
    DateTime? purchaseDate,
    double? purchasePrice,
    DateTime? warrantyExpiry,
    ItemCondition? condition,
    String? imageUrl,
    String? thumbnailUrl,
    String? notes,
    SyncStatus? syncStatus,
    String? remoteId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? locationName,
    String? locationIcon,
    String? locationPath,
    String? ownerName,
    List<ItemTag>? tags,
    ItemTypeConfig? typeConfig,
    Map<String, dynamic>? slotPosition,
  }) {
    return HouseholdItem(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      description: description ?? this.description,
      itemType: itemType ?? this.itemType,
      locationId: locationId ?? this.locationId,
      ownerId: ownerId ?? this.ownerId,
      quantity: quantity ?? this.quantity,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
      condition: condition ?? this.condition,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      notes: notes ?? this.notes,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteId: remoteId ?? this.remoteId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      locationName: locationName ?? this.locationName,
      locationIcon: locationIcon ?? this.locationIcon,
      locationPath: locationPath ?? this.locationPath,
      ownerName: ownerName ?? this.ownerName,
      tags: tags ?? this.tags,
      typeConfig: typeConfig ?? this.typeConfig,
      slotPosition: slotPosition ?? this.slotPosition,
    );
  }
}
