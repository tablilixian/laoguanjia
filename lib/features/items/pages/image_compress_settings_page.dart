import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

final imageCompressSettingsProvider =
    StateNotifierProvider<ImageCompressSettingsNotifier, ImageCompressSettings>((
      ref,
    ) {
      return ImageCompressSettingsNotifier();
    });

class ImageCompressSettings {
  final int quality;
  final int maxWidth;
  final int maxHeight;

  const ImageCompressSettings({
    this.quality = 80,
    this.maxWidth = 1024,
    this.maxHeight = 1024,
  });

  ImageCompressSettings copyWith({int? quality, int? maxWidth, int? maxHeight}) {
    return ImageCompressSettings(
      quality: quality ?? this.quality,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
    );
  }
}

class ImageCompressSettingsNotifier extends StateNotifier<ImageCompressSettings> {
  static const String _qualityKey = 'image_compress_quality';
  static const String _maxWidthKey = 'image_compress_max_width';
  static const String _maxHeightKey = 'image_compress_max_height';

  ImageCompressSettingsNotifier() : super(const ImageCompressSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = ImageCompressSettings(
      quality: prefs.getInt(_qualityKey) ?? 80,
      maxWidth: prefs.getInt(_maxWidthKey) ?? 1024,
      maxHeight: prefs.getInt(_maxHeightKey) ?? 1024,
    );
  }

  Future<void> updateQuality(int quality) async {
    state = state.copyWith(quality: quality);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_qualityKey, quality);
  }

  Future<void> updateMaxWidth(int width) async {
    state = state.copyWith(maxWidth: width);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxWidthKey, width);
  }

  Future<void> updateMaxHeight(int height) async {
    state = state.copyWith(maxHeight: height);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxHeightKey, height);
  }
}

class ImageCompressSettingsPage extends ConsumerWidget {
  const ImageCompressSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(imageCompressSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('图片压缩设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 压缩质量
          _buildSectionTitle('压缩质量'),
          _buildQualitySlider(context, ref, settings, theme),
          const SizedBox(height: 24),

          // 最大宽度
          _buildSectionTitle('最大宽度'),
          _buildMaxWidthSelector(context, ref, settings, theme),
          const SizedBox(height: 24),

          // 最大高度
          _buildSectionTitle('最大高度'),
          _buildMaxHeightSelector(context, ref, settings, theme),
          const SizedBox(height: 32),

          // 说明
          _buildInfoCard(theme),
          const SizedBox(height: 24),

          // 预估压缩效果
          _buildCompressionEstimate(settings, theme),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildQualitySlider(
    BuildContext context,
    WidgetRef ref,
    ImageCompressSettings settings,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('质量'),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${settings.quality}%',
                  style: const TextStyle(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryGold,
              thumbColor: AppTheme.primaryGold,
              overlayColor: AppTheme.primaryGold.withOpacity(0.2),
            ),
            child: Slider(
              value: settings.quality.toDouble(),
              min: 10,
              max: 100,
              divisions: 18,
              onChanged: (value) {
                ref
                    .read(imageCompressSettingsProvider.notifier)
                    .updateQuality(value.round());
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10%', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Text('高质量', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Text('100%', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaxWidthSelector(
    BuildContext context,
    WidgetRef ref,
    ImageCompressSettings settings,
    ThemeData theme,
  ) {
    final options = [512, 768, 1024, 1536, 2048];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('最大宽度'),
              Text(
                '${settings.maxWidth}px',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((width) {
              final isSelected = settings.maxWidth == width;
              return ChoiceChip(
                label: Text('${width}px'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    ref
                        .read(imageCompressSettingsProvider.notifier)
                        .updateMaxWidth(width);
                  }
                },
                selectedColor: AppTheme.primaryGold.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primaryGold : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMaxHeightSelector(
    BuildContext context,
    WidgetRef ref,
    ImageCompressSettings settings,
    ThemeData theme,
  ) {
    final options = [512, 768, 1024, 1536, 2048];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('最大高度'),
              Text(
                '${settings.maxHeight}px',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((height) {
              final isSelected = settings.maxHeight == height;
              return ChoiceChip(
                label: Text('${height}px'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    ref
                        .read(imageCompressSettingsProvider.notifier)
                        .updateMaxHeight(height);
                  }
                },
                selectedColor: AppTheme.primaryGold.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primaryGold : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '压缩说明',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• 质量越低，图片体积越小，但可能损失细节\n'
            '• 尺寸越小，图片体积越小，但可能影响清晰度\n'
            '• 推荐设置：质量80%，尺寸1024px\n'
            '• 适合分享：质量70%，尺寸768px\n'
            '• 高清保存：质量90%，尺寸2048px',
            style: TextStyle(color: Colors.blue.shade800, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCompressionEstimate(
    ImageCompressSettings settings,
    ThemeData theme,
  ) {
    // 根据质量估算压缩率
    double compressionRatio;
    if (settings.quality >= 90) {
      compressionRatio = 0.3;
    } else if (settings.quality >= 80) {
      compressionRatio = 0.2;
    } else if (settings.quality >= 70) {
      compressionRatio = 0.15;
    } else if (settings.quality >= 50) {
      compressionRatio = 0.1;
    } else {
      compressionRatio = 0.05;
    }

    // 根据尺寸调整
    final sizeRatio =
        (settings.maxWidth * settings.maxHeight) / (1024 * 1024);
    compressionRatio *= sizeRatio;

    // 假设原始图片为 4MB (4000x3000)
    const originalSize = 4.0; // MB
    final compressedSize = originalSize * compressionRatio;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compress, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '预估压缩效果',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEstimateRow('原始图片', '4MB (4000×3000)', Colors.grey.shade600),
          const SizedBox(height: 8),
          _buildEstimateRow(
            '压缩后',
            '${compressedSize.toStringAsFixed(2)}MB',
            Colors.green.shade700,
          ),
          const SizedBox(height: 8),
          _buildEstimateRow(
            '压缩率',
            '${((1 - compressionRatio) * 100).toStringAsFixed(0)}%',
            AppTheme.primaryGold,
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
