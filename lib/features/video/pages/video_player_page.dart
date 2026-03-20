import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import '../constants/video_constants.dart';
import '../widgets/video_player_widget.dart';

/// 视频播放器基础演示页面
///
/// 展示如何使用 VideoPlayerWidget 播放网络视频
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final video = VideoConstants.testVideos[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('视频播放'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _showVideoList,
            tooltip: '选择视频',
          ),
        ],
      ),
      body: Column(
        children: [
          // 视频信息
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  video.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // 视频播放器
          Expanded(
            child: Center(
              child: VideoPlayerWidget(
                videoUrl: video.url,
                autoPlay: false,
                looping: false,
                onFinished: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('视频播放完成')));
                },
                onError: (error) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('播放错误: $error')));
                },
              ),
            ),
          ),

          // 视频列表预览
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: VideoConstants.testVideos.length,
              itemBuilder: (context, index) {
                final v = VideoConstants.testVideos[index];
                final isSelected = index == _currentIndex;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  child: Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.video_library,
                              color: Colors.white54,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              color: Colors.black54,
                              child: Text(
                                v.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showVideoList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: VideoConstants.testVideos.length,
        itemBuilder: (context, index) {
          final video = VideoConstants.testVideos[index];
          return ListTile(
            leading: const Icon(Icons.video_file),
            title: Text(video.name),
            subtitle: Text(video.description),
            selected: index == _currentIndex,
            onTap: () {
              setState(() {
                _currentIndex = index;
              });
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}
