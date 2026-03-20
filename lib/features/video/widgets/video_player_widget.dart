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
    );

    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
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
          // 进度条颜色
          progressBarPlayedColor: Color(0xFFFF5722),
          progressBarHandleColor: Color(0xFFFF5722),
        ),
      ),
      betterPlayerDataSource: dataSource,
    );

    _controller.addEventsListener(_onPlayerEvent);

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
      case BetterPlayerEventType.error:
        final error = event.error ?? 'Unknown error';
        setState(() {
          _errorMessage = error;
        });
        widget.onError?.call(error);
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
