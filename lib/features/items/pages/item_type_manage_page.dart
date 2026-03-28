import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/item_type_config.dart';
import '../../../data/repositories/item_repository.dart';
import '../../household/providers/household_provider.dart';
import '../providers/offline_item_types_provider.dart';

class ItemTypeManagePage extends ConsumerStatefulWidget {
  const ItemTypeManagePage({super.key});

  @override
  ConsumerState<ItemTypeManagePage> createState() => _ItemTypeManagePageState();
}

class _ItemTypeManagePageState extends ConsumerState<ItemTypeManagePage> {
  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(allItemTypesProvider);
    final householdState = ref.watch(householdProvider);
    final theme = Theme.of(context);

    if (householdState.currentHousehold == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('类型管理')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('请先加入或创建家庭'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/join-household'),
                child: const Text('创建/加入家庭'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('类型管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: householdState.currentHousehold == null
                ? null
                : () => _showAddEditDialog(context, null),
          ),
        ],
      ),
      body: householdState.currentHousehold == null
          ? _buildEmptyState()
          : typesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (types) {
                // 分离预设类型和自定义类型
                final presetTypes = types.where((t) => t.isPreset).toList();
                final customTypes = types.where((t) => !t.isPreset).toList();

                // 按 sort_order 排序
                presetTypes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                customTypes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

                if (types.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allItemTypesProvider);
                  ref.invalidate(itemTypesProvider);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 系统预设类型
                      _buildSectionHeader('🏷️ 系统预设', '${presetTypes.length}种'),
                      const SizedBox(height: 12),
                      _buildTypeGrid(presetTypes, isPreset: true),
                      const SizedBox(height: 24),

                      // 自定义类型
                      _buildSectionHeader('✨ 自定义类型', '${customTypes.length}种'),
                      const SizedBox(height: 12),
                      if (customTypes.isEmpty)
                        _buildEmptyCustomTypes()
                      else
                        _buildTypeGrid(customTypes, isPreset: false),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('还没有类型数据', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(
            '请点击右上角添加或联系管理员初始化',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCustomTypes() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.add_circle_outline, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('暂无自定义类型', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showAddEditDialog(context, null),
            icon: const Icon(Icons.add),
            label: const Text('添加自定义类型'),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeGrid(List<ItemTypeConfig> types, {required bool isPreset}) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: types
          .asMap()
          .entries
          .map(
            (entry) => _buildTypeCard(
              entry.value,
              index: entry.key,
              isPreset: isPreset,
            ),
          )
          .toList(),
    );
  }

  Widget _buildTypeCard(
    ItemTypeConfig type, {
    required int index,
    required bool isPreset,
  }) {
    final color = _parseColor(type.color);

    return GestureDetector(
      onTap: isPreset ? null : () => _showAddEditDialog(context, type),
      onLongPress: isPreset ? null : () => _showTypeMenu(context, type),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: type.isActive ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: type.isActive
                ? color.withValues(alpha: 0.5)
                : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: type.isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              type.icon,
              style: TextStyle(
                fontSize: 28,
                color: type.isActive ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type.typeLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: type.isActive ? Colors.black87 : Colors.grey,
                decoration: type.isActive ? null : TextDecoration.lineThrough,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!type.isActive) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '已停用',
                  style: TextStyle(fontSize: 8, color: Colors.grey),
                ),
              ),
            ],
            if (isPreset) ...[
              const SizedBox(height: 4),
              Icon(Icons.lock_outline, size: 12, color: Colors.grey.shade400),
            ],
          ],
        ),
      ),
    ).animate().scale(
      begin: const Offset(0.8, 0.8),
      end: const Offset(1, 1),
      delay: Duration(milliseconds: 50 * index),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryGold;
    }
  }

  void _showTypeMenu(BuildContext context, ItemTypeConfig type) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(type.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(
                    type.typeLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑类型'),
              onTap: () {
                Navigator.pop(context);
                _showAddEditDialog(context, type);
              },
            ),
            ListTile(
              leading: Icon(type.isActive ? Icons.pause : Icons.play_arrow),
              title: Text(type.isActive ? '停用类型' : '启用类型'),
              subtitle: Text(type.isActive ? '停用后新建物品不可选' : '启用后可正常使用'),
              onTap: () {
                Navigator.pop(context);
                _toggleTypeActive(type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除类型', style: TextStyle(color: Colors.red)),
              subtitle: const Text('同时删除所有关联数据'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, type);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, ItemTypeConfig? type) {
    final nameController = TextEditingController(text: type?.typeLabel ?? '');
    String selectedIcon = type?.icon ?? '📦';
    String selectedColor = type?.color ?? '#2196F3';
    bool isEditing = type != null;

    // 预设图标
    final icons = [
      '📦',
      '🎮',
      '🔌',
      '👕',
      '🛋️',
      '🍽️',
      '🔧',
      '🖼️',
      '🧴',
      '📚',
      '💊',
      '⚽',
      '🎸',
      '🎻',
      '🎧',
      '📷',
      '🌸',
      '🍀',
      '🎁',
      '🪴',
      '🧸',
      '📻',
      '🔦',
      '🪑',
      '🚗',
      '🧺',
      '🧻',
      '📎',
      '✏️',
      '🎒',
      '👓',
      '💍',
      '🐕',
      '🌱',
      '🪴',
    ];

    // 预设颜色
    final colors = [
      '#F44336',
      '#E91E63',
      '#9C27B0',
      '#673AB7',
      '#3F51B5',
      '#2196F3',
      '#00BCD4',
      '#009688',
      '#4CAF50',
      '#8BC34A',
      '#CDDC39',
      '#FFEB3B',
      '#FFC107',
      '#FF9800',
      '#FF5722',
      '#795548',
      '#9E9E9E',
      '#607D8B',
      '#455A64',
      '#000000',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '编辑自定义类型' : '添加自定义类型'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 类型名称
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '类型名称',
                    hintText: '例如：乐器、花卉',
                  ),
                  autofocus: true,
                  maxLength: 20,
                ),
                const SizedBox(height: 16),

                // 选择图标
                const Text(
                  '选择图标',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: icons.map((icon) {
                    final isSelected = selectedIcon == icon;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = icon),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryGold.withValues(alpha: 0.2)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color: AppTheme.primaryGold,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 选择颜色
                const Text(
                  '选择颜色',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((color) {
                    final isSelected = selectedColor == color;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(color.replaceFirst('#', '0xFF')),
                          ),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('请输入类型名称')));
                  return;
                }

                final householdId = ref
                    .read(householdProvider)
                    .currentHousehold
                    ?.id;
                if (householdId == null) return;

                try {
                  final repository = ItemRepository();

                  if (isEditing) {
                    // 更新现有类型
                    final updatedType = type.copyWith(
                      typeLabel: name,
                      icon: selectedIcon,
                      color: selectedColor,
                    );
                    await repository.updateItemTypeConfig(updatedType);
                  } else {
                    // 创建新类型
                    final newType = ItemTypeConfig(
                      id: '',
                      householdId: householdId,
                      typeKey: _generateTypeKey(name),
                      typeLabel: name,
                      icon: selectedIcon,
                      color: selectedColor,
                      sortOrder: 50, // 自定义类型默认排后面
                      isActive: true,
                      createdAt: DateTime.now(),
                    );
                    await repository.createItemType(newType);
                  }

                  ref.invalidate(allItemTypesProvider);
                  ref.invalidate(itemTypesProvider);

                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
                  }
                }
              },
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  String _generateTypeKey(String name) {
    // 从名称生成 type_key
    final key = name
        .replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9]'), '')
        .toLowerCase();
    return 'custom_${key.isEmpty ? 'type' : key}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _toggleTypeActive(ItemTypeConfig type) async {
    try {
      final repository = ItemRepository();
      if (type.isActive) {
        await repository.deactivateItemType(type.id);
      } else {
        // 重新启用
        final updatedType = type.copyWith(isActive: true);
        await repository.updateItemTypeConfig(updatedType);
      }
      ref.invalidate(allItemTypesProvider);
                  ref.invalidate(itemTypesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  void _showDeleteDialog(BuildContext context, ItemTypeConfig type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除类型'),
        content: Text('确定要删除「${type.typeLabel}」吗？\n\n注意：这将同时删除所有使用此类型的物品数据！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteType(type);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteType(ItemTypeConfig type) async {
    try {
      final repository = ItemRepository();
      await repository.deleteItemType(type.id);
      ref.invalidate(allItemTypesProvider);
                  ref.invalidate(itemTypesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }
}
