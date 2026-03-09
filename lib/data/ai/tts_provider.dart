import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TTSState { stopped, playing, paused }

class TTSNotifier extends StateNotifier<TTSState> {
  final FlutterTts _flutterTts = FlutterTts();

  TTSNotifier() : super(TTSState.stopped) {
    _init();
  }

  Future<void> _init() async {
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
      state = TTSState.stopped;
    });
  }

  Future<void> speak(String text) async {
    await stop();
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    state = TTSState.stopped;
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    state = TTSState.paused;
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
