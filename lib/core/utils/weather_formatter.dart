import 'package:home_manager/data/models/weather_models.dart';
import 'package:intl/intl.dart';

class WeatherFormatter {
  static String formatForAI(WeatherData weather, bool useCelsius) {
    final tempUnit = useCelsius ? '摄氏度' : '华氏度';
    final tempSymbol = useCelsius ? '°C' : '°F';
    
    final temp = useCelsius 
        ? weather.temperature 
        : weather.temperature * 9 / 5 + 32;
    final feelsLike = useCelsius 
        ? weather.feelsLike 
        : weather.feelsLike * 9 / 5 + 32;
    final tempMin = weather.tempMin != null 
        ? (useCelsius ? weather.tempMin! : weather.tempMin! * 9 / 5 + 32)
        : null;
    final tempMax = weather.tempMax != null 
        ? (useCelsius ? weather.tempMax! : weather.tempMax! * 9 / 5 + 32)
        : null;

    final dateStr = DateFormat('yyyy年M月d日').format(weather.dt);
    final timeStr = DateFormat('HH:mm').format(weather.dt);
    final sunriseStr = DateFormat('HH:mm').format(weather.sunrise);
    final sunsetStr = DateFormat('HH:mm').format(weather.sunset);

    return '''
日期：$dateStr $timeStr
城市：${weather.city}
国家：${weather.country}
天气：${weather.description}
当前温度：${temp.toStringAsFixed(1)}$tempSymbol
体感温度：${feelsLike.toStringAsFixed(1)}$tempSymbol
${tempMin != null && tempMax != null ? '温度范围：${tempMin.toStringAsFixed(1)}~$tempMax.toStringAsFixed(1)$tempSymbol' : ''}
湿度：${weather.humidity}%
气压：${weather.pressure ?? '未知'} hPa
风速：${weather.windSpeed} m/s
风向：${weather.getWindDirection()}
云量：${weather.cloudiness}%
能见度：${(weather.visibility / 1000).toStringAsFixed(1)} km
日出：$sunriseStr
日落：$sunsetStr
''';
  }

  static String formatTemperature(double temp, bool useCelsius) {
    final symbol = useCelsius ? '°C' : '°F';
    if (useCelsius) {
      return '${temp.toStringAsFixed(1)}$symbol';
    } else {
      return '${(temp * 9 / 5 + 32).toStringAsFixed(1)}$symbol';
    }
  }

  static String getWeatherSuggestion(WeatherData weather) {
    final suggestions = <String>[];
    
    if (weather.temperature > 30) {
      suggestions.add('今天气温很高，建议多喝水，避免长时间户外活动，注意防暑降温。');
    } else if (weather.temperature > 25) {
      suggestions.add('天气比较热，建议穿着轻薄透气的衣物，注意防晒。');
    } else if (weather.temperature > 20) {
      suggestions.add('天气舒适宜人，适合外出活动。');
    } else if (weather.temperature > 10) {
      suggestions.add('天气有点凉，建议带件外套。');
    } else if (weather.temperature > 0) {
      suggestions.add('天气较冷，记得穿厚一点哦！');
    } else {
      suggestions.add('今天非常寒冷！建议减少外出，注意保暖。');
    }

    if (weather.description.contains('雨')) {
      suggestions.add('今天有雨，出门记得带伞🌂');
    }
    if (weather.description.contains('雪')) {
      suggestions.add('有降雪天气，路面可能湿滑，出行请注意安全🚗');
    }
    if (weather.description.contains('雾') || weather.description.contains('霾')) {
      suggestions.add('有雾或霾天气，能见度较差，出行请注意安全');
    }
    if (weather.windSpeed > 10) {
      suggestions.add('风比较大，建议穿防风衣物');
    }
    if (weather.humidity > 80) {
      suggestions.add('空气湿度较大，可能会有点闷');
    }
    if (weather.humidity < 30) {
      suggestions.add('空气比较干燥，记得多喝水💧');
    }
    if (weather.cloudiness > 80) {
      suggestions.add('云层较厚，天气会比较阴沉');
    }

    if (suggestions.isEmpty) {
      suggestions.add('今天天气不错，祝您有个愉快的一天！');
    }

    return suggestions.join('\n');
  }

  static String formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      return '今天';
    } else if (date == today.add(const Duration(days: 1))) {
      return '明天';
    } else if (date == today.add(const Duration(days: 2))) {
      return '后天';
    } else {
      return DateFormat('M月d日').format(dt);
    }
  }
}
