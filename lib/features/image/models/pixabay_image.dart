/// Pixabay 图片数据模型
class PixabayImage {
  final int id;
  final String pageUrl;
  final String type; // photo, illustration, vector
  final String tags;
  final String previewUrl;
  final int previewWidth;
  final int previewHeight;
  final String webformatUrl;
  final int webformatWidth;
  final int webformatHeight;
  final String largeImageUrl;
  final int imageWidth;
  final int imageHeight;
  final int imageSize;
  final int views;
  final int downloads;
  final int likes;
  final int comments;
  final String userName;
  final String userImageUrl;

  const PixabayImage({
    required this.id,
    required this.pageUrl,
    required this.type,
    required this.tags,
    required this.previewUrl,
    required this.previewWidth,
    required this.previewHeight,
    required this.webformatUrl,
    required this.webformatWidth,
    required this.webformatHeight,
    required this.largeImageUrl,
    required this.imageWidth,
    required this.imageHeight,
    required this.imageSize,
    required this.views,
    required this.downloads,
    required this.likes,
    required this.comments,
    required this.userName,
    required this.userImageUrl,
  });

  /// 获取标签列表
  List<String> get tagList =>
      tags.split(', ').where((t) => t.isNotEmpty).toList();

  /// 获取缩略图 URL（优先使用 webformat）
  String get thumbnailUrl => webformatUrl.isNotEmpty ? webformatUrl : previewUrl;

  /// 获取显示用的图片 URL
  String get displayUrl => largeImageUrl.isNotEmpty ? largeImageUrl : webformatUrl;

  /// 从 JSON 创建
  factory PixabayImage.fromJson(Map<String, dynamic> json) {
    return PixabayImage(
      id: json['id'] as int,
      pageUrl: json['pageURL'] as String? ?? '',
      type: json['type'] as String? ?? 'photo',
      tags: json['tags'] as String? ?? '',
      previewUrl: json['previewURL'] as String? ?? '',
      previewWidth: json['previewWidth'] as int? ?? 0,
      previewHeight: json['previewHeight'] as int? ?? 0,
      webformatUrl: json['webformatURL'] as String? ?? '',
      webformatWidth: json['webformatWidth'] as int? ?? 0,
      webformatHeight: json['webformatHeight'] as int? ?? 0,
      largeImageUrl: json['largeImageURL'] as String? ?? '',
      imageWidth: json['imageWidth'] as int? ?? 0,
      imageHeight: json['imageHeight'] as int? ?? 0,
      imageSize: json['imageSize'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      downloads: json['downloads'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      comments: json['comments'] as int? ?? 0,
      userName: json['user'] as String? ?? '',
      userImageUrl: json['userImageURL'] as String? ?? '',
    );
  }

  @override
  String toString() => 'PixabayImage(id: $id, tags: $tags, type: $type)';
}

/// 图片类型枚举
enum ImageType {
  all('全部', 'all'),
  photo('照片', 'photo'),
  illustration('插图', 'illustration'),
  vector('矢量图', 'vector');

  const ImageType(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

/// 图片方向枚举
enum ImageOrientation {
  all('全部', 'all'),
  horizontal('横向', 'horizontal'),
  vertical('纵向', 'vertical');

  const ImageOrientation(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

/// API 响应模型
class PixabayImageResponse {
  final int total;
  final int totalHits;
  final List<PixabayImage> images;

  const PixabayImageResponse({
    required this.total,
    required this.totalHits,
    required this.images,
  });

  factory PixabayImageResponse.fromJson(Map<String, dynamic> json) {
    return PixabayImageResponse(
      total: json['total'] as int? ?? 0,
      totalHits: json['totalHits'] as int? ?? 0,
      images: (json['hits'] as List<dynamic>? ?? [])
          .map((h) => PixabayImage.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasMore => images.length >= 20;

  @override
  String toString() =>
      'PixabayImageResponse(total: $total, images: ${images.length})';
}
