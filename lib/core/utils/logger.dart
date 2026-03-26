import 'dart:developer' as developer;

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class AppLogger {
  static const String _defaultTag = 'App';

  static LogLevel _minLevel = LogLevel.debug;
  static bool _enabled = true;

  static final Map<String, bool> _moduleEnabled = {};

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

    final emoji = _getEmoji(level);
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    
    if (error != null) {
      developer.log(
        '$emoji [$tag] $message',
        level: _getDartLogLevel(level),
        error: error,
        stackTrace: stackTrace,
        time: DateTime.now(),
      );
    } else {
      developer.log(
        '$emoji [$tag] $message',
        level: _getDartLogLevel(level),
        time: DateTime.now(),
      );
    }
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
