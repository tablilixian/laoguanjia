import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/task_broadcast_service.dart';
import '../../../core/services/weather_service.dart';
import '../../../data/ai/ai_models.dart';
import '../../../data/ai/ai_providers.dart';
import '../../../data/ai/tts_provider.dart';
import '../../../data/models/weather_models.dart';
import '../../../data/weather/weather_providers.dart';
import '../../household/providers/household_provider.dart';

class AIChatPage extends ConsumerStatefulWidget {
  const AIChatPage({super.key});

  @override
  ConsumerState<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends ConsumerState<AIChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTtsPlaying = false;

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkApiKey() async {
    final settings = ref.read(aiSettingsServiceProvider);
    final provider = await settings.getProvider();
    final model = await settings.getSelectedModel();
    final hasKey = await settings.hasApiKey(provider);

    if (!hasKey && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNoApiKeyDialog(provider.displayName);
      });
    }
  }

  void _showNoApiKeyDialog(String providerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('请先配置 API Key'),
        content: Text('您当前选择的是 $providerName，请配置对应的 API Key。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/settings/ai');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
            ),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final isTaskBroadcast = _checkTaskBroadcast(text);
    final isWeatherQuery = _checkWeatherQuery(text);

    _messageController.clear();

    if (isTaskBroadcast) {
      _handleTaskBroadcast();
    } else if (isWeatherQuery) {
      _handleWeatherQuery();
    } else {
      ref.read(chatProvider.notifier).sendMessage(text);
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _checkTaskBroadcast(String text) {
    final keywords = [
      '播报任务',
      '任务播报',
      '朗读任务',
      '读出任务',
      '有哪些任务',
      '任务列表',
      '今天的任务',
      '本周任务',
      '帮我任务',
      '报告任务',
      '帮我播报当前的任务列表',
    ];

    return keywords.any((keyword) => text.contains(keyword));
  }

  bool _checkWeatherQuery(String text) {
    final keywords = [
      '天气',
      '气温',
      '温度',
      '冷不冷',
      '热不热',
      '多少度',
      '晴天',
      '阴天',
      '下雨',
      '下雪',
      '刮风',
      '多云',
    ];

    return keywords.any((keyword) => text.contains(keyword));
  }

  Future<void> _handleWeatherQuery() async {
    final apiKey = ref.read(weatherApiKeyProvider);
    final preference = ref.read(weatherPreferenceProvider);

    if (apiKey == null || apiKey.isEmpty) {
      _addErrorMessage('请先在设置中配置 OpenWeatherMap API Key');
      return;
    }

    if (!preference.useGps && (preference.defaultCity == null || preference.defaultCity!.isEmpty)) {
      _addErrorMessage('请先在设置中设置默认城市');
      return;
    }

    _addUserMessage('查询天气');

    try {
      final weatherService = ref.read(weatherServiceProvider);
      WeatherData weatherData;

      if (preference.useGps) {
        _addErrorMessage('GPS 定位功能开发中，请先设置默认城市');
        return;
      } else {
        // 确保城市名称不为空
        if (preference.defaultCity == null || preference.defaultCity!.isEmpty) {
          _addErrorMessage('请先在设置中设置默认城市');
          return;
        }
        
        weatherData = await weatherService.getWeatherByCity(
          preference.defaultCity!,
          preference.countryCode,
          apiKey,
        );
      }

      final aiService = ref.read(aiServiceProvider);
      final formattedWeather = _formatWeatherForAI(weatherData, preference.useCelsius);
      final prompt = _buildWeatherPrompt(formattedWeather);

      final weatherText = await aiService.sendMessage(prompt, []);
      ref.read(chatProvider.notifier).addAiMessage(weatherText);

      await Future.delayed(const Duration(milliseconds: 500));
      final ttsNotifier = ref.read(ttsProvider.notifier);
      await ttsNotifier.speak(weatherText);
    } catch (e) {
      _addErrorMessage('天气查询失败: ${e.toString()}');
    }
  }

  String _formatWeatherForAI(WeatherData weather, bool useCelsius) {
    final tempUnit = useCelsius ? '摄氏度' : '华氏度';
    final tempSymbol = useCelsius ? '°C' : '°F';

    final temp = useCelsius
        ? weather.temperature
        : weather.temperature * 9 / 5 + 32;
    final feelsLike = useCelsius
        ? weather.feelsLike
        : weather.feelsLike * 9 / 5 + 32;

    return '''
城市：${weather.city}
国家：${weather.country}
天气：${weather.description} ${weather.getWeatherEmoji()}
当前温度：${temp.toStringAsFixed(1)}$tempSymbol
体感温度：${feelsLike.toStringAsFixed(1)}$tempSymbol
湿度：${weather.humidity}%
气压：${weather.pressure ?? '未知'} hPa
风速：${weather.windSpeed} m/s
风向：${weather.getWindDirection()}
云量：${weather.cloudiness}%
能见度：${(weather.visibility / 1000).toStringAsFixed(1)} km
日出时间：${weather.sunrise.hour.toString().padLeft(2, '0')}:${weather.sunrise.minute.toString().padLeft(2, '0')}
日落时间：${weather.sunset.hour.toString().padLeft(2, '0')}:${weather.sunset.minute.toString().padLeft(2, '0')}
''';
  }

  String _buildWeatherPrompt(String formattedWeather) {
    return '''
你是一个温暖的家庭天气助手。请根据以下天气数据，用自然、亲切的语气播报天气，并给出适当的建议。

要求：
1. 开头有友好的问候语
2. 清晰播报天气信息：城市、天气状况、温度、体感温度、湿度、风速等
3. 根据天气情况给出实用的生活建议（如穿衣、出行等）
4. 语气亲切自然，像朋友聊天一样
5. 播报长度适中，控制在200字以内
6. 直接输出播报内容，不要添加格式符号

天气数据：
$formattedWeather

请生成天气播报：
''';
  }

  Future<void> _handleTaskBroadcast() async {
    final householdState = ref.read(householdProvider);
    final householdId = householdState.currentHousehold?.id;

    if (householdId == null) {
      _addErrorMessage('请先加入一个家庭');
      return;
    }

    _addUserMessage('帮我播报当前的任务列表');

    try {
      final aiService = ref.read(aiServiceProvider);
      final broadcastService = TaskBroadcastService(aiService);

      final members = householdState.members;
      final broadcastText = await broadcastService.generateBroadcastText(householdId, members);

      ref.read(chatProvider.notifier).addAiMessage(broadcastText);

      // 延迟一下确保 TTS 初始化完成
      await Future.delayed(const Duration(milliseconds: 500));
      final ttsNotifier = ref.read(ttsProvider.notifier);
      await ttsNotifier.speak(broadcastText);
    } catch (e) {
      _addErrorMessage('任务播报失败: ${e.toString()}');
    }
  }

  void _addUserMessage(String text) {
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      isUser: true,
    );
    ref.read(chatProvider.notifier).addMessage(userMessage);
  }

  void _addErrorMessage(String error) {
    final errorMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: error,
      isUser: false,
    );
    ref.read(chatProvider.notifier).addMessage(errorMessage);
  }

  void _toggleTts(String text) {
    final ttsNotifier = ref.read(ttsProvider.notifier);
    final ttsState = ref.read(ttsProvider);

    if (_isTtsPlaying) {
      ttsNotifier.stop();
      setState(() => _isTtsPlaying = false);
    } else {
      ttsNotifier.speak(text);
      setState(() => _isTtsPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final theme = Theme.of(context);
    final modelAsync = ref.watch(aiModelProvider);

    // 监听 TTS 状态
    ref.listen<TTSState>(ttsProvider, (previous, next) {
      setState(() {
        _isTtsPlaying = next == TTSState.playing;
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: modelAsync.when(
          data: (model) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(model?.name ?? 'AI 助手'),
            ],
          ),
          loading: () => const Text('AI 助手'),
          error: (_, __) => const Text('AI 助手'),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings/ai'),
          ),
          if (chatState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('清空对话'),
                    content: const Text('确定要清空当前对话吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () {
                          ref.read(chatProvider.notifier).clearChat();
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.error,
                        ),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      return _MessageBubble(
                        message: message,
                        onSpeak: message.isUser
                            ? null
                            : () => _toggleTts(message.content),
                        isPlaying:
                            _isTtsPlaying &&
                            index == chatState.messages.length - 1,
                      ).animate().fadeIn(
                        delay: Duration(milliseconds: index * 50),
                      );
                    },
                  ),
          ),

          // 错误提示
          if (chatState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatState.error!,
                      style: TextStyle(color: AppTheme.error, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.error, size: 18),
                    onPressed: () {
                      ref.read(chatProvider.notifier).setError('');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // 输入区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(
                            0.3,
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: '和 AI 助手聊天...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !chatState.isLoading,
                        maxLines: 4,
                        minLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: chatState.isLoading ? null : _sendMessage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: chatState.isLoading
                            ? null
                            : AppTheme.primaryGradient(),
                        color: chatState.isLoading
                            ? theme.colorScheme.surfaceContainerHighest
                            : null,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: chatState.isLoading
                            ? null
                            : [
                                BoxShadow(
                                  color: AppTheme.primaryGold.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: chatState.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGold.withOpacity(0.1),
                        AppTheme.primaryGold.withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 64,
                    color: AppTheme.primaryGold,
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 2000.ms,
                ),
            const SizedBox(height: 24),
            Text(
              '你好！我是老管家 AI 助手',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '有什么可以帮你的吗？',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  label: '今天天气怎么样',
                  onTap: () => _sendSuggestion('今天天气怎么样？'),
                ),
                _SuggestionChip(
                  label: '帮我规划日程',
                  onTap: () => _sendSuggestion('帮我规划今天的日程'),
                ),
                _SuggestionChip(
                  label: '讲个笑话',
                  onTap: () => _sendSuggestion('讲个笑话听听'),
                ),
                _SuggestionChip(
                  label: '播报任务',
                  onTap: () => _sendSuggestion('帮我播报当前的任务列表'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendSuggestion(String text) {
    _messageController.text = text;
    _sendMessage();
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onSpeak;
  final bool isPlaying;

  const _MessageBubble({
    required this.message,
    this.onSpeak,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    if (isUser) {
      // 用户消息 - 渐变背景
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient(),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: const Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGold.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message.content,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      );
    } else {
      // AI 消息 - 带头像
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI 头像
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),

            // 消息内容
            Expanded(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.5,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: const Radius.circular(20),
                    bottomLeft: const Radius.circular(20),
                    bottomRight: const Radius.circular(20),
                  ),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message.content, style: theme.textTheme.bodyMedium),
                    if (onSpeak != null) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: onSpeak,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? AppTheme.primaryGold
                                : AppTheme.primaryGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPlaying ? Icons.stop : Icons.volume_up,
                                size: 14,
                                color: isPlaying
                                    ? Colors.white
                                    : AppTheme.primaryGold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPlaying ? '停止' : '朗读',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isPlaying
                                      ? Colors.white
                                      : AppTheme.primaryGold,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
