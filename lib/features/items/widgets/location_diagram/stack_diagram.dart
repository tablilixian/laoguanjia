import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/location_template/location_template.dart';

class StackDiagram extends StatefulWidget {
  final StackConfig config;
  final String? selectedLevel;
  final Set<String> occupiedSlots;
  final ValueChanged<String>? onLevelSelected;

  const StackDiagram({
    super.key,
    required this.config,
    this.selectedLevel,
    this.occupiedSlots = const {},
    this.onLevelSelected,
  });

  @override
  State<StackDiagram> createState() => _StackDiagramState();
}

class _StackDiagramState extends State<StackDiagram> {
  late String? _selectedLevel;

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.selectedLevel;
  }

  @override
  void didUpdateWidget(StackDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLevel != widget.selectedLevel) {
      _selectedLevel = widget.selectedLevel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = widget.config.generateSlotNames();

    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: levels.reversed.map((level) {
              final isSelected = _selectedLevel == level;
              final isOccupied = widget.occupiedSlots.contains(level);

              return GestureDetector(
                onTap: () => _selectLevel(level),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGold
                        : isOccupied
                            ? Colors.grey.shade200
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? Border.all(color: AppTheme.primaryGold, width: 2)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.layers,
                            size: 18,
                            color: isOccupied && !isSelected
                                ? Colors.grey
                                : (isSelected ? Colors.white : Colors.black87),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            level,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isOccupied && !isSelected
                                  ? Colors.grey
                                  : (isSelected ? Colors.white : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                      if (isOccupied)
                        Icon(Icons.check_circle, size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_selectedLevel != null) ...[
          const SizedBox(height: 16),
          _buildSelectionSummary(),
        ],
      ],
    );
  }

  void _selectLevel(String level) {
    setState(() => _selectedLevel = level);
    widget.onLevelSelected?.call(level);
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
            _selectedLevel ?? '',
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

  String? get currentSlot => _selectedLevel;

  Map<String, dynamic>? get currentPosition {
    if (_selectedLevel == null) return null;
    final levels = widget.config.generateSlotNames();
    final index = levels.indexOf(_selectedLevel!);
    return {'level': index + 1};
  }
}
