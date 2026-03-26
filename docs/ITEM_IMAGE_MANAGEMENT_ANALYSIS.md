# 物品图片管理功能详细分析

> 分析日期：2026-03-26
> 基于版本：master (fc126ee)
> 分析范围：图片管理功能完整度

---

## 一、已完成功能清单 ✅

### 1.1 核心图片功能

| 功能 | 状态 | 文件 | 完成度 |
|------|------|------|----------|
| 图片选择（相机） | ✅ 完成 | `image_service.dart: takePhoto()` | 100% |
| 图片选择（相册） | ✅ 完成 | `image_service.dart: pickFromGallery()` | 100% |
| 图片压缩 | ✅ 完成 | `image_service.dart: _processAndSaveImage()` | 100% |
| 压缩设置 | ✅ 完成 | `image_compress_settings_page.dart` | 100% |
| 云端上传 | ✅ 完成 | `cloud_storage_service.dart: uploadImage()` | 100% |
| 云端删除 | ✅ 完成 | `cloud_storage_service.dart: deleteImage()` | 100% |
| 图片显示 | ✅ 完成 | `item_create_page.dart: _buildImagePicker()` | 100% |
| 压缩信息显示 | ✅ 完成 | `item_create_page.dart: 压缩信息卡片` | 100% |

### 1.2 数据库支持

| 字段 | 状态 | 用途 |
|------|------|------|
| `image_url` | ✅ 完成 | 存储云端图片URL |
| `thumbnail_url` | ✅ 完成 | 存储缩略图URL |

### 1.3 UI组件

| 组件 | 状态 | 功能 |
|------|------|------|
| 图片选择器 | ✅ 完成 | 相机/相册选择 |
| 图片预览 | ✅ 完成 | 显示已选图片 |
| 压缩信息卡片 | ✅ 完成 | 显示压缩前后大小对比 |
| 压缩设置页面 | ✅ 完成 | 调整压缩参数 |

---

## 二、待完善功能清单 🚧

### 2.1 高优先级功能

#### 功能1：图片裁剪 ⚡ 紧急

**当前状态**：
- ❌ 无图片裁剪功能
- 用户只能使用原始图片
- 无法调整图片构图

**需要开发**：
```dart
// lib/features/items/pages/image_crop_page.dart
class ImageCropPage extends ConsumerStatefulWidget {
  final String imagePath;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('裁剪图片'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveCroppedImage,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CropWidget(
              image: File(imagePath),
              aspectRatio: CropAspectRatio.ratio1_1, // 可选：1:1, 4:3, 16:9
              onCropped: (croppedImage) {
                setState(() {
                  _croppedImage = croppedImage;
                });
              },
            ),
          ),
          // 裁剪比例选择
          _buildAspectRatioSelector(),
        ],
      ),
    );
  }
  
  Future<void> _saveCroppedImage() async {
    if (_croppedImage == null) return;
    
    // 保存裁剪后的图片
    final savedPath = await ImageService.saveCroppedImage(_croppedImage!);
    
    if (mounted) {
      context.pop(savedPath);
    }
  }
}

// lib/data/services/image_service.dart 添加方法
class ImageService {
  /// 裁剪图片
  static Future<String?> cropImage(String imagePath, {
    double aspectRatio = 1.0,
  }) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      
      // 使用 image_cropper 包
      final croppedFile = await ImageCropper.cropImage(
        file: file,
        aspectRatio: aspectRatio,
      );
      
      return croppedFile?.path;
    } catch (e) {
      print('裁剪图片失败: $e');
      return null;
    }
  }
  
  /// 保存裁剪后的图片
  static Future<String> saveCroppedImage(File croppedImage) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/item_images');
    
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    
    final fileName = '${_uuid.v4()}_cropped.jpg';
    final targetPath = path.join(imagesDir.path, fileName);
    
    await croppedImage.copy(targetPath);
    return targetPath;
  }
}
```

**依赖包**：
```yaml
# pubspec.yaml
dependencies:
  image_cropper: ^5.0.0  # 图片裁剪
  image_editor: ^1.0.0     # 图片编辑（可选）
```

**验收标准**：
- [ ] 选择图片后可进入裁剪页面
- [ ] 支持多种裁剪比例（1:1, 4:3, 16:9, 自由）
- [ ] 裁剪后自动压缩
- [ ] 裁剪结果实时预览
- [ ] 支持取消裁剪

---

#### 功能2：多图上传 ⚡ 高优先级

**当前状态**：
- ❌ 只支持单张图片
- 物品只能有一张图片
- 无法展示多个角度

**需要开发**：
```dart
// lib/data/models/household_item.dart
class HouseholdItem {
  final String? imageUrl;        // 主图
  final String? thumbnailUrl;    // 主图缩略图
  final List<String>? imageUrls;   // 多图URL（新增）
  final List<String>? thumbnailUrls; // 多图缩略图（新增）
}

// lib/features/items/pages/item_create_page.dart
class ItemCreatePage extends ConsumerStatefulWidget {
  final List<String> _localImagePaths = []; // 多图路径
  final List<String> _cloudImageUrls = [];  // 多图URL
  
  Widget _buildMultiImagePicker() {
    return Column(
      children: [
        // 图片网格显示
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _localImagePaths.length + 1, // +1 为添加按钮
          itemBuilder: (context, index) {
            if (index == _localImagePaths.length) {
              // 添加图片按钮
              return _buildAddImageButton();
            }
            // 显示已选图片
            return _buildImageItem(index);
          },
        ),
        // 图片操作按钮
        _buildImageActions(),
      ],
    );
  }
  
  Widget _buildImageItem(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(_localImagePaths[index]),
            fit: BoxFit.cover,
          ),
        ),
        // 设置主图按钮
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            decoration: BoxDecoration(
              color: index == 0 ? Colors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.star,
              color: index == 0 ? Colors.white : Colors.grey,
              size: 16,
            ),
          ),
        ),
        // 删除按钮
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => _removeImage(index),
          ),
        ),
      ],
    );
  }
  
  Future<void> _addImages() async {
    // 选择多张图片
    final images = await ImageService.pickMultipleImages();
    if (images != null) return;
    
    setState(() {
      _localImagePaths.addAll(images!);
    });
  }
  
  void _removeImage(int index) {
    setState(() {
      _localImagePaths.removeAt(index);
    });
  }
  
  void _setMainImage(int index) {
    setState(() {
      final mainImage = _localImagePaths.removeAt(index);
      _localImagePaths.insert(0, mainImage);
    });
  }
}

// lib/data/services/image_service.dart 添加方法
class ImageService {
  /// 选择多张图片
  static Future<List<String>?> pickMultipleImages() async {
    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 100,
      );
      
      if (images == null || images!.files.isEmpty) return null;
      
      // 处理每张图片
      final processedPaths = <String>[];
      for (final image in images!.files) {
        final processedPath = await _processAndSaveImage(image.path);
        processedPaths.add(processedPath);
      }
      
      return processedPaths;
    } catch (e) {
      print('选择多张图片失败: $e');
      return null;
    }
  }
  
  /// 批量上传图片
  static Future<List<String>> uploadMultipleImages(List<String> localPaths) async {
    final uploadedUrls = <String>[];
    
    for (final path in localPaths) {
      final url = await uploadToCloud(path);
      if (url != null) {
        uploadedUrls.add(url!);
      }
    }
    
    return uploadedUrls;
  }
}
```

**数据库修改**：
```dart
// lib/data/local_db/tables/household_items.dart
class HouseholdItems extends Table {
  // 现有字段...
  
  // 新增字段
  TextColumn get imageUrls => text().nullable();  // JSON格式存储多图URL
  TextColumn get thumbnailUrls => text().nullable(); // JSON格式存储多图缩略图
}

// lib/data/models/household_item.dart
class HouseholdItem {
  // 现有字段...
  
  final List<String>? imageUrls;
  final List<String>? thumbnailUrls;
  
  HouseholdItem({
    // 现有参数...
    this.imageUrls,
    this.thumbnailUrls,
  });
  
  factory HouseholdItem.fromMap(Map<String, dynamic> map) {
    return HouseholdItem(
      // 现有字段...
      imageUrls: map['image_urls'] != null 
          ? List<String>.from(jsonDecode(map['image_urls']))
          : null,
      thumbnailUrls: map['thumbnail_urls'] != null
          ? List<String>.from(jsonDecode(map['thumbnail_urls']))
          : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      // 现有字段...
      'image_urls': imageUrls != null ? jsonEncode(imageUrls) : null,
      'thumbnail_urls': thumbnailUrls != null ? jsonEncode(thumbnailUrls) : null,
    };
  }
}
```

**验收标准**：
- [ ] 支持选择多张图片（最多9张）
- [ ] 图片网格显示
- [ ] 支持设置主图（第一张）
- [ ] 支持删除单张图片
- [ ] 支持拖拽排序
- [ ] 批量上传到云端
- [ ] 上传进度显示

---

#### 功能3：缩略图自动生成 🟠 高优先级

**当前状态**：
- ❌ 缩略图字段存在但未使用
- 手动上传缩略图
- 缺少自动生成逻辑

**需要开发**：
```dart
// lib/data/services/image_service.dart 添加方法
class ImageService {
  /// 生成缩略图
  static Future<String?> generateThumbnail(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;
      
      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory('${appDir.path}/item_thumbnails');
      
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }
      
      final fileName = '${_uuid.v4()}_thumb.jpg';
      final targetPath = path.join(thumbnailsDir.path, fileName);
      
      // 使用 flutter_image_compress 生成缩略图
      final thumbnailFile = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: 70,
        minWidth: 200,
        minHeight: 200,
        format: CompressFormat.jpeg,
      );
      
      return thumbnailFile?.path;
    } catch (e) {
      print('生成缩略图失败: $e');
      return null;
    }
  }
  
  /// 批量生成缩略图
  static Future<List<String>> generateThumbnails(List<String> imagePaths) async {
    final thumbnails = <String>[];
    
    for (final path in imagePaths) {
      final thumbnail = await generateThumbnail(path);
      if (thumbnail != null) {
        thumbnails.add(thumbnail!);
      }
    }
    
    return thumbnails;
  }
}

// lib/data/services/cloud_storage_service.dart 添加方法
class CloudStorageService {
  /// 上传图片并生成缩略图
  static Future<Map<String, String>> uploadImageWithThumbnail(
    String localPath,
  ) async {
    try {
      // 上传原图
      final imageUrl = await uploadImage(localPath);
      if (imageUrl == null) return {};
      
      // 生成本地缩略图
      final thumbnailPath = await ImageService.generateThumbnail(localPath);
      if (thumbnailPath == null) return {imageUrl: imageUrl};
      
      // 上传缩略图
      final thumbnailUrl = await uploadImage(thumbnailPath!);
      
      // 删除本地缩略图
      await ImageService.deleteImage(thumbnailPath);
      
      return {
        'imageUrl': imageUrl,
        'thumbnailUrl': thumbnailUrl,
      };
    } catch (e) {
      print('上传图片和缩略图失败: $e');
      return {};
    }
  }
}
```

**验收标准**：
- [ ] 上传图片时自动生成缩略图
- [ ] 缩略图尺寸：200x200px
- [ ] 缩略图质量：70%
- [ ] 缩略图自动上传到云端
- [ ] 列表显示使用缩略图
- [ ] 详情页显示使用原图

---

### 2.2 中优先级功能

#### 功能4：图片预览（大图查看）🟡 中优先级

**当前状态**：
- ❌ 只有小图预览
- 无法查看大图
- 无法缩放查看

**需要开发**：
```dart
// lib/features/items/pages/image_preview_page.dart
class ImagePreviewPage extends StatelessWidget {
  final String imageUrl;
  final String? title;
  final int initialIndex;
  final List<String>? allImages;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: title != null ? Text(title!) : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadImage,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareImage,
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (context, index) {
          return PhotoView(
            imageProvider: NetworkImage(allImages![index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          );
        },
        itemCount: allImages?.length ?? 1,
        loadingBuilder: (context, index) => Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        pageController: PhotoViewGalleryPageController(initialPage: initialIndex),
      ),
    );
  }
  
  Future<void> _downloadImage() async {
    // 下载图片到本地
  }
  
  Future<void> _shareImage() async {
    // 分享图片
  }
}

// lib/features/items/widgets/image_grid_item.dart
class ImageGridItem extends StatelessWidget {
  final String imageUrl;
  final int index;
  final List<String> allImages;
  final String? itemTitle;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 点击进入大图预览
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImagePreviewPage(
              imageUrl: imageUrl,
              title: itemTitle,
              initialIndex: index,
              allImages: allImages,
            ),
          ),
        );
      },
      child: Hero(
        tag: 'image_$index',
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildErrorWidget(),
        ),
      ),
    );
  }
}
```

**依赖包**：
```yaml
# pubspec.yaml
dependencies:
  photo_view: ^0.14.0      # 图片预览和缩放
  cached_network_image: ^3.3.0 # 图片缓存
```

**验收标准**：
- [ ] 点击图片进入大图预览
- [ ] 支持手势缩放（双击放大/缩小）
- [ ] 支持左右滑动查看多图
- [ ] 支持下载图片
- [ ] 支持分享图片
- [ ] Hero动画过渡

---

#### 功能5：图片缓存优化 🟡 中优先级

**当前状态**：
- ⚠️ 使用默认缓存
- 缓存策略不明确
- 可能重复下载

**需要开发**：
```dart
// lib/data/services/image_cache_service.dart
class ImageCacheService {
  static final Map<String, String> _cache = {};
  
  /// 获取缓存图片URL
  static String? getCachedUrl(String originalUrl) {
    return _cache[originalUrl];
  }
  
  /// 缓存图片URL
  static void cacheUrl(String originalUrl, String cachedUrl) {
    _cache[originalUrl] = cachedUrl;
  }
  
  /// 清除缓存
  static Future<void> clearCache() async {
    await DefaultCacheManager().emptyCache();
    _cache.clear();
  }
  
  /// 获取缓存大小
  static Future<int> getCacheSize() async {
    return await DefaultCacheManager().getCacheSize();
  }
}

// lib/features/items/pages/cache_settings_page.dart
class CacheSettingsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('缓存设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('缓存大小'),
            subtitle: FutureBuilder<int>(
              future: ImageCacheService.getCacheSize(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(_formatFileSize(snapshot.data!));
                }
                return const Text('计算中...');
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showClearCacheDialog(),
            ),
          ),
          SwitchListTile(
            title: const Text('启用图片缓存'),
            subtitle: const Text('减少流量消耗，加快加载速度'),
            value: true,
            onChanged: (value) {
              // 切换缓存开关
            },
          ),
        ],
      ),
    );
  }
}
```

**验收标准**：
- [ ] 图片自动缓存
- [ ] 缓存大小显示
- [ ] 支持清除缓存
- [ ] 缓存开关设置
- [ ] 离线时显示缓存图片

---

#### 功能6：图片懒加载 🟡 中优先级

**当前状态**：
- ⚠️ 列表一次性加载所有图片
- 网络慢时体验差
- 流量消耗大

**需要开发**：
```dart
// lib/features/items/widgets/lazy_image_widget.dart
class LazyImageWidget extends StatefulWidget {
  final String imageUrl;
  final String? thumbnailUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  
  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(imageUrl),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction > 0.1) {
          // 图片可见时才加载
          _loadImage();
        }
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildImage(),
      ),
    );
  }
}

// lib/features/items/widgets/optimized_image_list.dart
class OptimizedImageList extends StatelessWidget {
  final List<String> imageUrls;
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) {
        return LazyImageWidget(
          imageUrl: imageUrls[index],
          thumbnailUrl: null, // 优先显示缩略图
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
```

**验收标准**：
- [ ] 只加载可见区域图片
- [ ] 滚动时自动加载/卸载
- [ ] 显示缩略图占位
- [ ] 图片加载失败显示占位图
- [ ] 流量消耗降低60%

---

### 2.3 低优先级功能

#### 功能7：图片编辑 🟢 低优先级

**当前状态**：
- ❌ 无图片编辑功能
- 无法调整亮度/对比度
- 无法添加文字/贴纸

**需要开发**：
```dart
// lib/features/items/pages/image_edit_page.dart
class ImageEditPage extends ConsumerStatefulWidget {
  final String imagePath;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑图片'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveEditedImage,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ImageEditor(
              image: File(imagePath),
              onEditingComplete: (editedImage) {
                setState(() {
                  _editedImage = editedImage;
                });
              },
            ),
          ),
          // 编辑工具栏
          _buildEditTools(),
        ],
      ),
    );
  }
}
```

**依赖包**：
```yaml
# pubspec.yaml
dependencies:
  image_editor: ^1.0.0  # 图片编辑
```

**验收标准**：
- [ ] 支持调整亮度/对比度
- [ ] 支持添加文字
- [ ] 支持添加贴纸
- [ ] 支持滤镜效果
- [ ] 编辑后自动压缩

---

## 三、技术实现细节

### 3.1 图片处理流程

#### 当前流程：
```
用户选择图片
    ↓
ImageService.pickFromGallery/takePhoto
    ↓
_processAndSaveImage (压缩)
    ↓
保存到本地 (item_images/xxx.jpg)
    ↓
显示压缩信息
    ↓
上传到云端 (可选)
    ↓
保存URL到数据库
```

#### 完善后的流程：
```
用户选择图片
    ↓
ImageService.pickMultipleImages (支持多选)
    ↓
进入裁剪页面 (可选)
    ↓
ImageService.cropImage
    ↓
_processAndSaveImage (压缩)
    ↓
generateThumbnail (生成缩略图)
    ↓
CloudStorageService.uploadImageWithThumbnail
    ↓
保存URL到数据库 (支持多图)
    ↓
列表显示缩略图
    ↓
点击查看原图
```

### 3.2 数据库设计

#### 当前设计：
```dart
class HouseholdItems extends Table {
  TextColumn get imageUrl => text().nullable();      // 单图URL
  TextColumn get thumbnailUrl => text().nullable();    // 单图缩略图
}
```

#### 完善后设计：
```dart
class HouseholdItems extends Table {
  TextColumn get imageUrl => text().nullable();        // 主图URL
  TextColumn get thumbnailUrl => text().nullable();    // 主图缩略图
  TextColumn get imageUrls => text().nullable();      // 多图URL (JSON)
  TextColumn get thumbnailUrls => text().nullable();  // 多图缩略图 (JSON)
}
```

### 3.3 性能优化策略

#### 图片压缩策略：
- **质量设置**：70-90%（可配置）
- **尺寸限制**：1024x1024px（可配置）
- **缩略图**：200x200px，质量70%
- **预期压缩率**：60-80%

#### 缓存策略：
- **内存缓存**：CachedNetworkImage自动管理
- **磁盘缓存**：默认100MB
- **懒加载**：只加载可见区域图片
- **预期流量节省**：60%

---

## 四、开发优先级建议

### 第一阶段（1周）：核心功能完善

1. **图片裁剪** ⚡ 紧急
   - 提升用户体验
   - 支持多种比例
   - 完善图片处理流程

2. **缩略图自动生成** 🟠 高优先级
   - 提升列表加载速度
   - 减少流量消耗
   - 优化用户体验

### 第二阶段（1-2周）：多图支持

3. **多图上传** 🟠 高优先级
   - 支持多角度展示
   - 提升物品信息完整性
   - 丰富展示效果

4. **图片预览** 🟡 中优先级
   - 支持大图查看
   - 支持手势缩放
   - 提升查看体验

### 第三阶段（2-3周）：性能优化

5. **图片缓存优化** 🟡 中优先级
   - 优化加载速度
   - 减少流量消耗
   - 支持离线查看

6. **图片懒加载** 🟡 中优先级
   - 只加载可见图片
   - 提升滚动性能
   - 减少内存占用

### 第四阶段（1个月）：高级功能

7. **图片编辑** 🟢 低优先级
   - 支持图片美化
   - 添加文字/贴纸
   - 提升趣味性

---

## 五、风险评估

### 5.1 技术风险

| 风险 | 影响 | 缓解方案 |
|------|----------|----------|
| 图片裁剪兼容性 | 不同平台表现不一致 | 充分测试iOS/Android |
| 多图上传性能 | 上传时间过长 | 显示上传进度，支持取消 |
| 缓存管理 | 缓存占用过大 | 设置缓存上限，支持清理 |
| 图片质量 | 压缩后质量下降 | 提供质量设置，支持原图 |

### 5.2 用户体验风险

| 风险 | 影响 | 缓解方案 |
|------|----------|----------|
| 操作复杂度 | 功能太多导致混乱 | 分步引导，简化默认设置 |
| 网络依赖 | 上传失败影响使用 | 支持离线使用，本地优先 |
| 存储空间 | 多图占用空间 | 提供清理工具，压缩优化 |

---

## 六、验收标准

### 第一阶段完成标准

- [ ] 图片裁剪功能正常工作
- [ ] 缩略图自动生成
- [ ] 列表显示缩略图
- [ ] 上传速度提升50%

### 第二阶段完成标准

- [ ] 支持多图上传（最多9张）
- [ ] 支持设置主图
- [ ] 支持图片排序
- [ ] 大图预览流畅

### 第三阶段完成标准

- [ ] 图片缓存正常工作
- [ ] 懒加载效果明显
- [ ] 流量消耗降低60%
- [ ] 滚动性能提升

### 最终完成标准

- [ ] 所有图片功能正常工作
- [ ] 性能指标达标
- [ ] 用户体验流畅
- [ ] 代码质量良好

---

*文档结束*