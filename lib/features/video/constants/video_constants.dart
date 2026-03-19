/// 视频功能模块常量
///
/// 包含测试视频 URL 和相关常量

/// 测试视频 URL 列表 (CC0 公共版权)
class VideoConstants {
  VideoConstants._();

  // MP4 测试视频
  static const List<VideoTestSource> testVideos = [
    VideoTestSource(
      name: 'Big Buck Bunny',
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      description: '经典开源动画短片',
    ),
    VideoTestSource(
      name: 'Elephants Dream',
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      description: '开源 3D 动画',
    ),
    VideoTestSource(
      name: 'ForBiggerBlazes',
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      description: 'Google 测试视频 (短)',
    ),
    VideoTestSource(
      name: 'Butterfly',
      url:
          'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      description: 'Flutter 官方测试视频',
    ),
  ];

  // HLS 测试流
  static const List<VideoTestSource> hlsTestStreams = [
    VideoTestSource(
      name: 'Sintel HLS',
      url: 'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8',
      description: '支持多画质切换',
    ),
    VideoTestSource(
      name: 'Tears of Steel',
      url:
          'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
      description: '支持多音轨',
    ),
  ];

  // 默认测试视频
  static const String defaultTestVideo =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  // 默认 HLS 流
  static const String defaultHlsStream =
      'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8';
}

/// 测试视频源
class VideoTestSource {
  final String name;
  final String url;
  final String description;

  const VideoTestSource({
    required this.name,
    required this.url,
    required this.description,
  });
}
