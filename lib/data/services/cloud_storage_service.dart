import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class CloudStorageService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const Uuid _uuid = Uuid();

  /// 上传图片到云端
  /// 返回云端图片的公开URL
  static Future<String?> uploadImage(String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        print('文件不存在: $localPath');
        return null;
      }

      // 获取当前用户ID
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        print('用户未登录');
        return null;
      }

      // 生成唯一的文件名
      final fileName = '${_uuid.v4()}.jpg';
      final filePath = 'items/$userId/$fileName';

      // 读取文件内容
      final fileBytes = await file.readAsBytes();

      // 上传到 Supabase Storage
      final storageResponse = await _client.storage
          .from('item-images')
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      if (storageResponse.isEmpty) {
        print('上传失败');
        return null;
      }

      // 获取公开URL
      final imageUrl = _client.storage
          .from('item-images')
          .getPublicUrl(filePath);

      print('上传成功: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('上传图片失败: $e');
      return null;
    }
  }

  /// 删除云端图片
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      // 从URL中提取文件路径
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // URL格式: https://xxx.supabase.co/storage/v1/object/public/item-images/items/xxx/xxx.jpg
      // 需要提取 items/xxx/xxx.jpg 部分
      if (pathSegments.length < 6) {
        print('无效的图片URL: $imageUrl');
        return false;
      }

      final filePath = pathSegments.sublist(5).join('/');
      
      // 删除文件
      await _client.storage.from('item-images').remove([filePath]);
      
      print('删除成功: $filePath');
      return true;
    } catch (e) {
      print('删除图片失败: $e');
      return false;
    }
  }

  /// 检查是否已登录
  static bool get isLoggedIn => _client.auth.currentUser != null;

  /// 获取当前用户ID
  static String? get userId => _client.auth.currentUser?.id;
}
