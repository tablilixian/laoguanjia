import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/household_item.dart';
import '../../../data/repositories/item_repository.dart';
import '../providers/items_provider.dart';
import '../providers/item_types_provider.dart';

// 用于详情页的单独物品数据提供者
final itemDetailProvider = FutureProvider.family<HouseholdItem?, String>((
  ref,
  itemId,
) async {
  final repository = ItemRepository();
  return repository.getItemById(itemId);
});

class ItemDetailPage extends ConsumerWidget {
  final String itemId;

  const ItemDetailPage({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemDetailProvider(itemId));
    final typesAsync = ref.watch(itemTypesProvider);
    final theme = Theme.of(context);

    return itemAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('物品详情'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('物品详情'), centerTitle: true),
        body: Center(child: Text('加载失败: $error')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('物品详情'), centerTitle: true),
            body: const Center(child: Text('物品不存在或已被删除')),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // AppBar with image
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: item.imageUrl != null
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildImagePlaceholder(item),
                        )
                      : _buildImagePlaceholder(item),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/home/items/$itemId/edit'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _showDeleteDialog(context, ref, item),
                  ),
                ],
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名称
                      _buildSection(
                        title: '名称',
                        child: Text(
                          item.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const Divider(height: 32),

                      // 类型和位置
                      Row(
                        children: [
                          Expanded(
                            child: _buildSection(
                              title: '类型',
                              child: typesAsync.when(
                                loading: () => const Text('加载中...'),
                                error: (_, __) =>
                                    Text(_getTypeLabel(item.itemType)),
                                data: (types) {
                                  final type = types
                                      .where((t) => t.typeKey == item.itemType)
                                      .firstOrNull;
                                  return Row(
                                    children: [
                                      Text(
                                        type?.icon ?? '📦',
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(type?.typeLabel ?? '其他'),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildSection(
                              title: '位置',
                              child:
                                  item.locationPath != null ||
                                      item.locationName != null
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.locationIcon ?? '📍',
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.locationPath ??
                                                item.locationName ??
                                                '-',
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      '-',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 品牌和型号
                      if (item.brand != null || item.model != null)
                        Row(
                          children: [
                            if (item.brand != null)
                              Expanded(
                                child: _buildSection(
                                  title: '品牌',
                                  child: Text(item.brand!),
                                ),
                              ),
                            if (item.model != null)
                              Expanded(
                                child: _buildSection(
                                  title: '型号',
                                  child: Text(item.model!),
                                ),
                              ),
                          ],
                        ),

                      if (item.brand != null || item.model != null)
                        const SizedBox(height: 24),

                      // 数量和状态
                      Row(
                        children: [
                          Expanded(
                            child: _buildSection(
                              title: '数量',
                              child: Text('${item.quantity}'),
                            ),
                          ),
                          Expanded(
                            child: _buildSection(
                              title: '状态',
                              child: _buildConditionChip(item.condition),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 购买日期和价格
                      if (item.purchaseDate != null ||
                          item.purchasePrice != null)
                        Row(
                          children: [
                            if (item.purchaseDate != null)
                              Expanded(
                                child: _buildSection(
                                  title: '购买日期',
                                  child: Text(
                                    '${item.purchaseDate!.year}-${item.purchaseDate!.month.toString().padLeft(2, '0')}-${item.purchaseDate!.day.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              ),
                            if (item.purchasePrice != null)
                              Expanded(
                                child: _buildSection(
                                  title: '购买价格',
                                  child: Text(
                                    '¥ ${item.purchasePrice!.toStringAsFixed(2)}',
                                  ),
                                ),
                              ),
                          ],
                        ),

                      if (item.purchaseDate != null ||
                          item.purchasePrice != null)
                        const SizedBox(height: 24),

                      // 保修到期
                      if (item.warrantyExpiry != null)
                        _buildSection(
                          title: '保修到期',
                          child: Row(
                            children: [
                              Text(
                                '${item.warrantyExpiry!.year}-${item.warrantyExpiry!.month.toString().padLeft(2, '0')}-${item.warrantyExpiry!.day.toString().padLeft(2, '0')}',
                              ),
                              const SizedBox(width: 8),
                              _buildWarrantyStatus(item.warrantyExpiry!),
                            ],
                          ),
                        ),

                      if (item.warrantyExpiry != null)
                        const SizedBox(height: 24),

                      // 描述
                      if (item.description != null &&
                          item.description!.isNotEmpty)
                        _buildSection(
                          title: '描述',
                          child: Text(item.description!),
                        ),

                      if (item.description != null &&
                          item.description!.isNotEmpty)
                        const SizedBox(height: 24),

                      // 标签
                      if (item.tags.isNotEmpty)
                        _buildSection(
                          title: '标签',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: item.tags.map((tag) {
                              return Chip(
                                label: Text(tag.name),
                                backgroundColor: tag.color != null
                                    ? Color(
                                        int.parse(
                                          tag.color!.replaceFirst('#', '0xFF'),
                                        ),
                                      ).withOpacity(0.2)
                                    : null,
                              );
                            }).toList(),
                          ),
                        ),

                      if (item.tags.isNotEmpty) const SizedBox(height: 24),

                      // 备注
                      if (item.notes != null && item.notes!.isNotEmpty)
                        _buildSection(title: '备注', child: Text(item.notes!)),

                      if (item.notes != null && item.notes!.isNotEmpty)
                        const SizedBox(height: 24),

                      const Divider(height: 32),

                      // 元数据
                      _buildSection(
                        title: '元数据',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '创建: ${_formatDateTime(item.createdAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '更新: ${_formatDateTime(item.updatedAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 辅助方法
  Widget _buildImagePlaceholder(HouseholdItem item) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          _getTypeEmoji(item.itemType),
          style: const TextStyle(fontSize: 80),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildConditionChip(ItemCondition condition) {
    final (icon, label, color) = switch (condition) {
      ItemCondition.new_ => ('🆕', '全新', Colors.green),
      ItemCondition.good => ('✅', '正常使用', Colors.green),
      ItemCondition.fair => ('⚠️', '有些磨损', Colors.orange),
      ItemCondition.poor => ('❌', '需要维修', Colors.red),
    };
    return Row(children: [Text(icon), const SizedBox(width: 4), Text(label)]);
  }

  Widget _buildWarrantyStatus(DateTime warrantyExpiry) {
    final now = DateTime.now();
    final daysLeft = warrantyExpiry.difference(now).inDays;

    if (daysLeft < 0) {
      return Chip(
        label: const Text('已过期', style: TextStyle(color: Colors.red)),
        backgroundColor: Colors.red.shade50,
      );
    } else if (daysLeft < 30) {
      return Chip(
        label: Text(
          '还剩 $daysLeft 天',
          style: const TextStyle(color: Colors.orange),
        ),
        backgroundColor: Colors.orange.shade50,
      );
    } else {
      final years = (daysLeft / 365).floor();
      return Chip(
        label: Text(
          '还有 ${years > 0 ? "$years 年" : "$daysLeft 天"}',
          style: const TextStyle(color: Colors.green),
        ),
        backgroundColor: Colors.green.shade50,
      );
    }
  }

  String _getTypeLabel(String typeKey) {
    const labels = {
      'appliance': '家电',
      'furniture': '家具',
      'clothing': '衣物',
      'tableware': '餐具',
      'tool': '工具',
      'book': '书籍',
      'decoration': '装饰品',
      'sports': '运动器材',
      'toy': '玩具',
      'medicine': '药品',
      'daily': '日用品',
      'other': '其他',
    };
    return labels[typeKey] ?? '其他';
  }

  String _getTypeEmoji(String type) {
    const emojiMap = {
      'appliance': '🔌',
      'clothing': '👕',
      'furniture': '🛋️',
      'tableware': '🍽️',
      'tool': '🔧',
      'decoration': '🖼️',
      'daily': '🧴',
      'book': '📚',
      'medicine': '💊',
      'sports': '⚽',
      'toy': '🎮',
    };
    return emojiMap[type] ?? '📦';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    HouseholdItem item,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除物品'),
        content: Text('确定要删除「${item.name}」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(itemsProvider.notifier).deleteItem(item.id);
              if (context.mounted) {
                context.pop();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
