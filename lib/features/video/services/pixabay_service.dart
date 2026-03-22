import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/pixabay_video.dart';
import '../constants/video_categories.dart';
import '../../../core/config/api_config.dart';

/// Pixabay API 服务
class PixabayService {
  final http.Client _httpClient;

  PixabayService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// 搜索视频
  Future<PixabayVideoResponse> searchVideos({
    String? query,
    VideoCategory? category,
    VideoTab? tab,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{
      'key': ApiConfig.pixabayApiKey,
      'video_type': 'film',
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

    // 排序
    if (tab != null && tab.orderValue != null) {
      params['order'] = tab.orderValue!;
    }

    final uri = Uri.parse(ApiConfig.pixabayVideoUrl)
        .replace(queryParameters: params);

    try {
      final response = await _httpClient.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PixabayVideoResponse.fromJson(json);
      } else {
        throw PixabayException('API 错误: ${response.statusCode}');
      }
    } catch (e) {
      if (e is PixabayException) rethrow;
      throw PixabayException('网络错误: $e');
    }
  }

  /// 获取热门视频
  Future<List<PixabayVideo>> getPopularVideos({int page = 1}) async {
    final result = await searchVideos(tab: VideoTab.popular, page: page);
    return result.videos;
  }

  /// 按分类获取视频
  Future<List<PixabayVideo>> getVideosByCategory(
    VideoCategory category, {
    int page = 1,
  }) async {
    final result = await searchVideos(category: category, page: page);
    return result.videos;
  }

  /// 搜索视频
  Future<List<PixabayVideo>> search(String query, {int page = 1}) async {
    final result = await searchVideos(query: query, page: page);
    return result.videos;
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Pixabay API 异常
class PixabayException implements Exception {
  final String message;
  PixabayException(this.message);

  @override
  String toString() => 'PixabayException: $message';
}
