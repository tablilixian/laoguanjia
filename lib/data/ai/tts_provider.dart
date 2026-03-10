import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TTSState { stopped, playing, paused }

class TTSNotifier extends StateNotifier<TTSState> {
  final FlutterTts _flutterTts = FlutterTts();
  String? _lastError;

  TTSNotifier() : super(TTSState.stopped) {
    _init();
  }

  String? get lastError => _lastError;

  Future<void> _init() async {
    try {
      // Android 需要设置共享实例
      if (Platform.isAndroid) {
        await _flutterTts.setSharedInstance(true);
      }
      
      await _flutterTts.setLanguage('zh-CN');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);



      _flutterTts.setStartHandler(() {
        state = TTSState.playing;
      });

      _flutterTts.setCompletionHandler(() {
        state = TTSState.stopped;
      });

      _flutterTts.setErrorHandler((msg) {
        _lastError = msg.toString();
        state = TTSState.stopped;
      });
    } catch (e) {
      _lastError = e.toString();
    }
  }

  Future<void> speak(String text) async {
    try {
      _lastError = null;
      await stop();
      await _flutterTts.speak(text);
    } catch (e) {
      _lastError = e.toString();
      state = TTSState.stopped;
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      state = TTSState.stopped;
    } catch (e) {
      _lastError = e.toString();
    }
  }

  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      state = TTSState.paused;
    } catch (e) {
      _lastError = e.toString();
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}

final ttsProvider = StateNotifierProvider<TTSNotifier, TTSState>((ref) {
  return TTSNotifier();
});
