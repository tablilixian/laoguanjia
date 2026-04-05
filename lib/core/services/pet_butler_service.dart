import 'package:home_manager/data/models/weather_models.dart';
import 'package:home_manager/data/models/task.dart';
import 'package:home_manager/data/repositories/task_repository.dart';
import 'package:home_manager/data/local_db/app_database.dart' as db;

/// 管家播报数据模型
class ButlerBriefing {
  final String greeting;
  final String? weatherAdvice;
  final List<TaskAlert> taskAlerts;
  final List<ItemAlert> itemAlerts;

  const ButlerBriefing({
    required this.greeting,
    this.weatherAdvice,
    this.taskAlerts = const [],
    this.itemAlerts = const [],
  });

  bool get hasAlerts =>
      taskAlerts.isNotEmpty || itemAlerts.isNotEmpty || weatherAdvice != null;
}

/// 任务提醒
class TaskAlert {
  final Task task;
  final String urgency; // 'urgent', 'today', 'tomorrow', 'upcoming'
  final String message;

  const TaskAlert({
    required this.task,
    required this.urgency,
    required this.message,
  });
}

/// 物品提醒
class ItemAlert {
  final String itemName;
  final String alertType; // 'expired', 'expiring_soon', 'maintenance', 'low_stock'
  final String message;
  final String? location;

  const ItemAlert({
    required this.itemName,
    required this.alertType,
    required this.message,
    this.location,
  });
}

/// 宠物管家播报服务
///
/// 组合天气、任务、物品数据，生成管家播报内容。
class PetButlerService {
  final TaskRepository _taskRepo;
  final db.AppDatabase _localDb;

  PetButlerService({
    TaskRepository? taskRepo,
    db.AppDatabase? localDb,
  })  : _taskRepo = taskRepo ?? TaskRepository(),
        _localDb = localDb ?? db.AppDatabase();

  /// 生成晨间播报
  Future<ButlerBriefing> generateBriefing({
    required String householdId,
    required String petName,
    WeatherData? weather,
  }) async {
    final greeting = _generateGreeting(petName);
    final tasks = await _getTaskAlerts(householdId);
    final items = await _getItemAlerts();
    final weatherAdvice = weather != null ? _generateWeatherAdvice(weather) : null;

    return ButlerBriefing(
      greeting: greeting,
      weatherAdvice: weatherAdvice,
      taskAlerts: tasks,
      itemAlerts: items,
    );
  }

  String _generateGreeting(String petName) {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了，$petName 还在陪着你~ 🌙';
    if (hour < 9) return '早上好！$petName 已经准备好新的一天了 ☀️';
    if (hour < 12) return '上午好！$petName 想你了~ 😊';
    if (hour < 14) return '中午好！记得吃午饭哦 🍱';
    if (hour < 18) return '下午好！$petName 在等你呢~ 🌤️';
    if (hour < 22) return '晚上好！今天辛苦啦 🌆';
    return '夜深了，早点休息吧 $petName 陪你入眠 🌙';
  }

  Future<List<TaskAlert>> _getTaskAlerts(String householdId) async {
    try {
      final tasks = await _taskRepo.getTasks(householdId);
      final now = DateTime.now();
      final alerts = <TaskAlert>[];

      for (final task in tasks) {
        if (task.isCompleted || task.isDeleted) continue;

        final dueDate = task.dueDate;
        if (dueDate == null) continue;

        final diff = dueDate.difference(now);
        if (diff.isNegative) {
          alerts.add(TaskAlert(
            task: task,
            urgency: 'urgent',
            message: '「${task.title}」已经逾期了！',
          ));
        } else if (diff.inHours <= 2) {
          alerts.add(TaskAlert(
            task: task,
            urgency: 'urgent',
            message: '「${task.title}」快到期了，还剩不到2小时！',
          ));
        } else if (task.isDueToday) {
          alerts.add(TaskAlert(
            task: task,
            urgency: 'today',
            message: '今天需要完成「${task.title}」',
          ));
        } else if (task.isDueTomorrow) {
          alerts.add(TaskAlert(
            task: task,
            urgency: 'tomorrow',
            message: '明天要完成「${task.title}」',
          ));
        }
      }

      alerts.sort((a, b) {
        const order = {'urgent': 0, 'today': 1, 'tomorrow': 2, 'upcoming': 3};
        return (order[a.urgency] ?? 3).compareTo(order[b.urgency] ?? 3);
      });

      return alerts;
    } catch (_) {
      return [];
    }
  }

  Future<List<ItemAlert>> _getItemAlerts() async {
    try {
      final items = await _localDb.itemsDao.getAll();
      final alerts = <ItemAlert>[];
      final now = DateTime.now();

      for (final item in items) {
        if (item.deletedAt != null) continue;

        // 检查保修期
        if (item.warrantyExpiry != null) {
          final diff = item.warrantyExpiry!.difference(now);
          if (diff.isNegative) {
            alerts.add(ItemAlert(
              itemName: item.name,
              alertType: 'expired',
              message: '「${item.name}」保修期已过',
              location: item.locationId,
            ));
          } else if (diff.inDays <= 30) {
            alerts.add(ItemAlert(
              itemName: item.name,
              alertType: 'maintenance',
              message: '「${item.name}」保修期还剩 ${diff.inDays} 天',
              location: item.locationId,
            ));
          }
        }
      }

      alerts.sort((a, b) {
        const order = {
          'expired': 0,
          'expiring_soon': 1,
          'maintenance': 2,
          'low_stock': 3,
        };
        return (order[a.alertType] ?? 3).compareTo(order[b.alertType] ?? 3);
      });

      return alerts;
    } catch (_) {
      return [];
    }
  }

  String? _generateWeatherAdvice(WeatherData weather) {
    final temp = weather.temperature;
    final feelsLike = weather.feelsLike;
    final humidity = weather.humidity;
    final desc = weather.description.toLowerCase();

    final tips = <String>[];

    if (temp > 35) {
      tips.add('今天太热了 (${temp.toInt()}°C)，注意防暑降温！');
    } else if (temp > 30) {
      tips.add('今天有点热 (${temp.toInt()}°C)，穿轻薄透气的衣服~');
    } else if (temp < 0) {
      tips.add('今天很冷 (${temp.toInt()}°C)，穿厚一点！');
    } else if (temp < 10) {
      tips.add('今天比较冷 (${temp.toInt()}°C)，记得穿外套~');
    } else if (feelsLike != temp) {
      tips.add('体感温度 ${feelsLike.toInt()}°C，${feelsLike < temp ? '比实际温度冷' : '比实际温度热'}，注意调整穿着~');
    }

    if (humidity > 80) {
      tips.add('湿度很高，注意防潮~');
    } else if (humidity < 30) {
      tips.add('空气干燥，记得多喝水~');
    }

    if (desc.contains('rain') || desc.contains('drizzle')) {
      tips.add('今天有雨，出门记得带伞 ☂️');
    } else if (desc.contains('snow')) {
      tips.add('今天下雪了，路滑注意安全 ❄️');
    } else if (desc.contains('cloud')) {
      tips.add('今天多云，适合出门走走 ☁️');
    } else if (desc.contains('clear') || desc.contains('sun')) {
      tips.add('今天天气很好，适合户外活动 ☀️');
    }

    return tips.isEmpty ? null : tips.join(' ');
  }
}
