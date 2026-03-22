import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';

/// 视频播放器核心 Widget
///
/// 提供统一的视频播放能力，支持网络视频和本地视频
class VideoPlayerWidget extends StatefulWidget {
  /// 视频 URL
  final String videoUrl;

  /// 是否自动播放
  final bool autoPlay;

  /// 是否循环播放
  final bool looping;

  /// 显示比例
  final double aspectRatio;

  /// 视频类型
  final BetterPlayerDataSourceType dataSourceType;

  /// 自定义请求头 (用于需要认证的视频)
  final Map<String, String>? headers;

  /// 字幕列表
  final List<BetterPlayerSubtitlesSource>? subtitles;

  /// 缓存配置
  final BetterPlayerCacheConfiguration? cacheConfiguration;

  /// 播放完成回调
  final VoidCallback? onFinished;

  /// 错误回调
  final void Function(String error)? onError;

  /// 视频时长（秒），用于覆盖播放器检测的时长
  final int? durationSeconds;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.looping = false,
    this.aspectRatio = 16 / 9,
    this.dataSourceType = BetterPlayerDataSourceType.network,
    this.headers,
    this.subtitles,
    this.cacheConfiguration,
    this.onFinished,
    this.onError,
    this.durationSeconds,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with WidgetsBindingObserver {
  late BetterPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  void _initController() {
    final dataSource = BetterPlayerDataSource(
      widget.dataSourceType,
      widget.videoUrl,
      headers: widget.headers,
      subtitles: widget.subtitles,
      cacheConfiguration: widget.cacheConfiguration,
      // 指定视频格式为 MP4
      videoFormat: BetterPlayerVideoFormat.other,
      // 强制设置视频时长（如果提供了的话）
      overriddenDuration: widget.durationSeconds != null
          ? Duration(seconds: widget.durationSeconds!)
          : null,
    );

    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        // 不自动播放，手动控制
        autoPlay: false,
        looping: widget.looping,
        // 显示占位符直到播放
        showPlaceholderUntilPlay: true,
        // 允许播放时显示进度条
        allowedScreenSleep: false,
        // 处理生命周期
        handleLifecycle: true,
        // 使用事件监听器获取初始化状态
        eventListener: (event) {
          _onPlayerEvent(event);
          // 当视频初始化完成且需要自动播放时
          if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
            if (widget.autoPlay) {
              // 延迟一小段时间确保元数据加载完成
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  _controller.play();
                }
              });
            }
          }
        },
        controlsConfiguration: BetterPlayerControlsConfiguration(
          // 启用所有控制功能
          enableFullscreen: true,
          enableMute: true,
          enableProgressBar: true,
          enableProgressBarDrag: true,
          enablePlayPause: true,
          enableSkips: true,
          enableOverflowMenu: true,
          enablePlaybackSpeed: true,
          enableSubtitles: true,
          enableQualities: true,
          enableRetry: true,
          // 控制栏显示配置
          showControls: true,
          showControlsOnInitialize: false, // 初始化时不显示控制栏
          controlsHideTime: const Duration(seconds: 3), // 3秒后自动隐藏
          // 进度条颜色
          progressBarPlayedColor: Color(0xFFFF5722),
          progressBarHandleColor: Color(0xFFFF5722),
        ),
      ),
      betterPlayerDataSource: dataSource,
    );

    setState(() {
      _isInitialized = true;
    });
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.finished:
        widget.onFinished?.call();
        if (widget.looping) {
          _controller.seekTo(Duration.zero);
          _controller.play();
        }
        break;
      case BetterPlayerEventType.exception:
        final error = event.parameters?['exception']?.toString() ?? 'Unknown error';
        setState(() {
          _errorMessage = error;
        });
        widget.onError?.call(error);
        break;
      case BetterPlayerEventType.progress:
        // 监听进度事件，视频加载后会持续触发
        // 这里可以用来获取视频时长和当前进度
        // 但不需要额外处理，播放器会自动使用这些数据
        break;
      default:
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _controller.pause();
        break;
      case AppLifecycleState.resumed:
        // 不自动恢复播放
        break;
      case AppLifecycleState.inactive:
        _controller.pause();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeEventsListener(_onPlayerEvent);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: BetterPlayer(controller: _controller),
    );
  }

  Widget _buildLoadingWidget() {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5722)),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                '视频加载失败',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isInitialized = false;
                  });
                  _initController();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 使用示例:
// VideoPlayerWidget(
//   videoUrl: 'https://example.com/video.mp4',
//   autoPlay: true,
//   looping: false,
//   onFinished: () => print('播放完成'),
//   onError: (error) => print('错误: $error'),
// )
