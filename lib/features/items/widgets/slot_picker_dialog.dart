import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item_location.dart';
import '../../../data/repositories/item_repository.dart';
import '../widgets/location_diagram/location_diagram_widget.dart';

class SlotPickerDialog extends ConsumerStatefulWidget {
  final List<ItemLocation> locations;
  final String? initialLocationId;
  final Map<String, dynamic>? initialSlotPosition;

  const SlotPickerDialog({
    super.key,
    required this.locations,
    this.initialLocationId,
    this.initialSlotPosition,
  });

  @override
  ConsumerState<SlotPickerDialog> createState() => _SlotPickerDialogState();

  static Future<MapEntry<String, Map<String, dynamic>?>?> show(
    BuildContext context, {
    required List<ItemLocation> locations,
    String? initialLocationId,
    Map<String, dynamic>? initialSlotPosition,
  }) {
    return showModalBottomSheet<MapEntry<String, Map<String, dynamic>?>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SlotPickerDialog(
        locations: locations,
        initialLocationId: initialLocationId,
        initialSlotPosition: initialSlotPosition,
      ),
    );
  }
}

class _SlotPickerDialogState extends ConsumerState<SlotPickerDialog> {
  final _repository = ItemRepository();
  String? _selectedLocationId;
  Map<String, dynamic>? _selectedSlotPosition;
  Map<String, Set<String>> _occupiedSlotsCache = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedLocationId = widget.initialLocationId;
    _selectedSlotPosition = widget.initialSlotPosition;
    if (_selectedLocationId != null) {
      _loadOccupiedSlots(_selectedLocationId!);
    }
  }

  Future<void> _loadOccupiedSlots(String locationId) async {
    if (_occupiedSlotsCache.containsKey(locationId)) return;

    setState(() => _isLoading = true);
    final occupied = await _repository.getOccupiedSlots(locationId);
    setState(() {
      _occupiedSlotsCache[locationId] = occupied;
      _isLoading = false;
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildLocationList(rootLocations, 0),
                if (_selectedLocation != null &&
                    _selectedLocation!.hasTemplate) ...[
                  const SizedBox(height: 24),
                  _buildSlotSelector(),
                ],
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          const Expanded(
            child: Text(
              '选择位置和槽位',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildLocationList(List<ItemLocation> locations, int depth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              },
              child: Container(
                padding: EdgeInsets.only(
                  left: depth * 16.0 + 8,
                  top: 12,
                  bottom: 12,
                  right: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(location.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (location.hasTemplate)
                            Text(
                              location.templateType!.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                      ),
                    if (hasChildren && !isSelected)
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
            if (hasChildren) _buildLocationList(children, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSlotSelector() {
    final location = _selectedLocation!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '选择槽位',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedSlotPosition = null;
                });
              },
              child: const Text('清除'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          LocationDiagramWidget(
            templateType: location.templateType!,
            templateConfig: location.templateConfig,
            initialPosition: _selectedSlotPosition,
            occupiedSlots: _currentOccupiedSlots,
            onPositionChanged: (position) {
              if (mounted) {
                setState(() {
                  _selectedSlotPosition = position;
                });
              }
            },
            useGrid9Mode:
                location.templateType == LocationTemplateType.direction,
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () {
                final result = _selectedLocationId != null
                    ? MapEntry(_selectedLocationId!, _selectedSlotPosition)
                    : null;
                Navigator.pop(context, result);
              },
              child: Text(_selectedLocation != null ? '确认' : '跳过'),
            ),
          ),
        ],
      ),
    );
  }
}
