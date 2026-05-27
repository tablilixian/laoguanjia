enum AIProvider {
  gemini('Google Gemini', 'https://generativelanguage.googleapis.com'),
  zhipu('智谱AI', 'https://open.bigmodel.cn');

  final String displayName;
  final String baseUrl;
  const AIProvider(this.displayName, this.baseUrl);
}

enum ModelCapability {
  chat('对话'),
  vision('视觉理解'),
  imageGeneration('图片生成'),
  videoGeneration('视频生成');

  final String displayName;
  const ModelCapability(this.displayName);
}

class AIModel {
  final String id;
  final String name;
  final AIProvider provider;
  final ModelCapability capability;
  final String description;
  final bool isFree;

  const AIModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.capability,
    required this.description,
    this.isFree = false,
  });

  static List<AIModel> getAvailableModels(AIProvider provider, {ModelCapability? capability}) {
    final all = _allModels(provider);
    if (capability != null) {
      return all.where((m) => m.capability == capability).toList();
    }
    return all;
  }

  static List<AIModel> _allModels(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return [
          const AIModel(
            id: 'gemini-2.0-flash',
            name: 'Gemini 2.0 Flash',
            provider: AIProvider.gemini,
            capability: ModelCapability.chat,
            description: '快速响应，适合日常对话',
          ),
          const AIModel(
            id: 'gemini-1.5-flash',
            name: 'Gemini 1.5 Flash',
            provider: AIProvider.gemini,
            capability: ModelCapability.chat,
            description: '平衡性能与成本',
          ),
          const AIModel(
            id: 'gemini-1.5-pro',
            name: 'Gemini 1.5 Pro',
            provider: AIProvider.gemini,
            capability: ModelCapability.chat,
            description: '更强推理能力',
          ),
          const AIModel(
            id: 'gemini-2.0-flash',
            name: 'Gemini 2.0 Flash (视觉)',
            provider: AIProvider.gemini,
            capability: ModelCapability.vision,
            description: '支持图像理解',
          ),
        ];
      case AIProvider.zhipu:
        return [
          // --- 对话模型 ---
          const AIModel(
            id: 'glm-4-flash',
            name: 'GLM-4-Flash',
            provider: AIProvider.zhipu,
            capability: ModelCapability.chat,
            description: '快速响应，免费额度充足',
            isFree: true,
          ),
          const AIModel(
            id: 'glm-4',
            name: 'GLM-4',
            provider: AIProvider.zhipu,
            capability: ModelCapability.chat,
            description: '智谱最新模型',
          ),
          const AIModel(
            id: 'glm-3-turbo',
            name: 'GLM-3-Turbo',
            provider: AIProvider.zhipu,
            capability: ModelCapability.chat,
            description: '性价比高',
          ),
          const AIModel(
            id: 'glm-z1-flash',
            name: 'GLM-Z1-Flash',
            provider: AIProvider.zhipu,
            capability: ModelCapability.chat,
            description: '免费推理模型，擅长数学/编程',
            isFree: true,
          ),
          // --- 视觉理解模型 ---
          const AIModel(
            id: 'glm-4v-flash',
            name: 'GLM-4V-Flash',
            provider: AIProvider.zhipu,
            capability: ModelCapability.vision,
            description: '免费图像理解，支持图片URL/Base64',
            isFree: true,
          ),
          const AIModel(
            id: 'glm-4.1v-thinking-flash',
            name: 'GLM-4.1V-Thinking-Flash',
            provider: AIProvider.zhipu,
            capability: ModelCapability.vision,
            description: '免费视觉推理模型',
            isFree: true,
          ),
          // --- 图片生成模型 ---
          const AIModel(
            id: 'cogview-3-flash',
            name: 'CogView-3-Flash',
            provider: AIProvider.zhipu,
            capability: ModelCapability.imageGeneration,
            description: '免费文生图，多分辨率支持',
            isFree: true,
          ),
          // --- 视频生成模型 ---
          const AIModel(
            id: 'cogvideox-flash',
            name: 'CogVideoX-Flash',
            provider: AIProvider.zhipu,
            capability: ModelCapability.videoGeneration,
            description: '免费文生视频/图生视频',
            isFree: true,
          ),
        ];
    }
  }
}

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
