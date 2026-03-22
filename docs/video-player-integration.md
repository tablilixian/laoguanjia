# 🎬 Better Player Plus 视频播放器接入文档

> 本文档详细记录了如何在 `home_manager` 项目中集成专业视频播放功能。
> 
> **方案选择**: Better Player Plus — 功能最全面的 Flutter 视频播放解决方案

---

## 📋 目录

1. [方案概述](#1-方案概述)
2. [功能特性](#2-功能特性)
3. [安装配置](#3-安装配置)
4. [代码示例](#4-代码示例)
5. [进阶功能](#5-进阶功能)
6. [测试资源](#6-测试资源)
7. [常见问题](#7-常见问题)

---

## 1. 方案概述

### 1.1 为什么选择 Better Player Plus

| 对比项 | video_player | chewie | Better Player Plus |
|--------|:---:|:---:|:---:|
| 基础播放 | ✅ | ✅ | ✅ |
| HLS 流媒体 | ⚠️ 基础 | ⚠️ 基础 | ✅ 完整 |
| DASH 流媒体 | ❌ | ❌ | ✅ |
| 多字幕轨道 | ❌ | ⚠️ | ✅ |
| 画质切换 | ❌ | ❌ | ✅ |
| 视频缓存 | ❌ | ❌ | ✅ |
| 播放列表 | ❌ | ❌ | ✅ |
| DRM 保护 | ❌ | ❌ | ✅ |
| 画中画 (PiP) | ✅ | ❌ | ✅ |

### 1.2 包信息

```yaml
包名: better_player_plus
版本: ^1.1.5
许可证: Apache 2.0
平台: Android, iOS
底层: Android Media3 (ExoPlayer) / iOS AVPlayer
```

---

## 2. 功能特性

### 2.1 播放源支持

- **网络视频**: MP4, WebM 等直接链接
- **HLS 流媒体**: m3u8 自适应流
- **DASH 流媒体**: mpd 格式
- **本地文件**: 设备存储的视频文件
- **内存视频**: bytes 数据直接播放

### 2.2 播放控制

- 播放/暂停/停止
- 进度拖动
- 音量控制/静音
- 播放速度 (0.5x - 2.0x)
- 10秒快进/快退
- 全屏切换
- 画中画模式

### 2.3 专业功能

- **字幕**: SRT, WebVTT, HLS 内嵌字幕
- **多音轨**: 切换不同语言/声道
- **画质选择**: HLS 多分辨率切换
- **视频缓存**: 离线播放支持
- **DRM**: Token, Widevine, FairPlay

---

## 3. 安装配置

### 3.1 添加依赖

编辑 `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # ... 其他现有依赖 ...
  
  # 视频播放器
  better_player_plus: ^1.1.5
```

执行安装:
```bash
flutter pub get
```

### 3.2 Android 配置

编辑 `android/app/build.gradle.kts`:

```kotlin
android {
    namespace = "com.family.home_manager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.family.home_manager"
        minSdk = 24  // Better Player Plus 要求最低 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // ✅ 启用 Multidex (如果应用较大)
        multiDexEnabled = true
    }
}

// ✅ 添加 Multidex 依赖
dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
```

### 3.3 iOS 配置

#### 3.3.1 Podfile

编辑 `ios/Podfile`:

```ruby
platform :ios, '11.0'  # 最低 iOS 11

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
      config.build_settings['SWIFT_VERSION'] = '5.0'
    end
  end
end
```

#### 3.3.2 Info.plist (已配置)

`ios/Runner/Info.plist` 已包含全屏旋转支持，无需额外配置。

如需播放 HTTP 视频（非 HTTPS），添加:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## 4. 代码示例

### 4.1 基础使用

```dart
import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';

class BasicVideoPlayerPage extends StatefulWidget {
  const BasicVideoPlayerPage({super.key});

  @override
  State<BasicVideoPlayerPage> createState() => _BasicVideoPlayerPageState();
}

class _BasicVideoPlayerPageState extends State<BasicVideoPlayerPage> {
  late BetterPlayerController _controller;
  
  // 测试视频 URL
  static const String _videoUrl = 
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      _videoUrl,
    );

    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        autoPlay: false,
        looping: false,
        fit: BoxFit.contain,
      ),
      betterPlayerDataSource: dataSource,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频播放')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _controller),
          ),
          const SizedBox(height: 16),
          // 播放控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () => _controller.play(),
              ),
              IconButton(
                icon: const Icon(Icons.pause),
                onPressed: () => _controller.pause(),
              ),
              IconButton(
                icon: const Icon(Icons.replay_10),
                onPressed: () async {
                  final position = await _controller.videoPlayerController?.position;
                  if (position != null) {
                    _controller.seekTo(position - const Duration(seconds: 10));
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.forward_10),
                onPressed: () async {
                  final position = await _controller.videoPlayerController?.position;
                  if (position != null) {
                    _controller.seekTo(position + const Duration(seconds: 10));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### 4.2 本地视频播放

```dart
import 'dart:io';
import 'package:better_player_plus/better_player_plus.dart';

// 选择本地文件
Future<void> _pickAndPlayLocalVideo() async {
  // 使用 file_picker 包选择视频
  // final result = await FilePicker.platform.pickFiles(type: FileType.video);
  // if (result != null && result.files.single.path != null) {
  //   final file = File(result.files.single.path!);
  //   await _playLocalFile(file);
  // }

  // 或者直接播放已知路径
  final file = File('/path/to/your/video.mp4');
  await _playLocalFile(file);
}

Future<void> _playLocalFile(File file) async {
  final dataSource = BetterPlayerDataSource(
    BetterPlayerDataSourceType.file,
    file.path,
  );

  final controller = BetterPlayerController(
    const BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      autoPlay: true,
    ),
    betterPlayerDataSource: dataSource,
  );

  if (mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(file.path.split('/').last)),
          body: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: BetterPlayer(controller: controller),
            ),
          ),
        ),
      ),
    );
  }
}
```

### 4.3 HLS 流媒体播放

```dart
import 'package:better_player_plus/better_player_plus.dart';

class HLSPlayerPage extends StatefulWidget {
  const HLSPlayerPage({super.key});

  @override
  State<HLSPlayerPage> createState() => _HLSPlayerPageState();
}

class _HLSPlayerPageState extends State<HLSPlayerPage> {
  late BetterPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    // HLS 测试流
    const hlsUrl = 'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8';

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      hlsUrl,
      videoFormat: BetterPlayerVideoFormat.hls,
      useAsmsTracks: true,        // 启用画质选择
      useAsmsSubtitles: true,     // 启用字幕选择
      useAsmsAudioTracks: true,   // 启用音轨选择
    );

    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        autoPlay: true,
        liveStream: false,  // 设置为 true 如果是直播
      ),
      betterPlayerDataSource: dataSource,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HLS 流媒体播放')),
      body: AspectRatio(
        aspectRatio: 16 / 9,
        child: BetterPlayer(controller: _controller),
      ),
    );
  }
}
```

### 4.4 自定义控制栏

```dart
BetterPlayerController(
  BetterPlayerConfiguration(
    aspectRatio: 16 / 9,
    controlsConfiguration: BetterPlayerControlsConfiguration(
      // 颜色配置
      controlBarColor: Colors.black87,
      textColor: Colors.white,
      iconsColor: Colors.white,
      progressBarPlayedColor: Colors.red,
      progressBarHandleColor: Colors.red,
      progressBarBufferedColor: Colors.white70,
      progressBarBackgroundColor: Colors.white30,
      
      // 控制栏尺寸
      controlBarHeight: 48.0,
      
      // 功能开关
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
      enablePip: true,
      enableRetry: true,
      enableAudioTracks: true,
      
      // 跳过时间 (毫秒)
      forwardSkipTimeInMilliseconds: 10000,   // 快进 10秒
      backwardSkipTimeInMilliseconds: 10000,  // 快退 10秒
      
      // 控制栏显示时间
      controlsHideTime: const Duration(seconds: 3),
    ),
  ),
  betterPlayerDataSource: dataSource,
);
```

### 4.5 带字幕的视频

```dart
BetterPlayerDataSource dataSource = BetterPlayerDataSource(
  BetterPlayerDataSourceType.network,
  'https://example.com/video.mp4',
  subtitles: [
    BetterPlayerSubtitlesSource(
      type: BetterPlayerSubtitlesSourceType.network,
      url: 'https://example.com/subtitles/en.srt',
      name: 'English',
    ),
    BetterPlayerSubtitlesSource(
      type: BetterPlayerSubtitlesSourceType.network,
      url: 'https://example.com/subtitles/zh.srt',
      name: '中文',
    ),
  ],
);
```

### 4.6 全屏播放

```dart
BetterPlayerController(
  BetterPlayerConfiguration(
    aspectRatio: 16 / 9,
    
    // 全屏配置
    fullScreenByDefault: false,  // 是否默认全屏
    fullScreenAspectRatio: 16 / 9,
    autoDetectFullscreenDeviceOrientation: true,  // 自动检测方向
    autoDetectFullscreenAspectRatio: true,        // 自动检测比例
    
    // 全屏时的设备方向
    deviceOrientationsOnFullScreen: [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    
    // 退出全屏后的方向
    deviceOrientationsAfterFullScreen: [
      DeviceOrientation.portraitUp,
    ],
    
    // 系统 UI
    systemOverlaysAfterFullScreen: SystemUiOverlay.values,
    allowedScreenSleep: false,
  ),
  betterPlayerDataSource: dataSource,
);

// 编程控制
_controller.enterFullScreen();
_controller.exitFullScreen();
_controller.isFullScreen.then((isFull) => print('全屏状态: $isFull'));
```

### 4.7 播放列表

```dart
class PlaylistPlayerPage extends StatelessWidget {
  List<BetterPlayerDataSource> _createDataSourceList() {
    return [
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      ),
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      ),
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('播放列表')),
      body: BetterPlayerPlaylist(
        betterPlayerConfiguration: const BetterPlayerConfiguration(
          aspectRatio: 16 / 9,
          autoPlay: true,
        ),
        betterPlayerPlaylistConfiguration: const BetterPlayerPlaylistConfiguration(
          loopVideos: true,                    // 循环播放
          nextVideoDelay: Duration(seconds: 3), // 间隔 3 秒
        ),
        betterPlayerDataSourceList: _createDataSourceList(),
      ),
    );
  }
}
```

### 4.8 视频缓存 (离线播放)

```dart
BetterPlayerDataSource dataSource = BetterPlayerDataSource(
  BetterPlayerDataSourceType.network,
  'https://example.com/video.mp4',
  cacheConfiguration: const BetterPlayerCacheConfiguration(
    useCache: true,
    preCacheSize: 10 * 1024 * 1024,      // 预缓存 10MB
    maxCacheSize: 100 * 1024 * 1024,     // 最大缓存 100MB
    maxCacheFileSize: 50 * 1024 * 1024,  // 单文件最大 50MB
    key: 'video_cache_key',              // 缓存标识
  ),
);

// 编程控制缓存
Future<void> preCacheVideo() async {
  BetterPlayerDataSource cacheDataSource = BetterPlayerDataSource(
    BetterPlayerDataSourceType.network,
    'https://example.com/another_video.mp4',
    cacheConfiguration: const BetterPlayerCacheConfiguration(
      useCache: true,
      preCacheSize: 5 * 1024 * 1024,
    ),
  );
  await _controller.preCache(cacheDataSource);
  print('视频预缓存完成');
}

Future<void> clearVideoCache() async {
  await _controller.clearCache();
  print('缓存已清除');
}
```

---

## 5. 进阶功能

### 5.1 Riverpod 集成

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:better_player_plus/better_player_plus.dart';

// Provider
final betterPlayerControllerProvider = Provider.family<
    BetterPlayerController,
    VideoSource
>((ref, source) {
  final controller = BetterPlayerController(
    const BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      autoPlay: false,
    ),
    betterPlayerDataSource: BetterPlayerDataSource(
      source.type,
      source.url,
      headers: source.headers,
      subtitles: source.subtitles,
    ),
  );
  
  ref.onDispose(() => controller.dispose());
  return controller;
});

class VideoSource {
  final BetterPlayerDataSourceType type;
  final String url;
  final Map<String, String>? headers;
  final List<BetterPlayerSubtitlesSource>? subtitles;
  
  VideoSource({
    required this.type,
    required this.url,
    this.headers,
    this.subtitles,
  });
}

// 使用
class VideoPlayerWidget extends ConsumerWidget {
  final VideoSource source;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(betterPlayerControllerProvider(source));
    
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: BetterPlayer(controller: controller),
    );
  }
}
```

### 5.2 监听播放状态

```dart
_controller.addEventsListener((event) {
  switch (event.betterPlayerEventType) {
    case BetterPlayerEventType.play:
      print('开始播放');
      break;
    case BetterPlayerEventType.pause:
      print('暂停');
      break;
    case BetterPlayerEventType.progress:
      // 进度更新
      final progress = event.parameters?['progress'] as double?;
      break;
    case BetterPlayerEventType.finished:
      print('播放完成');
      _onVideoFinished();
      break;
    case BetterPlayerEventType.error:
      print('错误: ${event.error}');
      _showErrorDialog(event.error ?? 'Unknown error');
      break;
    case BetterPlayerEventType.bufferingStart:
      print('开始缓冲');
      break;
    case BetterPlayerEventType.bufferingUpdate:
      print('缓冲更新');
      break;
    case BetterPlayerEventType.bufferingEnd:
      print('缓冲结束');
      break;
    case BetterPlayerEventType.fullScreenChange:
      print('全屏状态变化');
      break;
    case BetterPlayerEventType.qualityChanged:
      final quality = event.parameters?['quality'] as String?;
      print('画质切换: $quality');
      break;
  }
});
```

### 5.3 DRM 保护 (高级)

```dart
// Token DRM
BetterPlayerDataSource dataSource = BetterPlayerDataSource(
  BetterPlayerDataSourceType.network,
  'https://protected-content.com/video',
  drmConfiguration: BetterPlayerDrmConfiguration(
    drmType: BetterPlayerDrmType.token,
    token: 'your_bearer_token',
  ),
);

// Widevine DRM (Android)
BetterPlayerDrmConfiguration(
  drmType: BetterPlayerDrmType.widevine,
  licenseUrl: 'https://license.server.com/widevine',
  headers: {'Authorization': 'Bearer token'},
)

// FairPlay DRM (iOS) via EZDRM
BetterPlayerDrmConfiguration(
  drmType: BetterPlayerDrmType.fairplay,
  licenseUrl: 'https://fpsdk1.ezdrm.com/c西游/play',
  certificateUrl: 'https://fpsdk1.ezdrm.com/c西游/cert',
)
```

### 5.4 画中画模式

```dart
BetterPlayerConfiguration(
  controlsConfiguration: BetterPlayerControlsConfiguration(
    enablePip: true,
  ),
)

// 编程控制
_controller.enablePiP();
_controller.disablePiP();
_controller.isPiPSupported.then((supported) {
  print('PiP 支持: $supported');
});
```

---

## 6. Pixabay API 集成

> **方案**: 使用 Pixabay Video API 作为视频源，提供海量免费视频 + 缩略图

### 6.1 为什么选择 Pixabay

| 特性 | 说明 |
|------|------|
| **免费无限调用** | 无需担心配额限制（合理使用） |
| **CC0 协议** | 所有视频无版权，可商用 |
| **带缩略图** | 每个视频都有高质量缩略图 |
| **分类丰富** | 自然、动物、城市、人物、科技等 |
| **搜索能力** | 支持关键词搜索 + 标签筛选 |

### 6.2 API 配置

#### 1. 注册获取 API Key

1. 访问 https://pixabay.com 注册账号
2. 进入 https://pixabay.com/api/docs/ 获取 API Key
3. 将 Key 配置到项目中

#### 2. 环境配置

创建 `lib/core/config/api_config.dart`:

```dart
class ApiConfig {
  ApiConfig._();
  
  // Pixabay API Key（请替换为你自己的 Key）
  static const String pixabayApiKey = 'YOUR_PIXABAY_API_KEY';
  
  // API 基础 URL
  static const String pixabayBaseUrl = 'https://pixabay.com/api/videos/';
}
```

### 6.3 API 端点

#### 视频搜索

```
GET https://pixabay.com/api/videos/
```

**参数说明**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `key` | string | ✅ | API Key |
| `q` | string | ❌ | 搜索关键词（URL编码） |
| `lang` | string | ❌ | 语言，默认 `en` |
| `video_type` | string | ❌ | `film`, `animation` |
| `category` | string | ❌ | `backgrounds`, `fashion`, `nature`, `science`, `education`, `feelings`, `health`, `people`, `religion`, `places`, `animals`, `industry`, `computer`, `food`, `sports`, `transportation`, `travel`, `buildings`, `business`, `music` |
| `min_width` | int | ❌ | 最小宽度 |
| `min_height` | int | ❌ | 最小高度 |
| `editors_choice` | bool | ❌ | 编辑精选 |
| `safesearch` | bool | ❌ | 安全搜索 |
| `order` | string | ❌ | `popular`, `latest` |
| `page` | int | ❌ | 页码 |
| `per_page` | int | ❌ | 每页数量（3-200） |

**响应示例**:

```json
{
  "total": 1250,
  "totalHits": 1250,
  "hits": [
    {
      "id": 2499611,
      "pageURL": "https://pixabay.com/videos/...",
      "type": "film",
      "tags": "ocean, water, sea",
      "duration": 33,
      "videos": {
        "large": {
          "url": "https://cdn.pixabay.com/video/...large.mp4",
          "width": 3840,
          "height": 2160,
          "size": 6615235,
          "thumbnail": "https://cdn.pixabay.com/video/...large.jpg"
        },
        "medium": {
          "url": "https://cdn.pixabay.com/video/...medium.mp4",
          "width": 1920,
          "height": 1080,
          "size": 2500000,
          "thumbnail": "https://cdn.pixabay.com/video/...medium.jpg"
        },
        "small": {
          "url": "https://cdn.pixabay.com/video/...small.mp4",
          "width": 1280,
          "height": 720,
          "size": 1200000,
          "thumbnail": "https://cdn.pixabay.com/video/...small.jpg"
        }
      },
      "views": 150000,
      "downloads": 50000,
      "likes": 2500,
      "user_id": 12345,
      "user": "username",
      "userImageURL": "https://cdn.pixabay.com/user/...250x250.jpg"
    }
  ]
}
```

### 6.4 数据模型

```dart
// lib/features/video/models/pixabay_video.dart

/// Pixabay 视频数据模型
class PixabayVideo {
  final int id;
  final String pageUrl;
  final String tags;
  final int duration; // 秒
  final VideoFile videoLarge;
  final VideoFile videoMedium;
  final VideoFile videoSmall;
  final int views;
  final int downloads;
  final int likes;
  final String userName;
  final String userImageUrl;

  const PixabayVideo({
    required this.id,
    required this.pageUrl,
    required this.tags,
    required this.duration,
    required this.videoLarge,
    required this.videoMedium,
    required this.videoSmall,
    required this.views,
    required this.downloads,
    required this.likes,
    required this.userName,
    required this.userImageUrl,
  });

  /// 获取最佳播放源（优先 medium）
  VideoFile get bestVideo => videoMedium.url.isNotEmpty ? videoMedium : videoSmall;
  
  /// 获取缩略图
  String get thumbnailUrl => bestVideo.thumbnail;

  /// 获取播放 URL
  String get videoUrl => bestVideo.url;

  /// 从 JSON 创建
  factory PixabayVideo.fromJson(Map<String, dynamic> json) {
    final videos = json['videos'] as Map<String, dynamic>;
    return PixabayVideo(
      id: json['id'] as int,
      pageUrl: json['pageURL'] as String? ?? '',
      tags: json['tags'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      videoLarge: VideoFile.fromJson(videos['large'] as Map<String, dynamic>? ?? {}),
      videoMedium: VideoFile.fromJson(videos['medium'] as Map<String, dynamic>? ?? {}),
      videoSmall: VideoFile.fromJson(videos['small'] as Map<String, dynamic>? ?? {}),
      views: json['views'] as int? ?? 0,
      downloads: json['downloads'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      userName: json['user'] as String? ?? '',
      userImageUrl: json['userImageURL'] as String? ?? '',
    );
  }

  /// 获取标签列表
  List<String> get tagList => tags.split(', ').where((t) => t.isNotEmpty).toList();
}

/// 视频文件信息
class VideoFile {
  final String url;
  final int width;
  final int height;
  final int size;
  final String thumbnail;

  const VideoFile({
    required this.url,
    required this.width,
    required this.height,
    required this.size,
    required this.thumbnail,
  });

  factory VideoFile.fromJson(Map<String, dynamic> json) {
    return VideoFile(
      url: json['url'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      thumbnail: json['thumbnail'] as String? ?? '',
    );
  }
}

/// API 响应模型
class PixabayVideoResponse {
  final int total;
  final int totalHits;
  final List<PixabayVideo> videos;

  const PixabayVideoResponse({
    required this.total,
    required this.totalHits,
    required this.videos,
  });

  factory PixabayVideoResponse.fromJson(Map<String, dynamic> json) {
    return PixabayVideoResponse(
      total: json['total'] as int? ?? 0,
      totalHits: json['totalHits'] as int? ?? 0,
      videos: (json['hits'] as List<dynamic>? ?? [])
          .map((h) => PixabayVideo.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }
}
```

### 6.5 视频分类定义

```dart
// lib/features/video/constants/video_categories.dart

/// 视频分类
enum VideoCategory {
  all('全部', null),
  nature('自然', 'nature'),
  animals('动物', 'animals'),
  people('人物', 'people'),
  places('风景', 'places'),
  travel('旅行', 'travel'),
  food('美食', 'food'),
  sports('运动', 'sports'),
  music('音乐', 'music'),
  science('科技', 'science'),
  business('商务', 'business'),
  background('背景', 'backgrounds');

  const VideoCategory(this.label, this.apiValue);
  
  final String label;      // 显示名称
  final String? apiValue;  // API 参数值（null 表示全部）
}

/// Tab 类型
enum VideoTab {
  popular('热门', 'popular'),
  latest('最新', 'latest'),
  editorsChoice('精选', null); // 需要用 editors_choice=true

  const VideoTab(this.label, this.orderValue);
  
  final String label;
  final String? orderValue;
}
```

### 6.6 API Service 示例

```dart
// lib/features/video/services/pixabay_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/pixabay_video.dart';
import '../constants/video_categories.dart';
import '../../../core/config/api_config.dart';

/// Pixabay API 服务
class PixabayService {
  final http.Client _httpClient;
  
  PixabayService({http.Client? httpClient}) 
      : _httpClient = httpClient ?? http.Client();

  /// 搜索视频
  Future<PixabayVideoResponse> searchVideos({
    String? query,
    VideoCategory? category,
    VideoTab? tab,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{
      'key': ApiConfig.pixabayApiKey,
      'video_type': 'film',
      'per_page': perPage.toString(),
      'page': page.toString(),
    };

    // 搜索词
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }

    // 分类
    if (category != null && category.apiValue != null) {
      params['category'] = category.apiValue!;
    }

    // 排序
    if (tab != null) {
      if (tab == VideoTab.editorsChoice) {
        params['editors_choice'] = 'true';
      } else if (tab.orderValue != null) {
        params['order'] = tab.orderValue!;
      }
    }

    final uri = Uri.parse(ApiConfig.pixabayBaseUrl).replace(queryParameters: params);
    final response = await _httpClient.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PixabayVideoResponse.fromJson(json);
    } else {
      throw Exception('Pixabay API 错误: ${response.statusCode}');
    }
  }

  /// 获取热门视频
  Future<List<PixabayVideo>> getPopularVideos({int page = 1}) async {
    final result = await searchVideos(tab: VideoTab.popular, page: page);
    return result.videos;
  }

  /// 按分类获取视频
  Future<List<PixabayVideo>> getVideosByCategory(
    VideoCategory category, {
    int page = 1,
  }) async {
    final result = await searchVideos(category: category, page: page);
    return result.videos;
  }

  void dispose() {
    _httpClient.close();
  }
}
```

---

## 7. 视频库页面设计

### 7.1 页面结构

```
VideoLibraryPage (视频库首页)
├── 顶部: Tab 栏 (热门 | 最新 | 精选)
├── 中部: 分类标签栏 (横向滚动)
│   └── 全部 | 自然 | 动物 | 人物 | 风景 | ...
├── 主体: 视频卡片网格 (2列)
│   └── VideoCard
│       ├── 缩略图 (带播放按钮)
│       ├── 标题/标签
│       ├── 时长
│       └── 作者头像 + 用户名
└── 底部: 加载更多 / 分页指示器
```

### 7.2 页面代码示例

```dart
// lib/features/video/pages/video_library_page.dart

import 'package:flutter/material.dart';
import '../models/pixabay_video.dart';
import '../services/pixabay_service.dart';
import '../constants/video_categories.dart';
import '../widgets/video_card.dart';
import 'video_player_page.dart';

class VideoLibraryPage extends StatefulWidget {
  const VideoLibraryPage({super.key});

  @override
  State<VideoLibraryPage> createState() => _VideoLibraryPageState();
}

class _VideoLibraryPageState extends State<VideoLibraryPage> {
  final PixabayService _service = PixabayService();
  final List<PixabayVideo> _videos = [];
  
  VideoTab _currentTab = VideoTab.popular;
  VideoCategory _currentCategory = VideoCategory.all;
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = 1;
        _videos.clear();
        _hasMore = true;
      }
    });

    try {
      final result = await _service.searchVideos(
        category: _currentCategory,
        tab: _currentTab,
        page: _currentPage,
      );

      setState(() {
        _videos.addAll(result.videos);
        _hasMore = result.videos.length >= 20;
        _currentPage++;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频库')),
      body: Column(
        children: [
          // Tab 栏
          _buildTabBar(),
          
          // 分类标签栏
          _buildCategoryChips(),
          
          // 视频网格
          Expanded(child: _buildVideoGrid()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Row(
      children: VideoTab.values.map((tab) {
        final isSelected = tab == _currentTab;
        return Expanded(
          child: InkWell(
            onTap: () {
              setState(() => _currentTab = tab);
              _loadVideos(refresh: true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                tab.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: VideoCategory.values.length,
        itemBuilder: (context, index) {
          final category = VideoCategory.values[index];
          final isSelected = category == _currentCategory;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(category.label),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _currentCategory = category);
                _loadVideos(refresh: true);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoGrid() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoading && 
            _hasMore && 
            scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          _loadVideos();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 16 / 12,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _videos.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _videos.length) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final video = _videos[index];
          return VideoCard(
            video: video,
            onTap: () => _playVideo(video),
          );
        },
      ),
    );
  }

  void _playVideo(PixabayVideo video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          videoUrl: video.videoUrl,
          title: video.tags,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
```

### 7.3 VideoCard 组件

```dart
// lib/features/video/widgets/video_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/pixabay_video.dart';

class VideoCard extends StatelessWidget {
  final PixabayVideo video;
  final VoidCallback onTap;

  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 缩略图
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.error, color: Colors.white54),
                    ),
                  ),
                  // 播放按钮
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  // 时长
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(video.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 信息栏
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  // 用户头像
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: video.userImageUrl.isNotEmpty
                        ? NetworkImage(video.userImageUrl)
                        : null,
                    child: video.userImageUrl.isEmpty
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // 标签
                  Expanded(
                    child: Text(
                      video.tagList.first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
```

---

## 8. 测试资源（保留原有内容）

### 8.1 公开测试视频

| 视频名称 | URL | 格式 | 许可证 |
|---------|-----|------|-------|
| Big Buck Bunny | `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4` | MP4 | CC0 |
| ForBiggerBlazes | `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4` | MP4 | CC0 |
| Elephants Dream | `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4` | MP4 | CC0 |
| Sintel Trailer | `https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4` | MP4 | BSD |

### 8.2 HLS 测试流

| 名称 | URL |
|-----|-----|
| Sintel HLS | `https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8` |
| Tears of Steel | `https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8` |

---

## 9. 常见问题

### Q1: 视频无法播放，显示黑屏

**可能原因**:
1. 网络权限未配置
2. 视频格式不支持
3. URL 无效

**解决方案**:
```xml
<!-- Android: AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET"/>

<!-- iOS: Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Q2: iOS 模拟器播放失败

Better Player Plus 需要 iOS 14+ 或真机进行完整测试。模拟器支持有限。

### Q3: 如何处理生命周期?

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.paused:
      _controller.pause();
      break;
    case AppLifecycleState.resumed:
      _controller.play();
      break;
  }
}
```

### Q4: 如何获取当前播放进度?

```dart
final position = await _controller.videoPlayerController?.position;
final duration = _controller.videoPlayerController?.value.duration;

// 格式化为 mm:ss
String formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
```

---

## 📁 相关文件

### 现有文件
- `lib/features/video/widgets/video_player_widget.dart` - 播放器组件
- `lib/features/video/pages/video_player_page.dart` - 视频播放器页面
- `lib/features/video/constants/video_constants.dart` - 测试视频常量

### 新增文件（视频库功能）
- `lib/core/config/api_config.dart` - API 配置（Pixabay Key）
- `lib/features/video/models/pixabay_video.dart` - Pixabay 数据模型
- `lib/features/video/constants/video_categories.dart` - 视频分类定义
- `lib/features/video/services/pixabay_service.dart` - Pixabay API 服务
- `lib/features/video/pages/video_library_page.dart` - 视频库首页
- `lib/features/video/widgets/video_card.dart` - 视频卡片组件

### 依赖包
- `http` - HTTP 请求
- `cached_network_image` - 图片缓存

---

## 🔗 参考链接

### Better Player Plus
- [Better Player Plus Pub.dev](https://pub.dev/packages/better_player_plus)
- [Better Player Plus GitHub](https://github.com/SunnatilloShavkatov/betterplayer)
- [Flutter 视频播放官方文档](https://docs.flutter.dev/cookbook/plugins/play-video)
- [Android Media3 (ExoPlayer)](https://developer.android.com/media3)
- [HLS 官方规范](https://developer.apple.com/streaming/)

### Pixabay API
- [Pixabay API 文档](https://pixabay.com/api/docs/)
- [Pixabay 视频分类](https://pixabay.com/videos/)
- [cached_network_image](https://pub.dev/packages/cached_network_image)

### 依赖包
- [http](https://pub.dev/packages/http)
- [cached_network_image](https://pub.dev/packages/cached_network_image)

---

*文档版本: 1.1.0*
*创建日期: 2026-03-19*
*更新日期: 2026-03-21*
*维护者: home_manager team*

---

## 📝 更新日志

### v1.1.0 (2026-03-21)
- 新增 Pixabay API 集成方案
- 新增视频库页面设计
- 新增视频分类和标签筛选
- 新增 VideoCard 组件设计
- 新增数据模型和 API Service 示例

### v1.0.0 (2026-03-19)
- 初始版本
- Better Player Plus 基础集成
- 播放器功能和配置
