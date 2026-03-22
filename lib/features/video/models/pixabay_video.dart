/// Pixabay 视频数据模型
class PixabayVideo {
  final int id;
  final String pageUrl;
  final String tags;
  final int duration; // 秒
  final VideoFile videoLarge;
  final VideoFile videoMedium;
  final VideoFile videoSmall;
  final VideoFile videoTiny;
  final int views;
  final int downloads;
  final int likes;
  final String userName;
  final String userImageUrl;

  const PixabayVideo({
    required this.id,
    required this.pageUrl,
    required this.tags,
    required this.duration,
    required this.videoLarge,
    required this.videoMedium,
    required this.videoSmall,
    required this.videoTiny,
    required this.views,
    required this.downloads,
    required this.likes,
    required this.userName,
    required this.userImageUrl,
  });

  /// 获取最佳播放源（优先 tiny 以加快加载）
  VideoFile get bestVideo {
    if (videoTiny.url.isNotEmpty) return videoTiny;
    if (videoSmall.url.isNotEmpty) return videoSmall;
    return videoMedium;
  }

  /// 获取缩略图
  String get thumbnailUrl => bestVideo.thumbnail;

  /// 获取播放 URL
  String get videoUrl => bestVideo.url;

  /// 获取标签列表
  List<String> get tagList =>
      tags.split(', ').where((t) => t.isNotEmpty).toList();

  /// 从 JSON 创建
  factory PixabayVideo.fromJson(Map<String, dynamic> json) {
    final videos = json['videos'] as Map<String, dynamic>;
    return PixabayVideo(
      id: json['id'] as int,
      pageUrl: json['pageURL'] as String? ?? '',
      tags: json['tags'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      videoLarge: VideoFile.fromJson(
        videos['large'] as Map<String, dynamic>? ?? {},
      ),
      videoMedium: VideoFile.fromJson(
        videos['medium'] as Map<String, dynamic>? ?? {},
      ),
      videoSmall: VideoFile.fromJson(
        videos['small'] as Map<String, dynamic>? ?? {},
      ),
      videoTiny: VideoFile.fromJson(
        videos['tiny'] as Map<String, dynamic>? ?? {},
      ),
      views: json['views'] as int? ?? 0,
      downloads: json['downloads'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      userName: json['user'] as String? ?? '',
      userImageUrl: json['userImageURL'] as String? ?? '',
    );
  }

  @override
  String toString() => 'PixabayVideo(id: $id, tags: $tags, duration: ${duration}s)';
}

/// 视频文件信息
class VideoFile {
  final String url;
  final int width;
  final int height;
  final int size;
  final String thumbnail;

  const VideoFile({
    required this.url,
    required this.width,
    required this.height,
    required this.size,
    required this.thumbnail,
  });

  factory VideoFile.fromJson(Map<String, dynamic> json) {
    return VideoFile(
      url: json['url'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      thumbnail: json['thumbnail'] as String? ?? '',
    );
  }

  bool get isEmpty => url.isEmpty;
  bool get isNotEmpty => url.isNotEmpty;

  @override
  String toString() => 'VideoFile(${width}x$height, ${(size / 1024 / 1024).toStringAsFixed(1)}MB)';
}

/// API 响应模型
class PixabayVideoResponse {
  final int total;
  final int totalHits;
  final List<PixabayVideo> videos;

  const PixabayVideoResponse({
    required this.total,
    required this.totalHits,
    required this.videos,
  });

  factory PixabayVideoResponse.fromJson(Map<String, dynamic> json) {
    return PixabayVideoResponse(
      total: json['total'] as int? ?? 0,
      totalHits: json['totalHits'] as int? ?? 0,
      videos: (json['hits'] as List<dynamic>? ?? [])
          .map((h) => PixabayVideo.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasMore => videos.length >= 20;

  @override
  String toString() =>
      'PixabayVideoResponse(total: $total, videos: ${videos.length})';
}
