import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  String? _selectedModelId;
  final _apiKeyController = TextEditingController();
  bool _isTesting = false;
  bool _isSaving = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(aiSettingsServiceProvider);
    final provider = await settings.getProvider();
    final model = await settings.getSelectedModel();
    final apiKey = await settings.getApiKey(provider);

    // 调试
    print('Loading - Provider: ${provider.name}, Model: ${model?.id}, HasKey: ${apiKey != null}');

    setState(() {
      _selectedProvider = provider;
      _selectedModelId = model?.id;
      _apiKeyController.text = apiKey ?? '';
    });
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
      
      // 保存提供商
      await settings.setProvider(_selectedProvider!);
      // 保存模型
      if (_selectedModelId != null) {
        await settings.setModelId(_selectedModelId!);
      }
      // 保存 API Key
      await settings.setApiKey(_selectedProvider!, apiKey);

      // 验证保存成功
      final savedProvider = await settings.getProvider();
      final savedKey = await settings.getApiKey(savedProvider);
      
      print('Saved - Provider: ${savedProvider.name}, HasKey: ${savedKey != null && savedKey.isNotEmpty}');

      // 刷新 provider 让聊天页面获取最新设置
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
          Text(
            '选择 AI 提供商',
            style: theme.textTheme.titleMedium,
          ),
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
                  // 切换 provider 时自动选择第一个模型
                  final models = AIModel.getAvailableModels(value!);
                  _selectedModelId = models.isNotEmpty ? models.first.id : null;
                  // 清空 API Key 输入框，让用户重新填写
                  _apiKeyController.clear();
                });
              },
            );
          }),
          const SizedBox(height: 24),
          if (_selectedProvider != null) ...[
            Text(
              '选择模型',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...AIModel.getAvailableModels(_selectedProvider!).map((model) {
              return RadioListTile<String>(
                title: Text(model.name),
                subtitle: Text(model.description),
                value: model.id,
                groupValue: _selectedModelId,
                onChanged: (value) {
                  setState(() {
                    _selectedModelId = value;
                  });
                },
              );
            }),
            const SizedBox(height: 24),
            Text(
              'API Key',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                hintText: _selectedProvider == AIProvider.gemini
                    ? '输入 Google Gemini API Key'
                    : '输入智谱AI API Key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.visibility_off),
                  onPressed: () {},
                ),
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
                    color: _testResult!.contains('✅')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testApiKey,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
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
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('保存'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          '获取 API Key',
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedProvider == AIProvider.gemini) ...[
                      Text(
                        'Google Gemini:',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '1. 访问 makersuite.google.com/app/apikeys\n'
                        '2. 创建新的 API Key\n'
                        '3. 复制并粘贴到上方输入框',
                        style: theme.textTheme.bodySmall,
                      ),
                    ] else ...[
                      Text(
                        '智谱AI:',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '1. 访问 open.bigmodel.cn\n'
                        '2. 注册/登录后进入控制台\n'
                        '3. 创建 API Key\n'
                        '4. 复制并粘贴到上方输入框',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getProviderDescription(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return 'Google 官方 AI，免费额度充足';
      case AIProvider.zhipu:
        return '智谱AI，国内访问稳定';
    }
  }
}
