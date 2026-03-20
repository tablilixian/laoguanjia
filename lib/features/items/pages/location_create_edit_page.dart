import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/item_location.dart';
import '../../../data/location_template/location_template.dart';
import '../../../data/location_template/location_template_library.dart';
import '../../../data/services/location_path_service.dart';
import '../../household/providers/household_provider.dart';
import '../providers/locations_provider.dart';
import '../widgets/location_diagram/location_diagram_widget.dart';

class LocationCreateEditPage extends ConsumerStatefulWidget {
  final ItemLocation? location;
  final String? parentId;

  const LocationCreateEditPage({super.key, this.location, this.parentId});

  @override
  ConsumerState<LocationCreateEditPage> createState() =>
      _LocationCreateEditPageState();
}

class _LocationCreateEditPageState
    extends ConsumerState<LocationCreateEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedIcon = '📍';
  LocationTemplateType? _selectedTemplateType;
  LocationTemplate? _selectedTemplate;
  bool _isLoading = false;

  // 新增：父级槽位选择
  Map<String, dynamic>? _parentSlotPosition;

  bool get isEditing => widget.location != null;
  bool get isRootLocation =>
      widget.parentId == null && widget.location?.parentId == null;

  /// 获取父位置信息
  ItemLocation? get parentLocation {
    if (isEditing) {
      // 编辑时：如果当前位置有父级，获取父级
      if (widget.location?.parentId != null) {
        final locations = ref.read(locationsProvider).locations;
        return locations.firstWhere(
          (l) => l.id == widget.location!.parentId,
          orElse: () => locations.first,
        );
      }
      return null;
    } else {
      // 创建时：从 parentId 获取父位置
      if (widget.parentId != null) {
        final locations = ref.read(locationsProvider).locations;
        return locations.firstWhere(
          (l) => l.id == widget.parentId,
          orElse: () => locations.first,
        );
      }
      return null;
    }
  }

  /// 判断是否显示父级槽位选择（有父位置时显示）
  bool get showParentSlotSelector => parentLocation != null;

  /// 判断是否显示父级信息（有父位置时显示）
  bool get showParentInfo => parentLocation != null;

  /// 生成完整的位置描述
  String? get fullPositionDescription {
    final parent = parentLocation;
    final name = _nameController.text.trim();
    if (name.isEmpty) return null;

    if (parent != null && _parentSlotPosition != null) {
      // 有父位置和槽位选择
      final slotDesc = LocationPathService.formatSlotForDisplaySimple(
        _parentSlotPosition,
      );
      return '${parent.name}的$slotDesc$name';
    } else if (parent != null) {
      // 有父位置但未选择槽位
      return '${parent.name}的$name';
    } else {
      // 顶层位置
      return name;
    }
  }

  /// 获取全路径描述
  String? get fullPathDescription {
    final name = _nameController.text.trim();
    if (name.isEmpty) return null;

    // 如果是编辑模式，使用已有的路径信息
    if (isEditing && widget.location?.path != null) {
      // 构建完整路径
      return _buildFullPathFromLocation(name);
    }

    return fullPositionDescription;
  }

  /// 从位置对象构建完整路径
  String _buildFullPathFromLocation(String currentName) {
    final parent = parentLocation;
    if (parent == null) return currentName;

    // 如果父位置有路径，拼接父路径
    if (parent.path != null && parent.path!.isNotEmpty) {
      // 父路径 + 当前槽位 + 当前名称
      final slotDesc = _parentSlotPosition != null
          ? LocationPathService.formatSlotForDisplaySimple(_parentSlotPosition)
          : '';
      if (slotDesc.isNotEmpty) {
        return '${parent.path} → $slotDesc$currentName';
      }
      return '${parent.path} → $currentName';
    }

    // 如果父位置没有路径，从父名称开始
    final slotDesc = _parentSlotPosition != null
        ? LocationPathService.formatSlotForDisplaySimple(_parentSlotPosition)
        : '';
    if (slotDesc.isNotEmpty) {
      return '${parent.name} → $slotDesc$currentName';
    }
    return '${parent.name} → $currentName';
  }

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.location!.name;
      _selectedIcon = widget.location!.icon;
      if (widget.location!.templateType != null) {
        _selectedTemplateType = widget.location!.templateType;
        _selectedTemplate = LocationTemplate.fromConfigJson(
          widget.location!.templateConfig,
        );
      }
      // 加载已有的父级槽位信息
      _parentSlotPosition = widget.location!.positionInParent;
    } else {
      _suggestTemplate();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 当名称变化时，刷新位置描述预览
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _suggestTemplate() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final suggestion = LocationTemplateSuggester.suggest(
      name,
      isRoot: isRootLocation,
    );

    if (suggestion != null) {
      setState(() {
        _selectedTemplateType = suggestion.template.type;
        _selectedTemplate = suggestion.template;
      });
    }
  }

  void _onNameChanged(String value) {
    if (!isEditing && _selectedTemplateType == null) {
      _suggestTemplate();
    }
    setState(() {}); // 刷新位置描述预览
  }

  void _onParentSlotChanged(Map<String, dynamic>? position) {
    setState(() {
      _parentSlotPosition = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? '编辑位置' : (showParentSlotSelector ? '添加子位置' : '添加位置'),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // 显示父位置信息（创建或编辑有父位置时）
            if (showParentInfo) ...[
              _buildParentLocationCard(),
              const SizedBox(height: 8),
              _buildParentSlotSelector(),
              const SizedBox(height: 8),
              _buildFullPathPreview(),
              const SizedBox(height: 12),
            ],
            _buildBasicInfo(),
            const SizedBox(height: 12),
            _buildTemplateSelector(),
            if (_selectedTemplate != null) ...[
              const SizedBox(height: 12),
              _buildTemplatePreview(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// 构建父位置信息卡片
  Widget _buildParentLocationCard() {
    final parent = parentLocation;
    if (parent == null) return const SizedBox.shrink();

    // 获取父位置的完整描述
    final parentDisplay = _getParentDisplayText(parent);

    return Card(
      color: AppTheme.primaryGold.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppTheme.primaryGold,
                ),
                const SizedBox(width: 6),
                Text(
                  '父级: $parentDisplay',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 获取父位置的显示文本
  /// 优先使用 positionDescription，如果没有则使用 path
  String _getParentDisplayText(ItemLocation parent) {
    // 如果父位置有 positionDescription，使用它
    if (parent.positionDescription != null &&
        parent.positionDescription!.isNotEmpty) {
      return '${parent.icon} ${parent.positionDescription!}${parent.name}';
    }

    // 如果父位置有 path，构建完整描述
    if (parent.path != null && parent.path!.isNotEmpty) {
      // path 格式: "主卧 → 鞋柜"
      // 构建完整显示: "主卧 → 鞋柜" 的 "衣柜"
      // 但父位置本身可能没有槽位描述
      return '${parent.icon} ${parent.path} → ${parent.name}';
    }

    // 默认只显示名称
    return '${parent.icon} ${parent.name}';
  }

  /// 构建父级槽位选择器
  Widget _buildParentSlotSelector() {
    final parent = parentLocation;
    if (parent == null) return const SizedBox.shrink();
    if (parent.templateType == null ||
        parent.templateType == LocationTemplateType.none) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '选择位置',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGold,
                  ),
                ),
                if (_parentSlotPosition != null)
                  GestureDetector(
                    onTap: () => _onParentSlotChanged(null),
                    child: const Text(
                      '清除',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 使用九宫格进行槽位选择
            Center(
              child: LocationDiagramWidget(
                templateType: parent.templateType!,
                templateConfig: parent.templateConfig,
                initialPosition: _parentSlotPosition,
                occupiedSlots: const {},
                onPositionChanged: _onParentSlotChanged,
                useGrid9Mode: true,
              ),
            ),
            // 选中槽位显示
            if (_parentSlotPosition != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '已选: ${LocationPathService.formatSlotForDisplaySimple(_parentSlotPosition)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryGold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建全路径预览
  Widget _buildFullPathPreview() {
    final path = fullPathDescription;
    if (path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '完整路径',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  path,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建位置描述预览
  Widget _buildPositionDescriptionPreview() {
    final description = fullPositionDescription;
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '位置描述预览',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"$description"',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '基本信息',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '位置名称',
                hintText: '例如：客厅、衣柜、主卧',
              ),
              onChanged: _onNameChanged,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入位置名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              '选择图标',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _iconOptions.map((icon) {
                final isSelected = _selectedIcon == icon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryGold.withValues(alpha: 0.2)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: AppTheme.primaryGold, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '定位方式',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGold,
                  ),
                ),
                if (!isEditing)
                  TextButton(
                    onPressed: _suggestTemplate,
                    child: const Text('智能推荐'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '选择如何定位此位置中的物品',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LocationTemplateType.values.map((type) {
                final isSelected = _selectedTemplateType == type;
                return ChoiceChip(
                  label: Text(type.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTemplateType = selected ? type : null;
                      if (selected && type != LocationTemplateType.none) {
                        _selectedTemplate = _createDefaultTemplate(type);
                      } else {
                        _selectedTemplate = null;
                      }
                    });
                  },
                  selectedColor: AppTheme.primaryGold.withValues(alpha: 0.3),
                );
              }).toList(),
            ),
            if (_selectedTemplateType != null &&
                _selectedTemplateType != LocationTemplateType.none) ...[
              const SizedBox(height: 16),
              _buildTemplateConfig(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateConfig() {
    switch (_selectedTemplateType) {
      case LocationTemplateType.direction:
        return _buildDirectionConfig();
      case LocationTemplateType.numbering:
        return _buildIndexConfig();
      case LocationTemplateType.grid:
        return _buildGridConfig();
      case LocationTemplateType.stack:
        return _buildStackConfig();
      case LocationTemplateType.none:
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDirectionConfig() {
    final config = _selectedTemplate?.directionConfig;
    final hasHeights = _selectedTemplate?.heightConfig?.enabled ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('方向数量', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('4方向')),
            ButtonSegment(value: true, label: Text('8方向')),
          ],
          selected: {
            config?.labels.length == 8 ||
                    (config?.labels.length == 4 &&
                        config?.includeCenter == true)
                ? true
                : false,
          },
          onSelectionChanged: (selected) {
            setState(() {
              _selectedTemplate = LocationTemplate.direction(
                directions: selected.first
                    ? DirectionConfig.eightDirectionsWithCenter()
                    : DirectionConfig.fourDirectionsWithCenter(),
                heights: hasHeights ? HeightConfig.threeLevels() : null,
              );
            });
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('包含高度'),
          subtitle: const Text('如上层、中层、下层'),
          value: hasHeights,
          onChanged: (value) {
            setState(() {
              _selectedTemplate = LocationTemplate.direction(
                directions:
                    config ?? DirectionConfig.fourDirectionsWithCenter(),
                heights: value ? HeightConfig.threeLevels() : null,
              );
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildIndexConfig() {
    final config =
        _selectedTemplate?.indexConfig ?? const IndexConfig(totalSlots: 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('格子数量', style: TextStyle(fontSize: 14)),
            const Spacer(),
            IconButton(
              onPressed: () {
                if (config.totalSlots > 2) {
                  setState(() {
                    _selectedTemplate = LocationTemplate.numbering(
                      config: IndexConfig(
                        totalSlots: config.totalSlots - 1,
                        namingPattern: config.namingPattern,
                        columns: config.columns,
                      ),
                    );
                  });
                }
              },
              icon: const Icon(Icons.remove),
            ),
            Text(
              '${config.totalSlots}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () {
                if (config.totalSlots < 10) {
                  setState(() {
                    _selectedTemplate = LocationTemplate.numbering(
                      config: IndexConfig(
                        totalSlots: config.totalSlots + 1,
                        namingPattern: config.namingPattern,
                        columns: config.columns,
                      ),
                    );
                  });
                }
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('命名格式', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: '第{n}层', label: Text('第{n}层')),
            ButtonSegment(value: '{n}F', label: Text('{n}F')),
            ButtonSegment(value: 'L{n}', label: Text('L{n}')),
          ],
          selected: {config.namingPattern},
          onSelectionChanged: (selected) {
            setState(() {
              _selectedTemplate = LocationTemplate.numbering(
                config: IndexConfig(
                  totalSlots: config.totalSlots,
                  namingPattern: selected.first,
                  columns: config.columns,
                ),
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildGridConfig() {
    final config =
        _selectedTemplate?.gridConfig ?? const GridConfig(rows: 3, cols: 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('行数', style: TextStyle(fontSize: 14)),
            const Spacer(),
            IconButton(
              onPressed: () {
                if (config.rows > 2) {
                  setState(() {
                    _selectedTemplate = LocationTemplate.grid(
                      config: GridConfig(
                        rows: config.rows - 1,
                        cols: config.cols,
                      ),
                    );
                  });
                }
              },
              icon: const Icon(Icons.remove),
            ),
            Text(
              '${config.rows}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () {
                if (config.rows < 6) {
                  setState(() {
                    _selectedTemplate = LocationTemplate.grid(
                      config: GridConfig(
                        rows: config.rows + 1,
                        cols: config.cols,
                      ),
                    );
                  });
                }
              },
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 24),
            const Text('列数', style: TextStyle(fontSize: 14)),
            const Spacer(),
            IconButton(
              onPressed: () {
                if (config.cols > 2) {
                  setState(() {
                    _selectedTemplate = LocationTemplate.grid(
                      config: GridConfig(
                        rows: config.rows,
                        cols: config.cols - 1,
                      ),
                    );
                  });
                }
              },
              icon: const Icon(Icons.remove),
            ),
            Text(
              '${config.cols}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () {
                if (config.cols < 6) {
                  setState(() {
                    _selectedTemplate = LocationTemplate.grid(
                      config: GridConfig(
                        rows: config.rows,
                        cols: config.cols + 1,
                      ),
                    );
                  });
                }
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStackConfig() {
    final config =
        _selectedTemplate?.stackConfig ?? const StackConfig(levels: 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('层数', style: TextStyle(fontSize: 14)),
            const Spacer(),
            IconButton(
              onPressed: () {
                if (config.levels > 2) {
                  setState(() {
                    _selectedTemplate = LocationTemplate.stack(
                      config: StackConfig(levels: config.levels - 1),
                    );
                  });
                }
              },
              icon: const Icon(Icons.remove),
            ),
            Text(
              '${config.levels}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () {
                if (config.levels < 6) {
                  setState(() {
                    _selectedTemplate = LocationTemplate.stack(
                      config: StackConfig(levels: config.levels + 1),
                    );
                  });
                }
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplatePreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '示意图预览',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '点击示意图选择位置',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Center(
              child: LocationDiagramWidget(
                templateType: _selectedTemplateType!,
                templateConfig: _selectedTemplate?.toConfigJson(),
                onPositionChanged: (position) {},
                useGrid9Mode:
                    _selectedTemplateType ==
                    LocationTemplateType.direction, // 方向型使用九宫格
              ),
            ),
            if (_selectedTemplate != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '共 ${_selectedTemplate!.totalSlots} 个槽位',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
        color: Theme.of(context).scaffoldBackgroundColor,
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
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _isLoading ? null : _saveLocation,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEditing ? '保存' : '添加'),
            ),
          ),
        ],
      ),
    );
  }

  LocationTemplate? _createDefaultTemplate(LocationTemplateType type) {
    switch (type) {
      case LocationTemplateType.direction:
        return LocationTemplate.direction(
          directions: DirectionConfig.fourDirectionsWithCenter(),
          heights: HeightConfig.threeLevels(),
        );
      case LocationTemplateType.numbering:
        return LocationTemplate.numbering(
          config: const IndexConfig(totalSlots: 3),
        );
      case LocationTemplateType.grid:
        return LocationTemplate.grid(
          config: const GridConfig(rows: 3, cols: 3),
        );
      case LocationTemplateType.stack:
        return LocationTemplate.stack(config: const StackConfig(levels: 3));
      case LocationTemplateType.none:
        return LocationTemplate.none();
    }
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final householdId = ref.read(householdProvider).currentHousehold?.id;
      if (householdId == null) {
        _showError('请先加入家庭');
        return;
      }

      // 计算 positionInParent 和 positionDescription
      Map<String, dynamic>? positionInParent;
      String? positionDescription;

      if (showParentSlotSelector && _parentSlotPosition != null) {
        positionInParent = _parentSlotPosition;
        positionDescription = fullPositionDescription;
      }

      final newLocation = ItemLocation(
        id: widget.location?.id ?? '',
        householdId: householdId,
        name: _nameController.text.trim(),
        icon: _selectedIcon,
        parentId: widget.location?.parentId ?? widget.parentId,
        depth: widget.location?.depth ?? (widget.parentId != null ? 1 : 0),
        // path 字段：创建时设为 null，让数据库或应用层计算
        path: widget.location?.path,
        templateType: _selectedTemplateType,
        templateConfig: _selectedTemplate?.toConfigJson(),
        positionInParent: positionInParent,
        positionDescription: positionDescription,
        createdAt: widget.location?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isEditing) {
        await ref.read(locationsProvider.notifier).updateLocation(newLocation);
      } else {
        await ref.read(locationsProvider.notifier).createLocation(newLocation);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('保存失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  static const List<String> _iconOptions = [
    '📍',
    '🛋️',
    '📺',
    '🛏️',
    '🚪',
    '🗄️',
    '🍳',
    '🧊',
    '🚿',
    '📚',
    '🧸',
    '⚽',
    '🔧',
    '💊',
    '🧴',
    '🔑',
    '👔',
    '🎮',
    '📦',
    '🌿',
    '🪴',
    '🧺',
    '🧹',
    '🪑',
    '🛁',
    '🚽',
    '🧱',
    '🏠',
    '🚗',
    '🛵',
  ];
}
