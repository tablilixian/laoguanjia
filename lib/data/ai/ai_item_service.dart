import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/household_item.dart';
import '../models/item_location.dart';
import '../supabase/supabase_client.dart';
import 'ai_models.dart';
import 'ai_settings_service.dart';

class AIItemService {
  final AISettingsService _settings;
  final String _userId;

  AIItemService(this._settings, this._userId);

  static const Map<String, String> _typeKeywords = {
    'appliance': '电视,空调,冰箱,洗衣机,微波炉,电饭煲,扫地机器人,吸尘器,净化器,路由器,打印机,电脑,笔记本,手机,平板,耳机,音响,投影仪,热水器,电暖器,风扇,电吹风,剃须刀,榨汁机,豆浆机,咖啡机,面包机,电磁炉,电饼铛,烤箱,空气炸锅,洗碗机,干衣机',
    'furniture': '沙发,床,衣柜,书柜,餐桌,餐椅,茶几,电视柜,鞋柜,梳妆台,床头柜,书桌,椅子,凳子,储物柜,置物架,花架,屏风,沙发床,折叠床,儿童床,上下床',
    'clothing': '衣服,裤子,裙子,衬衫,T恤,外套,羽绒服,大衣,西装,运动服,睡衣,内衣,袜子,帽子,围巾,手套,皮带,领带,围巾,披肩,外套',
    'tableware': '碗,盘子,杯子,筷子,勺子,叉子,刀,锅,炒锅,煎锅,汤锅,蒸锅,高压锅,砂锅,茶具,酒具,保温杯,水杯,果盘,调味瓶',
    'tool': '螺丝刀,锤子,扳手,钳子,电钻,锯子,尺子,墨斗,水平仪,工具箱,梯子,吸盘,钉子,螺丝,螺母,膨胀螺栓,胶水,透明胶,双面胶,剪刀,美工刀',
    'book': '书,书籍,小说,杂志,漫画,词典,字典,教材,课本,绘本,儿童书,相册,日历,笔记本,日记本',
    'decoration': '画,照片,相框,花瓶,绿植,盆栽,时钟,台灯,落地灯,装饰画,雕塑,风铃,香薰,蜡烛,抱枕,靠垫,窗帘,地毯,挂毯',
    'sports': '自行车,跑步机,瑜伽垫,哑铃,杠铃,跳绳,球拍,羽毛球,乒乓球,篮球,足球,网球,高尔夫,滑雪板,泳镜,泳帽,泳衣,健身器材,动感单车,椭圆机',
    'toy': '玩具,积木,乐高,游戏机,switch,ps5,xbox,玩具车,玩具枪,玩偶,毛绒玩具,芭比娃娃,变形金刚,遥控车,无人机,拼图,棋牌,麻将',
    'medicine': '药,药品,创可贴,纱布,体温计,血压计,血糖仪,维生素,钙片,感冒药,退烧药,止咳药,消炎药,肠胃药,眼药水,酒精,消毒液,口罩',
    'daily': '洗发水,沐浴露,牙膏,牙刷,毛巾,纸巾,湿巾,卫生纸,洗衣液,洗洁精,清洁剂,护肤品,化妆品,香水,剃须刀,梳子,镜子,垃圾桶,垃圾袋,保鲜膜,保鲜袋',
  };

  Future<String> parseAndCreateItems(String userMessage, String householdId) async {
    final apiKey = await _settings.getApiKey(await _settings.getProvider());
    final model = await _settings.getSelectedModel();
    
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 API Key');
    }

    final locationPrompt = await _buildLocationContext(householdId);
    final typesPrompt = _buildTypesContext();
    final parsePrompt = '''
你是一个家庭物品管理助手。请从用户的消息中提取要保存的物品信息。

$locationPrompt

$typesPrompt

用户消息：$userMessage

请分析用户消息，提取：
1. 物品名称列表
2. 物品要保存的位置（匹配上面的位置名称）
3. 每个物品的类型（从类型列表中选择最合适的）

请以 JSON 格式返回，格式如下：
```json
{
  "location": "匹配到的位置名称，如果没有匹配到返回 null",
  "items": [
    {"name": "物品名称", "type": "类型键，如 appliance, furniture 等"},
    ...
  ]
}
```

注意：
- 只返回 JSON，不要有任何其他内容
- 如果用户没有指定位置，location 设为 null
- 物品名称要简洁，去除数量词（如"一台电视" -> "电视"）
- 类型必须从上面的类型列表中选择

返回 JSON：
''';

    final parseResult = await _callAI(apiKey, model!.id, parsePrompt);
    final parsed = _parseJSONResult(parseResult);

    if (parsed['items'] == null || (parsed['items'] as List).isEmpty) {
      return '抱歉，我没有理解您要保存的物品。请尝试说"帮我把电视和冰箱保存到客厅"。';
    }

    final locationName = parsed['location'] as String?;
    String? locationId;
    
    print('DEBUG: locationName = $locationName');
    
    if (locationName != null) {
      final location = await _findLocation(householdId, locationName);
      print('DEBUG: location = $location');
      if (location == null) {
        return '抱歉，我没有找到位置"$locationName"。请先在位置管理中添加这个位置。';
      }
      locationId = location.id;
      print('DEBUG: locationId = $locationId');
    } else {
      return '抱歉，我没有理解您要把物品保存到哪里。请说"帮我把XX保存到客厅"。';
    }

    final itemsData = parsed['items'] as List;
    print('DEBUG: itemsData = $itemsData');
    final itemsToCreate = <HouseholdItem>[];

    for (final itemData in itemsData) {
      final name = itemData['name'] as String;
      final type = itemData['type'] as String? ?? 'other';
      print('DEBUG: Creating item - name: $name, type: $type, locationId: $locationId');
      
      itemsToCreate.add(HouseholdItem(
        id: '',
        householdId: householdId,
        name: name,
        itemType: type,
        locationId: locationId,
        quantity: 1,
        condition: ItemCondition.good,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    print('DEBUG: About to create ${itemsToCreate.length} items');
    final createdItems = await _createItems(itemsToCreate);
    print('DEBUG: Created ${createdItems.length} items');
    return _buildSuccessMessage(createdItems, locationName);
  }

  Future<String> _buildLocationContext(String householdId) async {
    final client = SupabaseClientManager.client;
    final response = await client
        .from('item_locations')
        .select('name')
        .eq('household_id', householdId)
        .order('name');

    final locations = (response as List).map((e) => e['name'] as String).toList();
    
    if (locations.isEmpty) {
      return '注意：当前家庭还没有创建任何位置。';
    }
    
    return '当前家庭已创建的位置：${locations.join(", ")}';
  }

  String _buildTypesContext() {
    final buffer = StringBuffer('可选的物品类型：\n');
    for (final entry in _typeKeywords.entries) {
      buffer.writeln('- ${entry.key}: ${entry.value.split(',').take(5).join(', ')}...');
    }
    return buffer.toString();
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

  Future<String> _callGemini(String apiKey, String modelId, String prompt) async {
    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{
          'parts': [{'text': prompt}]
        }]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI 调用失败: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'];
  }

  Future<String> _callZhipu(String apiKey, String modelId, String prompt) async {
    final response = await http.post(
      Uri.parse('https://open.bigmodel.cn/api/paas/v4/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': modelId,
        'messages': [{'role': 'user', 'content': prompt}]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI 调用失败: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  }

  Map<String, dynamic> _parseJSONResult(String result) {
    try {
      final jsonMatch = RegExp(r'```json\n?([\s\S]*?)\n?```').firstMatch(result);
      final jsonStr = jsonMatch != null ? jsonMatch.group(1)! : result;
      return jsonDecode(jsonStr);
    } catch (e) {
      return {'location': null, 'items': []};
    }
  }

  Future<ItemLocation?> _findLocation(String householdId, String name) async {
    final client = SupabaseClientManager.client;
    
    final response = await client
        .from('item_locations')
        .select()
        .eq('household_id', householdId)
        .ilike('name', '%$name%')
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return ItemLocation.fromMap(response);
  }

  Future<List<HouseholdItem>> _createItems(List<HouseholdItem> items) async {
    if (items.isEmpty) return [];

    final client = SupabaseClientManager.client;
    final data = items.map((item) => {
      'household_id': item.householdId,
      'name': item.name,
      'item_type': item.itemType,
      'location_id': item.locationId,
      'quantity': item.quantity,
      'condition': item.condition.dbValue,
      'sync_status': 'synced',
    }).toList();

    print('DEBUG: Inserting items: $data');

    try {
      final response = await client
          .from('household_items')
          .insert(data)
          .select();

      print('DEBUG: Insert response: $response');
      return (response as List).map((e) => HouseholdItem.fromMap(e)).toList();
    } catch (e) {
      print('DEBUG: Insert error: $e');
      rethrow;
    }
  }

  String _buildSuccessMessage(List<HouseholdItem> items, String locationName) {
    if (items.isEmpty) {
      return '物品保存失败，请重试。';
    }

    final typeLabels = {
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

    final buffer = StringBuffer();
    buffer.writeln('已为您保存以下物品到 $locationName：');
    buffer.writeln();

    for (final item in items) {
      final typeLabel = typeLabels[item.itemType] ?? '其他';
      buffer.writeln('✅ ${item.name} ($typeLabel)');
    }

    buffer.writeln();
    buffer.write('共 ${items.length} 件物品已保存！');

    return buffer.toString();
  }
}
