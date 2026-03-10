import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/core/services/weather_service.dart';
import 'package:home_manager/data/models/weather_models.dart';
import 'package:home_manager/data/weather/weather_providers.dart';

class WeatherSettingsPage extends ConsumerStatefulWidget {
  const WeatherSettingsPage({super.key});

  @override
  ConsumerState<WeatherSettingsPage> createState() =>
      _WeatherSettingsPageState();
}

class _WeatherSettingsPageState extends ConsumerState<WeatherSettingsPage> {
  final _cityController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final preference = ref.read(weatherPreferenceProvider);
    _cityController.text = preference.defaultCity ?? '';
    _apiKeyController.text = ref.read(weatherApiKeyProvider) ?? '';
  }

  @override
  void dispose() {
    _cityController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _testResult = '请输入 API Key');
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final service = ref.read(weatherServiceProvider);
    final success = await service.testApiKey(apiKey);

    setState(() {
      _isTesting = false;
      _testResult = success ? '✅ 连接成功！' : '❌ 连接失败，请检查 API Key';
    });
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    await ref.read(weatherApiKeyProvider.notifier).setApiKey(key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key 已保存')),
      );
      ref.invalidate(currentWeatherProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preference = ref.watch(weatherPreferenceProvider);
    final currentWeather = ref.watch(currentWeatherProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('天气设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (currentWeather.hasValue && currentWeather.value != null) ...[
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentWeather.value!.getWeatherEmoji(),
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentWeather.value!.city,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currentWeather.value!.description,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${currentWeather.value!.temperature.toStringAsFixed(1)}°',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '体感 ${currentWeather.value!.feelsLike.toStringAsFixed(1)}° | 湿度 ${currentWeather.value!.humidity}%',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '位置设置',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('使用 GPS 定位'),
                    subtitle: const Text('自动获取当前位置'),
                    value: preference.useGps,
                    onChanged: (value) {
                      ref
                          .read(weatherPreferenceProvider.notifier)
                          .setUseGps(value);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('默认城市'),
                    subtitle: Text(
                      preference.defaultCity?.isNotEmpty == true
                          ? preference.defaultCity!
                          : '未设置',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showCityDialog(),
                  ),
                  ListTile(
                    title: const Text('国家/地区代码'),
                    subtitle: Text(preference.countryCode),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showCountryDialog(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.thermostat, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '温度单位',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<bool>(
                    title: const Text('摄氏度 (°C)'),
                    value: true,
                    groupValue: preference.useCelsius,
                    onChanged: (value) {
                      ref
                          .read(weatherPreferenceProvider.notifier)
                          .setUseCelsius(value!);
                    },
                  ),
                  RadioListTile<bool>(
                    title: const Text('华氏度 (°F)'),
                    value: false,
                    groupValue: preference.useCelsius,
                    onChanged: (value) {
                      ref
                          .read(weatherPreferenceProvider.notifier)
                          .setUseCelsius(value!);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.key, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'API 设置',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'OpenWeatherMap API Key',
                      hintText: '请输入 API Key',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '申请地址: openweathermap.org',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTesting ? null : _testApiKey,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering),
                          label: const Text('测试连接'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saveApiKey,
                          icon: const Icon(Icons.save),
                          label: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _testResult!.contains('成功')
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_testResult!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showCityDialog() {
    final controller = TextEditingController(
      text: ref.read(weatherPreferenceProvider).defaultCity,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置默认城市'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '例如：北京、上海',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final city = controller.text.trim();
              if (city.isNotEmpty) {
                ref
                    .read(weatherPreferenceProvider.notifier)
                    .setDefaultCity(city);
                ref.invalidate(currentWeatherProvider);
              }
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showCountryDialog() {
    final countries = {
      'CN': '中国',
      'US': '美国',
      'JP': '日本',
      'KR': '韩国',
      'GB': '英国',
      'DE': '德国',
      'FR': '法国',
      'AU': '澳大利亚',
    };

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择国家/地区'),
        children: countries.entries.map((entry) {
          return SimpleDialogOption(
            onPressed: () {
              ref
                  .read(weatherPreferenceProvider.notifier)
                  .setCountryCode(entry.key);
              ref.invalidate(currentWeatherProvider);
              Navigator.pop(context);
            },
            child: Text('${entry.value} (${entry.key})'),
          );
        }).toList(),
      ),
    );
  }
}
