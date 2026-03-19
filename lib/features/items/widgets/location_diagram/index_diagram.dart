import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/location_template/location_template.dart';

class IndexDiagram extends StatefulWidget {
  final IndexConfig config;
  final String? selectedIndex;
  final Set<String> occupiedSlots;
  final ValueChanged<String>? onIndexSelected;

  const IndexDiagram({
    super.key,
    required this.config,
    this.selectedIndex,
    this.occupiedSlots = const {},
    this.onIndexSelected,
  });

  @override
  State<IndexDiagram> createState() => _IndexDiagramState();
}

class _IndexDiagramState extends State<IndexDiagram> {
  late String? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(IndexDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _selectedIndex = widget.selectedIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = widget.config.generateSlotNames();

    if (widget.config.columns == 1) {
      return Column(
        children: [
          _buildVerticalLayout(slots),
          if (_selectedIndex != null) ...[
            const SizedBox(height: 16),
            _buildSelectionSummary(),
          ],
        ],
      );
    } else {
      return Column(
        children: [
          _buildGridLayout(slots),
          if (_selectedIndex != null) ...[
            const SizedBox(height: 16),
            _buildSelectionSummary(),
          ],
        ],
      );
    }
  }

  Widget _buildVerticalLayout(List<String> slots) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Column(
        children: slots.reversed.map((slot) {
          final isSelected = _selectedIndex == slot;
          final isOccupied = widget.occupiedSlots.contains(slot);

          return GestureDetector(
            onTap: () => _selectIndex(slot),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryGold
                    : isOccupied
                        ? Colors.grey.shade200
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryGold : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    slot,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isOccupied && !isSelected
                          ? Colors.grey
                          : (isSelected ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (isOccupied)
                    Icon(Icons.check_circle, size: 16, color: Colors.grey.shade400),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGridLayout(List<String> slots) {
    final rows = <List<String>>[];
    for (int i = 0; i < slots.length; i += widget.config.columns) {
      final end = (i + widget.config.columns > slots.length)
          ? slots.length
          : i + widget.config.columns;
      rows.add(slots.sublist(i, end));
    }

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((slot) {
              final isSelected = _selectedIndex == slot;
              final isOccupied = widget.occupiedSlots.contains(slot);

              return GestureDetector(
                onTap: () => _selectIndex(slot),
                child: Container(
                  width: 70,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGold
                        : isOccupied
                            ? Colors.grey.shade200
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryGold : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slot,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isOccupied && !isSelected
                              ? Colors.grey
                              : (isSelected ? Colors.white : Colors.black87),
                        ),
                      ),
                      if (isOccupied)
                        Icon(Icons.check_circle, size: 12, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  void _selectIndex(String index) {
    setState(() => _selectedIndex = index);
    widget.onIndexSelected?.call(index);
  }

  Widget _buildSelectionSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, size: 18, color: AppTheme.primaryGold),
          const SizedBox(width: 8),
          Text(
            _selectedIndex ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryGold,
            ),
          ),
        ],
      ),
    );
  }

  String? get currentSlot => _selectedIndex;

  Map<String, dynamic>? get currentPosition {
    if (_selectedIndex == null) return null;
    final index = widget.config.generateSlotNames().indexOf(_selectedIndex!);
    return {'index': widget.config.startFrom + index};
  }
}
