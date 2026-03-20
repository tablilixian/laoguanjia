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
class BatchItem {
  final String name;
  final int quantity;
  final String type;
  final String typeLabel;
  final bool isNewType;

  BatchItem({
    required this.name,
    required this.quantity,
    required this.type,
    required this.typeLabel,
    this.isNewType = false,
  });

  BatchItem copyWith({
    String? name,
    int? quantity,
    String? type,
    String? typeLabel,
    bool? isNewType,
  }) {
    return BatchItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      type: type ?? this.type,
      typeLabel: typeLabel ?? this.typeLabel,
      isNewType: isNewType ?? this.isNewType,
    );
  }
}

class BatchAddService {
  final AISettingsService _settings;

  BatchAddService(this._settings);

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
    if (itemCount > 20) {
      throw Exception('输入的物品种类过多（${itemCount}种），请分批输入，每次最多20种');
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
用户会输入一系列物品，可能包含数量信息，例如：
- 热水器一个，浴霸一个，洗脸盆8个，马桶一个，沐浴露一瓶
- 电视机 2台，空调 3台，冰箱 1台

## 现有物品类型
$typesDescription

## 输出要求
请以 JSON 数组格式返回，每个物品包含以下字段：
- name: 物品名称（简洁，去除数量词如"一台"、"一个"）
- quantity: 数量（数字）
- type: 类型键名（优先使用现有类型，如无法匹配可创建新类型）
- typeLabel: 类型显示名称（如果是新类型，使用中文描述）

## 注意事项
1. 物品名称要简洁，例如"一台电视机" -> "电视机"
2. 如果没有明确数量，默认为1
3. 如果物品类型无法匹配现有类型，创建新类型，但要简洁明了
4. 最多返回20个物品

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

        // 检查是否是新类型
        final isNewType = !_typeKeywords.containsKey(type);

        items.add(
          BatchItem(
            name: name,
            quantity: quantity,
            type: type,
            typeLabel: typeLabel,
            isNewType: isNewType,
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
