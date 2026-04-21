// 地产大亨 - 主题选择页面
// 
// 允许玩家在游戏开始前选择不同的棋盘主题
// 
// 【使用方式】
// 在游戏设置流程中，在 GameSetupPage 之前显示此页面

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/themes/theme_provider.dart';
import '../constants/themes/board_theme.dart';
import 'game_setup_page.dart';

/// 主题选择页面
class ThemeSelectionPage extends ConsumerWidget {
  const ThemeSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(availableThemesProvider);
    final selectedThemeId = ref.watch(selectedThemeIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择地图'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '请选择一个地图主题',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 主题列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: themes.length,
                itemBuilder: (context, index) {
                  final theme = themes[index];
                  final isSelected = theme.info.id == selectedThemeId;
                  
                  return _ThemeCard(
                    theme: theme,
                    isSelected: isSelected,
                    onTap: () {
                      ref.read(selectedThemeIdProvider.notifier).setTheme(theme.info.id);
                    },
                  );
                },
              ),
            ),
            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 显示所选主题的预览信息
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前选择: ${_getSelectedThemeName(ref)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getSelectedThemeDescription(ref),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 继续按钮
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const GameSetupPage(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      '下一步',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSelectedThemeName(WidgetRef ref) {
    final theme = ref.read(currentThemeProvider);
    return theme.info.name;
  }

  String _getSelectedThemeDescription(WidgetRef ref) {
    final theme = ref.read(currentThemeProvider);
    return theme.info.description;
  }
}

/// 主题卡片组件
class _ThemeCard extends StatelessWidget {
  final BoardTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
          child: Row(
            children: [
              // 主题图标
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    _getThemeIcon(),
                    size: 32,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 主题信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.info.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      theme.info.description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 显示格子数量
                    Text(
                      '共 ${theme.properties.length} 个地产+${theme.specialCells.length} 个特殊格+${theme.stations.length} 个站点',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // 选中标记
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getThemeIcon() {
    switch (theme.info.type) {
      case BoardThemeType.chinaCities:
        return Icons.location_city;
      case BoardThemeType.international:
        return Icons.public;
      // 宋代主题使用 custom 类型，映射到历史/古典图标
      case BoardThemeType.custom:
        return Icons.account_balance;
      // 未来添加更多主题类型时，在这里添加
      // case BoardThemeType.europe:
      //   return Icons.castle;
    }
  }
}