import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../data/models/item_tag.dart';
import '../../household/providers/household_provider.dart';
import '../providers/tags_provider.dart';

/// 标签分类配置 Provider
class TagCategoriesState {
  final Map<String, String> categoryLabels; // category -> label
  final Map<String, String> categoryIcons; // category -> icon

  const TagCategoriesState({
    this.categoryLabels = const {},
    this.categoryIcons = const {},
  });

  TagCategoriesState copyWith({
    Map<String, String>? categoryLabels,
    Map<String, String>? categoryIcons,
  }) {
    return TagCategoriesState(
      categoryLabels: categoryLabels ?? this.categoryLabels,
      categoryIcons: categoryIcons ?? this.categoryIcons,
    );
  }

  String getLabel(String category) {
    return categoryLabels[category] ?? _defaultLabels[category] ?? category;
  }

  String getIcon(String category) {
    return categoryIcons[category] ?? _defaultIcons[category] ?? '🏷️';
  }

  static const Map<String, String> _defaultLabels = {
    'season': '季节',
    'color': '颜色',
    'status': '状态',
    'warranty': '保修',
    'ownership': '归属',
    'storage': '存放方式',
    'frequency': '使用频率',
    'value': '价值',
    'source': '来源',
    'disposition': '处理意向',
    'other': '其他',
  };

  static const Map<String, String> _defaultIcons = {
    'season': '🌡️',
    'color': '🎨',
    'status': '📊',
    'warranty': '🔧',
    'ownership': '👥',
    'storage': '📦',
    'frequency': '⏰',
    'value': '💰',
    'source': '🎁',
    'disposition': '🗑️',
    'other': '🏷️',
  };

  static const List<String> defaultCategories = [
    'season',
    'color',
    'status',
    'warranty',
    'ownership',
    'storage',
    'frequency',
    'value',
    'source',
    'disposition',
    'other',
  ];
}

final tagCategoriesProvider = StateProvider<TagCategoriesState>((ref) {
  return const TagCategoriesState();
});

class ItemTagsPage extends ConsumerStatefulWidget {
  const ItemTagsPage({super.key});

  @override
  ConsumerState<ItemTagsPage> createState() => _ItemTagsPageState();
}

class _ItemTagsPageState extends ConsumerState<ItemTagsPage> {
  final _searchController = TextEditingController();

  // 物品类型选项
  static const Map<String, String> _typeLabels = {
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsState = ref.watch(tagsProvider);
    final householdState = ref.watch(householdProvider);

    if (householdState.currentHousehold == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('标签管理')),
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

    // 过滤标签
    final searchQuery = _searchController.text.toLowerCase();
    final filteredTags = tagsState.tags.where((tag) {
      if (searchQuery.isEmpty) return true;
      return tag.name.toLowerCase().contains(searchQuery);
    }).toList();

    // 按分类分组
    final tagsByCategory = <String, List<ItemTag>>{};
    for (final tag in filteredTags) {
      tagsByCategory.putIfAbsent(tag.category, () => []).add(tag);
    }

    final categoriesState = ref.watch(tagCategoriesProvider);
    final categoryOrder = TagCategoriesState.defaultCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showCategorySettings(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(context, null),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索标签...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // 标签列表
          Expanded(
            child: tagsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : tagsState.tags.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => ref.read(tagsProvider.notifier).refresh(),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final category in categoryOrder)
                          if (tagsByCategory[category]?.isNotEmpty ?? false)
                            _buildCategorySection(
                              category,
                              tagsByCategory[category]!,
                            ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.label_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty ? '没有找到匹配的标签' : '还没有创建标签',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          if (_searchController.text.isEmpty)
            TextButton.icon(
              onPressed: () => _showAddEditDialog(context, null),
              icon: const Icon(Icons.add),
              label: const Text('添加标签'),
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category, List<ItemTag> tags) {
    final categoriesState = ref.watch(tagCategoriesProvider);
    final categoryLabel = categoriesState.getLabel(category);
    final categoryIcon = categoriesState.getIcon(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(categoryIcon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                categoryLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tags.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) => _buildTagChip(tag)).toList(),
        ),
        const SizedBox(height: 16),
      ],
    ).animate().fadeIn();
  }

  Widget _buildTagChip(ItemTag tag) {
    final color = _parseColor(tag.color);

    return GestureDetector(
      onLongPress: () => _showTagMenu(context, tag),
      child: Chip(
        label: Text(tag.name),
        avatar: tag.icon != null ? Text(tag.icon!) : null,
        backgroundColor: color.withValues(alpha: 0.2),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: () => _showDeleteDialog(context, tag),
      ),
    ).animate().scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }

  Color _parseColor(String colorStr) {
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  /// 显示分类设置对话框
  void _showCategorySettings(BuildContext context) {
    final categoriesState = ref.read(tagCategoriesProvider);
    final labels = <String, TextEditingController>{};
    final icons = <String, TextEditingController>{};

    for (final c in TagCategoriesState.defaultCategories) {
      labels[c] = TextEditingController(
        text:
            categoriesState.categoryLabels[c] ??
            TagCategoriesState._defaultLabels[c] ??
            c,
      );
      icons[c] = TextEditingController(
        text:
            categoriesState.categoryIcons[c] ??
            TagCategoriesState._defaultIcons[c] ??
            '🏷️',
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置分类名称'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final cat in TagCategoriesState.defaultCategories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: TextField(
                          controller: icons[cat],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: labels[cat],
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: cat,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                '可用的emoji图标: 🌡️ 🎨 📊 🔧 🏷️ 📦 🔌 🛋️ 👕 🍽️ 🔧 📚 🖼️ ⚽ 🎮 💊 🧴',
                style: TextStyle(fontSize: 10),
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
            onPressed: () {
              ref
                  .read(tagCategoriesProvider.notifier)
                  .state = TagCategoriesState(
                categoryLabels: {
                  for (final c in TagCategoriesState.defaultCategories)
                    c: labels[c]!.text.trim().isEmpty
                        ? c
                        : labels[c]!.text.trim(),
                },
                categoryIcons: {
                  for (final c in TagCategoriesState.defaultCategories)
                    c: icons[c]!.text.trim().isEmpty
                        ? '🏷️'
                        : icons[c]!.text.trim(),
                },
              );
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, ItemTag? tag) {
    final nameController = TextEditingController(text: tag?.name ?? '');
    String selectedCategory = tag?.category ?? 'other';
    String selectedColor = tag?.color ?? '#6B7280';
    List<String> selectedTypes = List<String>.from(tag?.applicableTypes ?? []);

    // 预置颜色
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
      '#000000',
      '#FFFFFF',
    ];

    final categoriesState = ref.watch(tagCategoriesProvider);
    final categoryOrder = TagCategoriesState.defaultCategories;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tag != null ? '编辑标签' : '添加标签'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '标签名称',
                    hintText: '例如：春装、深色、需要维修',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),

                // 分类选择
                const Text(
                  '选择分类',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: categoryOrder.map((cat) {
                    final isSelected = selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(
                        '${categoriesState.getIcon(cat)} ${categoriesState.getLabel(cat)}',
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedCategory = cat);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 适用物品类型选择
                const Text(
                  '适用物品类型（可选）',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                const Text(
                  '不选择则适用于所有类型',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _typeLabels.entries.map((entry) {
                    final isSelected = selectedTypes.contains(entry.key);
                    return FilterChip(
                      label: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            selectedTypes.add(entry.key);
                          } else {
                            selectedTypes.remove(entry.key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 颜色选择
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
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(color.replaceFirst('#', '0xFF')),
                          ),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
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
                  ).showSnackBar(const SnackBar(content: Text('请输入标签名称')));
                  return;
                }

                final householdId = ref
                    .read(householdProvider)
                    .currentHousehold
                    ?.id;
                if (householdId == null) return;

                final newTag = ItemTag(
                  id: tag?.id ?? '',
                  householdId: householdId,
                  name: name,
                  color: selectedColor,
                  category: selectedCategory,
                  applicableTypes: selectedTypes,
                  createdAt: tag?.createdAt ?? DateTime.now(),
                );

                if (tag != null) {
                  await ref.read(tagsProvider.notifier).updateTag(newTag);
                } else {
                  await ref.read(tagsProvider.notifier).createTag(newTag);
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: Text(tag != null ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTagMenu(BuildContext context, ItemTag tag) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(context);
                _showAddEditDialog(context, tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, tag);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ItemTag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定要删除「${tag.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(tagsProvider.notifier).deleteTag(tag.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
