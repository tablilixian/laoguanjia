import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/ai/ai_item_service.dart';
import '../../../data/ai/ai_settings_service.dart';
import '../../../data/ai/ai_providers.dart';
import '../../../data/models/household_item.dart';
import '../../household/providers/household_provider.dart';
import '../providers/offline_items_provider.dart';
import '../providers/tags_provider.dart';

/// AI 物品助手页面
/// 支持：AI创建物品、AI查询物品、AI统计
class ItemAIAssistantPage extends ConsumerStatefulWidget {
  const ItemAIAssistantPage({super.key});

  @override
  ConsumerState<ItemAIAssistantPage> createState() => _ItemAIAssistantPageState();
}

class _ItemAIAssistantPageState extends ConsumerState<ItemAIAssistantPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<AIChatMessage> _messages = [];
  bool _isLoading = false;

  // 类型标签映射
  static const Map<String, String> _typeLabels = {
    'appliance': '🔌 家电',
    'furniture': '🛋️ 家具',
    'clothing': '👕 衣物',
    'tableware': '🍽️ 餐具',
    'tool': '🔧 工具',
    'book': '📚 书籍',
    'decoration': '🖼️ 装饰品',
    'sports': '⚽ 运动器材',
    'toy': '🎮 玩具',
    'medicine': '💊 药品',
    'daily': '🧴 日用品',
    'food': '🍜 食品调料',
    'bedding': '🛏️ 床上用品',
    'electronics': '📱 电子数码',
    'jewelry': '💍 珠宝首饰',
    'pet': '🐕 宠物用品',
    'garden': '🌱 园艺绿植',
    'automotive': '🚗 车载物品',
    'stationery': '📝 文具办公',
    'consumables': '🧻 消耗品',
    'other': '📦 其他',
  };

  // 标签分类名称映射
  static const Map<String, String> _tagCategoryLabels = {
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

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(AIChatMessage(
      role: 'assistant',
      content: '''你好！我是物品管理助手 🤖

我可以帮你：

📦 **创建物品**
「帮我把冰箱和电视保存到客厅」

🔍 **查询物品**
「找出客厅里所有的家电」
「我有哪些衣服？」

🏷️ **按标签查询**
「哪些物品打了'需要维修'标签？」
「查看所有'全新'的物品」
「有'高价值'标签的物品有哪些？」

📊 **统计信息**
「我家有多少物品？」
「按类型统计一下」
「物品总价值是多少？」

请告诉我你想做什么？''',
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // 添加用户消息
    setState(() {
      _messages.add(AIChatMessage(role: 'user', content: text));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final householdId = ref.read(householdProvider).currentHousehold?.id;
      if (householdId == null) {
        _addErrorMessage('请先加入一个家庭');
        return;
      }

      // 意图识别
      final intent = _detectIntent(text);
      String response;

      switch (intent) {
        case 'create':
          response = await _handleCreateIntent(text, householdId);
          break;
        case 'query':
          response = await _handleQueryIntent(text);
          break;
        case 'stats':
          response = await _handleStatsIntent();
          break;
        default:
          response = _handleUnknownIntent(text);
      }

      setState(() {
        _messages.add(AIChatMessage(role: 'assistant', content: response));
      });
    } catch (e) {
      _addErrorMessage('出错了: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  /// 检测用户意图
  String _detectIntent(String text) {
    final lower = text.toLowerCase();

    // 创建物品关键词
    final createKeywords = [
      '保存', '录入', '添加', '创建', '登记', '记录', '放进', '放进去',
      '把', '新增', '收藏'
    ];
    for (final kw in createKeywords) {
      if (lower.contains(kw)) return 'create';
    }

    // 统计关键词
    final statsKeywords = [
      '多少', '统计', '总数', '总计', '汇总', '加起来', '价值',
      '贵重', '物品列表', '按类型', '按位置'
    ];
    for (final kw in statsKeywords) {
      if (lower.contains(kw)) return 'stats';
    }

    // 查询关键词
    final queryKeywords = [
      '找出', '找找', '查找', '搜索', '查询', '有哪些', '有没有',
      '在哪', '哪个', '看看', '列出', '展示'
    ];
    for (final kw in queryKeywords) {
      if (lower.contains(kw)) return 'query';
    }

    return 'unknown';
  }

  /// 处理创建物品意图
  Future<String> _handleCreateIntent(String text, String householdId) async {
    try {
      // 懒加载创建 AI 服务
      final settings = ref.read(aiSettingsServiceProvider);
      final householdState = ref.read(householdProvider);
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        return '用户信息获取失败，请重新登录';
      }
      final member = householdState.members.firstWhere(
        (m) => m.userId == currentUserId,
        orElse: () => throw Exception('未找到成员信息'),
      );
      if (member.userId == null) {
        return '成员信息不完整，请重新登录';
      }
      final aiService = AIItemService(settings, member.userId!);
      return await aiService.parseAndCreateItems(text, householdId);
    } catch (e) {
      if (e.toString().contains('API')) {
        return 'AI 调用失败，请检查 API Key 设置。\n\n你可以去「设置 → AI 设置」配置 API Key。';
      }
      return '创建物品失败: $e';
    }
  }

  /// 处理查询物品意图
  Future<String> _handleQueryIntent(String text) async {
    final itemsState = ref.read(offlineItemsProvider);
    final items = itemsState.items;
    final lower = text.toLowerCase();

    // 按位置查询 - 使用模糊匹配
    final locationNames = items
        .where((i) => i.locationName != null)
        .map((i) => i.locationName!)
        .toSet()
        .toList();

    // 查找用户提到的位置（模糊匹配）
    String? matchedLocation;
    for (final locationName in locationNames) {
      final lowerLocation = locationName.toLowerCase();
      // 检查位置名是否是用户输入的子串，或用户输入是否是位置名的子串
      if (lowerLocation.contains(lower) || 
          lower.contains(lowerLocation) ||
          _fuzzyMatch(lower, lowerLocation)) {
        matchedLocation = locationName;
        break;
      }
    }

    // 如果没找到，尝试关键词匹配
    if (matchedLocation == null) {
      final locationKeywords = {
        '卧室': ['卧室', '卧房', '睡房', '主卧', '次卧'],
        '厨房': ['厨房'],
        '客厅': ['客厅', '起居室'],
        '浴室': ['浴室', '卫生间', '洗手间', '厕所', '厕所'],
        '书房': ['书房', '书房', '工作室'],
        '阳台': ['阳台'],
        '储藏室': ['储藏室', '储藏间', '杂物间'],
      };

      for (final entry in locationKeywords.entries) {
        for (final keyword in entry.value) {
          if (lower.contains(keyword) || keyword.contains(lower)) {
            // 找到包含这个关键词的位置
            for (final locationName in locationNames) {
              if (locationName.contains(entry.key) || locationName.contains(keyword)) {
                matchedLocation = locationName;
                break;
              }
            }
            if (matchedLocation != null) break;
          }
        }
        if (matchedLocation != null) break;
      }
    }

    if (matchedLocation != null) {
      final filtered = items.where((i) => i.locationName == matchedLocation).toList();
      return _formatItemList(filtered, '$matchedLocation 的物品');
    }

    // 按类型查询
    for (final entry in _typeLabels.entries) {
      final typeKey = entry.key;
      final typeLabel = entry.value;
      if (lower.contains(typeLabel) || lower.contains(typeKey)) {
        final filtered = items.where((i) => i.itemType == typeKey).toList();
        return _formatItemList(filtered, typeLabel);
      }
    }

    // 按标签查询
    final tagsState = ref.read(tagsProvider);
    final tags = tagsState.tags;
    
    // 获取所有标签名称用于匹配
    for (final tag in tags) {
      final tagName = tag.name.toLowerCase();
      if (lower.contains(tagName) || tagName.contains(lower)) {
        // 找到匹配的标签
        final tagItems = items.where((item) => 
          item.tags.any((t) => t.id == tag.id)
        ).toList();
        if (tagItems.isNotEmpty) {
          return _formatItemList(tagItems, '带有标签"${tag.name}"的物品');
        }
      }
    }

    // 按标签分类查询
    for (final entry in _tagCategoryLabels.entries) {
      final categoryKey = entry.key;
      final categoryLabel = entry.value;
      if (lower.contains(categoryLabel) || lower.contains(categoryKey)) {
        // 找到该分类下的所有标签
        final categoryTags = tags.where((t) => t.category == categoryKey).toList();
        final tagIds = categoryTags.map((t) => t.id).toSet();
        final tagItems = items.where((item) => 
          item.tags.any((t) => tagIds.contains(t.id))
        ).toList();
        if (tagItems.isNotEmpty) {
          return _formatItemList(tagItems, categoryLabel);
        }
      }
    }

    // 查询特定名称的物品
    if (lower.contains('的') && lower.contains('哪些')) {
      // 例如 "我有哪些衣服"
      final match = RegExp('(.+?)的').firstMatch(text);
      if (match != null) {
        final query = match.group(1);
        if (query != null) {
          final filtered = items.where((i) => i.name.contains(query)).toList();
          return _formatItemList(filtered, '包含"${query}"的物品');
        }
      }
    }

    // 默认返回所有物品
    return _formatItemList(items, '所有物品');
  }

  /// 简单的模糊匹配
  bool _fuzzyMatch(String input, String target) {
    // 检查输入是否是目标的一部分
    if (target.contains(input)) return true;
    // 检查目标是否是输入的一部分
    if (input.contains(target)) return true;
    // 检查是否有共同子串（至少2个字符）
    for (int i = 0; i < input.length - 1; i++) {
      if (target.contains(input.substring(i, i + 2))) {
        return true;
      }
    }
    return false;
  }

  /// 处理统计意图
  Future<String> _handleStatsIntent() async {
    final itemsState = ref.read(offlineItemsProvider);
    final items = itemsState.items;
    final buffer = StringBuffer();

    buffer.writeln('📊 **物品统计**\n');

    // 总数
    buffer.writeln('• 总物品数: ${items.length} 件');

    // 按类型统计
    final byType = <String, int>{};
    for (final item in items) {
      byType[item.itemType] = (byType[item.itemType] ?? 0) + 1;
    }

    buffer.writeln('\n**按类型分布:**');
    final sortedTypes = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedTypes.take(5)) {
      final label = _typeLabels[entry.key] ?? entry.key;
      buffer.writeln('  ${label}: ${entry.value} 件');
    }

    // 总价值
    double totalValue = 0;
    for (final item in items) {
      if (item.purchasePrice != null) {
        totalValue += item.purchasePrice!;
      }
    }
    buffer.writeln('\n**💰 总价值: ¥${totalValue.toStringAsFixed(2)}**');

    // 保修相关
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 30));
    final nearExpiry = items.where((i) =>
      i.warrantyExpiry != null &&
      i.warrantyExpiry!.isAfter(now) &&
      i.warrantyExpiry!.isBefore(soon)
    ).toList();

    if (nearExpiry.isNotEmpty) {
      buffer.writeln('\n**⚠️ 即将到期的保修 (30天内): ${nearExpiry.length} 件**');
      for (final item in nearExpiry.take(3)) {
        buffer.writeln('  • ${item.name} (${_formatDate(item.warrantyExpiry!)})');
      }
    }

    final expired = items.where((i) =>
      i.warrantyExpiry != null && i.warrantyExpiry!.isBefore(now)
    ).toList();
    if (expired.isNotEmpty) {
      buffer.writeln('\n**❌ 已过期的保修: ${expired.length} 件**');
    }

    return buffer.toString();
  }

  /// 处理未知意图
  String _handleUnknownIntent(String text) {
    return '''抱歉，我没有理解你的意图 😔

你可以试试：
• 「帮我把电视保存到客厅」
• 「找出客厅里所有的家电」
• 「我家有多少物品？」

或者你可以直接用物品页面的「+」按钮添加物品。''';
  }

  /// 格式化物品列表
  String _formatItemList(List<HouseholdItem> items, String title) {
    if (items.isEmpty) {
      return '没有找到物品 😔';
    }

    final buffer = StringBuffer();
    buffer.writeln('📋 **$title** (共 ${items.length} 件)\n');

    // 按类型分组
    final byType = <String, List<HouseholdItem>>{};
    for (final item in items) {
      byType.putIfAbsent(item.itemType, () => []).add(item);
    }

    for (final entry in byType.entries) {
      final label = _typeLabels[entry.key] ?? entry.key;
      buffer.writeln('**$label**');
      for (final item in entry.value) {
        final location = item.locationName != null ? ' (${item.locationName})' : '';
        buffer.writeln('• ${item.name}$location');
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  void _addErrorMessage(String error) {
    setState(() {
      _messages.add(AIChatMessage(
        role: 'assistant',
        content: '❌ $error',
        isError: true,
      ));
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy, size: 24),
            SizedBox(width: 8),
            Text('AI 物品助手'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message, theme);
              },
            ),
          ),

          // 加载指示器
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('思考中...'),
                ],
              ),
            ),

          // 输入框
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '告诉我你想做什么...',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AIChatMessage message, ThemeData theme) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.primaryGold
              : (message.isError
                  ? Colors.red.shade100
                  : theme.colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : (message.isError ? Colors.red : null),
          ),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline),
            SizedBox(width: 8),
            Text('使用帮助'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('**📦 创建物品**', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('「帮我把冰箱和电视保存到客厅」'),
              Text('「把新买的吸尘器录入」'),
              SizedBox(height: 12),
              Text('**🔍 查询物品**', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('「找出客厅里所有的家电」'),
              Text('「我有哪些衣服？」'),
              Text('「查看厨房的物品」'),
              SizedBox(height: 12),
              Text('**🏷️ 按标签查询**', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('「哪些物品打了\'需要维修\'标签？」'),
              Text('「查看所有\'全新\'的物品」'),
              Text('「有\'高价值\'标签的物品有哪些？」'),
              SizedBox(height: 12),
              Text('**📊 统计信息**', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('「我家有多少物品？」'),
              Text('「按类型统计一下」'),
              Text('「物品总价值是多少？」'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

/// 聊天消息模型
class AIChatMessage {
  final String role;
  final String content;
  final bool isError;

  AIChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
  });
}
