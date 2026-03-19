import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/location_template/location_template.dart';

class GridDiagram extends StatefulWidget {
  final GridConfig config;
  final String? selectedCell;
  final Set<String> occupiedSlots;
  final ValueChanged<String>? onCellSelected;

  const GridDiagram({
    super.key,
    required this.config,
    this.selectedCell,
    this.occupiedSlots = const {},
    this.onCellSelected,
  });

  @override
  State<GridDiagram> createState() => _GridDiagramState();
}

class _GridDiagramState extends State<GridDiagram> {
  late String? _selectedCell;

  @override
  void initState() {
    super.initState();
    _selectedCell = widget.selectedCell;
  }

  @override
  void didUpdateWidget(GridDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCell != widget.selectedCell) {
      _selectedCell = widget.selectedCell;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildGrid(),
        if (_selectedCell != null) ...[
          const SizedBox(height: 16),
          _buildSelectionSummary(),
        ],
      ],
    );
  }

  Widget _buildGrid() {
    final rowLabels = widget.config.rowLabels ??
        List.generate(widget.config.rows, (i) => '${i + 1}');
    final colLabels = widget.config.colLabels ??
        List.generate(widget.config.cols, (i) => '${i + 1}');

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 40),
            ...colLabels.map((label) => SizedBox(
                  width: 60,
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(widget.config.rows, (r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  child: Center(
                    child: Text(
                      rowLabels[r],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                ...List.generate(widget.config.cols, (c) {
                  final cellLabel = widget.config.getCellLabel(r, c);
                  return _buildCell(cellLabel, r, c);
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCell(String label, int row, int col) {
    final isSelected = _selectedCell == label;
    final isOccupied = widget.occupiedSlots.contains(label);

    return GestureDetector(
      onTap: () => _selectCell(label),
      child: Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 2),
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
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isOccupied && !isSelected
                    ? Colors.grey
                    : (isSelected ? Colors.white : Colors.black87),
              ),
            ),
            if (isOccupied)
              Icon(Icons.check_circle, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _selectCell(String cell) {
    setState(() => _selectedCell = cell);
    widget.onCellSelected?.call(cell);
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
            _selectedCell ?? '',
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

  String? get currentSlot => _selectedCell;

  Map<String, dynamic>? get currentPosition {
    if (_selectedCell == null) return null;
    final slots = widget.config.generateSlotNames();
    final index = slots.indexOf(_selectedCell!);
    final row = index ~/ widget.config.cols;
    final col = index % widget.config.cols;
    return {
      'row': widget.config.rowLabels != null
          ? widget.config.rowLabels![row]
          : row + 1,
      'col': widget.config.colLabels != null
          ? widget.config.colLabels![col]
          : col + 1,
    };
  }
}
