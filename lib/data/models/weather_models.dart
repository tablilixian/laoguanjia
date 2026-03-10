class WeatherPreference {
  final String? defaultCity;
  final String countryCode;
  final bool useGps;
  final bool useCelsius;

  WeatherPreference({
    this.defaultCity,
    this.countryCode = 'CN',
    this.useGps = false,
    this.useCelsius = true,
  });

  WeatherPreference copyWith({
    String? defaultCity,
    String? countryCode,
    bool? useGps,
    bool? useCelsius,
  }) {
    return WeatherPreference(
      defaultCity: defaultCity ?? this.defaultCity,
      countryCode: countryCode ?? this.countryCode,
      useGps: useGps ?? this.useGps,
      useCelsius: useCelsius ?? this.useCelsius,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultCity': defaultCity,
      'countryCode': countryCode,
      'useGps': useGps,
      'useCelsius': useCelsius,
    };
  }

  factory WeatherPreference.fromJson(Map<String, dynamic> json) {
    return WeatherPreference(
      defaultCity: json['defaultCity'] as String?,
      countryCode: json['countryCode'] as String? ?? 'CN',
      useGps: json['useGps'] as bool? ?? false,
      useCelsius: json['useCelsius'] as bool? ?? true,
    );
  }
}

class WeatherData {
  final String city;
  final String country;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final String description;
  final String icon;
  final double windSpeed;
  final int windDeg;
  final int cloudiness;
  final int visibility;
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime dt;
  final double? tempMin;
  final double? tempMax;
  final int? pressure;
  final int? seaLevel;
  final int? groundLevel;

  WeatherData({
    required this.city,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.windDeg,
    required this.cloudiness,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.dt,
    this.tempMin,
    this.tempMax,
    this.pressure,
    this.seaLevel,
    this.groundLevel,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final weather = (json['weather'] as List).first as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>;
    final clouds = json['clouds'] as Map<String, dynamic>;
    final sys = json['sys'] as Map<String, dynamic>;

    return WeatherData(
      city: json['name'] as String,
      country: sys['country'] as String? ?? '',
      temperature: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      humidity: main['humidity'] as int,
      description: weather['description'] as String,
      icon: weather['icon'] as String,
      windSpeed: (wind['speed'] as num).toDouble(),
      windDeg: wind['deg'] as int? ?? 0,
      cloudiness: clouds['all'] as int,
      visibility: json['visibility'] as int? ?? 10000,
      sunrise: DateTime.fromMillisecondsSinceEpoch(
        (sys['sunrise'] as int) * 1000,
      ),
      sunset: DateTime.fromMillisecondsSinceEpoch(
        (sys['sunset'] as int) * 1000,
      ),
      dt: DateTime.fromMillisecondsSinceEpoch(
        (json['dt'] as int) * 1000,
      ),
      tempMin: (main['temp_min'] as num?)?.toDouble(),
      tempMax: (main['temp_max'] as num?)?.toDouble(),
      pressure: main['pressure'] as int?,
      seaLevel: main['sea_level'] as int?,
      groundLevel: main['grnd_level'] as int?,
    );
  }

  String getWindDirection() {
    const directions = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
    final index = ((windDeg + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  String getWeatherEmoji() {
    final iconCode = icon;
    if (iconCode.startsWith('01')) return '☀️';
    if (iconCode.startsWith('02')) return '⛅';
    if (iconCode.startsWith('03')) return '☁️';
    if (iconCode.startsWith('04')) return '☁️';
    if (iconCode.startsWith('09')) return '🌧️';
    if (iconCode.startsWith('10')) return '🌧️';
    if (iconCode.startsWith('11')) return '⛈️';
    if (iconCode.startsWith('13')) return '❄️';
    if (iconCode.startsWith('50')) return '🌫️';
    return '🌤️';
  }
}
