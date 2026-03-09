enum AIProvider {
  gemini('Google Gemini', 'https://generativelanguage.googleapis.com'),
  zhipu('智谱AI', 'https://open.bigmodel.cn');

  final String displayName;
  final String baseUrl;
  const AIProvider(this.displayName, this.baseUrl);
}

class AIModel {
  final String id;
  final String name;
  final AIProvider provider;
  final String description;

  const AIModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.description,
  });

  static List<AIModel> getAvailableModels(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return [
          const AIModel(
            id: 'gemini-2.0-flash',
            name: 'Gemini 2.0 Flash',
            provider: AIProvider.gemini,
            description: '快速响应，适合日常对话',
          ),
          const AIModel(
            id: 'gemini-1.5-flash',
            name: 'Gemini 1.5 Flash',
            provider: AIProvider.gemini,
            description: '平衡性能与成本',
          ),
          const AIModel(
            id: 'gemini-1.5-pro',
            name: 'Gemini 1.5 Pro',
            provider: AIProvider.gemini,
            description: '更强推理能力',
          ),
        ];
      case AIProvider.zhipu:
        return [
          const AIModel(
            id: 'glm-4',
            name: 'GLM-4',
            provider: AIProvider.zhipu,
            description: '智谱最新模型',
          ),
          const AIModel(
            id: 'glm-4-flash',
            name: 'GLM-4-Flash',
            provider: AIProvider.zhipu,
            description: '快速响应，免费额度充足',
          ),
          const AIModel(
            id: 'glm-3-turbo',
            name: 'GLM-3-Turbo',
            provider: AIProvider.zhipu,
            description: '性价比高',
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
