import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/ai/batch_add_service.dart';
import '../../../data/ai/ai_settings_service.dart';
import '../../../data/models/household_item.dart';
import '../../../data/models/item_location.dart';
import '../../household/providers/household_provider.dart';
import '../providers/locations_provider.dart';
import '../providers/offline_item_stats_provider.dart';
import '../providers/offline_items_provider.dart';
import '../providers/paginated_items_provider.dart';
import '../widgets/slot_picker_dialog.dart';

/// 批量录入页面状态
enum BatchAddStep {
  selectLocation, // 选择位置
  inputItems, // 输入物品
  preview, // 预览确认
}

class BatchAddPage extends ConsumerStatefulWidget {
  const BatchAddPage({super.key});

  @override
  ConsumerState<BatchAddPage> createState() => _BatchAddPageState();
}

class _BatchAddPageState extends ConsumerState<BatchAddPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  BatchAddStep _currentStep = BatchAddStep.selectLocation;
  ItemLocation? _selectedLocation;
  BatchParseResult? _parseResult;
  List<BatchItem> _editableItems = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('批量录入物品'), centerTitle: true),
      body: _buildCurrentStep(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case BatchAddStep.selectLocation:
        return _buildLocationSelector();
      case BatchAddStep.inputItems:
        return _buildInputStep();
      case BatchAddStep.preview:
        return _buildPreviewStep();
    }
  }

  // ========== 步骤1：选择位置 ==========
  Widget _buildLocationSelector() {
    final locationsState = ref.watch(locationsProvider);

    if (locationsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (locationsState.errorMessage != null) {
      return Center(child: Text('加载位置失败: ${locationsState.errorMessage}'));
    }

    final locations = locationsState.locations;
    final rootLocations = locationsState.rootLocations;

    if (rootLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '还没有创建位置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('请先在位置管理中添加位置', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/home/items/locations'),
              icon: const Icon(Icons.add),
              label: const Text('添加位置'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '选择要录入物品的位置',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          '选择后，物品将全部录入到这个位置',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ...rootLocations.map(
          (location) => _buildLocationTile(location, locations, 0),
        ),
      ],
    );
  }

  Widget _buildLocationTile(
    ItemLocation location,
    List<ItemLocation> allLocations,
    int depth,
  ) {
    final children = allLocations
        .where((l) => l.parentId == location.id)
        .toList();
    final isSelected = _selectedLocation?.id == location.id;
    final hasChildren = children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _selectedLocation = location;
            });
          },
          child: Container(
            padding: EdgeInsets.only(
              left: depth * 16.0 + 12,
              top: 12,
              bottom: 12,
              right: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryGold.withValues(alpha: 0.1)
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
                      if (location.positionDescription != null)
                        Text(
                          location.positionDescription!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppTheme.primaryGold),
              ],
            ),
          ),
        ),
        if (hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: children
                  .map(
                    (child) =>
                        _buildLocationTile(child, allLocations, depth + 1),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  // ========== 步骤2：输入物品 ==========
  Widget _buildInputStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      controller: _scrollController,
      children: [
        // 已选位置
        _buildSelectedLocationCard(),
        const SizedBox(height: 16),
        // 输入区域
        _buildInputCard(),
        const SizedBox(height: 16),
        // 错误信息
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedLocationCard() {
    return Card(
      color: AppTheme.primaryGold.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: AppTheme.primaryGold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '录入位置',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${_selectedLocation!.icon} ${_selectedLocation!.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = BatchAddStep.selectLocation;
                });
              },
              child: const Text('更换'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '输入物品列表',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '支持逗号、顿号、换行分隔，例如：\n热水器一个，浴霸一个，洗脸盆8个',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inputController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: '请输入物品，例如：\n热水器一个，浴霸一个\n洗脸盆8个，马桶一个\n沐浴露一瓶',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _parseInput,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isLoading ? 'AI 解析中...' : 'AI 智能解析'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== 步骤3：预览确认 ==========
  Widget _buildPreviewStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 位置信息
        _buildSelectedLocationCard(),
        const SizedBox(height: 16),
        // 物品列表
        _buildItemList(),
        const SizedBox(height: 16),
        // 添加按钮
        OutlinedButton.icon(
          onPressed: _addNewItem,
          icon: const Icon(Icons.add),
          label: const Text('添加物品'),
        ),
      ],
    );
  }

  Widget _buildItemList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '识别结果',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${_editableItems.length} 种物品',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 表头
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '物品名称',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '数量',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '类型',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(width: 48), // 操作列
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 物品列表
            ...List.generate(_editableItems.length, (index) {
              return _buildItemRow(index);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _editableItems[index];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(item.name, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            flex: 1,
            child: Text(
              item.quantity.toString(),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.typeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: item.isNewType
                          ? AppTheme.primaryGold
                          : Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.isNewType)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '新',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.primaryGold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Row(
              children: [
                InkWell(
                  onTap: () => _editItem(index),
                  child: const Icon(Icons.edit, size: 18, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _removeItem(index),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== 底部按钮 ==========
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
          if (_currentStep != BatchAddStep.selectLocation)
            Expanded(
              child: OutlinedButton(
                onPressed: _goBack,
                child: const Text('上一步'),
              ),
            ),
          if (_currentStep != BatchAddStep.selectLocation)
            const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _canProceed() ? _goNext : null,
              child: Text(_getNextButtonText()),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case BatchAddStep.selectLocation:
        return _selectedLocation != null;
      case BatchAddStep.inputItems:
        return _inputController.text.trim().isNotEmpty && !_isLoading;
      case BatchAddStep.preview:
        return _editableItems.isNotEmpty && !_isLoading;
    }
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case BatchAddStep.selectLocation:
        return '下一步';
      case BatchAddStep.inputItems:
        return '开始解析';
      case BatchAddStep.preview:
        return '确认保存';
    }
  }

  void _goBack() {
    setState(() {
      switch (_currentStep) {
        case BatchAddStep.selectLocation:
          break;
        case BatchAddStep.inputItems:
          _currentStep = BatchAddStep.selectLocation;
          break;
        case BatchAddStep.preview:
          _currentStep = BatchAddStep.inputItems;
          break;
      }
    });
  }

  void _goNext() {
    switch (_currentStep) {
      case BatchAddStep.selectLocation:
        setState(() {
          _currentStep = BatchAddStep.inputItems;
        });
        break;
      case BatchAddStep.inputItems:
        _parseInput();
        break;
      case BatchAddStep.preview:
        _saveItems();
        break;
    }
  }

  // ========== 业务逻辑 ==========

  Future<void> _parseInput() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorMessage = '请输入物品列表';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = BatchAddService(AISettingsService());
      final result = await service.parseInput(input);

      setState(() {
        _parseResult = result;
        _editableItems = result.items;
        _currentStep = BatchAddStep.preview;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _addNewItem() {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        onAdd: (item) {
          setState(() {
            _editableItems.add(item);
          });
        },
      ),
    );
  }

  void _editItem(int index) {
    final item = _editableItems[index];
    showDialog(
      context: context,
      builder: (context) => _EditItemDialog(
        item: item,
        onSave: (updatedItem) {
          setState(() {
            _editableItems[index] = updatedItem;
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _editableItems.removeAt(index);
    });
  }

  Future<void> _saveItems() async {
    if (_editableItems.isEmpty || _selectedLocation == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final householdState = ref.read(householdProvider);
      final householdId = householdState.currentHousehold?.id;
      if (householdId == null) {
        throw Exception('请先加入家庭');
      }

      // 使用本地数据库写入（离线优先架构）
      final repository = ref.read(offlineItemRepositoryProvider);
      final commandService = repository.commandService;

      int successCount = 0;
      for (final item in _editableItems) {
        final householdItem = HouseholdItem(
          id: '',  // 会由 createItem 自动生成
          householdId: householdId,
          name: item.name,
          quantity: item.quantity,
          itemType: item.type,
          locationId: _selectedLocation!.id,
          condition: ItemCondition.good,
          syncStatus: SyncStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await commandService.createItem(householdItem);
        successCount++;
      }

      // 刷新物品列表（两个 provider 都需要刷新）
      await ref.read(paginatedItemsProvider.notifier).refresh();
      await ref.read(offlineItemsProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功添加 $successCount 种物品'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }
}

// ========== 添加物品对话框 ==========
class _AddItemDialog extends StatefulWidget {
  final ValueChanged<BatchItem> onAdd;

  const _AddItemDialog({required this.onAdd});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _typeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加物品'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '物品名称',
              hintText: '例如：电视机',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '数量', hintText: '1'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _typeController,
            decoration: const InputDecoration(
              labelText: '类型',
              hintText: '例如：电器',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;

            final quantity = int.tryParse(_quantityController.text) ?? 1;
            final typeLabel = _typeController.text.trim().isNotEmpty
                ? _typeController.text.trim()
                : '其他';

            widget.onAdd(
              BatchItem(
                name: name,
                quantity: quantity,
                type: 'custom',
                typeLabel: typeLabel,
                isNewType: true,
              ),
            );

            Navigator.pop(context);
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}

// ========== 编辑物品对话框 ==========
class _EditItemDialog extends StatefulWidget {
  final BatchItem item;
  final ValueChanged<BatchItem> onSave;

  const _EditItemDialog({required this.item, required this.onSave});

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _typeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _quantityController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _typeController = TextEditingController(text: widget.item.typeLabel);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑物品'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '物品名称'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '数量'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _typeController,
            decoration: const InputDecoration(labelText: '类型'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;

            final quantity =
                int.tryParse(_quantityController.text) ?? widget.item.quantity;
            final typeLabel = _typeController.text.trim().isNotEmpty
                ? _typeController.text.trim()
                : widget.item.typeLabel;

            widget.onSave(
              widget.item.copyWith(
                name: name,
                quantity: quantity,
                typeLabel: typeLabel,
              ),
            );

            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
