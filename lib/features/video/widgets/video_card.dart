import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/pixabay_video.dart';

/// 视频卡片组件
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
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 缩略图
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 缩略图
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.videocam_off,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
                  ),

                  // 播放按钮覆盖层
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 时长标签
                  Positioned(
                    bottom: 6,
                    right: 6,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
                    backgroundColor: Colors.grey[300],
                    backgroundImage: video.userImageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(video.userImageUrl)
                        : null,
                    child: video.userImageUrl.isEmpty
                        ? const Icon(Icons.person, size: 14, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 8),

                  // 标签
                  Expanded(
                    child: Text(
                      video.tagList.isNotEmpty ? video.tagList.first : '视频',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),

                  // 点赞数
                  Icon(
                    Icons.favorite_border,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatCount(video.likes),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 11,
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

  /// 格式化时长
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// 格式化数量
  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
