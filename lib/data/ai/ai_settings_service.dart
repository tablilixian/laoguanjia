import 'package:home_manager/core/services/storage_service.dart';
import 'ai_models.dart';

class AISettingsService {
  static StorageService? _storage;

  static Future<void> init() async {
    _storage ??= await StorageService.getInstance();
  }

  static const _keyProvider = 'ai_provider';
  static const _keyModel = 'ai_model';
  static const _keyGeminiApiKey = 'gemini_api_key';
  static const _keyZhipuApiKey = 'zhipu_api_key';

  Future<AIProvider> getProvider() async {
    await init();
    final value = await _storage!.getString(_keyProvider);
    if (value == null) return AIProvider.gemini;
    return AIProvider.values.firstWhere(
      (p) => p.name == value,
      orElse: () => AIProvider.gemini,
    );
  }

  Future<void> setProvider(AIProvider provider) async {
    await init();
    await _storage!.setString(_keyProvider, provider.name);
  }

  Future<String?> getModelId() async {
    await init();
    return await _storage!.getString(_keyModel);
  }

  Future<void> setModelId(String modelId) async {
    await init();
    await _storage!.setString(_keyModel, modelId);
  }

  Future<String?> getApiKey(AIProvider provider) async {
    await init();
    switch (provider) {
      case AIProvider.gemini:
        return await _storage!.getString(_keyGeminiApiKey);
      case AIProvider.zhipu:
        return await _storage!.getString(_keyZhipuApiKey);
    }
  }

  Future<void> setApiKey(AIProvider provider, String apiKey) async {
    await init();
    switch (provider) {
      case AIProvider.gemini:
        await _storage!.setString(_keyGeminiApiKey, apiKey);
        break;
      case AIProvider.zhipu:
        await _storage!.setString(_keyZhipuApiKey, apiKey);
        break;
    }
  }

  Future<void> clearApiKey(AIProvider provider) async {
    await init();
    switch (provider) {
      case AIProvider.gemini:
        await _storage!.remove(_keyGeminiApiKey);
        break;
      case AIProvider.zhipu:
        await _storage!.remove(_keyZhipuApiKey);
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
