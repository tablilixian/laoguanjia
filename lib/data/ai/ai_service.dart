import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_models.dart';
import 'ai_settings_service.dart';

class AIService {
  final AISettingsService _settings;

  AIService(this._settings);

  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    final provider = await _settings.getProvider();
    final model = await _settings.getSelectedModelForCapability(ModelCapability.chat);
    final apiKey = await _settings.getApiKey(provider);

    print(
      'AI Service - Provider: ${provider.name}, Model: ${model?.id}, HasKey: ${apiKey != null && apiKey.isNotEmpty}',
    );

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 ${provider.displayName} 的 API Key 并保存');
    }

    if (model == null) {
      throw Exception('请先在设置中选择对话模型');
    }

    switch (provider) {
      case AIProvider.gemini:
        return await _callGemini(apiKey, model.id, message, history);
      case AIProvider.zhipu:
        return await _callZhipu(apiKey, model.id, message, history);
    }
  }

  Stream<String> sendMessageStream(
    String message,
    List<ChatMessage> history,
  ) async* {
    final provider = await _settings.getProvider();
    final model = await _settings.getSelectedModelForCapability(ModelCapability.chat);
    final apiKey = await _settings.getApiKey(provider);

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 ${provider.displayName} 的 API Key 并保存');
    }

    if (model == null) {
      throw Exception('请先在设置中选择对话模型');
    }

    switch (provider) {
      case AIProvider.gemini:
        yield* _callGeminiStream(apiKey, model.id, message, history);
        break;
      case AIProvider.zhipu:
        yield* _callZhipuStream(apiKey, model.id, message, history);
        break;
    }
  }

  Future<String> _callGemini(
    String apiKey,
    String modelId,
    String message,
    List<ChatMessage> history,
  ) async {
    final model = GenerativeModel(model: modelId, apiKey: apiKey);

    final contents = <Content>[];

    for (final msg in history) {
      contents.add(
        Content(msg.isUser ? "user" : "model", [TextPart(msg.content)]),
      );
    }
    contents.add(Content.text(message));

    final response = await model.generateContent(contents);
    return response.text ?? '无响应';
  }

  Future<String> _callZhipu(
    String apiKey,
    String modelId,
    String message,
    List<ChatMessage> history,
  ) async {
    final url = Uri.parse(
      'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    );

    final messages = <Map<String, String>>[];

    for (final msg in history) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.content,
      });
    }
    messages.add({'role': 'user', 'content': message});

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'model': modelId, 'messages': messages}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? '智谱AI调用失败');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  }

  Stream<String> _callGeminiStream(
    String apiKey,
    String modelId,
    String message,
    List<ChatMessage> history,
  ) async* {
    final model = GenerativeModel(model: modelId, apiKey: apiKey);

    final contents = <Content>[];

    for (final msg in history) {
      contents.add(
        Content(msg.isUser ? "user" : "model", [TextPart(msg.content)]),
      );
    }
    contents.add(Content.text(message));

    final response = await model.generateContentStream(contents);

    await for (final chunk in response) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) {
        yield text;
      }
    }
  }

  Stream<String> _callZhipuStream(
    String apiKey,
    String modelId,
    String message,
    List<ChatMessage> history,
  ) async* {
    final url = Uri.parse(
      'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    );

    final messages = <Map<String, String>>[];

    for (final msg in history) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.content,
      });
    }
    messages.add({'role': 'user', 'content': message});

    final client = http.Client();
    final request = http.Request('POST', url);
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'model': modelId,
      'messages': messages,
      'stream': true,
    });

    final response = await client.send(request);

    await for (final chunk
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (chunk.startsWith('data: ')) {
        final data = chunk.substring(6);
        if (data == '[DONE]') break;
        try {
          final json = jsonDecode(data);
          final content = json['choices']?[0]?['delta']?['content'];
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (_) {}
      }
    }
    client.close();
  }

  /// 发送带图片的视觉理解请求
  Future<String> sendVisionMessage({
    required String imageUrlOrBase64,
    String? prompt,
    String? modelId,
  }) async {
    final provider = await _settings.getProvider();
    final model = modelId ?? (await _settings.getSelectedModelForCapability(ModelCapability.vision))?.id;
    final apiKey = await _settings.getApiKey(provider);

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 ${provider.displayName} 的 API Key');
    }
    if (model == null) {
      throw Exception('请先在设置中选择视觉模型');
    }

    switch (provider) {
      case AIProvider.gemini:
        return _callGeminiVision(apiKey, model, imageUrlOrBase64, prompt);
      case AIProvider.zhipu:
        return _callZhipuVision(apiKey, model, imageUrlOrBase64, prompt);
    }
  }

  Future<String> _callGeminiVision(
    String apiKey,
    String modelId,
    String imageUrlOrBase64,
    String? prompt,
  ) async {
    final model = GenerativeModel(model: modelId, apiKey: apiKey);
    final isUrl = imageUrlOrBase64.startsWith('http');
    final imagePart = isUrl
        ? await inlineImagePartFromUrl(imageUrlOrBase64)
        : inlineImagePartFromBase64(imageUrlOrBase64);
    final text = prompt ?? '请描述这张图片的内容';
    final response = await model.generateContent([
      Content.multi([TextPart(text), imagePart])
    ]);
    return response.text ?? '无法识别图片内容';
  }

  Future<String> _callZhipuVision(
    String apiKey,
    String modelId,
    String imageUrlOrBase64,
    String? prompt,
  ) async {
    final url = Uri.parse('https://open.bigmodel.cn/api/paas/v4/chat/completions');
    final isUrl = imageUrlOrBase64.startsWith('http');
    final content = [
      {
        'type': 'text',
        'text': prompt ?? '请描述这张图片的内容',
      },
      {
        'type': 'image_url',
        'image_url': {
          'url': isUrl ? imageUrlOrBase64 : imageUrlOrBase64,
        },
      },
    ];

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': modelId,
        'messages': [
          {'role': 'user', 'content': content},
        ],
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? '视觉理解调用失败');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  }

  /// 生成图片
  Future<String> generateImage({
    required String prompt,
    String? modelId,
    String? size,
  }) async {
    final provider = await _settings.getProvider();
    final model = modelId ?? (await _settings.getSelectedModelForCapability(ModelCapability.imageGeneration))?.id;
    final apiKey = await _settings.getApiKey(provider);

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 ${provider.displayName} 的 API Key');
    }
    if (model == null) {
      throw Exception('请先在设置中选择图片生成模型');
    }

    switch (provider) {
      case AIProvider.zhipu:
        return _callZhipuImageGen(apiKey, model, prompt, size);
      case AIProvider.gemini:
        throw Exception('Gemini 暂不支持图片生成');
    }
  }

  Future<String> _callZhipuImageGen(
    String apiKey,
    String modelId,
    String prompt,
    String? size,
  ) async {
    final url = Uri.parse('https://open.bigmodel.cn/api/paas/v4/images/generations');

    final body = <String, dynamic>{
      'model': modelId,
      'prompt': prompt,
    };
    if (size != null) {
      body['size'] = size;
    }

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? '图片生成失败');
    }

    final data = jsonDecode(response.body);
    return data['data'][0]['url'];
  }

  /// 生成视频（异步任务，返回 task_id）
  Future<String> generateVideo({
    required String prompt,
    String? modelId,
    String? imageUrl,
  }) async {
    final provider = await _settings.getProvider();
    final model = modelId ?? (await _settings.getSelectedModelForCapability(ModelCapability.videoGeneration))?.id;
    final apiKey = await _settings.getApiKey(provider);

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 ${provider.displayName} 的 API Key');
    }
    if (model == null) {
      throw Exception('请先在设置中选择视频生成模型');
    }

    switch (provider) {
      case AIProvider.zhipu:
        return _callZhipuVideoGen(apiKey, model, prompt, imageUrl);
      case AIProvider.gemini:
        throw Exception('Gemini 暂不支持视频生成');
    }
  }

  Future<String> _callZhipuVideoGen(
    String apiKey,
    String modelId,
    String prompt,
    String? imageUrl,
  ) async {
    final url = Uri.parse('https://open.bigmodel.cn/api/paas/v4/video/generations');

    final body = <String, dynamic>{
      'model': modelId,
      'prompt': prompt,
    };
    if (imageUrl != null) {
      body['image_url'] = imageUrl;
    }

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? '视频生成任务提交失败');
    }

    final data = jsonDecode(response.body);
    return data['id']; // 返回 task_id 用于查询结果
  }

  /// 查询视频生成结果
  Future<Map<String, dynamic>?> queryVideoTask(String taskId) async {
    final provider = await _settings.getProvider();
    final apiKey = await _settings.getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) return null;

    switch (provider) {
      case AIProvider.zhipu:
        return _queryZhipuVideoTask(apiKey, taskId);
      case AIProvider.gemini:
        return null;
    }
  }

  Future<Map<String, dynamic>?> _queryZhipuVideoTask(String apiKey, String taskId) async {
    final url = Uri.parse('https://open.bigmodel.cn/api/paas/v4/video/result/$taskId');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) return null;
    return jsonDecode(response.body);
  }

  Future<bool> testApiKey(AIProvider provider, String apiKey) async {
    try {
      switch (provider) {
        case AIProvider.gemini:
          return await _testGeminiApiKey(apiKey);
        case AIProvider.zhipu:
          return await _testZhipuApiKey(apiKey);
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> _testGeminiApiKey(String apiKey) async {
    final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
    final response = await model.generateContent([Content.text('Hello')]);
    return (response.text?.isNotEmpty ?? false);
  }

  Future<bool> _testZhipuApiKey(String apiKey) async {
    final url = Uri.parse(
      'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    );
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'glm-4-flash',
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
        'max_tokens': 1,
      }),
    );
    return response.statusCode == 200;
  }
}

/// Helper to build inline image parts for Gemini
DataPart inlineImagePartFromBase64(String base64String) {
  final base64Data = base64String.contains(',')
      ? base64String.split(',').last
      : base64String;
  return DataPart('image/jpeg', base64Decode(base64Data));
}

Future<DataPart> inlineImagePartFromUrl(String url) async {
  final client = http.Client();
  try {
    final response = await client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch image from URL: ${response.statusCode}');
    }
    final contentType = response.headers['content-type'] ?? 'image/jpeg';
    return DataPart(contentType, response.bodyBytes);
  } finally {
    client.close();
  }
}
