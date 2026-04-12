import 'dart:io';
import 'package:flutter/foundation.dart';
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
  if (kIsWeb) {
    return errorWidget ?? _buildDefaultErrorWidget(width, height);
  }
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      return errorWidget ?? _buildDefaultErrorWidget(width, height);
    },
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
  );
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
            '加载失败',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
