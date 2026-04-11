import 'dart:developer' as developer;

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// 日志记录模型
class LogRecord {
  final DateTime timestamp;
  final String tag;
  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const LogRecord({
    required this.timestamp,
    required this.tag,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get levelEmoji {
    switch (level) {
      case LogLevel.debug:
        return '🔵';
      case LogLevel.info:
        return '✅';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '🔴';
    }
  }

  String get levelName {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  String get formattedTime {
    return timestamp.toIso8601String().substring(11, 23);
  }

  @override
  String toString() {
    return '$levelEmoji [$tag] $message';
  }
}

class AppLogger {
  static const String _defaultTag = 'App';

  static LogLevel _minLevel = LogLevel.debug;
  static bool _enabled = true;

  static final Map<String, bool> _moduleEnabled = {};
  
  // 保存日志记录的列表
  static final List<LogRecord> _logRecords = [];
  
  // 最大日志记录数
  static const int _maxLogRecords = 1000;

  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  static void setModuleEnabled(String module, bool enabled) {
    _moduleEnabled[module] = enabled;
  }

  static bool _shouldLog(String tag, LogLevel level) {
    if (!_enabled) return false;
    if (level.index < _minLevel.index) return false;
    if (_moduleEnabled.isNotEmpty && _moduleEnabled[tag] == false) return false;
    return true;
  }

  static void _log(
    String tag,
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_shouldLog(tag, level)) return;

    final now = DateTime.now();
    final emoji = _getEmoji(level);
    final timestamp = now.toIso8601String().substring(11, 23);
    final logMessage = '$emoji [$tag] $message';
    
    // 保存日志记录
    final logRecord = LogRecord(
      timestamp: now,
      tag: tag,
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    
    _logRecords.add(logRecord);
    
    // 限制日志记录数量
    if (_logRecords.length > _maxLogRecords) {
      _logRecords.removeAt(0);
    }
    
    // 确保在web环境中也能看到日志
    if (error != null) {
      developer.log(
        logMessage,
        level: 0, // 使用最低级别确保显示
        error: error,
        stackTrace: stackTrace,
        time: now,
      );
    } else {
      developer.log(
        logMessage,
        level: 0, // 使用最低级别确保显示
        time: now,
      );
    }
    
    // 同时使用print确保在所有环境中都能看到
    print(logMessage);
  }

  static String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔵';
      case LogLevel.info:
        return '✅';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '🔴';
    }
  }

  static int _getDartLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }

  static void debug(String message, {String tag = _defaultTag}) {
    _log(tag, LogLevel.debug, message);
  }

  static void info(String message, {String tag = _defaultTag}) {
    _log(tag, LogLevel.info, message);
  }

  static void warning(String message, {String tag = _defaultTag}) {
    _log(tag, LogLevel.warning, message);
  }

  static void error(
    String message, {
    String tag = _defaultTag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(tag, LogLevel.error, message, error: error, stackTrace: stackTrace);
  }
  
  /// 获取所有日志记录
  static List<LogRecord> getLogRecords() {
    return List.from(_logRecords);
  }
  
  /// 清除所有日志记录
  static void clearLogRecords() {
    _logRecords.clear();
  }
  
  /// 获取指定标签的日志记录
  static List<LogRecord> getLogRecordsByTag(String tag) {
    return _logRecords.where((record) => record.tag == tag).toList();
  }
  
  /// 获取指定级别的日志记录
  static List<LogRecord> getLogRecordsByLevel(LogLevel level) {
    return _logRecords.where((record) => record.level == level).toList();
  }
}

class Logger {
  final String tag;

  const Logger(this.tag);

  void debug(String message) => AppLogger.debug(message, tag: tag);
  void info(String message) => AppLogger.info(message, tag: tag);
  void warning(String message) => AppLogger.warning(message, tag: tag);
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      AppLogger.error(message, tag: tag, error: error, stackTrace: stackTrace);
}
