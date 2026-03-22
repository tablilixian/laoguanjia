import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 全屏图片查看器
///
/// 支持：
/// - 双击放大/缩小
/// - 双指缩放
/// - 拖动查看
/// - 下滑关闭
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  /// 显示全屏图片查看器
  static void show(
    BuildContext context, {
    required String imageUrl,
    String? heroTag,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  double _scale = 1.0;
  Offset _doubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;

    if (_scale > 1.0) {
      // 已放大，双击缩小
      _animateReset();
    } else {
      // 未放大，双击放大到 2.5x
      _animateZoomIn();
    }
  }

  void _animateReset() {
    _scale = 1.0;
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward(from: 0);
  }

  void _animateZoomIn() {
    _scale = 2.5;

    // 计算放大中心点
    final position = _doubleTapPosition;
    final zoomed = Matrix4.identity()
      ..translate(position.dx, position.dy)
      ..scale(_scale)
      ..translate(-position.dx, -position.dy);

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: zoomed,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GestureDetector(
        onDoubleTapDown: _handleDoubleTap,
        onDoubleTap: () {}, // 需要这个来触发 onDoubleTapDown
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 5.0,
          onInteractionEnd: (details) {
            // 更新当前缩放级别
            final matrix = _transformationController.value;
            _scale = matrix.getMaxScaleOnAxis();
          },
          child: Center(
            child: Hero(
              tag: widget.heroTag ?? widget.imageUrl,
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 48),
                    SizedBox(height: 16),
                    Text(
                      '图片加载失败',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 图片查看器操作提示 Widget
class ImageViewerHint extends StatelessWidget {
  const ImageViewerHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.zoom_in, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text(
            '双击放大',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
