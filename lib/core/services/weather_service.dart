import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:home_manager/core/utils/city_name_converter.dart';
import 'package:home_manager/data/models/weather_models.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  
  WeatherData? _cachedWeather;
  DateTime? _cacheTime;
  static const int _cacheDurationMinutes = 30;

  bool get _isCacheValid {
    if (_cachedWeather == null || _cacheTime == null) return false;
    return DateTime.now().difference(_cacheTime!).inMinutes < _cacheDurationMinutes;
  }

  WeatherData? get cachedWeather => _isCacheValid ? _cachedWeather : null;

  Future<WeatherData> getWeatherByCity(String city, String countryCode, String apiKey) async {
    // 转换中文城市名为标准英文名
    final cityName = CityNameConverter.getCityName(city);
    
    if (_isCacheValid && _cachedWeather?.city.toLowerCase() == cityName.toLowerCase()) {
      return _cachedWeather!;
    }
    // 清除缓存，确保每次都重新查询
    clearCache();
    return _fetchWeather('q=$cityName,$countryCode', apiKey);
  }

  Future<WeatherData> getWeatherByCoordinates(double lat, double lon, String apiKey) async {
    if (_isCacheValid) {
      return _cachedWeather!;
    }
    return _fetchWeather('lat=$lat&lon=$lon', apiKey);
  }

  Future<WeatherData> _fetchWeather(String queryParams, String apiKey) async {
    final url = '$_baseUrl/weather?$queryParams&appid=$apiKey&units=metric';
    
    final result = await _fetchWithRetry(url);
    return result;
  }

  Future<WeatherData> _fetchWithRetry(String url, {int maxRetries = 10}) async {
    int retryCount = 0;
    int delaySeconds = 1;

    while (retryCount < maxRetries) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 10),
        );

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final weatherData = WeatherData.fromJson(json);
          
          _cachedWeather = weatherData;
          _cacheTime = DateTime.now();
          
          return weatherData;
        } else if (response.statusCode == 429) {
          retryCount++;
          if (retryCount >= maxRetries) {
            throw Exception('天气API请求次数超限，请稍后再试');
          }
          await Future.delayed(Duration(seconds: delaySeconds));
          delaySeconds = (delaySeconds * 2).clamp(1, 30);
        } else if (response.statusCode == 404) {
          throw Exception('未找到该城市，请检查城市名称是否正确');
        } else if (response.statusCode == 401) {
          throw Exception('API Key无效，请检查配置');
        } else {
          throw Exception('天气服务错误: ${response.statusCode}');
        }
      } catch (e) {
        if (e.toString().contains('未找到') || e.toString().contains('无效')) {
          rethrow;
        }
        retryCount++;
        if (retryCount >= maxRetries) {
          throw Exception('网络错误，已尝试$maxRetries次: $e');
        }
        await Future.delayed(Duration(seconds: delaySeconds));
        delaySeconds = (delaySeconds * 2).clamp(1, 30);
      }
    }

    throw Exception('天气查询失败，已达到最大重试次数');
  }

  Future<bool> testApiKey(String apiKey) async {
    try {
      final url = '$_baseUrl/weather?q=Beijing,CN&appid=$apiKey&units=metric';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void clearCache() {
    _cachedWeather = null;
    _cacheTime = null;
  }
}

class WeatherPreferenceService {
  static const String _prefKey = 'weather_preference';
  static const String _apiKeyKey = 'openweathermap_api_key';

  WeatherPreference _preference = WeatherPreference();
  String? _apiKey;

  WeatherPreference get preference => _preference;
  String? get apiKey => _apiKey;

  void setPreference(WeatherPreference pref) {
    _preference = pref;
  }

  void setApiKey(String? key) {
    _apiKey = key;
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;
}
