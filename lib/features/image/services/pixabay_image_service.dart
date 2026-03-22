import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/pixabay_image.dart';
import '../constants/image_categories.dart';
import '../../../core/config/api_config.dart';

/// Pixabay 图片 API 服务
class PixabayImageService {
  final http.Client _httpClient;

  PixabayImageService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// 搜索图片
  Future<PixabayImageResponse> searchImages({
    String? query,
    ImageCategory? category,
    ImageType? imageType,
    ImageOrientation? orientation,
    ImageTab? tab,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{
      'key': ApiConfig.pixabayApiKey,
      'per_page': perPage.toString(),
      'page': page.toString(),
      'safesearch': 'true',
    };

    // 搜索词
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }

    // 分类
    if (category != null && category.apiValue != null) {
      params['category'] = category.apiValue!;
    }

    // 图片类型
    if (imageType != null) {
      params['image_type'] = imageType.apiValue;
    }

    // 方向
    if (orientation != null) {
      params['orientation'] = orientation.apiValue;
    }

    // 排序
    if (tab != null && tab.orderValue != null) {
      params['order'] = tab.orderValue!;
    }

    final uri = Uri.parse(ApiConfig.pixabayImageUrl)
        .replace(queryParameters: params);

    try {
      final response = await _httpClient.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PixabayImageResponse.fromJson(json);
      } else {
        throw PixabayImageException('API 错误: ${response.statusCode}');
      }
    } catch (e) {
      if (e is PixabayImageException) rethrow;
      throw PixabayImageException('网络错误: $e');
    }
  }

  /// 获取热门图片
  Future<List<PixabayImage>> getPopularImages({int page = 1}) async {
    final result = await searchImages(tab: ImageTab.popular, page: page);
    return result.images;
  }

  /// 按分类获取图片
  Future<List<PixabayImage>> getImagesByCategory(
    ImageCategory category, {
    int page = 1,
  }) async {
    final result = await searchImages(category: category, page: page);
    return result.images;
  }

  /// 搜索图片
  Future<List<PixabayImage>> search(String query, {int page = 1}) async {
    final result = await searchImages(query: query, page: page);
    return result.images;
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Pixabay 图片 API 异常
class PixabayImageException implements Exception {
  final String message;
  PixabayImageException(this.message);

  @override
  String toString() => 'PixabayImageException: $message';
}
