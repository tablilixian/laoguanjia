import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_manager/core/services/weather_service.dart';
import 'package:home_manager/data/models/weather_models.dart';

// 使用 shared_preferences，支持 Web 平台
final _storageFuture = SharedPreferences.getInstance();

final weatherPreferenceProvider =
    StateNotifierProvider<WeatherPreferenceNotifier, WeatherPreference>(
  (ref) => WeatherPreferenceNotifier(),
);

final weatherApiKeyProvider =
    StateNotifierProvider<WeatherApiKeyNotifier, String?>(
  (ref) => WeatherApiKeyNotifier(),
);

class WeatherPreferenceNotifier extends StateNotifier<WeatherPreference> {
  WeatherPreferenceNotifier() : super(WeatherPreference()) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await _storageFuture;
      final data = prefs.getString('weather_preference');
      if (data != null) {
        final Map<String, dynamic> json = jsonDecode(data);
        state = WeatherPreference(
          defaultCity: json['defaultCity'] as String?,
          countryCode: json['countryCode'] as String? ?? 'CN',
          useGps: json['useGps'] as bool? ?? false,
          useCelsius: json['useCelsius'] as bool? ?? true,
        );
      }
    } catch (e) {
      debugPrint('加载天气偏好失败: $e');
    }
  }

  Future<void> setDefaultCity(String city) async {
    state = state.copyWith(defaultCity: city);
    await _savePreference();
  }

  Future<void> setCountryCode(String code) async {
    state = state.copyWith(countryCode: code);
    await _savePreference();
  }

  Future<void> setUseGps(bool use) async {
    state = state.copyWith(useGps: use);
    await _savePreference();
  }

  Future<void> setUseCelsius(bool use) async {
    state = state.copyWith(useCelsius: use);
    await _savePreference();
  }

  Future<void> _savePreference() async {
    try {
      final prefs = await _storageFuture;
      final data = jsonEncode({
        'defaultCity': state.defaultCity,
        'countryCode': state.countryCode,
        'useGps': state.useGps,
        'useCelsius': state.useCelsius,
      });
      await prefs.setString('weather_preference', data);
    } catch (e) {
      debugPrint('保存天气偏好失败: $e');
    }
  }
}

class WeatherApiKeyNotifier extends StateNotifier<String?> {
  WeatherApiKeyNotifier() : super(null) {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      final prefs = await _storageFuture;
      final key = prefs.getString('openweathermap_api_key');
      state = key;
    } catch (e) {
      debugPrint('加载 API Key 失败: $e');
    }
  }

  Future<void> setApiKey(String key) async {
    state = key;
    try {
      final prefs = await _storageFuture;
      await prefs.setString('openweathermap_api_key', key);
    } catch (e) {
      debugPrint('保存 API Key 失败: $e');
    }
  }

  Future<void> clearApiKey() async {
    state = null;
    try {
      final prefs = await _storageFuture;
      await prefs.remove('openweathermap_api_key');
    } catch (e) {
      debugPrint('删除 API Key 失败: $e');
    }
  }
}

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

final currentWeatherProvider = FutureProvider.autoDispose<WeatherData?>((ref) async {
  final preference = ref.watch(weatherPreferenceProvider);
  final apiKey = ref.watch(weatherApiKeyProvider);

  if (apiKey == null || apiKey.isEmpty) {
    return null;
  }

  final service = ref.read(weatherServiceProvider);

  try {
    if (preference.useGps) {
      return null;
    }

    if (preference.defaultCity == null || preference.defaultCity!.isEmpty) {
      return null;
    }

    return await service.getWeatherByCity(
      preference.defaultCity!,
      preference.countryCode,
      apiKey,
    );
  } catch (e) {
    debugPrint('获取天气失败: $e');
    return null;
  }
});
