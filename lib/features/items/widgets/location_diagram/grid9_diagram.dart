import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// 简洁的九宫格位置选择器
/// ┌─────┬─────┬─────┐
/// │ 西北 │  北  │ 东北 │
/// ├─────┼─────┼─────┤
/// │  西  │ 中心 │  东  │
/// ├─────┼─────┼─────┤
/// │ 西南 │  南  │ 东南 │
/// └─────┴─────┴─────┘
class SimpleGrid9Selector extends StatefulWidget {
  /// 高度选项（可选）
  final List<String> heightOptions;

  /// 当前选中的位置，如"东"、"南"等
  final String? selectedDirection;

  /// 当前选中的高度
  final String? selectedHeight;

  /// 位置选择回调
  final ValueChanged<String>? onDirectionSelected;

  /// 高度选择回调
  final ValueChanged<String?>? onHeightSelected;

  const SimpleGrid9Selector({
    super.key,
    this.heightOptions = const ['上层', '中层', '下层'],
    this.selectedDirection,
    this.selectedHeight,
    this.onDirectionSelected,
    this.onHeightSelected,
  });

  @override
  State<SimpleGrid9Selector> createState() => _SimpleGrid9SelectorState();
}

class _SimpleGrid9SelectorState extends State<SimpleGrid9Selector> {
  String? _selectedDirection;
  String? _selectedHeight;

  // 九宫格布局：索引对应位置
  // 0=西北, 1=北, 2=东北
  // 3=西,  4=中心, 5=东
  // 6=西南, 7=南, 8=东南
  final List<String> _directions = [
    '西北',
    '北',
    '东北',
    '西',
    '中心',
    '东',
    '西南',
    '南',
    '东南',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDirection = widget.selectedDirection;
    _selectedHeight = widget.selectedHeight;
  }

  @override
  void didUpdateWidget(SimpleGrid9Selector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDirection != widget.selectedDirection) {
      _selectedDirection = widget.selectedDirection;
    }
    if (oldWidget.selectedHeight != widget.selectedHeight) {
      _selectedHeight = widget.selectedHeight;
    }
  }

  void _selectDirection(String direction) {
    setState(() {
      _selectedDirection = (_selectedDirection == direction) ? null : direction;
    });
    // 无论选择还是取消，都通知父组件
    widget.onDirectionSelected?.call(_selectedDirection ?? '');
  }

  void _selectHeight(String height) {
    setState(() {
      _selectedHeight = (_selectedHeight == height) ? null : height;
    });
    // 无论选择还是取消，都通知父组件
    widget.onHeightSelected?.call(_selectedHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 九宫格按钮
        _buildGrid(),
        const SizedBox(height: 8),
        // 高度选择（如果有）
        if (widget.heightOptions.isNotEmpty) _buildHeightSelector(),
      ],
    );
  }

  Widget _buildGrid() {
    return Column(
      children: [
        // 第一行
        Row(
          children: [
            _buildCell(_directions[0]),
            _buildCell(_directions[1]),
            _buildCell(_directions[2]),
          ],
        ),
        const SizedBox(height: 4),
        // 第二行
        Row(
          children: [
            _buildCell(_directions[3]),
            _buildCell(_directions[4]),
            _buildCell(_directions[5]),
          ],
        ),
        const SizedBox(height: 4),
        // 第三行
        Row(
          children: [
            _buildCell(_directions[6]),
            _buildCell(_directions[7]),
            _buildCell(_directions[8]),
          ],
        ),
      ],
    );
  }

  Widget _buildCell(String direction) {
    final isSelected = _selectedDirection == direction;

    return Expanded(
      child: AspectRatio(
        aspectRatio: 1.5, // 宽一点，更像按钮
        child: GestureDetector(
          onTap: () => _selectDirection(direction),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryGold : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.primaryGold : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                direction,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeightSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.heightOptions.map((height) {
        final isSelected = _selectedHeight == height;
        return GestureDetector(
          onTap: () => _selectHeight(height),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryGold.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.primaryGold : Colors.grey.shade300,
              ),
            ),
            child: Text(
              height,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryGold : Colors.black54,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
