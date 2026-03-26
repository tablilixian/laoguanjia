import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// 图片懒加载组件
/// 
/// 只在图片可见时才加载，减少流量和内存消耗
class VisibilityLazyImage extends StatefulWidget {
  final String imageUrl;
  final String? thumbnailUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const VisibilityLazyImage({
    super.key,
    required this.imageUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  State<VisibilityLazyImage> createState() => _VisibilityLazyImageState();
}

class _VisibilityLazyImageState extends State<VisibilityLazyImage> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.imageUrl),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction > 0.1 && !_isVisible) {
          setState(() {
            _isVisible = true;
          });
        } else if (visibilityInfo.visibleFraction < 0.05 && _isVisible) {
          setState(() {
            _isVisible = false;
          });
        }
      },
      child: _isVisible
          ? _buildCachedImage()
          : widget.placeholder ?? _buildDefaultPlaceholder(),
    );
  }

  Widget _buildCachedImage() {
    final displayUrl = widget.thumbnailUrl ?? widget.imageUrl;

    return CachedNetworkImage(
      imageUrl: displayUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: widget.placeholder != null
          ? (context, url) => widget.placeholder!
          : (context, url) => _buildDefaultPlaceholder(),
      errorWidget: widget.errorWidget != null
          ? (context, url, error) => widget.errorWidget!
          : (context, url, error) => _buildDefaultErrorWidget(),
      fadeInDuration: widget.fadeInDuration,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      maxWidthDiskCache: 100 * 1024 * 1024,
      maxHeightDiskCache: 100 * 1024 * 1024,
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(Icons.image, color: Colors.grey, size: 32),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.grey, size: 32),
            SizedBox(height: 4),
            Text(
              '加载失败',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// 圆形图片懒加载组件
class VisibilityLazyCircleImage extends StatelessWidget {
  final String imageUrl;
  final String? thumbnailUrl;
  final double radius;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const VisibilityLazyCircleImage({
    super.key,
    required this.imageUrl,
    this.thumbnailUrl,
    this.radius = 30,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: VisibilityLazyImage(
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        width: radius * 2,
        height: radius * 2,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
      ),
    );
  }
}

/// 带有缩略图优先的图片组件
/// 
/// 优先显示缩略图，点击后加载原图
class ThumbnailFirstImage extends StatefulWidget {
  final String imageUrl;
  final String? thumbnailUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool enableTapToView;

  const ThumbnailFirstImage({
    super.key,
    required this.imageUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.enableTapToView = true,
  });

  @override
  State<ThumbnailFirstImage> createState() => _ThumbnailFirstImageState();
}

class _ThumbnailFirstImageState extends State<ThumbnailFirstImage> {
  bool _showFullImage = false;

  @override
  Widget build(BuildContext context) {
    final displayUrl = _showFullImage ? widget.imageUrl : (widget.thumbnailUrl ?? widget.imageUrl);

    return GestureDetector(
      onTap: widget.enableTapToView
          ? () {
              if (widget.thumbnailUrl != null && !_showFullImage) {
                setState(() {
                  _showFullImage = true;
                });
              } else {
                _showFullScreenImage(context);
              }
            }
          : null,
      child: VisibilityLazyImage(
        imageUrl: displayUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: 200,
        memCacheHeight: 200,
      ),
    );
  }

  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(
          imageUrl: widget.imageUrl,
        ),
      ),
    );
  }
}

/// 全屏图片页面
class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImagePage({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
