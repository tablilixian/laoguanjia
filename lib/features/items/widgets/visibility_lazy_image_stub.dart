import 'package:flutter/material.dart';

Widget buildLocalImage({
  required String path,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? errorWidget,
  int? cacheWidth,
  int? cacheHeight,
}) {
  return errorWidget ?? _buildDefaultErrorWidget(width, height);
}

Widget _buildDefaultErrorWidget(double? width, double? height) {
  return Container(
    width: width,
    height: height,
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
            'Web不支持本地图片',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
