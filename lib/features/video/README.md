# 📺 视频功能模块

> Better Player Plus 视频播放器集成

## ⚠️ 使用前准备

### 1. 安装依赖

```bash
# 添加到 pubspec.yaml
flutter pub add better_player_plus

# 或手动编辑 pubspec.yaml 后运行
flutter pub get
```

### 2. 平台配置

**Android**: 确保 `minSdk >= 24`
**iOS**: 确保 `platform :ios, '11.0'` 或更高

详细配置请参考 [docs/video-player-integration.md](../../docs/video-player-integration.md)

## 📁 文件结构

```
lib/features/video/
├── README.md                           # 本文件
├── constants/
│   └── video_constants.dart            # 测试视频 URL 常量
├── pages/
│   └── video_player_page.dart          # 视频播放器演示页面
└── widgets/
    └── video_player_widget.dart         # 核心播放器 Widget
```

## 🚀 快速使用

### 方式一：使用现成的 Widget

```dart
import 'package:home_manager/features/video/widgets/video_player_widget.dart';

VideoPlayerWidget(
  videoUrl: 'https://example.com/video.mp4',
  autoPlay: true,
  onFinished: () => print('播放完成'),
)
```

### 方式二：直接使用 BetterPlayerController

```dart
import 'package:better_player_plus/better_player_plus.dart';

final controller = BetterPlayerController(
  const BetterPlayerConfiguration(aspectRatio: 16 / 9),
  betterPlayerDataSource: BetterPlayerDataSource(
    BetterPlayerDataSourceType.network,
    'https://example.com/video.mp4',
  ),
);

BetterPlayer(controller: controller)
```

## 📝 文档

详细接入文档: [docs/video-player-integration.md](../../docs/video-player-integration.md)

## 🔗 参考链接

- [Better Player Plus Pub.dev](https://pub.dev/packages/better_player_plus)
- [Better Player Plus GitHub](https://github.com/SunnatilloShavkatov/betterplayer)
