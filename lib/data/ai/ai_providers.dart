import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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
  final Uuid _uuid = const Uuid();

  ChatNotifier(this._aiService, this._settings) : super(ChatState());

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
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final settings = ref.watch(aiSettingsServiceProvider);
  return ChatNotifier(aiService, settings);
});
