import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_storage_service.dart';

class ImageService {
  static final ImagePicker _picker = ImagePicker();
  static const Uuid _uuid = Uuid();

  static const String _qualityKey = 'image_compress_quality';
  static const String _maxWidthKey = 'image_compress_max_width';
  static const String _maxHeightKey = 'image_compress_max_height';

  /// 从相机拍照
  static Future<String?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // 先不压缩，后面单独压缩
      );

      if (photo == null) return null;

      return await _processAndSaveImage(photo.path);
    } catch (e) {
      print('拍照失败: $e');
      return null;
    }
  }

  /// 从相机拍照（返回压缩信息）
  static Future<Map<String, dynamic>?> takePhotoWithInfo() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (photo == null) return null;

      return await _processAndSaveImageWithInfo(photo.path);
    } catch (e) {
      print('拍照失败: $e');
      return null;
    }
  }

  /// 从相册选择
  static Future<String?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) return null;

      return await _processAndSaveImage(image.path);
    } catch (e) {
      print('选择图片失败: $e');
      return null;
    }
  }

  /// 从相册选择（返回压缩信息）
  static Future<Map<String, dynamic>?> pickFromGalleryWithInfo() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) return null;

      return await _processAndSaveImageWithInfo(image.path);
    } catch (e) {
      print('选择图片失败: $e');
      return null;
    }
  }

  /// 显示选择来源对话框（返回选择的图片路径）
  static Future<String?> showImageSourceDialog({
    required Future<void> Function() onCamera,
    required Future<void> Function() onGallery,
  }) async {
    // 这个方法由UI层调用，这里只是定义接口
    return null;
  }

  /// 获取压缩设置
  static Future<Map<String, int>> _getCompressSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'quality': prefs.getInt(_qualityKey) ?? 80,
      'maxWidth': prefs.getInt(_maxWidthKey) ?? 1024,
      'maxHeight': prefs.getInt(_maxHeightKey) ?? 1024,
    };
  }

  /// 处理并保存图片：压缩 → 保存到本地
  static Future<String> _processAndSaveImage(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/item_images');

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName = '${_uuid.v4()}.jpg';
    final targetPath = path.join(imagesDir.path, fileName);

    // 获取压缩设置
    final settings = await _getCompressSettings();

    // 压缩图片
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      quality: settings['quality']!,
      minWidth: settings['maxWidth']!,
      minHeight: settings['maxHeight']!,
      format: CompressFormat.jpeg,
    );

    if (compressedFile == null) {
      // 压缩失败，直接复制原文件
      await File(sourcePath).copy(targetPath);
      return targetPath;
    }

    return compressedFile.path;
  }

  /// 处理并保存图片：压缩 → 保存到本地（返回压缩信息）
  static Future<Map<String, dynamic>> _processAndSaveImageWithInfo(
    String sourcePath,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/item_images');

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName = '${_uuid.v4()}.jpg';
    final targetPath = path.join(imagesDir.path, fileName);

    // 获取原始图片大小
    final originalSize = await getImageSize(sourcePath);

    // 获取压缩设置
    final settings = await _getCompressSettings();

    // 压缩图片
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      quality: settings['quality']!,
      minWidth: settings['maxWidth']!,
      minHeight: settings['maxHeight']!,
      format: CompressFormat.jpeg,
    );

    String finalPath;
    if (compressedFile == null) {
      // 压缩失败，直接复制原文件
      await File(sourcePath).copy(targetPath);
      finalPath = targetPath;
    } else {
      finalPath = compressedFile.path;
    }

    // 获取压缩后图片大小
    final compressedSize = await getImageSize(finalPath);

    return {
      'imagePath': finalPath,
      'originalSize': originalSize,
      'compressedSize': compressedSize,
      'originalSizeFormatted': _formatFileSize(originalSize),
      'compressedSizeFormatted': _formatFileSize(compressedSize),
      'compressionRatio': originalSize > 0
          ? ((originalSize - compressedSize) / originalSize * 100)
                .toStringAsFixed(1)
          : '0',
    };
  }

  /// 删除本地图片
  static Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null) return;

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('删除图片失败: $e');
    }
  }

  /// 获取图片文件大小（KB）
  static Future<int> getImageSize(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.length();
        return (bytes / 1024).round();
      }
    } catch (e) {
      print('获取图片大小失败: $e');
    }
    return 0;
  }

  /// 验证图片路径是否有效
  static Future<bool> isImageValid(String? imagePath) async {
    if (imagePath == null) return false;

    try {
      final file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// 获取图片压缩信息（用于显示）
  static Future<Map<String, dynamic>> getCompressionInfo({
    required String sourcePath,
    required String compressedPath,
  }) async {
    final sourceSize = await getImageSize(sourcePath);
    final compressedSize = await getImageSize(compressedPath);
    
    final compressionRatio = sourceSize > 0 
        ? ((sourceSize - compressedSize) / sourceSize * 100).toStringAsFixed(1)
        : '0';

    return {
      'sourceSize': sourceSize,
      'compressedSize': compressedSize,
      'compressionRatio': compressionRatio,
      'sourceSizeFormatted': _formatFileSize(sourceSize),
      'compressedSizeFormatted': _formatFileSize(compressedSize),
    };
  }

  /// 格式化文件大小
  static String _formatFileSize(int kb) {
    if (kb < 1024) {
      return '${kb}KB';
    } else if (kb < 1024 * 1024) {
      return '${(kb / 1024).toStringAsFixed(1)}MB';
    } else {
      return '${(kb / 1024 / 1024).toStringAsFixed(2)}MB';
    }
  }

  /// 上传图片到云端
  static Future<String?> uploadToCloud(String localPath) async {
    try {
      return await CloudStorageService.uploadImage(localPath);
    } catch (e) {
      print('上传到云端失败: $e');
      return null;
    }
  }

  /// 删除云端图片
  static Future<bool> deleteFromCloud(String imageUrl) async {
    try {
      return await CloudStorageService.deleteImage(imageUrl);
    } catch (e) {
      print('删除云端图片失败: $e');
      return false;
    }
  }

  /// 检查是否已登录（可以上传到云端）
  static bool get canUploadToCloud => CloudStorageService.isLoggedIn;
}