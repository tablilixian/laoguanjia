import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/core/services/storage_service.dart';
import 'package:home_manager/core/services/weather_service.dart';
import 'package:home_manager/data/models/weather_models.dart';

// 存储服务
final _storageFuture = StorageService.getInstance();

// 存储键
class WeatherKeys {
  static const String preference = 'weather_preference';
  static const String apiKey = 'openweathermap_api_key';
  static const String defaultCity = 'weather_default_city';
  static const String countryCode = 'weather_country_code';
  static const String useGps = 'weather_use_gps';
  static const String useCelsius = 'weather_use_celsius';
}

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
      final storage = await _storageFuture;
      final defaultCity = await storage.getString(WeatherKeys.defaultCity);
      final countryCode = await storage.getString(WeatherKeys.countryCode) ?? 'CN';
      final useGps = await storage.getBool(WeatherKeys.useGps) ?? false;
      final useCelsius = await storage.getBool(WeatherKeys.useCelsius) ?? true;

      state = WeatherPreference(
        defaultCity: defaultCity,
        countryCode: countryCode,
        useGps: useGps,
        useCelsius: useCelsius,
      );
    } catch (e) {
      debugPrint('加载天气偏好失败: $e');
    }
  }

  Future<void> setDefaultCity(String city) async {
    state = state.copyWith(defaultCity: city);
    final storage = await _storageFuture;
    await storage.setString(WeatherKeys.defaultCity, city);
  }

  Future<void> setCountryCode(String code) async {
    state = state.copyWith(countryCode: code);
    final storage = await _storageFuture;
    await storage.setString(WeatherKeys.countryCode, code);
  }

  Future<void> setUseGps(bool use) async {
    state = state.copyWith(useGps: use);
    final storage = await _storageFuture;
    await storage.setBool(WeatherKeys.useGps, use);
  }

  Future<void> setUseCelsius(bool use) async {
    state = state.copyWith(useCelsius: use);
    final storage = await _storageFuture;
    await storage.setBool(WeatherKeys.useCelsius, use);
  }
}

class WeatherApiKeyNotifier extends StateNotifier<String?> {
  WeatherApiKeyNotifier() : super(null) {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      final storage = await _storageFuture;
      final key = await storage.getString(WeatherKeys.apiKey);
      state = key;
    } catch (e) {
      debugPrint('加载 API Key 失败: $e');
    }
  }

  Future<void> setApiKey(String key) async {
    state = key;
    try {
      final storage = await _storageFuture;
      await storage.setString(WeatherKeys.apiKey, key);
    } catch (e) {
      debugPrint('保存 API Key 失败: $e');
    }
  }

  Future<void> clearApiKey() async {
    state = null;
    try {
      final storage = await _storageFuture;
      await storage.remove(WeatherKeys.apiKey);
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
