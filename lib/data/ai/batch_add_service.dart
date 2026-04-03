import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/household_item.dart';
import '../models/item_location.dart';
import '../supabase/supabase_client.dart';
import 'ai_models.dart';
import 'ai_settings_service.dart';

/// 批量解析结果
class BatchParseResult {
  final List<BatchItem> items;
  final List<String> newTypes; // AI 新识别的类型

  BatchParseResult({required this.items, required this.newTypes});
}

/// 批量物品数据
///
/// 用于批量录入流程中的中间态物品表示。
/// 支持归属人、颜色、季节等扩展字段，以便在保存时映射到 tags_mask 和 owner_id。
class BatchItem {
  /// 物品名称（如 "T恤"、"牛仔裤"）
  final String name;

  /// 物品数量
  final int quantity;

  /// 物品类型键（引用 item_type_configs.type_key，如 "clothing"）
  final String type;

  /// 物品类型显示名称（如 "衣物"）
  final String typeLabel;

  /// 是否为新类型（不在预设类型列表中）
  final bool isNewType;

  /// 归属人成员ID（关联 members 表，null 表示不指定归属人）
  final String? ownerId;

  /// 归属人显示名称（用于 UI 展示，不存储到数据库）
  final String? ownerName;

  /// 颜色标签名称（如 "蓝色"、"红色"，保存时映射到 tags_mask）
  final String? color;

  /// 季节标签名称（如 "夏季"、"冬季"，保存时映射到 tags_mask）
  final String? season;

  BatchItem({
    required this.name,
    required this.quantity,
    required this.type,
    required this.typeLabel,
    this.isNewType = false,
    this.ownerId,
    this.ownerName,
    this.color,
    this.season,
  });

  /// 创建副本并选择性替换字段
  BatchItem copyWith({
    String? name,
    int? quantity,
    String? type,
    String? typeLabel,
    bool? isNewType,
    String? ownerId,
    String? ownerName,
    String? color,
    String? season,
  }) {
    return BatchItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      type: type ?? this.type,
      typeLabel: typeLabel ?? this.typeLabel,
      isNewType: isNewType ?? this.isNewType,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      color: color ?? this.color,
      season: season ?? this.season,
    );
  }
}

class BatchAddService {
  final AISettingsService _settings;

  BatchAddService(this._settings);

  /// 季节名称归一化映射：将用户/ AI 可能输入的变体映射到标准标签名
  /// 标准标签名：春装、夏装、秋装、冬装、四季
  static const Map<String, String> _seasonNormalize = {
    '春': '春装',
    '春天': '春装',
    '春季': '春装',
    '春装': '春装',
    '夏': '夏装',
    '夏天': '夏装',
    '夏季': '夏装',
    '夏装': '夏装',
    '秋': '秋装',
    '秋天': '秋装',
    '秋季': '秋装',
    '秋装': '秋装',
    '冬': '冬装',
    '冬天': '冬装',
    '冬季': '冬装',
    '冬装': '冬装',
    '四季': '四季',
    '四季通用': '四季',
    '全年': '四季',
  };

  /// 颜色名称归一化映射：将用户/ AI 可能输入的变体映射到标准标签名
  static const Map<String, String> _colorNormalize = {
    '黑': '黑色',
    '黑色': '黑色',
    '纯黑': '黑色',
    '白': '白色',
    '白色': '白色',
    '纯白': '白色',
    '米白': '白色',
    '红': '红色',
    '红色': '红色',
    '大红': '红色',
    '酒红': '红色',
    '蓝': '蓝色',
    '蓝色': '蓝色',
    '深蓝': '蓝色',
    '浅蓝': '蓝色',
    '天蓝': '蓝色',
    '灰': '灰色',
    '灰色': '灰色',
    '银灰': '灰色',
    '绿': '绿色',
    '绿色': '绿色',
    '草绿': '绿色',
    '军绿': '绿色',
    '墨绿': '绿色',
    '棕': '棕色',
    '棕色': '棕色',
    '卡其': '棕色',
    '卡其色': '棕色',
    '驼色': '棕色',
    '粉': '粉色',
    '粉色': '粉色',
    '粉红': '粉色',
    '黄': '黄色',
    '黄色': '黄色',
    '金黄': '黄色',
    '米黄': '黄色',
    '藏青': '藏青色',
    '藏青色': '藏青色',
    '海军蓝': '藏青色',
  };

  /// 归一化季节名称
  static String? normalizeSeason(String? season) {
    if (season == null || season.isEmpty) return null;
    return _seasonNormalize[season.toLowerCase()];
  }

  /// 归一化颜色名称
  static String? normalizeColor(String? color) {
    if (color == null || color.isEmpty) return null;
    return _colorNormalize[color.toLowerCase()];
  }

  /// 现有类型关键词映射
  static const Map<String, String> _typeKeywords = {
    'appliance': '电器',
    'furniture': '家具',
    'clothing': '衣物',
    'tableware': '餐具',
    'tool': '工具',
    'book': '书籍',
    'decoration': '装饰',
    'sports': '运动',
    'toy': '玩具',
    'medicine': '药品',
    'daily': '日用品',
    'food': '食品',
    'bedding': '床品',
    'electronics': '电子产品',
    'jewelry': '首饰',
    'pet': '宠物用品',
    'garden': '园艺',
    'automotive': '汽车用品',
    'stationery': '文具',
    'consumables': '消耗品',
    'other': '其他',
  };

  /// 解析批量输入
  Future<BatchParseResult> parseInput(String input) async {
    final apiKey = await _settings.getApiKey(await _settings.getProvider());
    final model = await _settings.getSelectedModel();

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 API Key');
    }

    // 检查输入数量
    final itemCount = _estimateItemCount(input);
    if (itemCount > 40) {
      throw Exception('输入的物品种类过多（${itemCount}种），请分批输入，每次最多40种');
    }

    final prompt = _buildPrompt(input);
    final response = await _callAI(apiKey, model!.id, prompt);
    return _parseResponse(response);
  }

  /// 估算物品数量
  int _estimateItemCount(String input) {
    // 简单估算：按逗号、顿号、换行分隔
    final separators = [',', '，', '、', '\n', '；', ';'];
    int count = 1;
    for (final sep in separators) {
      count = input.split(sep).length;
      if (count > 1) break;
    }
    return count;
  }

  String _buildPrompt(String input) {
    final typesDescription = _typeKeywords.entries
        .map((e) => '${e.key}(${e.value})')
        .join('、');

    return '''
你是一个家庭物品管理助手。请从用户输入的文本中提取物品信息。

## 输入格式
用户会输入一系列物品，可能包含数量、归属人、颜色、季节等信息，例如：
- 热水器一个，浴霸一个，洗脸盆8个，马桶一个，沐浴露一瓶
- 电视机 2台，空调 3台，冰箱 1台
- 爸爸的蓝色夏季T恤一件，妈妈的红色冬季大衣一件，孩子的黄色秋季卫衣两件

## 现有物品类型
$typesDescription

## 输出要求
请以 JSON 数组格式返回，每个物品包含以下字段：
- name: 物品名称（简洁，去除数量词如"一台"、"一个"，去除归属人、颜色、季节等修饰词）
- quantity: 数量（数字）
- type: 类型键名（优先使用现有类型，如无法匹配可创建新类型）
- typeLabel: 类型显示名称（如果是新类型，使用中文描述）
- ownerId: 归属人ID（仅当用户明确指定归属人时才填写，如"爸爸"、"妈妈"等，否则留null）
- ownerName: 归属人名称（与ownerId对应，如"爸爸"、"妈妈"，否则留null）
- color: 颜色（必须使用以下标准名称之一：黑色、白色、红色、蓝色、灰色、绿色、棕色、粉色、黄色、藏青色，无法识别时留null）
- season: 季节（必须使用以下标准名称之一：春装、夏装、秋装、冬装、四季，无法识别时留null）

## 注意事项
1. 物品名称要简洁，例如"一台电视机" -> "电视机"，"爸爸的蓝色T恤" -> "T恤"
2. 如果没有明确数量，默认为1
3. 如果物品类型无法匹配现有类型，创建新类型，但要简洁明了
4. ownerId 和 ownerName 需要成对出现，如果无法确定归属人，两者都留null
5. color 和 season 必须使用上面列出的标准名称，不要输出"夏天"、"春天"等变体
6. 最多返回40个物品

用户输入：
$input

请返回 JSON 数组（不要有任何其他内容）：
''';
  }

  BatchParseResult _parseResponse(String response) {
    try {
      // 提取 JSON 部分
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();

      final List<dynamic> data = jsonDecode(jsonStr);
      final items = <BatchItem>[];
      final newTypes = <String>[];

      for (final item in data) {
        final name = item['name'] as String? ?? '';
        final quantity = item['quantity'] as int? ?? 1;
        final type = item['type'] as String? ?? 'other';
        final typeLabel = item['typeLabel'] as String? ?? '其他';

        // 解析扩展字段：归属人、颜色、季节
        final ownerId = item['ownerId'] as String?;
        final ownerName = item['ownerName'] as String?;
        // 归一化颜色和季节名称，将用户变体映射到标准标签名
        final color = normalizeColor(item['color'] as String?);
        final season = normalizeSeason(item['season'] as String?);

        // 检查是否是新类型
        final isNewType = !_typeKeywords.containsKey(type);

        items.add(
          BatchItem(
            name: name,
            quantity: quantity,
            type: type,
            typeLabel: typeLabel,
            isNewType: isNewType,
            ownerId: ownerId,
            ownerName: ownerName,
            color: color,
            season: season,
          ),
        );

        if (isNewType && !newTypes.contains(type)) {
          newTypes.add(type);
        }
      }

      return BatchParseResult(items: items, newTypes: newTypes);
    } catch (e) {
      throw Exception('解析 AI 响应失败: $e');
    }
  }

  Future<String> _callAI(String apiKey, String modelId, String prompt) async {
    final provider = await _settings.getProvider();

    switch (provider) {
      case AIProvider.gemini:
        return _callGemini(apiKey, modelId, prompt);
      case AIProvider.zhipu:
        return _callZhipu(apiKey, modelId, prompt);
    }
  }

  Future<String> _callGemini(
    String apiKey,
    String modelId,
    String prompt,
  ) async {
    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI 调用失败: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'];
  }

  Future<String> _callZhipu(
    String apiKey,
    String modelId,
    String prompt,
  ) async {
    final response = await http.post(
      Uri.parse('https://open.bigmodel.cn/api/paas/v4/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': modelId,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI 调用失败: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  }

  /// 批量保存物品
  Future<List<HouseholdItem>> saveItems(
    List<BatchItem> items,
    String householdId,
    String locationId,
  ) async {
    final client = SupabaseClientManager.client;
    final itemsToCreate = <Map<String, dynamic>>[];

    for (final item in items) {
      itemsToCreate.add({
        'household_id': householdId,
        'name': item.name,
        'quantity': item.quantity,
        'item_type': item.type,
        'location_id': locationId,
        'condition': 'good',
        'sync_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    final response = await client
        .from('household_items')
        .insert(itemsToCreate)
        .select();

    return (response as List).map((e) => HouseholdItem.fromMap(e)).toList();
  }
}
