import 'package:flutter/material.dart';
import '../models/pixabay_video.dart';
import '../services/pixabay_service.dart';
import '../constants/video_categories.dart';
import '../widgets/video_card.dart';
import '../widgets/video_player_widget.dart';

/// 视频库首页
///
/// 从 Pixabay API 获取视频，支持分类筛选和 Tab 切换
class VideoLibraryPage extends StatefulWidget {
  const VideoLibraryPage({super.key});

  @override
  State<VideoLibraryPage> createState() => _VideoLibraryPageState();
}

class _VideoLibraryPageState extends State<VideoLibraryPage> {
  final PixabayService _service = PixabayService();
  final List<PixabayVideo> _videos = [];
  final ScrollController _scrollController = ScrollController();

  VideoTab _currentTab = VideoTab.popular;
  VideoCategory _currentCategory = VideoCategory.all;
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVideos();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _service.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadVideos();
    }
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      if (refresh) {
        _currentPage = 1;
        _videos.clear();
        _hasMore = true;
      }
    });

    try {
      final result = await _service.searchVideos(
        category: _currentCategory == VideoCategory.all ? null : _currentCategory,
        tab: _currentTab,
        page: _currentPage,
      );

      setState(() {
        _videos.addAll(result.videos);
        _hasMore = result.hasMore;
        _currentPage++;
      });
    } on PixabayException catch (e) {
      setState(() => _error = e.message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      setState(() => _error = '加载失败');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加载失败，请重试')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadVideos(refresh: true),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab 栏
          _buildTabBar(),

          // 分类标签栏
          _buildCategoryChips(),

          // 视频列表
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: VideoTab.values.map((tab) {
          final isSelected = tab == _currentTab;
          return Expanded(
            child: InkWell(
              onTap: () {
                if (_currentTab == tab) return;
                setState(() => _currentTab = tab);
                _loadVideos(refresh: true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: VideoCategory.values.length,
        itemBuilder: (context, index) {
          final category = VideoCategory.values[index];
          final isSelected = category == _currentCategory;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(category.label),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (selected) {
                if (_currentCategory == category) return;
                setState(() => _currentCategory = category);
                _loadVideos(refresh: true);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    // 初始加载中
    if (_isLoading && _videos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 错误状态
    if (_error != null && _videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _loadVideos(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // 空状态
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无视频',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    // 视频网格
    return RefreshIndicator(
      onRefresh: () => _loadVideos(refresh: true),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 16 / 13,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _videos.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // 加载更多指示器
          if (index >= _videos.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final video = _videos[index];
          return VideoCard(
            video: video,
            onTap: () => _playVideo(video),
          );
        },
      ),
    );
  }

  void _playVideo(PixabayVideo video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _VideoPlayerPage(video: video),
      ),
    );
  }
}

/// 视频播放页面
class _VideoPlayerPage extends StatelessWidget {
  final PixabayVideo video;

  const _VideoPlayerPage({required this.video});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          video.tagList.isNotEmpty ? video.tagList.first : '视频播放',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          // 视频播放器
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoPlayerWidget(
                  videoUrl: video.videoUrl,
                  autoPlay: true,
                  durationSeconds: video.duration,
                  onFinished: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('播放完成')),
                    );
                  },
                  onError: (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('播放错误: $error')),
                    );
                  },
                ),
              ),
              // 时长标签
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(video.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 视频信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标签
                Wrap(
                  spacing: 8,
                  children: video.tagList.map((tag) {
                    return Chip(
                      label: Text(tag),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // 统计信息
                Row(
                  children: [
                    _buildStat(Icons.visibility, '${video.views} 次观看'),
                    const SizedBox(width: 16),
                    _buildStat(Icons.favorite_border, '${video.likes} 喜欢'),
                    const SizedBox(width: 16),
                    _buildStat(Icons.download, '${video.downloads} 下载'),
                  ],
                ),
                const SizedBox(height: 12),

                // 作者信息
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: video.userImageUrl.isNotEmpty
                          ? NetworkImage(video.userImageUrl)
                          : null,
                      child: video.userImageUrl.isEmpty
                          ? const Icon(Icons.person, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      video.userName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
