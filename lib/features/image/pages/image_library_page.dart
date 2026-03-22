import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/pixabay_image.dart';
import '../services/pixabay_image_service.dart';
import '../constants/image_categories.dart';
import '../widgets/image_card.dart';
import '../widgets/fullscreen_image_viewer.dart';

/// 图片库首页
///
/// 从 Pixabay API 获取图片，支持分类筛选和 Tab 切换
class ImageLibraryPage extends StatefulWidget {
  const ImageLibraryPage({super.key});

  @override
  State<ImageLibraryPage> createState() => _ImageLibraryPageState();
}

class _ImageLibraryPageState extends State<ImageLibraryPage> {
  final PixabayImageService _service = PixabayImageService();
  final List<PixabayImage> _images = [];
  final ScrollController _scrollController = ScrollController();

  ImageTab _currentTab = ImageTab.popular;
  ImageCategory _currentCategory = ImageCategory.all;
  ImageType _currentImageType = ImageType.all;
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadImages();
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
      _loadImages();
    }
  }

  Future<void> _loadImages({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      if (refresh) {
        _currentPage = 1;
        _images.clear();
        _hasMore = true;
      }
    });

    try {
      final result = await _service.searchImages(
        category: _currentCategory == ImageCategory.all ? null : _currentCategory,
        imageType: _currentImageType == ImageType.all ? null : _currentImageType,
        tab: _currentTab,
        page: _currentPage,
      );

      setState(() {
        _images.addAll(result.images);
        _hasMore = result.hasMore;
        _currentPage++;
      });
    } on PixabayImageException catch (e) {
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
        title: const Text('图片库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadImages(refresh: true),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab 栏
          _buildTabBar(),

          // 图片类型筛选
          _buildImageTypeChips(),

          // 分类标签栏
          _buildCategoryChips(),

          // 图片列表
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
        children: ImageTab.values.map((tab) {
          final isSelected = tab == _currentTab;
          return Expanded(
            child: InkWell(
              onTap: () {
                if (_currentTab == tab) return;
                setState(() => _currentTab = tab);
                _loadImages(refresh: true);
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

  Widget _buildImageTypeChips() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: ImageType.values.length,
        itemBuilder: (context, index) {
          final type = ImageType.values[index];
          final isSelected = type == _currentImageType;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(type.label),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (selected) {
                if (_currentImageType == type) return;
                setState(() => _currentImageType = type);
                _loadImages(refresh: true);
              },
            ),
          );
        },
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
        itemCount: ImageCategory.values.length,
        itemBuilder: (context, index) {
          final category = ImageCategory.values[index];
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
                _loadImages(refresh: true);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    // 初始加载中
    if (_isLoading && _images.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 错误状态
    if (_error != null && _images.isEmpty) {
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
              onPressed: () => _loadImages(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // 空状态
    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无图片',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    // 图片网格
    return RefreshIndicator(
      onRefresh: () => _loadImages(refresh: true),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1, // 正方形卡片
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _images.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // 加载更多指示器
          if (index >= _images.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final image = _images[index];
          return ImageCard(
            image: image,
            onTap: () => _viewImage(image),
          );
        },
      ),
    );
  }

  void _viewImage(PixabayImage image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ImagePreviewPage(image: image),
      ),
    );
  }
}

/// 图片预览页面
class _ImagePreviewPage extends StatelessWidget {
  final PixabayImage image;

  const _ImagePreviewPage({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          image.tagList.isNotEmpty ? image.tagList.first : '图片预览',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('下载功能开发中...')),
              );
            },
            tooltip: '下载',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片（点击放大查看）
            GestureDetector(
              onTap: () {
                FullScreenImageViewer.show(
                  context,
                  imageUrl: image.displayUrl,
                  heroTag: 'image_${image.id}',
                );
              },
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Hero(
                    tag: 'image_${image.id}',
                    child: CachedNetworkImage(
                      imageUrl: image.displayUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => AspectRatio(
                        aspectRatio: image.imageWidth / image.imageHeight,
                        child: Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error, size: 48),
                        ),
                      ),
                    ),
                  ),
                  // 放大提示
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
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
                            '点击放大',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 图片信息
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标签
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: image.tagList.map((tag) {
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
                      _buildStat(Icons.visibility, '${image.views} 次查看'),
                      const SizedBox(width: 16),
                      _buildStat(Icons.favorite_border, '${image.likes} 喜欢'),
                      const SizedBox(width: 16),
                      _buildStat(Icons.download, '${image.downloads} 下载'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 图片尺寸
                  Row(
                    children: [
                      _buildStat(Icons.photo_size_select_large,
                          '${image.imageWidth} x ${image.imageHeight}'),
                      const SizedBox(width: 16),
                      _buildStat(Icons.data_usage,
                          '${(image.imageSize / 1024 / 1024).toStringAsFixed(1)} MB'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 作者信息
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: image.userImageUrl.isNotEmpty
                            ? NetworkImage(image.userImageUrl)
                            : null,
                        child: image.userImageUrl.isEmpty
                            ? const Icon(Icons.person, size: 20)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        image.userName,
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
}
