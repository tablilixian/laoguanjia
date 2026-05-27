import 'package:home_manager/core/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_models.dart';

class AISettingsService {
  static StorageService? _storage;
  static final _client = Supabase.instance.client;

  static Future<void> init() async {
    _storage ??= await StorageService.getInstance();
  }

  static const _keyProvider = 'ai_provider';
  static const _keyModel = 'ai_model';
  static const _keyGeminiApiKey = 'gemini_api_key';
  static const _keyZhipuApiKey = 'zhipu_api_key';

  // 各能力的模型选择 key
  static const _keyChatModel = 'ai_chat_model';
  static const _keyVisionModel = 'ai_vision_model';
  static const _keyImageGenModel = 'ai_image_gen_model';
  static const _keyVideoGenModel = 'ai_video_gen_model';

  Future<AIProvider> getProvider() async {
    await init();
    final value = await _storage!.getString(_keyProvider);
    if (value == null) return AIProvider.zhipu;
    return AIProvider.values.firstWhere(
      (p) => p.name == value,
      orElse: () => AIProvider.zhipu,
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

  /// 获取指定能力的模型 ID
  Future<String?> getModelIdForCapability(ModelCapability capability) async {
    await init();
    final key = _capabilityKey(capability);
    return await _storage!.getString(key);
  }

  /// 设置指定能力的模型 ID
  Future<void> setModelIdForCapability(ModelCapability capability, String modelId) async {
    await init();
    final key = _capabilityKey(capability);
    await _storage!.setString(key, modelId);
  }

  /// 获取指定能力的选定模型
  Future<AIModel?> getSelectedModelForCapability(ModelCapability capability) async {
    final provider = await getProvider();
    final modelId = await getModelIdForCapability(capability);
    final models = AIModel.getAvailableModels(provider, capability: capability);
    if (models.isEmpty) return null;
    if (modelId == null) return models.first;
    return models.firstWhere(
      (m) => m.id == modelId,
      orElse: () => models.first,
    );
  }

  String _capabilityKey(ModelCapability capability) {
    switch (capability) {
      case ModelCapability.chat:
        return _keyChatModel;
      case ModelCapability.vision:
        return _keyVisionModel;
      case ModelCapability.imageGeneration:
        return _keyImageGenModel;
      case ModelCapability.videoGeneration:
        return _keyVideoGenModel;
    }
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

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<AIModel?> getSelectedModel() async {
    return getSelectedModelForCapability(ModelCapability.chat);
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
