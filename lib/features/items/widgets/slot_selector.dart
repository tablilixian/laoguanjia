import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/item_location.dart';
import '../../../data/repositories/item_repository.dart';
import '../widgets/location_diagram/location_diagram_widget.dart';

class SlotSelector extends ConsumerStatefulWidget {
  final List<ItemLocation> locations;
  final String? selectedLocationId;
  final Map<String, dynamic>? selectedSlotPosition;
  final ValueChanged<String?>? onLocationSelected;
  final ValueChanged<Map<String, dynamic>?>? onSlotPositionSelected;

  const SlotSelector({
    super.key,
    required this.locations,
    this.selectedLocationId,
    this.selectedSlotPosition,
    this.onLocationSelected,
    this.onSlotPositionSelected,
  });

  @override
  ConsumerState<SlotSelector> createState() => _SlotSelectorState();
}

class _SlotSelectorState extends ConsumerState<SlotSelector> {
  String? _selectedLocationId;
  Map<String, dynamic>? _selectedSlotPosition;
  Map<String, Set<String>> _occupiedSlotsCache = {};

  @override
  void initState() {
    super.initState();
    _selectedLocationId = widget.selectedLocationId;
    _selectedSlotPosition = widget.selectedSlotPosition;
    if (_selectedLocationId != null) {
      _loadOccupiedSlots(_selectedLocationId!);
    }
  }

  @override
  void didUpdateWidget(SlotSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLocationId != widget.selectedLocationId) {
      _selectedLocationId = widget.selectedLocationId;
    }
    if (oldWidget.selectedSlotPosition != widget.selectedSlotPosition) {
      _selectedSlotPosition = widget.selectedSlotPosition;
    }
  }

  Future<void> _loadOccupiedSlots(String locationId) async {
    if (_occupiedSlotsCache.containsKey(locationId)) return;

    final repository = ItemRepository();
    final occupied = await repository.getOccupiedSlots(locationId);
    setState(() {
      _occupiedSlotsCache[locationId] = occupied;
    });
  }

  ItemLocation? get _selectedLocation {
    if (_selectedLocationId == null) return null;
    return widget.locations.firstWhere(
      (l) => l.id == _selectedLocationId,
      orElse: () => widget.locations.first,
    );
  }

  Set<String> get _currentOccupiedSlots {
    return _occupiedSlotsCache[_selectedLocationId] ?? {};
  }

  @override
  Widget build(BuildContext context) {
    final rootLocations = widget.locations.where((l) => l.isRoot).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择位置',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (rootLocations.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  '请先创建位置',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
        else
          _buildLocationTree(rootLocations, 0),
        if (_selectedLocation != null && _selectedLocation!.hasTemplate) ...[
          const SizedBox(height: 24),
          const Text(
            '选择槽位',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildSlotSelector(),
        ],
      ],
    );
  }

  Widget _buildLocationTree(List<ItemLocation> locations, int depth) {
    return Column(
      children: locations.map((location) {
        final children = widget.locations
            .where((l) => l.parentId == location.id)
            .toList();
        final isSelected = _selectedLocationId == location.id;
        final hasChildren = children.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _selectedLocationId = location.id;
                  _selectedSlotPosition = null;
                });
                _loadOccupiedSlots(location.id);
                widget.onLocationSelected?.call(location.id);
                widget.onSlotPositionSelected?.call(null);
              },
              child: Container(
                padding: EdgeInsets.only(
                  left: depth * 16.0 + 8,
                  top: 8,
                  bottom: 8,
                  right: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryGold.withValues(alpha: 0.1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(location.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? AppTheme.primaryGold : null,
                        ),
                      ),
                    ),
                    if (location.hasTemplate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          location.templateType!.label,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    if (isSelected)
                      const Icon(Icons.check, size: 18, color: AppTheme.primaryGold),
                  ],
                ),
              ),
            ),
            if (hasChildren)
              _buildLocationTree(children, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSlotSelector() {
    final location = _selectedLocation!;
    final templateType = location.templateType!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          LocationDiagramWidget(
            templateType: templateType,
            templateConfig: location.templateConfig,
            initialPosition: _selectedSlotPosition,
            occupiedSlots: _currentOccupiedSlots,
            onPositionChanged: (position) {
              setState(() {
                _selectedSlotPosition = position;
              });
              widget.onSlotPositionSelected?.call(position);
            },
          ),
          if (_selectedSlotPosition != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedSlotPosition = null;
                    });
                    widget.onSlotPositionSelected?.call(null);
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('清除槽位'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
