import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/data/ai/tts_provider.dart';

class TTSSettings {
  final bool enabled;
  final double speechRate;
  final double volume;

  TTSSettings({this.enabled = false, this.speechRate = 0.5, this.volume = 1.0});

  TTSSettings copyWith({bool? enabled, double? speechRate, double? volume}) {
    return TTSSettings(
      enabled: enabled ?? this.enabled,
      speechRate: speechRate ?? this.speechRate,
      volume: volume ?? this.volume,
    );
  }
}

class TTSSettingsNotifier extends Notifier<TTSSettings> {
  @override
  TTSSettings build() {
    return TTSSettings(enabled: false);
  }

  void toggle() {
    state = state.copyWith(enabled: !state.enabled);
  }

  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }

  void setSpeechRate(double rate) {
    state = state.copyWith(speechRate: rate);
  }

  void setVolume(double volume) {
    state = state.copyWith(volume: volume);
  }
}

final ttsSettingsProvider = NotifierProvider<TTSSettingsNotifier, TTSSettings>(
  TTSSettingsNotifier.new,
);
