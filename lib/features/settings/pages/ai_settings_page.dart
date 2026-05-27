import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/ai/ai_models.dart';
import '../../../data/ai/ai_settings_service.dart';
import '../../../data/ai/ai_providers.dart';

class AISettingsPage extends ConsumerStatefulWidget {
  const AISettingsPage({super.key});

  @override
  ConsumerState<AISettingsPage> createState() => _AISettingsPageState();
}

class _AISettingsPageState extends ConsumerState<AISettingsPage> {
  AIProvider? _selectedProvider;
  final _apiKeyController = TextEditingController();
  bool _isTesting = false;
  bool _isSaving = false;
  String? _testResult;

  // 各能力的模型选择
  final Map<ModelCapability, String?> _selectedModelIds = {};
  final Map<ModelCapability, bool> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    for (final cap in ModelCapability.values) {
      _expandedSections[cap] = cap == ModelCapability.chat;
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(aiSettingsServiceProvider);
    final provider = await settings.getProvider();
    final apiKey = await settings.getApiKey(provider);

    setState(() {
      _selectedProvider = provider;
      _apiKeyController.text = apiKey ?? '';
    });

    for (final cap in ModelCapability.values) {
      final model = await settings.getSelectedModelForCapability(cap);
      setState(() {
        _selectedModelIds[cap] = model?.id;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testApiKey() async {
    if (_selectedProvider == null || _apiKeyController.text.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final aiService = ref.read(aiServiceProvider);
      final success = await aiService.testApiKey(
        _selectedProvider!,
        _apiKeyController.text.trim(),
      );

      setState(() {
        _testResult = success ? '✅ API Key 测试成功！' : '❌ API Key 测试失败';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ 测试出错: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_selectedProvider == null) return;

    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 API Key')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final settings = ref.read(aiSettingsServiceProvider);

      await settings.setProvider(_selectedProvider!);
      await settings.setApiKey(_selectedProvider!, apiKey);

      // 保存各能力的模型选择
      for (final entry in _selectedModelIds.entries) {
        if (entry.value != null) {
          await settings.setModelIdForCapability(entry.key, entry.value!);
        }
      }

      ref.invalidate(aiModelProvider);
      ref.invalidate(aiProviderProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedProvider!.displayName} 设置已保存')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Provider Selection
          Text('选择 AI 提供商', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...AIProvider.values.map((provider) {
            return RadioListTile<AIProvider>(
              title: Text(provider.displayName),
              subtitle: Text(_getProviderDescription(provider)),
              value: provider,
              groupValue: _selectedProvider,
              onChanged: (value) {
                setState(() {
                  _selectedProvider = value;
                  _testResult = null;
                  _apiKeyController.clear();
                  _selectedModelIds.clear();
                  for (final cap in ModelCapability.values) {
                    final models = AIModel.getAvailableModels(value!, capability: cap);
                    _selectedModelIds[cap] = models.isNotEmpty ? models.first.id : null;
                  }
                });
              },
            );
          }),
          const SizedBox(height: 24),

          if (_selectedProvider != null) ...[
            // API Key
            Text('API Key', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                hintText: _selectedProvider == AIProvider.gemini
                    ? '输入 Google Gemini API Key'
                    : '输入智谱AI API Key',
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            if (_testResult != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testResult!.contains('✅') ? Colors.green : Colors.red,
                  ),
                ),
              ),

            // Test & Save Buttons
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testApiKey,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('测试连接'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: const Text('保存'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Per-capability Model Selection
            Text('模型选择', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '为不同功能分别选择模型，推荐使用智谱AI免费模型',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            ...ModelCapability.values.map((cap) => _buildCapabilitySection(theme, cap)),

            const SizedBox(height: 24),
            _buildHelpCard(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildCapabilitySection(ThemeData theme, ModelCapability capability) {
    final models = AIModel.getAvailableModels(_selectedProvider!, capability: capability);
    if (models.isEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedSections[capability] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedSections[capability] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(_capabilityIcon(capability), size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          capability.displayName,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (_selectedModelIds[capability] != null)
                          Text(
                            models.firstWhere(
                              (m) => m.id == _selectedModelIds[capability],
                              orElse: () => models.first,
                            ).name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_selectedModelIds[capability] != null)
                    _buildFreeBadge(models.firstWhere(
                      (m) => m.id == _selectedModelIds[capability],
                      orElse: () => models.first,
                    ).isFree),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (isExpanded)
            ...models.map((model) {
              return RadioListTile<String>(
                dense: true,
                title: Row(
                  children: [
                    Text(model.name, style: const TextStyle(fontSize: 14)),
                    if (model.isFree) ...[
                      const SizedBox(width: 8),
                      _buildFreeBadge(true),
                    ],
                  ],
                ),
                subtitle: Text(model.description, style: const TextStyle(fontSize: 12)),
                value: model.id,
                groupValue: _selectedModelIds[capability],
                onChanged: (value) {
                  setState(() {
                    _selectedModelIds[capability] = value;
                  });
                },
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFreeBadge(bool isFree) {
    if (!isFree) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        '免费',
        style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHelpCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('获取 API Key', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedProvider == AIProvider.gemini) ...[
              Text('Google Gemini:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                '1. 访问 makersuite.google.com/app/apikeys\n'
                '2. 创建新的 API Key\n'
                '3. 复制并粘贴到上方输入框',
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              Text('智谱AI:' , style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                '1. 访问 open.bigmodel.cn\n'
                '2. 注册/登录后进入控制台\n'
                '3. 创建 API Key\n'
                '4. 复制并粘贴到上方输入框\n\n'
                '免费模型清单（无需额外付费）：\n'
                '• GLM-4-Flash - 免费对话模型\n'
                '• GLM-4V-Flash - 免费视觉理解\n'
                '• CogView-3-Flash - 免费图片生成\n'
                '• CogVideoX-Flash - 免费视频生成',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _capabilityIcon(ModelCapability capability) {
    switch (capability) {
      case ModelCapability.chat:
        return Icons.chat_outlined;
      case ModelCapability.vision:
        return Icons.visibility_outlined;
      case ModelCapability.imageGeneration:
        return Icons.image_outlined;
      case ModelCapability.videoGeneration:
        return Icons.videocam_outlined;
    }
  }

  String _getProviderDescription(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return 'Google 官方 AI，免费额度充足';
      case AIProvider.zhipu:
        return '智谱AI，国内访问稳定，提供免费视觉/图像/视频模型';
    }
  }
}
