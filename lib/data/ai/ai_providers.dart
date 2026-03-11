import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:home_manager/core/services/local_storage_service.dart';
import 'package:home_manager/core/services/chat_local_storage.dart';
import 'ai_models.dart';
import 'ai_settings_service.dart';
import 'ai_service.dart';

final aiSettingsServiceProvider = Provider<AISettingsService>((ref) {
  return AISettingsService();
});

final aiServiceProvider = Provider<AIService>((ref) {
  final settings = ref.watch(aiSettingsServiceProvider);
  return AIService(settings);
});

// 本地存储服务 Provider
final chatLocalStorageProvider = Provider<ChatLocalStorage>((ref) {
  return ChatLocalStorage();
});

final aiProviderProvider = FutureProvider<AIProvider>((ref) async {
  final settings = ref.watch(aiSettingsServiceProvider);
  return await settings.getProvider();
});

final aiModelProvider = FutureProvider<AIModel?>((ref) async {
  final settings = ref.watch(aiSettingsServiceProvider);
  return await settings.getSelectedModel();
});

final aiApiKeyStatusProvider = FutureProvider<Map<String, bool>>((ref) async {
  final settings = ref.watch(aiSettingsServiceProvider);
  return await settings.getAllApiKeyStatus();
});

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final AIService _aiService;
  final AISettingsService _settings;
  final ChatLocalStorage _localStorage;
  final Uuid _uuid = const Uuid();
  bool _initialized = false;

  ChatNotifier(this._aiService, this._settings, this._localStorage) : super(ChatState());

  /// 初始化并加载历史消息
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // 初始化本地存储
      await LocalStorageService.instance.init();
      
      // 加载历史消息
      final messages = await _localStorage.loadMessages();
      if (messages.isNotEmpty) {
        state = state.copyWith(messages: messages);
      }
      _initialized = true;
    } catch (e) {
      // 初始化失败不影响正常使用
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      content: text,
      isUser: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    // 保存用户消息到本地
    try {
      await _localStorage.saveMessage(userMessage);
    } catch (e) {
      // 保存失败不阻塞流程
    }

    try {
      final history = state.messages
          .where((m) => m.id != userMessage.id)
          .toList();

      final response = await _aiService.sendMessage(text, history);

      final aiMessage = ChatMessage(
        id: _uuid.v4(),
        content: response,
        isUser: false,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
      );

      // 保存 AI 回复到本地
      try {
        await _localStorage.saveMessage(aiMessage);
      } catch (e) {
        // 保存失败不阻塞流程
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearChat() {
    state = ChatState();
  }

  void setError(String error) {
    state = state.copyWith(error: error);
  }

  void addMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
    );
    // 保存到本地
    _localStorage.saveMessage(message);
  }

  void addAiMessage(String content) {
    final aiMessage = ChatMessage(
      id: _uuid.v4(),
      content: content,
      isUser: false,
    );
    state = state.copyWith(
      messages: [...state.messages, aiMessage],
    );
    // 保存到本地
    _localStorage.saveMessage(aiMessage);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final settings = ref.watch(aiSettingsServiceProvider);
  final localStorage = ref.watch(chatLocalStorageProvider);
  return ChatNotifier(aiService, settings, localStorage);
});
