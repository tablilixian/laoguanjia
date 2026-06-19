import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MetronomePage extends StatefulWidget {
  const MetronomePage({super.key});

  @override
  State<MetronomePage> createState() => _MetronomePageState();
}

class _MetronomePageState extends State<MetronomePage>
    with SingleTickerProviderStateMixin {
  int _bpm = 120;
  bool _isPlaying = false;
  int _timeSignature = 4;
  int _currentBeat = -1;
  double _volume = 0.8;
  bool _muted = false;

  Timer? _timer;
  int _startTime = 0;
  int _beatCount = 0;
  final AudioPlayer _player = AudioPlayer();
  Uint8List? _tickWav;
  Uint8List? _accentWav;

  final List<int> _tapTimes = [];

  late AnimationController _pulseController;

  static const _minBpm = 20;
  static const _maxBpm = 280;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _generateSounds();
  }

  @override
  void dispose() {
    _stop();
    _timer?.cancel();
    _pulseController.dispose();
    _player.dispose();
    super.dispose();
  }

  void _generateSounds() {
    _tickWav = _generateWav(
      frequency: 1200,
      durationMs: 25,
      amplitude: 0.4,
    );
    _accentWav = _generateWav(
      frequency: 1800,
      durationMs: 45,
      amplitude: 0.7,
    );
  }

  Uint8List _generateWav({
    required int frequency,
    required int durationMs,
    required double amplitude,
  }) {
    final sampleRate = 44100;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataSize = numSamples * 2;
    final fileSize = 44 + dataSize;

    final data = ByteData(fileSize);
    int offset = 0;

    void writeRIFF() {
      data.setUint8(offset++, 0x52);
      data.setUint8(offset++, 0x49);
      data.setUint8(offset++, 0x46);
      data.setUint8(offset++, 0x46);
      data.setUint32(offset, fileSize - 8, Endian.little);
      offset += 4;
      data.setUint8(offset++, 0x57);
      data.setUint8(offset++, 0x41);
      data.setUint8(offset++, 0x56);
      data.setUint8(offset++, 0x45);
    }

    void writeFmt() {
      data.setUint8(offset++, 0x66);
      data.setUint8(offset++, 0x6D);
      data.setUint8(offset++, 0x74);
      data.setUint8(offset++, 0x20);
      data.setUint32(offset, 16, Endian.little);
      offset += 4;
      data.setUint16(offset, 1, Endian.little);
      offset += 2;
      data.setUint16(offset, 1, Endian.little);
      offset += 2;
      data.setUint32(offset, sampleRate, Endian.little);
      offset += 4;
      data.setUint32(offset, sampleRate * 2, Endian.little);
      offset += 4;
      data.setUint16(offset, 2, Endian.little);
      offset += 2;
      data.setUint16(offset, 16, Endian.little);
      offset += 2;
    }

    void writeData() {
      data.setUint8(offset++, 0x64);
      data.setUint8(offset++, 0x61);
      data.setUint8(offset++, 0x74);
      data.setUint8(offset++, 0x61);
      data.setUint32(offset, dataSize, Endian.little);
      offset += 4;

      final decay = durationMs / 1000.0;
      for (int i = 0; i < numSamples; i++) {
        final t = i / sampleRate;
        final envelope = exp(-6.0 * t / decay);
        final sample = sin(2 * pi * frequency * t) * amplitude * envelope;
        final intSample = (sample * 32767).round();
        data.setInt16(offset, intSample.clamp(-32767, 32767), Endian.little);
        offset += 2;
      }
    }

    writeRIFF();
    writeFmt();
    writeData();
    return data.buffer.asUint8List();
  }

  void _playBeat(int beat) async {
    if (_muted) return;
    try {
      final wav = beat == 0 ? _accentWav : _tickWav;
      if (wav != null) {
        await _player.setVolume(_volume);
        await _player.play(BytesSource(wav));
      }
    } catch (_) {}
  }

  void _start() {
    _isPlaying = true;
    _currentBeat = -1;
    _beatCount = 0;
    _startTime = DateTime.now().microsecondsSinceEpoch;
    _scheduleNext();
  }

  void _stop() {
    _isPlaying = false;
    _currentBeat = -1;
    _timer?.cancel();
    _pulseController.reset();
    if (mounted) setState(() {});
  }

  void _scheduleNext() {
    if (!_isPlaying) return;

    _timer?.cancel();
    final now = DateTime.now().microsecondsSinceEpoch;
    final interval = 60000000 ~/ _bpm;

    if (_beatCount == 0) {
      _timer = Timer(Duration.zero, () {
        if (!_isPlaying) return;
        _onBeat();
        _scheduleNext();
      });
      return;
    }

    final elapsed = now - _startTime;
    final target = _beatCount * interval;
    final delay = target - elapsed;

    _timer = Timer(Duration(microseconds: delay < 0 ? 0 : delay), () {
      if (!_isPlaying) return;
      _onBeat();
      _scheduleNext();
    });
  }

  void _onBeat() {
    if (!mounted) return;
    setState(() {
      _currentBeat = _beatCount % _timeSignature;
      _beatCount++;
    });
    _playBeat(_currentBeat);
    _pulseController.forward(from: 0);
  }

  void _adjustBpm(int delta) {
    setState(() {
      _bpm = (_bpm + delta).clamp(_minBpm, _maxBpm);
    });
    if (_isPlaying) {
      _scheduleNext();
    }
  }

  void _handleTap() {
    if (_isPlaying) return;
    final now = DateTime.now().microsecondsSinceEpoch;

    setState(() {
      _tapTimes.add(now);
      if (_tapTimes.length > 5) _tapTimes.removeAt(0);

      if (_tapTimes.length >= 3) {
        final intervals = <int>[];
        for (int i = 1; i < _tapTimes.length; i++) {
          intervals.add(_tapTimes[i] - _tapTimes[i - 1]);
        }
        intervals.sort();
        final median = intervals[intervals.length ~/ 2];
        final bpm = (60000000 / median).round();
        if (bpm >= _minBpm && bpm <= _maxBpm) {
          _bpm = bpm;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final surface = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '节拍器',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
            onPressed: () => setState(() => _muted = !_muted),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _BeatRing(
                  bpm: _bpm,
                  currentBeat: _isPlaying ? _currentBeat : -1,
                  timeSignature: _timeSignature,
                  isPlaying: _isPlaying,
                  pulseValue: _pulseController.value,
                  primaryColor: primary,
                  onSwipeUp: () => _adjustBpm(10),
                  onSwipeDown: () => _adjustBpm(-10),
                ),
              ),
            ),
            _BeatDots(
              currentBeat: _isPlaying ? _currentBeat : -1,
              timeSignature: _timeSignature,
              primaryColor: primary,
              pulseValue: _pulseController.value,
            ),
            const SizedBox(height: 8),
            Text(
              '$_bpm BPM',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 20),
            _ControlButtons(
              isPlaying: _isPlaying,
              onDecrement10: () => _adjustBpm(-10),
              onDecrement1: () => _adjustBpm(-1),
              onPlayPause: () {
                if (_isPlaying) {
                  _stop();
                } else {
                  _start();
                }
              },
              onIncrement1: () => _adjustBpm(1),
              onIncrement10: () => _adjustBpm(10),
              primaryColor: primary,
            ),
            const SizedBox(height: 16),
            _SettingsRow(
              timeSignature: _timeSignature,
              volume: _volume,
              isPlaying: _isPlaying,
              primaryColor: primary,
              onTimeSignatureChanged: (v) {
                setState(() => _timeSignature = v);
                if (_isPlaying) {
                  _currentBeat = 0;
                }
              },
              onVolumeChanged: (v) => setState(() => _volume = v),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _handleTap,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tap_and_play, size: 18, color: primary),
                    const SizedBox(width: 8),
                    Text(
                      _tapTimes.isEmpty ? '轻按此处 Tap 测速' : '继续点击测速...',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _BeatRing extends StatelessWidget {
  final int bpm;
  final int currentBeat;
  final int timeSignature;
  final bool isPlaying;
  final double pulseValue;
  final Color primaryColor;
  final VoidCallback onSwipeUp;
  final VoidCallback onSwipeDown;

  const _BeatRing({
    required this.bpm,
    required this.currentBeat,
    required this.timeSignature,
    required this.isPlaying,
    required this.pulseValue,
    required this.primaryColor,
    required this.onSwipeUp,
    required this.onSwipeDown,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final ringSize = size * 0.75;

        return GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -100) onSwipeUp();
              if (details.primaryVelocity! > 100) onSwipeDown();
            }
          },
          child: SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(ringSize, ringSize),
                  painter: _RingPainter(
                    currentBeat: currentBeat,
                    timeSignature: timeSignature,
                    isPlaying: isPlaying,
                    pulseValue: pulseValue,
                    primaryColor: primaryColor,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$bpm',
                      style: TextStyle(
                        fontSize: ringSize * 0.2,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        height: 1,
                      ),
                    ),
                    Text(
                      'BPM',
                      style: TextStyle(
                        fontSize: ringSize * 0.05,
                        fontWeight: FontWeight.w500,
                        color: primaryColor.withValues(alpha: 0.7),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final int currentBeat;
  final int timeSignature;
  final bool isPlaying;
  final double pulseValue;
  final Color primaryColor;

  _RingPainter({
    required this.currentBeat,
    required this.timeSignature,
    required this.isPlaying,
    required this.pulseValue,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    final strokeWidth = radius * 0.22;
    const gapAngle = 0.035;

    final bgPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final normalPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * (1 + pulseValue * 0.3)
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3 * (1 - pulseValue * 0.5))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final segmentAngle =
        (2 * pi - gapAngle * timeSignature) / timeSignature;

    for (int i = 0; i < timeSignature; i++) {
      final startAngle = -pi / 2 + i * (segmentAngle + gapAngle);
      final isActive = isPlaying && i == currentBeat;

      if (isActive) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          segmentAngle,
          false,
          glowPaint,
        );
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          segmentAngle,
          false,
          activePaint,
        );
      } else {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          segmentAngle,
          false,
          bgPaint,
        );
        if (isPlaying) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            startAngle,
            segmentAngle,
            false,
            normalPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.currentBeat != currentBeat ||
      oldDelegate.isPlaying != isPlaying ||
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.timeSignature != timeSignature;
}

class _BeatDots extends StatelessWidget {
  final int currentBeat;
  final int timeSignature;
  final Color primaryColor;
  final double pulseValue;

  const _BeatDots({
    required this.currentBeat,
    required this.timeSignature,
    required this.primaryColor,
    required this.pulseValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(timeSignature, (i) {
        final isActive = currentBeat == i;
        final isAccent = i == 0;
        final dotSize = isActive ? 10.0 : 6.0;

        return Container(
          width: dotSize + 8,
          height: dotSize + 8,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: isActive ? dotSize * (1 + pulseValue * 0.5) : dotSize,
            height: isActive ? dotSize * (1 + pulseValue * 0.5) : dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? (isAccent ? primaryColor : primaryColor.withValues(alpha: 0.8))
                  : primaryColor.withValues(alpha: 0.2),
            ),
          ),
        );
      }),
    );
  }
}

class _ControlButtons extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onDecrement10;
  final VoidCallback onDecrement1;
  final VoidCallback onPlayPause;
  final VoidCallback onIncrement1;
  final VoidCallback onIncrement10;
  final Color primaryColor;

  const _ControlButtons({
    required this.isPlaying,
    required this.onDecrement10,
    required this.onDecrement1,
    required this.onPlayPause,
    required this.onIncrement1,
    required this.onIncrement10,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(
          label: '-10',
          onTap: onDecrement10,
          primaryColor: primaryColor,
        ),
        const SizedBox(width: 8),
        _ControlBtn(
          label: '-1',
          onTap: onDecrement1,
          primaryColor: primaryColor,
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 64,
          height: 64,
          child: ElevatedButton(
            onPressed: onPlayPause,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              padding: EdgeInsets.zero,
            ),
            child: Icon(
              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 36,
            ),
          ),
        ),
        const SizedBox(width: 16),
        _ControlBtn(
          label: '+1',
          onTap: onIncrement1,
          primaryColor: primaryColor,
        ),
        const SizedBox(width: 8),
        _ControlBtn(
          label: '+10',
          onTap: onIncrement10,
          primaryColor: primaryColor,
        ),
      ],
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color primaryColor;

  const _ControlBtn({
    required this.label,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primaryColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final int timeSignature;
  final double volume;
  final bool isPlaying;
  final Color primaryColor;
  final ValueChanged<int> onTimeSignatureChanged;
  final ValueChanged<double> onVolumeChanged;

  const _SettingsRow({
    required this.timeSignature,
    required this.volume,
    required this.isPlaying,
    required this.primaryColor,
    required this.onTimeSignatureChanged,
    required this.onVolumeChanged,
  });

  static const signatures = [2, 3, 4, 5, 6, 7, 8, 9, 12];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _Dropdown(
            value: timeSignature,
            items: signatures,
            label: (v) => '$v/4',
            onChanged: isPlaying ? null : onTimeSignatureChanged,
            primaryColor: primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.volume_down_alt, size: 16, color: primaryColor.withValues(alpha: 0.6)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: primaryColor,
                          inactiveTrackColor: primaryColor.withValues(alpha: 0.15),
                          thumbColor: primaryColor,
                          overlayColor: primaryColor.withValues(alpha: 0.12),
                        ),
                        child: Slider(
                          value: volume,
                          onChanged: onVolumeChanged,
                        ),
                      ),
                    ),
                    Icon(Icons.volume_up, size: 16, color: primaryColor.withValues(alpha: 0.6)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final int value;
  final List<int> items;
  final String Function(int) label;
  final ValueChanged<int>? onChanged;
  final Color primaryColor;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          items: items
              .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      label(v),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: onChanged == null
                            ? primaryColor.withValues(alpha: 0.4)
                            : primaryColor,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged != null
              ? (v) {
                  if (v != null) onChanged!(v);
                }
              : null,
          icon: Icon(
            Icons.expand_more,
            size: 18,
            color: onChanged == null
                ? primaryColor.withValues(alpha: 0.4)
                : primaryColor,
          ),
        ),
      ),
    );
  }
}
