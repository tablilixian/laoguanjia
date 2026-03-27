import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../data/local_db/app_database.dart';

/// 物品功能调试页面
/// 
/// 功能列表：
/// 1. 初始化预设类型 - 21种全局物品类型（幂等操作）
/// 2. 初始化预设标签 - 38个预设标签（幂等操作）
/// 3. 生成测试数据 - 12个位置、27个物品、12个标签、6组标签关联
/// 4. 清空物品数据 - 删除所有物品相关数据（需二次确认）
class ItemDebugPage extends StatefulWidget {
  const ItemDebugPage({super.key});

  @override
  State<ItemDebugPage> createState() => _ItemDebugPageState();
}

class _ItemDebugPageState extends State<ItemDebugPage> {
  final List<DebugResult> _results = [];
  bool _isLoading = false;
  String? _currentHouseholdId;

  final SupabaseClient _client = Supabase.instance.client;
  late final SyncEngine _syncEngine;

  bool _showClearConfirm = false;
  int _mathA = 0;
  int _mathB = 0;
  int _mathAnswer = 0;
  final _answerController = TextEditingController();
  String? _answerError;

  @override
  void initState() {
    super.initState();
    _generateMathQuestion();
    _syncEngine = SyncEngine(
      localDb: AppDatabase(),
      remoteDb: _client,
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _generateMathQuestion() {
    final random = Random();
    _mathA = random.nextInt(100);
    _mathB = random.nextInt(100);
    _mathAnswer = _mathA + _mathB;
  }

  void _resetConfirm() {
    setState(() {
      _showClearConfirm = false;
      _answerController.clear();
      _answerError = null;
      _generateMathQuestion();
    });
  }

  bool _verifyAnswer() {
    final input = int.tryParse(_answerController.text.trim());
    if (input == null) {
      setState(() => _answerError = '请输入数字');
      return false;
    }
    if (input != _mathAnswer) {
      setState(() {
        _answerError = '答案错误，请重新计算';
        _generateMathQuestion();
        _answerController.clear();
      });
      return false;
    }
    return true;
  }

  // ========== 辅助方法 ==========

  Future<String?> _getHouseholdId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final memberRes = await _client
        .from('members')
        .select('household_id')
        .eq('user_id', userId)
        .maybeSingle();

    return memberRes?['household_id'] as String?;
  }

  void _addResult(String name, bool success, String message) {
    setState(() {
      _results.insert(
        0,
        DebugResult(
          name: name,
          success: success,
          message: message,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  // ========== 初始化预设类型 ==========

  Future<void> _initPresetTypes() async {
    setState(() {
      _isLoading = true;
      _results.clear();
    });

    try {
      _addResult('开始', true, '正在初始化预设类型...');

      // 预设类型列表（21种）
      final presetTypes = [
        {'key': 'clothing', 'label': '衣物', 'icon': '👕', 'color': '#E91E63', 'order': 1},
        {'key': 'appliance', 'label': '家电', 'icon': '🔌', 'color': '#2196F3', 'order': 2},
        {'key': 'furniture', 'label': '家具', 'icon': '🛋️', 'color': '#795548', 'order': 3},
        {'key': 'daily', 'label': '日用品', 'icon': '🧴', 'color': '#4CAF50', 'order': 4},
        {'key': 'tableware', 'label': '餐具', 'icon': '🍽️', 'color': '#FF9800', 'order': 5},
        {'key': 'food', 'label': '食品调料', 'icon': '🥫', 'color': '#8BC34A', 'order': 6},
        {'key': 'bedding', 'label': '床上用品', 'icon': '🛏️', 'color': '#9C27B0', 'order': 7},
        {'key': 'electronics', 'label': '电子数码', 'icon': '📱', 'color': '#3F51B5', 'order': 8},
        {'key': 'book', 'label': '书籍', 'icon': '📚', 'color': '#673AB7', 'order': 9},
        {'key': 'decoration', 'label': '装饰品', 'icon': '🖼️', 'color': '#00BCD4', 'order': 10},
        {'key': 'tool', 'label': '工具', 'icon': '🔧', 'color': '#607D8B', 'order': 11},
        {'key': 'medicine', 'label': '药品', 'icon': '💊', 'color': '#F44336', 'order': 12},
        {'key': 'sports', 'label': '运动器材', 'icon': '⚽', 'color': '#00BCD4', 'order': 13},
        {'key': 'toy', 'label': '玩具', 'icon': '🎮', 'color': '#FF5722', 'order': 14},
        {'key': 'jewelry', 'label': '珠宝首饰', 'icon': '💍', 'color': '#FFD700', 'order': 15},
        {'key': 'pet', 'label': '宠物用品', 'icon': '🐕', 'color': '#8D6E63', 'order': 16},
        {'key': 'garden', 'label': '园艺绿植', 'icon': '🌱', 'color': '#4CAF50', 'order': 17},
        {'key': 'automotive', 'label': '车载物品', 'icon': '🚗', 'color': '#455A64', 'order': 18},
        {'key': 'stationery', 'label': '文具办公', 'icon': '📎', 'color': '#78909C', 'order': 19},
        {'key': 'consumables', 'label': '消耗品', 'icon': '🧻', 'color': '#90A4AE', 'order': 20},
        {'key': 'other', 'label': '其他', 'icon': '📦', 'color': '#9E9E9E', 'order': 99},
      ];

      // 查询已存在的全局预设类型
      final existingTypes = await _client
          .from('item_type_configs')
          .select('type_key')
          .isFilter('household_id', null);

      final existingKeys = existingTypes.map((e) => e['type_key'] as String).toSet();

      int added = 0;
      int skipped = 0;

      for (final type in presetTypes) {
        if (existingKeys.contains(type['key'])) {
          skipped++;
          continue;
        }
        try {
          await _client.from('item_type_configs').insert({
            'household_id': null,
            'type_key': type['key'],
            'type_label': type['label'],
            'icon': type['icon'],
            'color': type['color'],
            'sort_order': type['order'],
            'is_active': true,
          });
          added++;
        } catch (e) {
          _addResult('插入类型', false, '${type['label']}: $e');
        }
      }

      _addResult('✅ 完成', true, '新增 $added 个类型，跳过 $skipped 个已存在');
    } catch (e) {
      _addResult('❌ 错误', false, e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ========== 初始化预设标签 ==========

  Future<void> _initPresetTags() async {
    setState(() {
      _isLoading = true;
      _results.clear();
    });

    final householdId = await _getHouseholdId();
    if (householdId == null) {
      _addResult('❌ 错误', false, '用户未加入任何家庭');
      setState(() => _isLoading = false);
      return;
    }

    try {
      _addResult('开始', true, '正在初始化预设标签...');

      final presetTags = [
        // 季节类
        {'name': '春装', 'color': '#4CAF50', 'icon': '🌸', 'category': 'season'},
        {'name': '夏装', 'color': '#FF9800', 'icon': '☀️', 'category': 'season'},
        {'name': '秋装', 'color': '#795548', 'icon': '🍂', 'category': 'season'},
        {'name': '冬装', 'color': '#2196F3', 'icon': '❄️', 'category': 'season'},
        // 颜色类
        {'name': '深色', 'color': '#424242', 'icon': '⬛', 'category': 'color'},
        {'name': '浅色', 'color': '#9E9E9E', 'icon': '⬜', 'category': 'color'},
        {'name': '红色', 'color': '#F44336', 'icon': '🔴', 'category': 'color'},
        {'name': '蓝色', 'color': '#2196F3', 'icon': '🔵', 'category': 'color'},
        // 状态类
        {'name': '全新', 'color': '#4CAF50', 'icon': '🆕', 'category': 'status'},
        {'name': '正常使用', 'color': '#2196F3', 'icon': '✅', 'category': 'status'},
        {'name': '有些磨损', 'color': '#FF9800', 'icon': '⚠️', 'category': 'status'},
        {'name': '需要维修', 'color': '#F44336', 'icon': '❌', 'category': 'status'},
        // 归属类
        {'name': '我的', 'color': '#2196F3', 'icon': '👤', 'category': 'ownership'},
        {'name': '家人专属', 'color': '#E91E63', 'icon': '👨‍👩‍👧', 'category': 'ownership'},
        {'name': '共用', 'color': '#4CAF50', 'icon': '🔄', 'category': 'ownership'},
        {'name': '借出', 'color': '#FF9800', 'icon': '📤', 'category': 'ownership'},
        {'name': '借入', 'color': '#9C27B0', 'icon': '📥', 'category': 'ownership'},
        // 存放方式类
        {'name': '收纳箱', 'color': '#795548', 'icon': '📦', 'category': 'storage'},
        {'name': '抽屉', 'color': '#607D8B', 'icon': '🗄️', 'category': 'storage'},
        {'name': '柜子', 'color': '#795548', 'icon': '🚪', 'category': 'storage'},
        {'name': '悬挂', 'color': '#2196F3', 'icon': '🧥', 'category': 'storage'},
        {'name': '堆叠', 'color': '#FF9800', 'icon': '📚', 'category': 'storage'},
        // 使用频率类
        {'name': '常用', 'color': '#4CAF50', 'icon': '🔥', 'category': 'frequency'},
        {'name': '偶尔用', 'color': '#2196F3', 'icon': '🔶', 'category': 'frequency'},
        {'name': '很少用', 'color': '#9E9E9E', 'icon': '📦', 'category': 'frequency'},
        // 价值类
        {'name': '高价值', 'color': '#F44336', 'icon': '💎', 'category': 'value'},
        {'name': '纪念品', 'color': '#9C27B0', 'icon': '🏆', 'category': 'value'},
        {'name': '便宜货', 'color': '#4CAF50', 'icon': '💵', 'category': 'value'},
        // 来源类
        {'name': '购买', 'color': '#2196F3', 'icon': '🛒', 'category': 'source'},
        {'name': '礼物', 'color': '#E91E63', 'icon': '🎁', 'category': 'source'},
        {'name': '二手', 'color': '#795548', 'icon': '♻️', 'category': 'source'},
        // 处理意向类
        {'name': '保留', 'color': '#2196F3', 'icon': '💾', 'category': 'disposition'},
        {'name': '送人', 'color': '#E91E63', 'icon': '🎁', 'category': 'disposition'},
        {'name': '捐赠', 'color': '#4CAF50', 'icon': '♻️', 'category': 'disposition'},
        {'name': '变卖', 'color': '#FF9800', 'icon': '💰', 'category': 'disposition'},
        {'name': '丢弃', 'color': '#9E9E9E', 'icon': '🗑️', 'category': 'disposition'},
      ];

      // 查询已存在的标签
      final existingTags = await _client
          .from('item_tags')
          .select('name')
          .eq('household_id', householdId);

      final existingNames = existingTags.map((e) => e['name'] as String).toSet();

      int added = 0;
      int skipped = 0;

      for (final tag in presetTags) {
        if (existingNames.contains(tag['name'])) {
          skipped++;
          continue;
        }
        try {
          await _client.from('item_tags').insert({
            'household_id': householdId,
            'name': tag['name'],
            'color': tag['color'],
            'icon': tag['icon'],
            'category': tag['category'],
          });
          added++;
        } catch (e) {
          _addResult('插入标签', false, '${tag['name']}: $e');
        }
      }

      _addResult('✅ 完成', true, '新增 $added 个标签，跳过 $skipped 个已存在');
    } catch (e) {
      _addResult('❌ 错误', false, e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ========== 生成测试数据 ==========

  Future<void> _generateTestData() async {
    setState(() {
      _isLoading = true;
      _results.clear();
    });

    final householdId = await _getHouseholdId();
    if (householdId == null) {
      _addResult('❌ 错误', false, '用户未加入任何家庭');
      setState(() => _isLoading = false);
      return;
    }

    _currentHouseholdId = householdId;

    try {
      // 1. 清理旧测试数据
      _addResult('清理旧数据', true, '正在清理已有测试数据...');
      await _cleanupTestData(householdId);

      // 2. 生成位置
      _addResult('生成位置', true, '正在创建位置数据...');
      await _generateLocations(householdId);

      // 3. 生成物品
      _addResult('生成物品', true, '正在创建物品数据...');
      final locationIds = await _getLocationIds(householdId);
      await _generateItems(householdId, locationIds);

      _addResult('✅ 完成', true, '测试数据生成成功！');
    } catch (e) {
      _addResult('❌ 错误', false, e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cleanupTestData(String householdId) async {
    final testItemNames = [
      'TCL 电视', '美的空调', '西门子冰箱', '小米扫地机器人', '戴森吸尘器',
      '小米空气净化器', '真皮沙发', '实木书桌', '双人床', '羽绒服', 'T恤',
      '牛仔裤', '骨瓷餐具套装', '不锈钢炒锅', '电钻', '工具箱', '三体',
      '人类简史', '金字塔原理', '跑步机', '瑜伽垫', '落地灯', '绿植',
      'Switch', '乐高积木', '创可贴', '维生素C',
    ];

    for (final name in testItemNames) {
      try {
        await _client.from('household_items').delete().match({
          'household_id': householdId,
          'name': name,
        });
      } catch (_) {}
    }

    final testLocationPaths = [
      'living-room', 'living-room.tv-cabinet', 'living-room.sofa',
      'kitchen', 'kitchen.cabinet', 'kitchen.fridge',
      'master-bedroom', 'master-bedroom.closet', 'master-bedroom.nightstand',
      'guest-bedroom', 'bathroom', 'study-room',
    ];

    for (final path in testLocationPaths) {
      try {
        await _client.from('item_locations').delete().match({
          'household_id': householdId,
          'path': path,
        });
      } catch (_) {}
    }

    final testTagNames = [
      '春装', '夏装', '秋装', '冬装', '深色', '浅色', '彩色',
      '需要维修', '新品', '待处理', '待丢弃', '已借出',
    ];

    for (final name in testTagNames) {
      try {
        await _client.from('item_tags').delete().match({
          'household_id': householdId,
          'name': name,
        });
      } catch (_) {}
    }
  }

  Future<void> _generateLocations(String householdId) async {
    final locations = [
      {'name': '客厅', 'icon': '🛋️', 'path': 'living-room', 'depth': 0},
      {'name': '电视柜', 'icon': '📺', 'path': 'living-room.tv-cabinet', 'depth': 1, 'parent_path': 'living-room'},
      {'name': '沙发', 'icon': '🛋️', 'path': 'living-room.sofa', 'depth': 1, 'parent_path': 'living-room'},
      {'name': '厨房', 'icon': '🍳', 'path': 'kitchen', 'depth': 0},
      {'name': '橱柜', 'icon': '🚪', 'path': 'kitchen.cabinet', 'depth': 1, 'parent_path': 'kitchen'},
      {'name': '冰箱', 'icon': '🧊', 'path': 'kitchen.fridge', 'depth': 1, 'parent_path': 'kitchen'},
      {'name': '主卧', 'icon': '🛏️', 'path': 'master-bedroom', 'depth': 0},
      {'name': '衣柜', 'icon': '🚪', 'path': 'master-bedroom.closet', 'depth': 1, 'parent_path': 'master-bedroom'},
      {'name': '床头柜', 'icon': '🗄️', 'path': 'master-bedroom.nightstand', 'depth': 1, 'parent_path': 'master-bedroom'},
      {'name': '次卧', 'icon': '🛏️', 'path': 'guest-bedroom', 'depth': 0},
      {'name': '浴室', 'icon': '🚿', 'path': 'bathroom', 'depth': 0},
      {'name': '书房', 'icon': '📚', 'path': 'study-room', 'depth': 0},
    ];

    final pathToId = <String, String>{};

    for (final loc in locations) {
      final parentId = loc['parent_path'] != null ? pathToId[loc['parent_path']] : null;

      final res = await _client.from('item_locations').insert({
        'household_id': householdId,
        'name': loc['name'],
        'icon': loc['icon'],
        'path': loc['path'],
        'depth': loc['depth'],
        'parent_id': parentId,
        'sort_order': locations.indexOf(loc),
      }).select().single();

      pathToId[loc['path'] as String] = res['id'] as String;
    }
  }

  Future<Map<String, String>> _getLocationIds(String householdId) async {
    final res = await _client
        .from('item_locations')
        .select('id, path')
        .eq('household_id', householdId);
    return {for (var e in res) e['path'] as String: e['id'] as String};
  }

  Future<void> _generateItems(String householdId, Map<String, String> locationIds) async {
    final items = [
      {'name': 'TCL 电视', 'type': 'appliance', 'location': 'living-room.tv-cabinet', 'brand': 'TCL', 'price': 2999.0},
      {'name': '美的空调', 'type': 'appliance', 'location': 'living-room', 'brand': '美的', 'price': 4500.0},
      {'name': '西门子冰箱', 'type': 'appliance', 'location': 'kitchen.fridge', 'brand': '西门子', 'price': 8000.0},
      {'name': '小米扫地机器人', 'type': 'appliance', 'location': 'living-room', 'brand': '小米', 'price': 3500.0},
      {'name': '戴森吸尘器', 'type': 'daily', 'location': 'living-room', 'brand': '戴森', 'price': 5000.0},
      {'name': '小米空气净化器', 'type': 'daily', 'location': 'master-bedroom', 'brand': '小米', 'price': 1500.0},
      {'name': '真皮沙发', 'type': 'furniture', 'location': 'living-room.sofa', 'brand': '顾家', 'price': 12000.0},
      {'name': '实木书桌', 'type': 'furniture', 'location': 'study-room', 'brand': '宜家', 'price': 2000.0},
      {'name': '双人床', 'type': 'furniture', 'location': 'master-bedroom', 'brand': '慕思', 'price': 6000.0},
      {'name': '羽绒服', 'type': 'clothing', 'location': 'master-bedroom.closet', 'brand': '波司登', 'price': 1500.0},
      {'name': 'T恤', 'type': 'clothing', 'location': 'master-bedroom.closet', 'brand': '优衣库', 'price': 99.0},
      {'name': '牛仔裤', 'type': 'clothing', 'location': 'master-bedroom.closet', 'brand': "Levi's", 'price': 800.0},
      {'name': '骨瓷餐具套装', 'type': 'tableware', 'location': 'kitchen.cabinet', 'brand': '康宁', 'price': 1200.0},
      {'name': '不锈钢炒锅', 'type': 'tableware', 'location': 'kitchen.cabinet', 'brand': '苏泊尔', 'price': 300.0},
      {'name': '电钻', 'type': 'tool', 'location': 'kitchen', 'brand': '博世', 'price': 800.0},
      {'name': '工具箱', 'type': 'tool', 'location': 'kitchen.cabinet', 'brand': '史丹利', 'price': 500.0},
      {'name': '三体', 'type': 'book', 'location': 'study-room', 'brand': '重庆出版社', 'price': 68.0},
      {'name': '人类简史', 'type': 'book', 'location': 'study-room', 'brand': '中信出版社', 'price': 68.0},
      {'name': '金字塔原理', 'type': 'book', 'location': 'study-room', 'brand': '民主与建设出版社', 'price': 59.0},
      {'name': '跑步机', 'type': 'sports', 'location': 'living-room', 'brand': '舒华', 'price': 4000.0},
      {'name': '瑜伽垫', 'type': 'sports', 'location': 'living-room', 'brand': 'Keep', 'price': 200.0},
      {'name': '落地灯', 'type': 'decoration', 'location': 'living-room.sofa', 'brand': 'IKEA', 'price': 499.0},
      {'name': '绿植', 'type': 'decoration', 'location': 'living-room', 'price': 150.0},
      {'name': 'Switch', 'type': 'toy', 'location': 'living-room.tv-cabinet', 'brand': '任天堂', 'price': 2500.0},
      {'name': '乐高积木', 'type': 'toy', 'location': 'master-bedroom.nightstand', 'brand': 'LEGO', 'price': 600.0},
      {'name': '创可贴', 'type': 'medicine', 'location': 'bathroom', 'brand': '云南白药', 'price': 5.0},
      {'name': '维生素C', 'type': 'medicine', 'location': 'bathroom', 'brand': '汤臣倍健', 'price': 120.0},
    ];

    for (final item in items) {
      try {
        await _client.from('household_items').insert({
          'household_id': householdId,
          'name': item['name'],
          'item_type': item['type'],
          'location_id': locationIds[item['location']],
          'brand': item['brand'],
          'purchase_price': item['price'],
          'quantity': 1,
          'condition': 'good',
          'sync_status': 'synced',
        });
      } catch (e) {
        _addResult('生成物品', false, '${item['name']}: $e');
      }
    }
  }

  // ========== 同步测试方法 ==========

  Future<void> _testItemSync() async {
    setState(() {
      _isLoading = true;
      _results.clear();
    });

    try {
      _addResult('开始同步', true, '正在同步物品数据...');
      
      final result = await _syncEngine.syncItems();
      
      _addResult(
        result.success ? '✅ 同步完成' : '⚠️ 同步完成（有错误）',
        result.success,
        '拉取: ${result.pulled}, 推送: ${result.pushed}, 冲突: ${result.conflicts}\n'
        '${result.errors.isNotEmpty ? "错误: ${result.errors.join(", ")}" : ""}',
      );
    } catch (e) {
      _addResult('❌ 同步失败', false, e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forceFullSync() async {
    setState(() {
      _isLoading = true;
      _results.clear();
    });

    try {
      _addResult('开始全量同步', true, '正在强制拉取所有物品数据...');
      
      final result = await _syncEngine.forceFullSyncItems(
        onProgress: (current, total) {
          setState(() {
            if (_results.isNotEmpty) {
              _results[0] = DebugResult(
                name: '同步进度',
                success: true,
                message: '正在同步: $current / $total',
                timestamp: DateTime.now(),
              );
            }
          });
        },
      );
      
      _addResult(
        result.success ? '✅ 全量同步完成' : '⚠️ 全量同步完成（有错误）',
        result.success,
        '共拉取: ${result.pulled} 条数据\n'
        '${result.errors.isNotEmpty ? "错误: ${result.errors.take(3).join(", ")}" : ""}',
      );
    } catch (e) {
      _addResult('❌ 全量同步失败', false, e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showLocalData() async {
    setState(() {
      _isLoading = true;
      _results.clear();
    });

    try {
      final db = AppDatabase();
      
      final items = await db.itemsDao.getAll();
      final locations = await db.locationsDao.getAll();
      final tags = await db.tagsDao.getAll();
      final types = await db.typesDao.getAll();
      
      _addResult('本地数据统计', true, 
        '物品: ${items.length} 条\n'
        '位置: ${locations.length} 条\n'
        '标签: ${tags.length} 条\n'
        '类型: ${types.length} 条');
      
      final pendingItems = items.where((i) => i.syncPending).length;
      final pendingLocations = locations.where((l) => l.syncPending).length;
      final pendingTags = tags.where((t) => t.syncPending).length;
      
      if (pendingItems > 0 || pendingLocations > 0 || pendingTags > 0) {
        _addResult('待同步数据', true,
          '物品: $pendingItems 条\n'
          '位置: $pendingLocations 条\n'
          '标签: $pendingTags 条');
      }
    } catch (e) {
      _addResult('❌ 查询失败', false, e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ========== 清空所有物品数据 ==========

  Future<void> _clearAllItemData() async {
    if (!_verifyAnswer()) return;

    setState(() {
      _isLoading = true;
      _results.clear();
      _showClearConfirm = false;
    });

    final householdId = await _getHouseholdId();
    if (householdId == null) {
      _addResult('❌ 错误', false, '用户未加入任何家庭');
      setState(() => _isLoading = false);
      return;
    }

    try {
      _addResult('开始清空', true, '正在删除所有物品相关数据...');

      // 1. 删除物品
      await _client.from('household_items').delete().eq('household_id', householdId);
      _addResult('删除物品', true, '已删除所有物品');

      // 2. 删除标签
      await _client.from('item_tags').delete().eq('household_id', householdId);
      _addResult('删除标签', true, '已删除所有标签');

      // 3. 删除位置
      await _client.from('item_locations').delete().eq('household_id', householdId);
      _addResult('删除位置', true, '已删除所有位置');

      _addResult('✅ 完成', true, '物品数据已全部清空');
    } catch (e) {
      _addResult('❌ 错误', false, e.toString());
    } finally {
      setState(() => _isLoading = false);
      _generateMathQuestion();
    }
  }

  // ========== UI 构建 ==========

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('物品调试'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 功能按钮区
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 功能说明
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppTheme.primaryGold),
                            const SizedBox(width: 8),
                            Text('功能说明', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryGold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• 初始化预设类型/标签：幂等操作，重复执行不重复添加\n'
                          '• 生成测试数据：创建12个位置、27个物品\n'
                          '• 清空物品数据：删除所有物品、标签、位置（需验证）',
                          style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 初始化预设类型
                  _buildButton(
                    icon: Icons.category_outlined,
                    label: '初始化预设类型',
                    description: '21种全局物品类型',
                    color: Colors.blue,
                    onPressed: _isLoading ? null : _initPresetTypes,
                  ),
                  const SizedBox(height: 12),

                  // 初始化预设标签
                  _buildButton(
                    icon: Icons.label_outline,
                    label: '初始化预设标签',
                    description: '38个预设标签（11种分类）',
                    color: Colors.green,
                    onPressed: _isLoading ? null : _initPresetTags,
                  ),
                  const SizedBox(height: 12),

                  // 生成测试数据
                  _buildButton(
                    icon: Icons.add_box_outlined,
                    label: '生成测试数据',
                    description: '创建12个位置、27个物品、标签关联',
                    color: AppTheme.primaryGold,
                    onPressed: _isLoading ? null : _generateTestData,
                  ),
                  const SizedBox(height: 12),

                  // 清空物品数据
                  _buildDangerButton(
                    icon: Icons.delete_forever,
                    label: '清空物品数据',
                    description: '删除所有物品、标签、位置',
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _showClearConfirm = true),
                  ),
                  
                  const Divider(height: 32),
                  
                  // 同步测试区域
                  Text(
                    '离线同步测试',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 测试物品同步
                  _buildButton(
                    icon: Icons.sync,
                    label: '测试物品同步',
                    description: '同步物品、位置、标签、类型',
                    color: Colors.purple,
                    onPressed: _isLoading ? null : _testItemSync,
                  ),
                  const SizedBox(height: 12),
                  
                  // 强制全量同步
                  _buildButton(
                    icon: Icons.sync_problem,
                    label: '强制全量同步',
                    description: '重置版本号，重新拉取所有数据',
                    color: Colors.orange,
                    onPressed: _isLoading ? null : _forceFullSync,
                  ),
                  const SizedBox(height: 12),
                  
                  // 查看本地数据
                  _buildButton(
                    icon: Icons.storage,
                    label: '查看本地数据',
                    description: '查看本地数据库中的物品数量',
                    color: Colors.teal,
                    onPressed: _isLoading ? null : _showLocalData,
                  ),
                ],
              ),
            ),

            // 结果列表
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.build_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            '点击上方按钮开始调试',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: result.success ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                result.success ? Icons.check_circle : Icons.error,
                                color: result.success ? Colors.green : Colors.red,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              result.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              result.message,
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // 清空数据的二次确认弹窗
      bottomSheet: _showClearConfirm
          ? Container(
              color: theme.scaffoldBackgroundColor,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              '确认清空所有物品数据？',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '此操作将删除：\n'
                          '• 所有物品（household_items）\n'
                          '• 所有标签（item_tags）\n'
                          '• 所有位置（item_locations）\n\n'
                          '此操作不可恢复！',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 数学验证
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '请计算以下算式验证身份：',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_mathA + $_mathB = ?',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _answerController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: '输入答案',
                                  errorText: _answerError,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onChanged: (_) {
                                  if (_answerError != null) {
                                    setState(() => _answerError = null);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _resetConfirm,
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isLoading ? null : _clearAllItemData,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('确认清空'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildDangerButton({
    required IconData icon,
    required String label,
    required String description,
    VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: Colors.red),
      ),
      child: Row(
        children: [
          const Icon(Icons.delete_forever, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}

class DebugResult {
  final String name;
  final bool success;
  final String message;
  final DateTime timestamp;

  DebugResult({
    required this.name,
    required this.success,
    required this.message,
    required this.timestamp,
  });
}
