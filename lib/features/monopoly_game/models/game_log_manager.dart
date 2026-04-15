// 地产大亨 - 游戏日志管理器
// 负责管理日志的存储、分发和查询

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'game_log.dart';

/// 日志配置
class GameLogConfig {
  final GameLogLevel minLevel;
  final bool enableConsole;
  final bool enableToast;
  final int maxEntries;

  const GameLogConfig({
    this.minLevel = GameLogLevel.debug,
    this.enableConsole = true,
    this.enableToast = true,
    this.maxEntries = 1000,
  });

  static const GameLogConfig defaultConfig = GameLogConfig();
}

/// 日志处理器接口
class GameLogHandler {
  void handle(GameLogEntry entry) {}
  Future<void> flush() async {}
  Future<void> close() async {}
}

/// 控制台日志处理器
class ConsoleGameLogHandler extends GameLogHandler {
  @override
  void handle(GameLogEntry entry) {
    final levelStr = entry.level.emoji;
    final playerStr = entry.playerName ?? '系统';
    final desc = entry.description.isNotEmpty && entry.description != entry.title
        ? ' - ${entry.description}'
        : '';
    debugPrint('$levelStr [GameLogger] $playerStr: ${entry.title}$desc');
  }
}

/// 游戏日志管理器
class GameLogManager extends ChangeNotifier {
  static GameLogManager? _instance;
  static GameLogManager get instance => _instance ??= GameLogManager._();

  GameLogManager._() {
    addHandler(ConsoleGameLogHandler());
  }

  final List<GameLogEntry> _entries = [];
  final List<GameLogHandler> _handlers = [];
  GameLogConfig _config = GameLogConfig.defaultConfig;

  int _currentTurnNumber = 0;
  String? _currentPlayerId;
  String? _currentPlayerName;
  int? _currentPlayerColor;

  final _uuid = const Uuid();

  List<GameLogEntry> get entries => List.unmodifiable(_entries);
  int get currentTurnNumber => _currentTurnNumber;
  GameLogConfig get config => _config;
  String? get currentPlayerId => _currentPlayerId;
  String? get currentPlayerName => _currentPlayerName;
  int? get currentPlayerColor => _currentPlayerColor;

  void setCurrentTurn(int turnNumber, {String? playerId, String? playerName, int? playerColor}) {
    _currentTurnNumber = turnNumber;
    _currentPlayerId = playerId;
    _currentPlayerName = playerName;
    _currentPlayerColor = playerColor;
  }

  void logEntry(GameLogEntry entry) {
    if (entry.level.level < _config.minLevel.level) return;

    _entries.add(entry);

    while (_entries.length > _config.maxEntries) {
      _entries.removeAt(0);
    }

    for (final handler in _handlers) {
      handler.handle(entry);
    }

    notifyListeners();
  }

  void updateConfig(GameLogConfig config) {
    _config = config;
    notifyListeners();
  }

  void addHandler(GameLogHandler handler) {
    _handlers.add(handler);
  }

  void removeHandler(GameLogHandler handler) {
    _handlers.remove(handler);
  }

  void _log(GameLogEntry entry) {
    if (entry.level.level < _config.minLevel.level) return;

    _entries.add(entry);

    while (_entries.length > _config.maxEntries) {
      _entries.removeAt(0);
    }

    for (final handler in _handlers) {
      handler.handle(entry);
    }

    notifyListeners();
  }

  void _logWithContext({
    required GameLogLevel level,
    required GameLogType type,
    required String title,
    required String description,
    int? amount,
    String? propertyName,
    String? targetPlayerId,
    String? targetPlayerName,
    Map<String, dynamic>? metadata,
    String? playerId,
    String? playerName,
    int? playerColor,
  }) {
    final entry = GameLogEntry(
      id: _uuid.v4(),
      turnNumber: _currentTurnNumber,
      playerId: playerId ?? _currentPlayerId,
      playerName: playerName ?? _currentPlayerName,
      playerColor: playerColor ?? _currentPlayerColor,
      level: level,
      type: type,
      title: title,
      description: description,
      amount: amount,
      propertyName: propertyName,
      targetPlayerId: targetPlayerId,
      targetPlayerName: targetPlayerName,
      metadata: metadata,
      timestamp: DateTime.now(),
    );

    _log(entry);
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  List<GameLogEntry> getFiltered({
    GameLogLevel? minLevel,
    GameLogType? type,
    String? playerId,
    int? turnNumber,
    String? searchQuery,
  }) {
    return _entries.where((entry) {
      if (minLevel != null && entry.level.level < minLevel.level) return false;
      if (type != null && entry.type != type) return false;
      if (playerId != null && entry.playerId != playerId) return false;
      if (turnNumber != null && entry.turnNumber != turnNumber) return false;
      if (searchQuery != null && !entry.description.contains(searchQuery)) return false;
      return true;
    }).toList();
  }

  Map<int, List<GameLogEntry>> getGroupedByTurn() {
    final Map<int, List<GameLogEntry>> grouped = {};
    for (final entry in _entries) {
      grouped.putIfAbsent(entry.turnNumber, () => []).add(entry);
    }
    return grouped;
  }

  List<Map<String, dynamic>> exportToJson() {
    return _entries.map((e) => e.toJson()).toList();
  }

  void importFromJson(List<Map<String, dynamic>> jsonList) {
    _entries.clear();
    for (final json in jsonList) {
      _entries.add(GameLogEntry.fromJson(json));
    }
    notifyListeners();
  }
}
