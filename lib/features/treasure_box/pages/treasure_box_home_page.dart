import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/treasure_card.dart';

/// 百宝箱主页 - 展示所有小工具的入口
/// 
/// 每个工具卡片点击后进入对应的工具页面
class TreasureBoxHomePage extends StatelessWidget {
  const TreasureBoxHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // AppBar 区域
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              '百宝箱',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  '各种小创意，等你来发现',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          
          // 工具卡片 Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildListDelegate([
                // 每日一句
                TreasureCard(
                  title: '每日一句',
                  subtitle: '古诗词/励志/毒鸡汤',
                  icon: Icons.format_quote,
                  color: const Color(0xFF667EEA),
                  onTap: () => context.push('/treasure-box/quote'),
                ),
                
                // 掷骰子
                TreasureCard(
                  title: '掷骰子',
                  subtitle: '随机掷1-6',
                  icon: Icons.casino_outlined,
                  color: const Color(0xFFFF7043),
                  onTap: () => context.push('/treasure-box/dice'),
                ),
                
                // 随机选择
                TreasureCard(
                  title: '随机选择',
                  subtitle: '帮你做决定',
                  icon: Icons.shuffle,
                  color: const Color(0xFF7E57C2),
                  onTap: () => context.push('/treasure-box/picker'),
                ),
                
                // 石头剪刀布（在规划中，显示 Coming Soon）
                TreasureCard(
                  title: '石头剪刀布',
                  subtitle: '即将上线',
                  icon: Icons.handshake_outlined,
                  color: const Color(0xFF26A69A),
                  onTap: () => _showComingSoon(context),
                ),
                
                // 抛硬币（在规划中，显示 Coming Soon）
                TreasureCard(
                  title: '抛硬币',
                  subtitle: '即将上线',
                  icon: Icons.monetization_on_outlined,
                  color: const Color(0xFFFFD54F),
                  onTap: () => _showComingSoon(context),
                ),
              ]),
            ),
          ),
          
          // 底部留白
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
  
  /// 显示"即将上线"提示
  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('即将上线，敬请期待 🎉'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}