import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/location_template/location_template.dart';

class DirectionDiagram extends StatefulWidget {
  final DirectionConfig directionConfig;
  final HeightConfig? heightConfig;
  final String? selectedDirection;
  final String? selectedHeight;
  final Set<String> occupiedSlots;
  final ValueChanged<String>? onDirectionSelected;
  final ValueChanged<String>? onHeightSelected;

  const DirectionDiagram({
    super.key,
    required this.directionConfig,
    this.heightConfig,
    this.selectedDirection,
    this.selectedHeight,
    this.occupiedSlots = const {},
    this.onDirectionSelected,
    this.onHeightSelected,
  });

  @override
  State<DirectionDiagram> createState() => _DirectionDiagramState();
}

class _DirectionDiagramState extends State<DirectionDiagram> {
  late String? _selectedDirection;
  late String? _selectedHeight;

  @override
  void initState() {
    super.initState();
    _selectedDirection = widget.selectedDirection;
    _selectedHeight = widget.selectedHeight;
  }

  @override
  void didUpdateWidget(DirectionDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDirection != widget.selectedDirection) {
      _selectedDirection = widget.selectedDirection;
    }
    if (oldWidget.selectedHeight != widget.selectedHeight) {
      _selectedHeight = widget.selectedHeight;
    }
  }

  bool _isSlotOccupied(String direction, String? height) {
    final slot = height != null ? '$direction$height' : direction;
    return widget.occupiedSlots.contains(slot);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCompass(),
        if (widget.heightConfig?.enabled == true) ...[
          const SizedBox(height: 16),
          _buildHeightSelector(),
        ],
        if (_selectedDirection != null) ...[
          const SizedBox(height: 16),
          _buildSelectionSummary(),
        ],
      ],
    );
  }

  Widget _buildCompass() {
    final labels = widget.directionConfig.labels;
    final hasHeights = widget.heightConfig?.enabled == true;

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
          ),
          if (widget.directionConfig.includeCenter)
            _buildCenterButton(),
          ..._buildDirectionButtons(labels, hasHeights),
        ],
      ),
    );
  }

  Widget _buildCenterButton() {
    final isSelected = _selectedDirection == '中心';
    return GestureDetector(
      onTap: () => _selectDirection('中心'),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? AppTheme.primaryGold
              : (widget.occupiedSlots.contains('中心') || 
                 widget.occupiedSlots.contains('中心${_selectedHeight}'))
                  ? Colors.grey.shade200
                  : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? AppTheme.primaryGold : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            '中心',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDirectionButtons(List<String> labels, bool hasHeights) {
    final buttons = <Widget>[];
    final positions = _getDirectionPositions(labels.length);

    for (int i = 0; i < labels.length; i++) {
      final label = labels[i];
      final pos = positions[i];
      buttons.add(
        Positioned(
          left: pos['left'],
          top: pos['top'],
          child: _buildDirectionButton(label, hasHeights),
        ),
      );
    }

    return buttons;
  }

  List<Map<String, double>> _getDirectionPositions(int count) {
    final positions = <Map<String, double>>[];
    const centerX = 0.5;
    const centerY = 0.5;
    const radius = 0.38;

    if (count == 4) {
      positions.add({'left': centerX - 0.08, 'top': centerY - radius - 0.06}); // 北
      positions.add({'left': centerX + radius - 0.08, 'top': centerY - 0.04}); // 东
      positions.add({'left': centerX - 0.08, 'top': centerY + radius - 0.1}); // 南
      positions.add({'left': centerX - radius - 0.08, 'top': centerY - 0.04}); // 西
    } else if (count == 8) {
      final angles = [-90.0, -45.0, 0.0, 45.0, 90.0, 135.0, 180.0, -135.0];
      for (final angle in angles) {
        final rad = angle * 3.14159 / 180;
        positions.add({
          'left': centerX + radius * 0.85 * (rad == 0 ? 1 : rad.abs() < 1 ? 0.7 : 1) * (angle == 0 ? 1 : angle > 0 ? 1 : -1) - 0.08,
          'top': centerY - radius * (angle == -90 ? 1 : angle == 90 ? -1 : (angle.abs() < 90 ? 0.7 : 0.85)) - 0.04,
        });
      }
      return [
        {'left': centerX - 0.08, 'top': centerY - radius - 0.06}, // 北
        {'left': centerX + radius * 0.7 - 0.08, 'top': centerY - radius * 0.7 - 0.06}, // 东北
        {'left': centerX + radius - 0.08, 'top': centerY - 0.04}, // 东
        {'left': centerX + radius * 0.7 - 0.08, 'top': centerY + radius * 0.7 - 0.1}, // 东南
        {'left': centerX - 0.08, 'top': centerY + radius - 0.1}, // 南
        {'left': centerX - radius * 1.7 + 0.08, 'top': centerY + radius * 0.7 - 0.1}, // 西南
        {'left': centerX - radius - 0.08, 'top': centerY - 0.04}, // 西
        {'left': centerX - radius * 1.7 + 0.08, 'top': centerY - radius * 0.7 - 0.06}, // 西北
      ];
    }

    return positions;
  }

  Widget _buildDirectionButton(String label, bool hasHeights) {
    final isSelected = _selectedDirection == label;
    final isOccupied = _isSlotOccupied(label, _selectedHeight);

    return GestureDetector(
      onTap: () => _selectDirection(label),
      child: Container(
        width: 56,
        height: 40,
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
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isOccupied && !isSelected
                  ? Colors.grey
                  : (isSelected ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  void _selectDirection(String direction) {
    setState(() => _selectedDirection = direction);
    widget.onDirectionSelected?.call(direction);
  }

  Widget _buildHeightSelector() {
    final heights = widget.heightConfig?.labels ?? [];
    if (heights.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      children: heights.map((height) {
        final isSelected = _selectedHeight == height;
        return ChoiceChip(
          label: Text(height),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedHeight = selected ? height : null);
            if (selected) {
              widget.onHeightSelected?.call(height);
            }
          },
          selectedColor: AppTheme.primaryGold.withValues(alpha: 0.3),
        );
      }).toList(),
    );
  }

  Widget _buildSelectionSummary() {
    final description = _buildPositionDescription();
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
            description,
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

  String _buildPositionDescription() {
    if (_selectedDirection == null) return '请选择位置';
    if (_selectedHeight != null) return '$_selectedDirection$_selectedHeight';
    return _selectedDirection!;
  }

  String? get currentSlot {
    if (_selectedDirection == null) return null;
    if (_selectedHeight != null) return '$_selectedDirection$_selectedHeight';
    return _selectedDirection;
  }

  Map<String, dynamic>? get currentPosition {
    if (_selectedDirection == null) return null;
    final pos = <String, dynamic>{'direction': _selectedDirection};
    if (_selectedHeight != null) {
      pos['height'] = _selectedHeight;
    }
    return pos;
  }
}
