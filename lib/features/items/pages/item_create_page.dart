import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/household_item.dart';
import '../../../data/models/item_location.dart';
import '../../../data/models/item_type_config.dart';
import '../../../data/models/item_tag.dart';
import '../../../data/models/member.dart';
import '../../../data/services/location_path_service.dart';
import '../../household/providers/household_provider.dart';
import '../providers/items_provider.dart';
import '../providers/item_types_provider.dart';
import '../providers/locations_provider.dart';
import '../providers/tags_provider.dart';
import '../widgets/slot_picker_dialog.dart';
import 'item_detail_page.dart';

class ItemCreatePage extends ConsumerStatefulWidget {
  final String? itemId;

  const ItemCreatePage({super.key, this.itemId});

  @override
  ConsumerState<ItemCreatePage> createState() => _ItemCreatePageState();
}

class _ItemCreatePageState extends ConsumerState<ItemCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'other';
  String? _selectedLocationId;
  String? _selectedOwnerId;
  Map<String, dynamic>? _selectedSlotPosition;
  ItemCondition _selectedCondition = ItemCondition.good;
  DateTime? _purchaseDate;
  DateTime? _warrantyExpiry;
  bool _isLoading = false;
  HouseholdItem? _originalItem;
  final Set<String> _selectedTagIds = {};

  bool get isEditMode => widget.itemId != null;

  // 预置品牌映射
  static const Map<String, List<String>> _typeBrands = {
    'appliance': [
      '小米',
      '美的',
      '海尔',
      '格力',
      'TCL',
      '华为',
      '苹果',
      '戴森',
      '西门子',
      '松下',
      '索尼',
      '三星',
      'LG',
      '博世',
      '飞利浦',
    ],
    'furniture': [
      '宜家',
      '顾家',
      '曲美',
      '索菲亚',
      '全友',
      '林氏木业',
      '芝华仕',
      '慕思',
      '喜临门',
      '雅兰',
      '舒达',
      '金可儿',
    ],
    'clothing': [
      '优衣库',
      'H&M',
      'Zara',
      'GAP',
      'Adidas',
      'Nike',
      '波司登',
      '海澜之家',
      '七匹狼',
      '杉杉',
      '罗蒙',
      'GXG',
    ],
    'tableware': [
      '康宁',
      '双立人',
      'WMF',
      '菲仕乐',
      '苏泊尔',
      '爱仕达',
      '炊大皇',
      '美的',
      '九阳',
      '小熊',
    ],
    'tool': [
      '博世',
      '史丹利',
      '世达',
      '得力',
      '田岛',
      'Stanley',
      'Milwaukee',
      '牧田',
      '东成',
      '大有',
    ],
    'book': [
      '中信出版社',
      '人民邮电出版社',
      '机械工业出版社',
      '电子工业出版社',
      '清华大学出版社',
      '北京大学出版社',
      '三联书店',
      '商务印书馆',
    ],
    'decoration': [
      'IKEA',
      '宜家',
      'HAY',
      'Muuto',
      'ferm living',
      '术木',
      '吱音',
      '失物招领',
    ],
    'sports': [
      'Nike',
      'Adidas',
      'Puma',
      'Under Armour',
      'Keep',
      '舒华',
      '亿健',
      '岱宇',
      '乔山',
      '必确',
    ],
    'toy': ['乐高', '孩之宝', '美泰', '万代', '高达', '变形金刚', '芭比', '费雪', '伟易达', '贝恩施'],
    'medicine': [
      '云南白药',
      '同仁堂',
      '九芝堂',
      '999',
      '汤臣倍健',
      '修正',
      '芬必得',
      '白敬亭',
      '江中',
      '葵花',
    ],
    'daily': [
      '蓝月亮',
      '立白',
      '威露士',
      '多芬',
      '海飞丝',
      '飘柔',
      '舒肤佳',
      '高露洁',
      '佳洁士',
      'Oral-B',
    ],
  };

  List<String> get _availableBrands {
    return _typeBrands[_selectedType] ?? [];
  }

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _loadItem();
    }
  }

  Future<void> _loadItem() async {
    final itemsState = ref.read(itemsProvider);
    final item = itemsState.items
        .where((i) => i.id == widget.itemId)
        .firstOrNull;
    if (item != null) {
      // 加载物品的标签
      final tagIds = item.tags.map((t) => t.id).toSet();

      setState(() {
        _originalItem = item;
        _nameController.text = item.name;
        _descriptionController.text = item.description ?? '';
        _brandController.text = item.brand ?? '';
        _modelController.text = item.model ?? '';
        _quantityController.text = item.quantity.toString();
        _priceController.text = item.purchasePrice?.toString() ?? '';
        _notesController.text = item.notes ?? '';
        _selectedType = item.itemType;
        _selectedLocationId = item.locationId;
        _selectedOwnerId = item.ownerId;
        _selectedSlotPosition = item.slotPosition;
        _selectedCondition = item.condition;
        _purchaseDate = item.purchaseDate;
        _warrantyExpiry = item.warrantyExpiry;
        _selectedTagIds.addAll(tagIds);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final householdState = ref.read(householdProvider);
      final householdId = householdState.currentHousehold?.id;
      if (householdId == null) {
        _showError('请先加入家庭');
        return;
      }

      final item = HouseholdItem(
        id: _originalItem?.id ?? '',
        householdId: householdId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        itemType: _selectedType,
        locationId: _selectedLocationId,
        ownerId: _selectedOwnerId,
        quantity: int.tryParse(_quantityController.text) ?? 1,
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        model: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        purchaseDate: _purchaseDate,
        purchasePrice: double.tryParse(_priceController.text),
        warrantyExpiry: _warrantyExpiry,
        condition: _selectedCondition,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        syncStatus: SyncStatus.pending,
        createdAt: _originalItem?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        slotPosition: _selectedSlotPosition,
      );

      if (isEditMode) {
        await ref
            .read(itemsProvider.notifier)
            .updateItem(item, tagIds: _selectedTagIds.toList());
      } else {
        await ref
            .read(itemsProvider.notifier)
            .createItem(item, tagIds: _selectedTagIds.toList());
      }

      // 刷新物品详情页面
      if (isEditMode) {
        ref.invalidate(itemDetailProvider(item.id));
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      _showError('保存失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(itemTypesProvider);
    final locationsState = ref.watch(locationsProvider);
    final tagsState = ref.watch(tagsProvider);
    final householdState = ref.watch(householdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? '编辑物品' : '添加物品'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '保存',
                    style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 名称
            _buildSectionTitle('名称', required: true),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('请输入物品名称'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入物品名称';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            // 类型
            _buildSectionTitle('类型', required: true),
            _buildTypeSelector(typesAsync),
            const SizedBox(height: 24),

            // 位置
            _buildSectionTitle('位置'),
            _buildLocationSelector(locationsState),
            const SizedBox(height: 24),

            // 归属人
            _buildSectionTitle('归属人'),
            _buildOwnerSelector(householdState),
            const SizedBox(height: 24),

            // 品牌（带自动完成）
            _buildSectionTitle('品牌'),
            _buildBrandAutocomplete(),
            const SizedBox(height: 24),

            // 型号
            _buildSectionTitle('型号'),
            TextFormField(
              controller: _modelController,
              decoration: _inputDecoration('请输入型号（可选）'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            // 数量
            _buildSectionTitle('数量'),
            _buildQuantitySelector(),
            const SizedBox(height: 24),

            // 状态
            _buildSectionTitle('状态'),
            _buildConditionSelector(),
            const SizedBox(height: 24),

            // 购买日期
            _buildSectionTitle('购买日期'),
            _buildDatePicker(
              date: _purchaseDate,
              hint: '选择购买日期',
              onChanged: (date) => setState(() => _purchaseDate = date),
            ),
            const SizedBox(height: 24),

            // 购买价格
            _buildSectionTitle('购买价格'),
            TextFormField(
              controller: _priceController,
              decoration: _inputDecoration('请输入购买价格（可选）', prefix: '¥ '),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            // 保修到期
            _buildSectionTitle('保修到期'),
            _buildDatePicker(
              date: _warrantyExpiry,
              hint: '选择保修到期日期',
              onChanged: (date) => setState(() => _warrantyExpiry = date),
            ),
            const SizedBox(height: 24),

            // 备注
            _buildSectionTitle('备注'),
            TextFormField(
              controller: _notesController,
              decoration: _inputDecoration('请输入备注（可选）'),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),

            // 标签选择
            _buildSectionTitle('标签'),
            _buildTagSelector(tagsState),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (required)
            const Text(' *', style: TextStyle(color: Colors.red, fontSize: 14)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {String? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTypeSelector(AsyncValue<List<ItemTypeConfig>> typesAsync) {
    return typesAsync.when(
      loading: () => const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildDropdown<String>(
        value: _selectedType,
        items: const [
          DropdownMenuItem(value: 'clothing', child: Text('👕 衣物')),
          DropdownMenuItem(value: 'appliance', child: Text('🔌 家电')),
          DropdownMenuItem(value: 'furniture', child: Text('🛋️ 家具')),
          DropdownMenuItem(value: 'daily', child: Text('🧴 日用品')),
          DropdownMenuItem(value: 'tableware', child: Text('🍽️ 餐具')),
          DropdownMenuItem(value: 'food', child: Text('🥫 食品调料')),
          DropdownMenuItem(value: 'bedding', child: Text('🛏️ 床上用品')),
          DropdownMenuItem(value: 'electronics', child: Text('📱 电子数码')),
          DropdownMenuItem(value: 'book', child: Text('📚 书籍')),
          DropdownMenuItem(value: 'decoration', child: Text('🖼️ 装饰品')),
          DropdownMenuItem(value: 'tool', child: Text('🔧 工具')),
          DropdownMenuItem(value: 'medicine', child: Text('💊 药品')),
          DropdownMenuItem(value: 'sports', child: Text('⚽ 运动器材')),
          DropdownMenuItem(value: 'toy', child: Text('🎮 玩具')),
          DropdownMenuItem(value: 'jewelry', child: Text('💍 珠宝首饰')),
          DropdownMenuItem(value: 'pet', child: Text('🐕 宠物用品')),
          DropdownMenuItem(value: 'garden', child: Text('🌱 园艺绿植')),
          DropdownMenuItem(value: 'automotive', child: Text('🚗 车载物品')),
          DropdownMenuItem(value: 'stationery', child: Text('📎 文具办公')),
          DropdownMenuItem(value: 'consumables', child: Text('🧻 消耗品')),
          DropdownMenuItem(value: 'other', child: Text('📦 其他')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedType = value;
              _brandController.clear();
            });
          }
        },
      ),
      data: (types) {
        // 合并预设类型和数据库类型
        final allTypes = <DropdownMenuItem<String>>[];
        for (final type in types) {
          allTypes.add(
            DropdownMenuItem(
              value: type.typeKey,
              child: Text('${type.icon} ${type.typeLabel}'),
            ),
          );
        }
        // 如果数据库没有当前选中的类型，添加进去
        if (!allTypes.any((t) => t.value == _selectedType)) {
          allTypes.insert(
            0,
            DropdownMenuItem(
              value: _selectedType,
              child: Text(_getTypeLabel(_selectedType)),
            ),
          );
        }
        return _buildDropdown<String>(
          value: _selectedType,
          items: allTypes,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedType = value;
                _brandController.clear();
              });
            }
          },
        );
      },
    );
  }

  String _getTypeLabel(String typeKey) {
    const labels = {
      'clothing': '👕 衣物',
      'appliance': '🔌 家电',
      'furniture': '🛋️ 家具',
      'daily': '🧴 日用品',
      'tableware': '🍽️ 餐具',
      'food': '🥫 食品调料',
      'bedding': '🛏️ 床上用品',
      'electronics': '📱 电子数码',
      'book': '📚 书籍',
      'decoration': '🖼️ 装饰品',
      'tool': '🔧 工具',
      'medicine': '💊 药品',
      'sports': '⚽ 运动器材',
      'toy': '🎮 玩具',
      'jewelry': '💍 珠宝首饰',
      'pet': '🐕 宠物用品',
      'garden': '🌱 园艺绿植',
      'automotive': '🚗 车载物品',
      'stationery': '📎 文具办公',
      'consumables': '🧻 消耗品',
      'other': '📦 其他',
    };
    return labels[typeKey] ?? '📦 其他';
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        underline: const SizedBox(),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildLocationSelector(LocationsState locationsState) {
    final locations = locationsState.locations;

    // 获取选中的位置信息
    ItemLocation? selectedLocation;
    if (_selectedLocationId != null) {
      selectedLocation = locations.firstWhere(
        (l) => l.id == _selectedLocationId,
        orElse: () => locations.first,
      );
    }

    return InkWell(
      onTap: () => _openSlotPicker(locations),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: locations.isEmpty
            ? Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '暂无位置，请先在位置管理中添加',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              )
            : Row(
                children: [
                  if (selectedLocation != null) ...[
                    Text(
                      selectedLocation.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedLocation.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_selectedSlotPosition != null)
                            Text(
                              LocationPathService.formatSlotForDisplaySimple(
                                _selectedSlotPosition!,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryGold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.location_on_outlined,
                      color: Colors.grey.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '点击选择位置和槽位',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
      ),
    );
  }

  Future<void> _openSlotPicker(List<ItemLocation> locations) async {
    if (locations.isEmpty) {
      // 如果没有位置，提示用户先创建位置
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先在位置管理中添加位置'),
          action: SnackBarAction(
            label: '去添加',
            onPressed: () => context.push('/home/items/locations'),
          ),
        ),
      );
      return;
    }

    final result = await SlotPickerDialog.show(
      context,
      locations: locations,
      initialLocationId: _selectedLocationId,
      initialSlotPosition: _selectedSlotPosition,
    );

    if (result != null) {
      setState(() {
        _selectedLocationId = result.key;
        _selectedSlotPosition = result.value;
      });
    }
  }

  Widget _buildOwnerSelector(HouseholdState householdState) {
    final members = householdState.members;

    if (members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '暂无家庭成员，请先添加成员',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('不选择归属人')),
      ...members.map(
        (member) => DropdownMenuItem(
          value: member.id,
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                backgroundImage: member.avatarUrl != null
                    ? NetworkImage(member.avatarUrl!)
                    : null,
                child: member.avatarUrl == null
                    ? Text(
                        member.name.isNotEmpty ? member.name[0] : '?',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryGold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(member.name),
            ],
          ),
        ),
      ),
    ];

    return _buildDropdown<String?>(
      value: _selectedOwnerId,
      items: items,
      onChanged: (value) => setState(() => _selectedOwnerId = value),
    );
  }

  Widget _buildBrandAutocomplete() {
    final brands = _availableBrands;

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _brandController.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return brands.take(10);
        }
        return brands.where((brand) => brand.contains(textEditingValue.text));
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        // 同步控制器
        if (controller.text != _brandController.text) {
          controller.text = _brandController.text;
        }
        controller.addListener(() {
          _brandController.text = controller.text;
        });
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: _inputDecoration('输入或选择品牌（可选）'),
          textInputAction: TextInputAction.next,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: MediaQuery.of(context).size.width - 32,
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (selection) {
        _brandController.text = selection;
      },
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final current = int.tryParse(_quantityController.text) ?? 1;
              if (current > 1) {
                setState(
                  () => _quantityController.text = (current - 1).toString(),
                );
              }
            },
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Expanded(
            child: TextFormField(
              controller: _quantityController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                final num = int.tryParse(value);
                if (num != null && num < 1) {
                  _quantityController.text = '1';
                }
              },
            ),
          ),
          IconButton(
            onPressed: () {
              final current = int.tryParse(_quantityController.text) ?? 1;
              setState(
                () => _quantityController.text = (current + 1).toString(),
              );
            },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionSelector() {
    return _buildDropdown<ItemCondition>(
      value: _selectedCondition,
      items: ItemCondition.values
          .map(
            (c) =>
                DropdownMenuItem(value: c, child: Text(_getConditionLabel(c))),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCondition = value);
        }
      },
    );
  }

  String _getConditionLabel(ItemCondition condition) {
    const labels = {
      ItemCondition.new_: '🆕 全新',
      ItemCondition.good: '✅ 正常使用',
      ItemCondition.fair: '⚠️ 有些磨损',
      ItemCondition.poor: '❌ 需要维修',
    };
    return labels[condition] ?? '正常使用';
  }

  Widget _buildDatePicker({
    required DateTime? date,
    required String hint,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        onChanged(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Text(
              date != null
                  ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                  : hint,
              style: TextStyle(
                color: date != null ? Colors.black : Colors.grey.shade600,
              ),
            ),
            const Spacer(),
            if (date != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () => onChanged(null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagSelector(TagsState tagsState) {
    final tags = tagsState.tags;

    if (tags.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '暂无标签，请先在标签管理中添加',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/home/items/tags'),
              child: const Text('去添加'),
            ),
          ],
        ),
      );
    }

    // 分类标签映射
    final categoryLabels = {
      'season': '🌡️ 季节',
      'color': '🎨 颜色',
      'status': '📊 状态',
      'warranty': '🔧 保修',
      'ownership': '👥 归属',
      'storage': '📦 存放方式',
      'frequency': '⏰ 使用频率',
      'value': '💰 价值',
      'source': '🎁 来源',
      'disposition': '🗑️ 处理意向',
      'other': '🏷️ 其他',
    };

    // 按类别分组，同时按类型相关性排序
    final groupedTags = <String, List<ItemTag>>{};
    for (final tag in tags) {
      final category = tag.category;
      groupedTags.putIfAbsent(category, () => []).add(tag);
    }

    // 对每个分类内的标签按类型相关性排序（相关的排在前面）
    for (final category in groupedTags.keys) {
      final categoryTagList = groupedTags[category]!;
      categoryTagList.sort((a, b) {
        final aApplies = a.isApplicableTo(_selectedType);
        final bApplies = b.isApplicableTo(_selectedType);
        if (aApplies && !bApplies) return -1;
        if (!aApplies && bApplies) return 1;
        return 0;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedTags.entries.map((entry) {
        final category = entry.key;
        final categoryTags = entry.value;

        // 检查该分类是否有适用的标签
        final hasRelevantTags = categoryTags.any(
          (t) => t.isApplicableTo(_selectedType),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    categoryLabels[category] ?? '🏷️ ${category}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (hasRelevantTags && category != 'other')
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '适用',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryTags.map((tag) {
                  final isSelected = _selectedTagIds.contains(tag.id);
                  final isApplicable = tag.isApplicableTo(_selectedType);

                  return FilterChip(
                    label: Text(
                      tag.icon != null ? '${tag.icon} ${tag.name}' : tag.name,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isApplicable ? Colors.black87 : Colors.grey),
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: isApplicable || isSelected
                        ? (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTagIds.add(tag.id);
                              } else {
                                _selectedTagIds.remove(tag.id);
                              }
                            });
                          }
                        : null,
                    backgroundColor: isApplicable
                        ? Colors.grey.shade100
                        : Colors.grey.shade200,
                    selectedColor: _parseColor(tag.color),
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? _parseColor(tag.color)
                          : (isApplicable
                                ? Colors.transparent
                                : Colors.grey.shade300),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      final hex = colorStr.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}
