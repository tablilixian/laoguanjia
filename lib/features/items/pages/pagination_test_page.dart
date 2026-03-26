import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/paginated_items_provider.dart';

/// 测试页面 - 用于调试分页加载问题
class PaginationTestPage extends ConsumerWidget {
  const PaginationTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分页加载测试'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('分页加载测试页面'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 测试 Provider 是否正常工作
                final state = ref.read(paginatedItemsProvider);
                print('🔵 [PaginationTestPage] 当前状态: ${state.items.length} 个物品');
              },
              child: const Text('测试 Provider'),
            ),
          ],
        ),
      ),
    );
  }
}
