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
    final model = await _settings.getSelectedModel();
    final apiKey = await _settings.getApiKey(provider);

    print(
      'AI Service - Provider: ${provider.name}, Model: ${model?.id}, HasKey: ${apiKey != null && apiKey.isNotEmpty}',
    );

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 ${provider.displayName} 的 API Key 并保存');
    }

    switch (provider) {
      case AIProvider.gemini:
        return await _callGemini(apiKey, model!.id, message, history);
      case AIProvider.zhipu:
        return await _callZhipu(apiKey, model!.id, message, history);
    }
  }

  Stream<String> sendMessageStream(
    String message,
    List<ChatMessage> history,
  ) async* {
    final provider = await _settings.getProvider();
    final model = await _settings.getSelectedModel();
    final apiKey = await _settings.getApiKey(provider);

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 ${provider.displayName} 的 API Key 并保存');
    }

    switch (provider) {
      case AIProvider.gemini:
        yield* _callGeminiStream(apiKey, model!.id, message, history);
        break;
      case AIProvider.zhipu:
        yield* _callZhipuStream(apiKey, model!.id, message, history);
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
        'model': 'glm-3-turbo',
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
        'max_tokens': 1,
      }),
    );
    return response.statusCode == 200;
  }
}
