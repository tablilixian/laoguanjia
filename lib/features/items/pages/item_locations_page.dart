import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/item_location.dart';
import '../../household/providers/household_provider.dart';
import '../providers/locations_provider.dart';

class ItemLocationsPage extends ConsumerStatefulWidget {
  const ItemLocationsPage({super.key});

  @override
  ConsumerState<ItemLocationsPage> createState() => _ItemLocationsPageState();
}

class _ItemLocationsPageState extends ConsumerState<ItemLocationsPage> {
  final _searchController = TextEditingController();
  final Set<String> _expandedLocations = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationsState = ref.watch(locationsProvider);
    final householdState = ref.watch(householdProvider);

    if (householdState.currentHousehold == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('位置管理')),
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

    // 过滤位置
    final searchQuery = _searchController.text.toLowerCase();
    final filteredLocations = locationsState.locations.where((loc) {
      if (searchQuery.isEmpty) return true;
      return loc.name.toLowerCase().contains(searchQuery);
    }).toList();

    final rootLocations = filteredLocations.where((l) => l.isRoot).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('位置管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToCreatePage(context, null),
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
                hintText: '搜索位置...',
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

          // 位置列表
          Expanded(
            child: locationsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : rootLocations.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(locationsProvider.notifier).refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: rootLocations.length,
                      itemBuilder: (context, index) {
                        final location = rootLocations[index];
                        return _buildLocationTile(
                          context,
                          location,
                          locationsState,
                          0,
                        );
                      },
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
          Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty ? '没有找到匹配的位置' : '还没有创建位置',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          if (_searchController.text.isEmpty)
            TextButton.icon(
              onPressed: () => _navigateToCreatePage(context, null),
              icon: const Icon(Icons.add),
              label: const Text('添加位置'),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationTile(
    BuildContext context,
    ItemLocation location,
    LocationsState state,
    int depth,
  ) {
    final children = state.getChildLocations(location.id);
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedLocations.contains(location.id);
    final directItemCount = state.getItemCount(location.id);
    final totalItemCount = state.getTotalItemCount(location.id);
    final childrenItemCount = state.getChildrenItemCount(location.id);

    // 搜索过滤时，显示所有子位置
    final showAllChildren = _searchController.text.isNotEmpty;

    // 构建副标题
    String? subtitle;
    if (hasChildren && totalItemCount > 0) {
      if (directItemCount > 0) {
        subtitle = '直接 $directItemCount 个，共 $totalItemCount 个物品';
      } else {
        subtitle = '包含子位置共 $totalItemCount 个物品';
      }
    } else if (directItemCount > 0) {
      subtitle = '$directItemCount 个物品';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(left: depth * 20.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Text(location.icon, style: const TextStyle(fontSize: 24)),
            title: Text(
              location.name,
              style: TextStyle(
                fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: subtitle != null ? Text(subtitle) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasChildren)
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedLocations.remove(location.id);
                        } else {
                          _expandedLocations.add(location.id);
                        }
                      });
                    },
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'add') {
                      _navigateToCreatePage(
                        context,
                        null,
                        parentId: location.id,
                      );
                    } else if (value == 'edit') {
                      _navigateToCreatePage(context, location);
                    } else if (value == 'delete') {
                      _showDeleteDialog(context, location);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'add',
                      child: Row(
                        children: [
                          Icon(Icons.add),
                          SizedBox(width: 8),
                          Text('添加子位置'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn().slideX(begin: 0.05, end: 0),
        if (hasChildren && (isExpanded || showAllChildren))
          ...children.map(
            (child) => _buildLocationTile(context, child, state, depth + 1),
          ),
      ],
    );
  }

  void _navigateToCreatePage(
    BuildContext context,
    ItemLocation? location, {
    String? parentId,
  }) {
    context.push(
      '/items/location/edit',
      extra: {'location': location, 'parentId': parentId},
    );
  }

  void _showDeleteDialog(BuildContext context, ItemLocation location) {
    final itemCount = ref.read(locationsProvider).getItemCount(location.id);
    final children = ref.read(locationsProvider).getChildLocations(location.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除位置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要删除「${location.name}」吗？'),
            if (itemCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '该位置下有 $itemCount 个物品，删除后这些物品的位置将被清除。',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            if (children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '该位置下有 ${children.length} 个子位置，也会一起被删除。',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              // 删除所有子位置
              final locationsNotifier = ref.read(locationsProvider.notifier);
              final locationsState = ref.read(locationsProvider);

              // 递归删除子位置
              Future<void> deleteWithChildren(ItemLocation loc) async {
                final childLocations = locationsState.getChildLocations(loc.id);
                for (final child in childLocations) {
                  await deleteWithChildren(child);
                }
                await locationsNotifier.deleteLocation(loc.id);
              }

              await deleteWithChildren(location);

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
