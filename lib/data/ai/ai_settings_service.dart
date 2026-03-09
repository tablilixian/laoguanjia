import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'ai_models.dart';

class AISettingsService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyProvider = 'ai_provider';
  static const _keyModel = 'ai_model';
  static const _keyGeminiApiKey = 'gemini_api_key';
  static const _keyZhipuApiKey = 'zhipu_api_key';

  Future<AIProvider> getProvider() async {
    final value = await _storage.read(key: _keyProvider);
    if (value == null) return AIProvider.gemini;
    return AIProvider.values.firstWhere(
      (p) => p.name == value,
      orElse: () => AIProvider.gemini,
    );
  }

  Future<void> setProvider(AIProvider provider) async {
    await _storage.write(key: _keyProvider, value: provider.name);
  }

  Future<String?> getModelId() async {
    return await _storage.read(key: _keyModel);
  }

  Future<void> setModelId(String modelId) async {
    await _storage.write(key: _keyModel, value: modelId);
  }

  Future<String?> getApiKey(AIProvider provider) async {
    switch (provider) {
      case AIProvider.gemini:
        return await _storage.read(key: _keyGeminiApiKey);
      case AIProvider.zhipu:
        return await _storage.read(key: _keyZhipuApiKey);
    }
  }

  Future<void> setApiKey(AIProvider provider, String apiKey) async {
    switch (provider) {
      case AIProvider.gemini:
        await _storage.write(key: _keyGeminiApiKey, value: apiKey);
        break;
      case AIProvider.zhipu:
        await _storage.write(key: _keyZhipuApiKey, value: apiKey);
        break;
    }
  }

  Future<void> clearApiKey(AIProvider provider) async {
    switch (provider) {
      case AIProvider.gemini:
        await _storage.delete(key: _keyGeminiApiKey);
        break;
      case AIProvider.zhipu:
        await _storage.delete(key: _keyZhipuApiKey);
        break;
    }
  }

  Future<AIModel?> getSelectedModel() async {
    final provider = await getProvider();
    final modelId = await getModelId();
    if (modelId == null) {
      final models = AIModel.getAvailableModels(provider);
      return models.isNotEmpty ? models.first : null;
    }
    final models = AIModel.getAvailableModels(provider);
    return models.firstWhere(
      (m) => m.id == modelId,
      orElse: () => models.first,
    );
  }

  Future<bool> hasApiKey(AIProvider provider) async {
    final key = await getApiKey(provider);
    return key != null && key.isNotEmpty;
  }

  Future<Map<String, bool>> getAllApiKeyStatus() async {
    return {
      'gemini': await hasApiKey(AIProvider.gemini),
      'zhipu': await hasApiKey(AIProvider.zhipu),
    };
  }
}
