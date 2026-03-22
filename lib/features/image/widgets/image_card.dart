import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/pixabay_image.dart';

/// 图片卡片组件
class ImageCard extends StatelessWidget {
  final PixabayImage image;
  final VoidCallback onTap;

  const ImageCard({
    super.key,
    required this.image,
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
            // 图片
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 缩略图
                  CachedNetworkImage(
                    imageUrl: image.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 32,
                      ),
                    ),
                  ),

                  // 图片类型标签
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor(image.type),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTypeLabel(image.type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
                    backgroundImage: image.userImageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(image.userImageUrl)
                        : null,
                    child: image.userImageUrl.isEmpty
                        ? const Icon(Icons.person, size: 14, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 8),

                  // 标签
                  Expanded(
                    child: Text(
                      image.tagList.isNotEmpty ? image.tagList.first : '图片',
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
                    _formatCount(image.likes),
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

  /// 获取图片类型颜色
  Color _getTypeColor(String type) {
    switch (type) {
      case 'photo':
        return Colors.blue;
      case 'illustration':
        return Colors.purple;
      case 'vector':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// 获取图片类型标签
  String _getTypeLabel(String type) {
    switch (type) {
      case 'photo':
        return '照片';
      case 'illustration':
        return '插图';
      case 'vector':
        return '矢量';
      default:
        return '图片';
    }
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
