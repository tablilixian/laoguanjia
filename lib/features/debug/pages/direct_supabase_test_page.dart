import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class DirectSupabaseTestPage extends StatefulWidget {
  const DirectSupabaseTestPage({super.key});

  @override
  State<DirectSupabaseTestPage> createState() => _DirectSupabaseTestPageState();
}

class _DirectSupabaseTestPageState extends State<DirectSupabaseTestPage> {
  final List<TestResult> _results = [];
  bool _isTesting = false;
  String? _currentHouseholdId;

  final SupabaseClient _client = Supabase.instance.client;

  Future<void> _runTests() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    await _testDirectConnection();
    await _testHouseholdsTable();
    await _testMembersTable();

    setState(() {
      _isTesting = false;
    });
  }

  Future<void> _generateTestData() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _addResult('生成测试数据', false, '用户未登录');
        setState(() => _isTesting = false);
        return;
      }

      _addResult('开始生成', true, '正在获取家庭信息...');

      final memberRes = await _client
          .from('members')
          .select('household_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (memberRes == null) {
        _addResult('生成测试数据', false, '用户未加入任何家庭');
        setState(() => _isTesting = false);
        return;
      }

      final householdId = memberRes['household_id'] as String;
      _currentHouseholdId = householdId;
      _addResult('获取家庭', true, '家庭ID: ${householdId.substring(0, 8)}...');

      // 先清理旧测试数据（幂等性保护）
      _addResult('清理旧数据', true, '正在清理已有测试数据...');
      await _cleanupTestData(householdId);
      _addResult('清理旧数据', true, '清理完成');

      _addResult('生成位置', true, '开始创建位置数据...');
      await _generateLocations(householdId);
      _addResult('生成位置', true, '位置创建完成');

      _addResult('生成标签', true, '开始创建标签数据...');
      await _generateTags(householdId);
      _addResult('生成标签', true, '标签创建完成');

      _addResult('生成物品', true, '开始创建物品数据...');
      final locationIds = await _getLocationIds(householdId);
      await _generateItems(householdId, locationIds);
      _addResult('生成物品', true, '物品创建完成');

      _addResult('生成标签关联', true, '开始创建标签关联...');
      await _generateTagRelations(householdId);
      _addResult('生成标签关联', true, '标签关联创建完成');

      _addResult('🎉 完成', true, '测试数据生成成功！共创建 27 个物品');
    } catch (e) {
      _addResult('生成测试数据', false, '错误: ${e.toString()}');
    }

    setState(() => _isTesting = false);
  }

  Future<void> _cleanupTestData(String householdId) async {
    // 通过名称匹配删除测试数据
    final testItemNames = [
      'TCL 电视',
      '美的空调',
      '西门子冰箱',
      '小米扫地机器人',
      '戴森吸尘器',
      '小米空气净化器',
      '真皮沙发',
      '实木书桌',
      '双人床',
      '羽绒服',
      'T恤',
      '牛仔裤',
      '骨瓷餐具套装',
      '不锈钢炒锅',
      '电钻',
      '工具箱',
      '三体',
      '人类简史',
      '金字塔原理',
      '跑步机',
      '瑜伽垫',
      '落地灯',
      '绿植',
      'Switch',
      '乐高积木',
      '创可贴',
      '维生素C',
    ];

    // 删除测试物品
    for (final name in testItemNames) {
      try {
        await _client.from('household_items').delete().match({
          'household_id': householdId,
          'name': name,
        });
      } catch (_) {}
    }

    // 删除测试位置
    final testLocationPaths = [
      'living-room',
      'living-room.tv-cabinet',
      'living-room.sofa',
      'kitchen',
      'kitchen.cabinet',
      'kitchen.fridge',
      'master-bedroom',
      'master-bedroom.closet',
      'master-bedroom.nightstand',
      'guest-bedroom',
      'bathroom',
      'study-room',
    ];

    for (final path in testLocationPaths) {
      try {
        await _client.from('item_locations').delete().match({
          'household_id': householdId,
          'path': path,
        });
      } catch (_) {}
    }

    // 删除测试标签
    final testTagNames = [
      '春装',
      '夏装',
      '秋装',
      '冬装',
      '深色',
      '浅色',
      '彩色',
      '需要维修',
      '新品',
      '待处理',
      '待丢弃',
      '已借出',
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
      {
        'name': '电视柜',
        'icon': '📺',
        'path': 'living-room.tv-cabinet',
        'depth': 1,
        'parent_path': 'living-room',
      },
      {
        'name': '沙发',
        'icon': '🛋️',
        'path': 'living-room.sofa',
        'depth': 1,
        'parent_path': 'living-room',
      },
      {'name': '厨房', 'icon': '🍳', 'path': 'kitchen', 'depth': 0},
      {
        'name': '橱柜',
        'icon': '🚪',
        'path': 'kitchen.cabinet',
        'depth': 1,
        'parent_path': 'kitchen',
      },
      {
        'name': '冰箱',
        'icon': '🧊',
        'path': 'kitchen.fridge',
        'depth': 1,
        'parent_path': 'kitchen',
      },
      {'name': '主卧', 'icon': '🛏️', 'path': 'master-bedroom', 'depth': 0},
      {
        'name': '衣柜',
        'icon': '🚪',
        'path': 'master-bedroom.closet',
        'depth': 1,
        'parent_path': 'master-bedroom',
      },
      {
        'name': '床头柜',
        'icon': '🗄️',
        'path': 'master-bedroom.nightstand',
        'depth': 1,
        'parent_path': 'master-bedroom',
      },
      {'name': '次卧', 'icon': '🛏️', 'path': 'guest-bedroom', 'depth': 0},
      {'name': '浴室', 'icon': '🚿', 'path': 'bathroom', 'depth': 0},
      {'name': '书房', 'icon': '📚', 'path': 'study-room', 'depth': 0},
    ];

    final Map<String, String> pathToId = {};

    for (final loc in locations) {
      final parentId = loc['parent_path'] != null
          ? pathToId[loc['parent_path']]
          : null;

      final res = await _client
          .from('item_locations')
          .insert({
            'household_id': householdId,
            'name': loc['name'],
            'icon': loc['icon'],
            'path': loc['path'],
            'depth': loc['depth'],
            'parent_id': parentId,
            'sort_order': locations.indexOf(loc),
          })
          .select()
          .single();

      pathToId[loc['path'] as String] = res['id'] as String;
    }
  }

  Future<void> _generateTags(String householdId) async {
    final tags = [
      {'name': '春装', 'color': '#4CAF50', 'category': 'season'},
      {'name': '夏装', 'color': '#FF9800', 'category': 'season'},
      {'name': '秋装', 'color': '#795548', 'category': 'season'},
      {'name': '冬装', 'color': '#2196F3', 'category': 'season'},
      {'name': '深色', 'color': '#424242', 'category': 'color'},
      {'name': '浅色', 'color': '#9E9E9E', 'category': 'color'},
      {'name': '彩色', 'color': '#E91E63', 'category': 'color'},
      {'name': '需要维修', 'color': '#F44336', 'category': 'status'},
      {'name': '新品', 'color': '#4CAF50', 'category': 'status'},
      {'name': '待处理', 'color': '#FF9800', 'category': 'status'},
      {'name': '待丢弃', 'color': '#795548', 'category': 'status'},
      {'name': '已借出', 'color': '#9C27B0', 'category': 'status'},
    ];

    for (final tag in tags) {
      try {
        await _client.from('item_tags').insert({
          'household_id': householdId,
          'name': tag['name'],
          'color': tag['color'],
          'category': tag['category'],
        });
      } catch (_) {}
    }
  }

  /// 初始化预设标签（幂等性：重复执行不重复添加）
  Future<void> _initPresetTags() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _addResult('初始化预设标签', false, '用户未登录');
        setState(() => _isTesting = false);
        return;
      }

      _addResult('开始初始化', true, '正在获取家庭信息...');

      final memberRes = await _client
          .from('members')
          .select('household_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (memberRes == null) {
        _addResult('初始化预设标签', false, '用户未加入任何家庭');
        setState(() => _isTesting = false);
        return;
      }

      final householdId = memberRes['household_id'] as String;
      _addResult('获取家庭', true, '家庭ID: ${householdId.substring(0, 8)}...');

      // 预设标签列表（11种分类，共38个标签）
      final presetTags = [
        // 季节类（适用于衣物）
        {
          'name': '春装',
          'color': '#4CAF50',
          'icon': '🌸',
          'category': 'season',
          'types': ['clothing'],
        },
        {
          'name': '夏装',
          'color': '#FF9800',
          'icon': '☀️',
          'category': 'season',
          'types': ['clothing'],
        },
        {
          'name': '秋装',
          'color': '#795548',
          'icon': '🍂',
          'category': 'season',
          'types': ['clothing'],
        },
        {
          'name': '冬装',
          'color': '#2196F3',
          'icon': '❄️',
          'category': 'season',
          'types': ['clothing'],
        },

        // 颜色类（适用于所有）
        {
          'name': '深色',
          'color': '#424242',
          'icon': '⬛',
          'category': 'color',
          'types': [],
        },
        {
          'name': '浅色',
          'color': '#9E9E9E',
          'icon': '⬜',
          'category': 'color',
          'types': [],
        },
        {
          'name': '红色',
          'color': '#F44336',
          'icon': '🔴',
          'category': 'color',
          'types': [],
        },
        {
          'name': '蓝色',
          'color': '#2196F3',
          'icon': '🔵',
          'category': 'color',
          'types': [],
        },

        // 状态类（适用于所有）
        {
          'name': '全新',
          'color': '#4CAF50',
          'icon': '🆕',
          'category': 'status',
          'types': [],
        },
        {
          'name': '正常使用',
          'color': '#2196F3',
          'icon': '✅',
          'category': 'status',
          'types': [],
        },
        {
          'name': '有些磨损',
          'color': '#FF9800',
          'icon': '⚠️',
          'category': 'status',
          'types': [],
        },
        {
          'name': '需要维修',
          'color': '#F44336',
          'icon': '❌',
          'category': 'status',
          'types': [],
        },

        // 保修类（适用于家电）
        {
          'name': '在保修期内',
          'color': '#4CAF50',
          'icon': '🛡️',
          'category': 'warranty',
          'types': ['appliance'],
        },
        {
          'name': '保修即将到期',
          'color': '#FF9800',
          'icon': '⏰',
          'category': 'warranty',
          'types': ['appliance'],
        },
        {
          'name': '保修已过期',
          'color': '#9E9E9E',
          'icon': '❌',
          'category': 'warranty',
          'types': ['appliance'],
        },

        // 归属类（适用于所有）
        {
          'name': '我的',
          'color': '#2196F3',
          'icon': '👤',
          'category': 'ownership',
          'types': [],
        },
        {
          'name': '家人专属',
          'color': '#E91E63',
          'icon': '👨‍👩‍👧',
          'category': 'ownership',
          'types': [],
        },
        {
          'name': '共用',
          'color': '#4CAF50',
          'icon': '🔄',
          'category': 'ownership',
          'types': [],
        },
        {
          'name': '借出',
          'color': '#FF9800',
          'icon': '📤',
          'category': 'ownership',
          'types': [],
        },
        {
          'name': '借入',
          'color': '#9C27B0',
          'icon': '📥',
          'category': 'ownership',
          'types': [],
        },

        // 存放方式类（适用于所有）
        {
          'name': '收纳箱',
          'color': '#795548',
          'icon': '📦',
          'category': 'storage',
          'types': [],
        },
        {
          'name': '抽屉',
          'color': '#607D8B',
          'icon': '🗄️',
          'category': 'storage',
          'types': [],
        },
        {
          'name': '柜子',
          'color': '#795548',
          'icon': '🚪',
          'category': 'storage',
          'types': [],
        },
        {
          'name': '悬挂',
          'color': '#2196F3',
          'icon': '🧥',
          'category': 'storage',
          'types': [],
        },
        {
          'name': '堆叠',
          'color': '#FF9800',
          'icon': '📚',
          'category': 'storage',
          'types': [],
        },

        // 使用频率类（适用于所有）
        {
          'name': '常用',
          'color': '#4CAF50',
          'icon': '🔥',
          'category': 'frequency',
          'types': [],
        },
        {
          'name': '偶尔用',
          'color': '#2196F3',
          'icon': '🔶',
          'category': 'frequency',
          'types': [],
        },
        {
          'name': '很少用',
          'color': '#9E9E9E',
          'icon': '📦',
          'category': 'frequency',
          'types': [],
        },

        // 价值类（适用于所有）
        {
          'name': '高价值',
          'color': '#F44336',
          'icon': '💎',
          'category': 'value',
          'types': [],
        },
        {
          'name': '纪念品',
          'color': '#9C27B0',
          'icon': '🏆',
          'category': 'value',
          'types': [],
        },
        {
          'name': '便宜货',
          'color': '#4CAF50',
          'icon': '💵',
          'category': 'value',
          'types': [],
        },

        // 来源类（适用于所有）
        {
          'name': '购买',
          'color': '#2196F3',
          'icon': '🛒',
          'category': 'source',
          'types': [],
        },
        {
          'name': '礼物',
          'color': '#E91E63',
          'icon': '🎁',
          'category': 'source',
          'types': [],
        },
        {
          'name': '二手',
          'color': '#795548',
          'icon': '♻️',
          'category': 'source',
          'types': [],
        },
        {
          'name': '自己制作',
          'color': '#4CAF50',
          'icon': '✂️',
          'category': 'source',
          'types': [],
        },
        {
          'name': '奖品',
          'color': '#FF9800',
          'icon': '🏅',
          'category': 'source',
          'types': [],
        },

        // 处理意向类（适用于所有）
        {
          'name': '保留',
          'color': '#2196F3',
          'icon': '💾',
          'category': 'disposition',
          'types': [],
        },
        {
          'name': '送人',
          'color': '#E91E63',
          'icon': '🎁',
          'category': 'disposition',
          'types': [],
        },
        {
          'name': '捐赠',
          'color': '#4CAF50',
          'icon': '♻️',
          'category': 'disposition',
          'types': [],
        },
        {
          'name': '变卖',
          'color': '#FF9800',
          'icon': '💰',
          'category': 'disposition',
          'types': [],
        },
        {
          'name': '丢弃',
          'color': '#9E9E9E',
          'icon': '🗑️',
          'category': 'disposition',
          'types': [],
        },
      ];

      // 查询已存在的标签
      _addResult('查询已存在标签', true, '正在检查...');
      final existingTags = await _client
          .from('item_tags')
          .select('name')
          .eq('household_id', householdId);

      final existingNames = existingTags
          .map((e) => e['name'] as String)
          .toSet();
      _addResult('查询已存在标签', true, '已有 ${existingNames.length} 个标签');

      // 统计
      int added = 0;
      int skipped = 0;

      // 插入不存在的标签
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
            'applicable_types': tag['types'],
          });
          added++;
        } catch (e) {
          _addResult('插入标签', false, '${tag['name']}: $e');
        }
      }

      _addResult('初始化完成', true, '新增 $added 个标签，跳过 $skipped 个已存在');

      // 显示分类统计
      final categoryCount = <String, int>{};
      for (final tag in presetTags) {
        final cat = tag['category'] as String;
        categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
      }

      final categoryLabels = {
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
      };

      for (final entry in categoryCount.entries) {
        final label = categoryLabels[entry.key] ?? entry.key;
        _addResult('分类 $label', true, '${entry.value} 个标签');
      }
    } catch (e) {
      _addResult('初始化预设标签', false, '错误: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  /// 初始化预设类型（幂等性：重复执行不重复添加）
  Future<void> _initPresetTypes() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    try {
      // 预设类型列表（21种）
      final presetTypes = [
        {
          'key': 'clothing',
          'label': '衣物',
          'icon': '👕',
          'color': '#E91E63',
          'order': 1,
        },
        {
          'key': 'appliance',
          'label': '家电',
          'icon': '🔌',
          'color': '#2196F3',
          'order': 2,
        },
        {
          'key': 'furniture',
          'label': '家具',
          'icon': '🛋️',
          'color': '#795548',
          'order': 3,
        },
        {
          'key': 'daily',
          'label': '日用品',
          'icon': '🧴',
          'color': '#4CAF50',
          'order': 4,
        },
        {
          'key': 'tableware',
          'label': '餐具',
          'icon': '🍽️',
          'color': '#FF9800',
          'order': 5,
        },
        {
          'key': 'food',
          'label': '食品调料',
          'icon': '🥫',
          'color': '#8BC34A',
          'order': 6,
        },
        {
          'key': 'bedding',
          'label': '床上用品',
          'icon': '🛏️',
          'color': '#9C27B0',
          'order': 7,
        },
        {
          'key': 'electronics',
          'label': '电子数码',
          'icon': '📱',
          'color': '#3F51B5',
          'order': 8,
        },
        {
          'key': 'book',
          'label': '书籍',
          'icon': '📚',
          'color': '#673AB7',
          'order': 9,
        },
        {
          'key': 'decoration',
          'label': '装饰品',
          'icon': '🖼️',
          'color': '#00BCD4',
          'order': 10,
        },
        {
          'key': 'tool',
          'label': '工具',
          'icon': '🔧',
          'color': '#607D8B',
          'order': 11,
        },
        {
          'key': 'medicine',
          'label': '药品',
          'icon': '💊',
          'color': '#F44336',
          'order': 12,
        },
        {
          'key': 'sports',
          'label': '运动器材',
          'icon': '⚽',
          'color': '#00BCD4',
          'order': 13,
        },
        {
          'key': 'toy',
          'label': '玩具',
          'icon': '🎮',
          'color': '#FF5722',
          'order': 14,
        },
        {
          'key': 'jewelry',
          'label': '珠宝首饰',
          'icon': '💍',
          'color': '#FFD700',
          'order': 15,
        },
        {
          'key': 'pet',
          'label': '宠物用品',
          'icon': '🐕',
          'color': '#8D6E63',
          'order': 16,
        },
        {
          'key': 'garden',
          'label': '园艺绿植',
          'icon': '🌱',
          'color': '#4CAF50',
          'order': 17,
        },
        {
          'key': 'automotive',
          'label': '车载物品',
          'icon': '🚗',
          'color': '#455A64',
          'order': 18,
        },
        {
          'key': 'stationery',
          'label': '文具办公',
          'icon': '📎',
          'color': '#78909C',
          'order': 19,
        },
        {
          'key': 'consumables',
          'label': '消耗品',
          'icon': '🧻',
          'color': '#90A4AE',
          'order': 20,
        },
        {
          'key': 'other',
          'label': '其他',
          'icon': '📦',
          'color': '#9E9E9E',
          'order': 99,
        },
      ];

      // 初始化全局预设类型（household_id = NULL）
      // 这些类型对所有用户可见，无需加入家庭即可使用

      // 查询已存在的全局预设类型
      _addResult('查询全局预设类型', true, '正在检查...');
      final existingTypes = await _client
          .from('item_type_configs')
          .select('type_key')
          .isFilter('household_id', null);

      final existingKeys = existingTypes
          .map((e) => e['type_key'] as String)
          .toSet();
      _addResult('查询全局预设类型', true, '已有 ${existingKeys.length} 个全局预设类型');

      // 统计
      int added = 0;
      int skipped = 0;

      // 插入不存在的全局预设类型
      for (final type in presetTypes) {
        if (existingKeys.contains(type['key'])) {
          skipped++;
          continue;
        }

        try {
          await _client.from('item_type_configs').insert({
            'household_id': null, // 全局预设类型
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

      _addResult('初始化完成', true, '新增 $added 个全局预设类型，跳过 $skipped 个已存在');
      _addResult('提示', true, '全局预设类型对所有用户可见，无需加入家庭');
    } catch (e) {
      _addResult('初始化预设类型', false, '错误: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<Map<String, String>> _getLocationIds(String householdId) async {
    final res = await _client
        .from('item_locations')
        .select('id, path')
        .eq('household_id', householdId);

    return {for (var e in res) e['path'] as String: e['id'] as String};
  }

  Future<void> _generateItems(
    String householdId,
    Map<String, String> locationIds,
  ) async {
    final items = [
      {
        'name': 'TCL 电视',
        'type': 'appliance',
        'location': 'living-room.tv-cabinet',
        'brand': 'TCL',
        'price': 2999.0,
        'desc': '55寸智能电视',
      },
      {
        'name': '美的空调',
        'type': 'appliance',
        'location': 'living-room',
        'brand': '美的',
        'price': 4500.0,
        'desc': '客厅立式空调',
      },
      {
        'name': '西门子冰箱',
        'type': 'appliance',
        'location': 'kitchen.fridge',
        'brand': '西门子',
        'price': 8000.0,
        'desc': '对开门冰箱',
      },
      {
        'name': '小米扫地机器人',
        'type': 'appliance',
        'location': 'living-room',
        'brand': '小米',
        'price': 3500.0,
        'desc': '智能扫拖一体',
      },
      {
        'name': '戴森吸尘器',
        'type': 'daily',
        'location': 'living-room',
        'brand': '戴森',
        'price': 5000.0,
        'desc': 'V15吸尘器',
      },
      {
        'name': '小米空气净化器',
        'type': 'daily',
        'location': 'master-bedroom',
        'brand': '小米',
        'price': 1500.0,
        'desc': '卧室用',
      },
      {
        'name': '真皮沙发',
        'type': 'furniture',
        'location': 'living-room.sofa',
        'brand': '顾家',
        'price': 12000.0,
        'desc': 'L型真皮沙发',
      },
      {
        'name': '实木书桌',
        'type': 'furniture',
        'location': 'study-room',
        'brand': '宜家',
        'price': 2000.0,
        'desc': '橡木书桌',
      },
      {
        'name': '双人床',
        'type': 'furniture',
        'location': 'master-bedroom',
        'brand': '慕思',
        'price': 6000.0,
        'desc': '1.8米双人床',
      },
      {
        'name': '羽绒服',
        'type': 'clothing',
        'location': 'master-bedroom.closet',
        'brand': '波司登',
        'price': 1500.0,
        'desc': '黑色中长款',
      },
      {
        'name': 'T恤',
        'type': 'clothing',
        'location': 'master-bedroom.closet',
        'brand': '优衣库',
        'price': 99.0,
        'desc': '纯棉白T恤',
      },
      {
        'name': '牛仔裤',
        'type': 'clothing',
        'location': 'master-bedroom.closet',
        'brand': "Levi's",
        'price': 800.0,
        'desc': '蓝色直筒裤',
      },
      {
        'name': '骨瓷餐具套装',
        'type': 'tableware',
        'location': 'kitchen.cabinet',
        'brand': '康宁',
        'price': 1200.0,
        'desc': '36件套',
      },
      {
        'name': '不锈钢炒锅',
        'type': 'tableware',
        'location': 'kitchen.cabinet',
        'brand': '苏泊尔',
        'price': 300.0,
        'desc': '32cm炒锅',
      },
      {
        'name': '电钻',
        'type': 'tool',
        'location': 'kitchen',
        'brand': '博世',
        'price': 800.0,
        'desc': '充电式电钻',
      },
      {
        'name': '工具箱',
        'type': 'tool',
        'location': 'kitchen.cabinet',
        'brand': '史丹利',
        'price': 500.0,
        'desc': '基础工具套装',
      },
      {
        'name': '三体',
        'type': 'book',
        'location': 'study-room',
        'brand': '重庆出版社',
        'price': 68.0,
        'desc': '科幻小说',
      },
      {
        'name': '人类简史',
        'type': 'book',
        'location': 'study-room',
        'brand': '中信出版社',
        'price': 68.0,
        'desc': '历史科普',
      },
      {
        'name': '金字塔原理',
        'type': 'book',
        'location': 'study-room',
        'brand': '民主与建设出版社',
        'price': 59.0,
        'desc': '商务写作',
      },
      {
        'name': '跑步机',
        'type': 'sports',
        'location': 'living-room',
        'brand': '舒华',
        'price': 4000.0,
        'desc': '家用折叠跑步机',
      },
      {
        'name': '瑜伽垫',
        'type': 'sports',
        'location': 'living-room',
        'brand': 'Keep',
        'price': 200.0,
        'desc': '加厚隔音垫',
      },
      {
        'name': '落地灯',
        'type': 'decoration',
        'location': 'living-room.sofa',
        'brand': 'IKEA',
        'price': 499.0,
        'desc': '北欧风格',
      },
      {
        'name': '绿植',
        'type': 'decoration',
        'location': 'living-room',
        'price': 150.0,
        'desc': '龟背竹',
      },
      {
        'name': 'Switch',
        'type': 'toy',
        'location': 'living-room.tv-cabinet',
        'brand': '任天堂',
        'price': 2500.0,
        'desc': 'OLED版',
      },
      {
        'name': '乐高积木',
        'type': 'toy',
        'location': 'master-bedroom.nightstand',
        'brand': 'LEGO',
        'price': 600.0,
        'desc': '城市系列',
      },
      {
        'name': '创可贴',
        'type': 'medicine',
        'location': 'bathroom',
        'brand': '云南白药',
        'price': 5.0,
        'desc': '防水型',
      },
      {
        'name': '维生素C',
        'type': 'medicine',
        'location': 'bathroom',
        'brand': '汤臣倍健',
        'price': 120.0,
        'desc': '咀嚼片',
      },
    ];

    for (final item in items) {
      try {
        await _client.from('household_items').insert({
          'household_id': householdId,
          'name': item['name'],
          'description': item['desc'],
          'item_type': item['type'],
          'location_id': locationIds[item['location']],
          'brand': item['brand'],
          'purchase_price': item['price'],
          'quantity': 1,
          'condition': 'good',
          'sync_status': 'synced',
        });
      } catch (e) {
        _addResult('生成物品', false, '错误: ${e.toString()}');
      }
    }
  }

  Future<void> _generateTagRelations(String householdId) async {
    final tagRes = await _client
        .from('item_tags')
        .select('id, name')
        .eq('household_id', householdId);
    final tagMap = {
      for (var e in tagRes) e['name'] as String: e['id'] as String,
    };

    final itemRes = await _client
        .from('household_items')
        .select('id, name, item_type')
        .eq('household_id', householdId);
    final itemMap = {
      for (var e in itemRes) e['name'] as String: e['id'] as String,
    };

    final relations = [
      {
        'item': '羽绒服',
        'tags': ['冬装', '深色'],
      },
      {
        'item': 'T恤',
        'tags': ['夏装'],
      },
      {
        'item': '牛仔裤',
        'tags': ['深色'],
      },
      {
        'item': '跑步机',
        'tags': ['待处理'],
      },
      {
        'item': '小米扫地机器人',
        'tags': ['新品'],
      },
      {
        'item': 'Switch',
        'tags': ['已借出'],
      },
    ];

    for (final rel in relations) {
      final itemId = itemMap[rel['item']];
      if (itemId == null) continue;

      for (final tagName in rel['tags'] as List<String>) {
        final tagId = tagMap[tagName];
        if (tagId == null) continue;

        try {
          await _client.from('item_tag_relations').insert({
            'item_id': itemId,
            'tag_id': tagId,
          });
        } catch (_) {}
      }
    }
  }

  Future<void> _deleteTestData() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _addResult('删除测试数据', false, '用户未登录');
        setState(() => _isTesting = false);
        return;
      }

      final memberRes = await _client
          .from('members')
          .select('household_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (memberRes == null) {
        _addResult('删除测试数据', false, '用户未加入任何家庭');
        setState(() => _isTesting = false);
        return;
      }

      final householdId = memberRes['household_id'] as String;
      _addResult('开始删除', true, '正在删除测试数据（仅测试数据）...');

      // 只删除名称匹配的测试数据
      await _cleanupTestData(householdId);

      _addResult('🎉 完成', true, '测试数据清理完成！');
    } catch (e) {
      _addResult('删除测试数据', false, '错误: ${e.toString()}');
    }

    setState(() => _isTesting = false);
  }

  Future<void> _testDirectConnection() async {
    try {
      final response = await _client.from('households').select('id').limit(1);
      _addResult('直接连接测试', true, '连接成功');
    } catch (e) {
      _addResult('直接连接测试', false, '错误: ${e.toString()}');
    }
  }

  Future<void> _testHouseholdsTable() async {
    try {
      final response = await _client.from('households').select('*').limit(3);
      _addResult('households 表', true, '查询成功: ${response.length} 条记录');
    } catch (e) {
      _addResult('households 表', false, '错误: ${e.toString()}');
    }
  }

  Future<void> _testMembersTable() async {
    try {
      final response = await _client.from('members').select('*').limit(3);
      _addResult('members 表', true, '查询成功: ${response.length} 条记录');
    } catch (e) {
      _addResult('members 表', false, '错误: ${e.toString()}');
    }
  }

  void _addResult(String testName, bool success, String message) {
    setState(() {
      _results.add(
        TestResult(
          testName: testName,
          success: success,
          message: message,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Supabase 测试'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isTesting ? null : _generateTestData,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add_box),
                          label: Text(_isTesting ? '生成中...' : '生成测试物品'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryGold,
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTesting ? null : _deleteTestData,
                          icon: const Icon(Icons.delete_outline),
                          label: Text(_isTesting ? '删除中...' : '删除测试物品'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _isTesting ? null : _runTests,
                      icon: const Icon(Icons.directions_run),
                      label: const Text('运行基础测试'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isTesting ? null : _initPresetTypes,
                      icon: const Icon(Icons.category_outlined),
                      label: const Text('初始化预设类型'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '初始化21种全局预设类型（所有用户可见，幂等执行不重复添加）',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 80,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '点击按钮生成测试数据',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '将创建：12个位置、12个标签、27个物品、6组标签关联',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
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
                                color: result.success
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                result.success
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: result.success
                                    ? Colors.green
                                    : Colors.red,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              result.testName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              result.message,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Text(
                              _formatTime(result.timestamp),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class TestResult {
  final String testName;
  final bool success;
  final String message;
  final DateTime timestamp;

  TestResult({
    required this.testName,
    required this.success,
    required this.message,
    required this.timestamp,
  });
}
