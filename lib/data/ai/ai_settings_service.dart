import 'package:shared_preferences/shared_preferences.dart';
import 'ai_models.dart';

class AISettingsService {
  // 使用 shared_preferences，支持 Web 平台
  static final _storageFuture = SharedPreferences.getInstance();

  static const _keyProvider = 'ai_provider';
  static const _keyModel = 'ai_model';
  static const _keyGeminiApiKey = 'gemini_api_key';
  static const _keyZhipuApiKey = 'zhipu_api_key';

  Future<AIProvider> getProvider() async {
    final prefs = await _storageFuture;
    final value = prefs.getString(_keyProvider);
    if (value == null) return AIProvider.gemini;
    return AIProvider.values.firstWhere(
      (p) => p.name == value,
      orElse: () => AIProvider.gemini,
    );
  }

  Future<void> setProvider(AIProvider provider) async {
    final prefs = await _storageFuture;
    await prefs.setString(_keyProvider, provider.name);
  }

  Future<String?> getModelId() async {
    final prefs = await _storageFuture;
    return prefs.getString(_keyModel);
  }

  Future<void> setModelId(String modelId) async {
    final prefs = await _storageFuture;
    await prefs.setString(_keyModel, modelId);
  }

  Future<String?> getApiKey(AIProvider provider) async {
    final prefs = await _storageFuture;
    switch (provider) {
      case AIProvider.gemini:
        return prefs.getString(_keyGeminiApiKey);
      case AIProvider.zhipu:
        return prefs.getString(_keyZhipuApiKey);
    }
  }

  Future<void> setApiKey(AIProvider provider, String apiKey) async {
    final prefs = await _storageFuture;
    switch (provider) {
      case AIProvider.gemini:
        await prefs.setString(_keyGeminiApiKey, apiKey);
        break;
      case AIProvider.zhipu:
        await prefs.setString(_keyZhipuApiKey, apiKey);
        break;
    }
  }

  Future<void> clearApiKey(AIProvider provider) async {
    final prefs = await _storageFuture;
    switch (provider) {
      case AIProvider.gemini:
        await prefs.remove(_keyGeminiApiKey);
        break;
      case AIProvider.zhipu:
        await prefs.remove(_keyZhipuApiKey);
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
