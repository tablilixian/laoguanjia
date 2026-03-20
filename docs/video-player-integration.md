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

## 6. 测试资源

### 6.1 公开测试视频

| 视频名称 | URL | 格式 | 许可证 |
|---------|-----|------|-------|
| Big Buck Bunny | `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4` | MP4 | CC0 |
| ForBiggerBlazes | `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4` | MP4 | CC0 |
| Elephants Dream | `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4` | MP4 | CC0 |
| Sintel Trailer | `https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4` | MP4 | BSD |

### 6.2 HLS 测试流

| 名称 | URL |
|-----|-----|
| Sintel HLS | `https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8` |
| Tears of Steel | `https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8` |

---

## 7. 常见问题

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

- `lib/features/video/pages/video_player_page.dart` - 视频播放器页面
- `lib/features/video/pages/hls_player_page.dart` - HLS 流媒体页面
- `lib/features/video/pages/video_demo_page.dart` - 功能演示页面
- `lib/features/video/widgets/video_player_widget.dart` - 播放器组件

---

## 🔗 参考链接

- [Better Player Plus Pub.dev](https://pub.dev/packages/better_player_plus)
- [Better Player Plus GitHub](https://github.com/SunnatilloShavkatov/betterplayer)
- [Flutter 视频播放官方文档](https://docs.flutter.dev/cookbook/plugins/play-video)
- [Android Media3 (ExoPlayer)](https://developer.android.com/media3)
- [HLS 官方规范](https://developer.apple.com/streaming/)

---

*文档版本: 1.0.0*
*创建日期: 2026-03-19*
*维护者: home_manager team*
