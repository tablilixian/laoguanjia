import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_study.dart';
import '../data/china_divisions.dart';
import '../data/city_study_repository.dart';
import '../providers/city_study_provider.dart';
import '../widgets/china_province_map.dart';
import 'city_study_edit_page.dart';
import 'city_study_list_page.dart';

class CityStudyHomePage extends ConsumerStatefulWidget {
  const CityStudyHomePage({super.key});

  @override
  ConsumerState<CityStudyHomePage> createState() => _CityStudyHomePageState();
}

class _CityStudyHomePageState extends ConsumerState<CityStudyHomePage> {
  bool _divisionsLoaded = false;
  // ignore: unused_field
  bool _storeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await ChinaDivisions.instance.load();
    await CityStudyRepository.instance.ensureLoaded();
    await ref.read(cityStudyProvider.notifier).load();
    if (mounted) {
      setState(() {
        _divisionsLoaded = true;
        _storeLoaded = true;
      });
    }
  }

  void _onProvinceTap(int provinceAdcode) {
    final province = ChinaDivisions.instance.getProvince(provinceAdcode);
    if (province == null) return;

    final counties = ChinaDivisions.instance.getCountiesInProvince(provinceAdcode);
    final store = ref.read(cityStudyProvider);

    _showCountySheet(context, province, counties, store);
  }

  void _onCountyTap(CountyInfo county) {
    final province = ChinaDivisions.instance.getProvince(county.provinceAdcode);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CityStudyEditPage(
          adcode: county.adcode,
          countyName: county.name,
          province: province?.name ?? '',
        ),
      ),
    );
  }

  void _showCountySheet(
    BuildContext context,
    ProvinceInfo province,
    List<CountyInfo> counties,
    CityStudyStore store,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final completed = counties
            .where((c) =>
                store.studies[c.adcode]?.status == CityStudyStatus.completed)
            .length;
        final inProgress = counties
            .where((c) =>
                store.studies[c.adcode]?.status == CityStudyStatus.inProgress)
            .length;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              province.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$completed 已完成 · $inProgress 进行中 · ${counties.length} 个县区',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // County list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: counties.length,
                    itemBuilder: (ctx, index) {
                      final county = counties[index];
                      final study = store.studies[county.adcode];

                      IconData statusIcon;
                      Color statusColor;
                      if (study?.status == CityStudyStatus.completed) {
                        statusIcon = Icons.check_circle;
                        statusColor = const Color(0xFF81C784);
                      } else if (study?.status == CityStudyStatus.inProgress) {
                        statusIcon = Icons.edit;
                        statusColor = const Color(0xFFFFD54F);
                      } else {
                        statusIcon = Icons.radio_button_unchecked;
                        statusColor = Colors.grey.shade300;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: Icon(statusIcon, color: statusColor),
                          title: Text(county.name,
                              style: const TextStyle(fontSize: 15)),
                          subtitle: study?.sections.hasAnyContent == true
                              ? Text(
                                  study!.sections.hasAnyContent
                                      ? '${study.sections.geography.content.isNotEmpty ? "📍" : ""}'
                                          '${study.sections.history.content.isNotEmpty ? "📜" : ""}'
                                          '${study.sections.figures.content.isNotEmpty ? "👤" : ""}'
                                          '${study.sections.industry.content.isNotEmpty ? "🏭" : ""}'
                                      : '',
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                          trailing: const Icon(Icons.chevron_right,
                              color: Colors.grey),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CityStudyEditPage(
                                  adcode: county.adcode,
                                  countyName: county.name,
                                  province: province.name,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openRandomCounty() {
    final county = ChinaDivisions.instance.getRandomCounty();
    if (county == null) return;
    final province =
        ChinaDivisions.instance.getProvince(county.provinceAdcode);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CityStudyEditPage(
          adcode: county.adcode,
          countyName: county.name,
          province: province?.name ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_divisionsLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('城市精读')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final store = ref.watch(cityStudyProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('城市精读'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: '精读列表',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CityStudyListPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导入/导出',
            onPressed: _showImportExportDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD4A574).withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _statItem(theme, '🎯', '已完成', '${store.completedCount}'),
                Container(
                  width: 1,
                  height: 30,
                  color: const Color(0xFFD4A574).withAlpha(50),
                ),
                _statItem(theme, '📝', '进行中', '${store.inProgressCount}'),
                Container(
                  width: 1,
                  height: 30,
                  color: const Color(0xFFD4A574).withAlpha(50),
                ),
                _statItem(theme, '🗺️', '总目标', '50'),
                Container(
                  width: 1,
                  height: 30,
                  color: const Color(0xFFD4A574).withAlpha(50),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '进度 ${(store.completedCount / 50 * 100).clamp(0, 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (store.completedCount / 50).clamp(0, 1),
                            backgroundColor:
                                const Color(0xFFD4A574).withAlpha(30),
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFD4A574)),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: ChinaProvinceMap(
              store: store,
              onProvinceTap: _onProvinceTap,
              onCountyTap: _onCountyTap,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRandomCounty,
        backgroundColor: const Color(0xFFD4A574),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.shuffle),
        label: const Text('随机选城'),
      ),
    );
  }

  Widget _statItem(
      ThemeData theme, String emoji, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text('$emoji $label',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }

  void _showImportExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入 / 导出'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('导出数据'),
              subtitle: const Text('导出为 JSON 文件'),
              onTap: () {
                Navigator.of(ctx).pop();
                _exportData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导入数据'),
              subtitle: const Text('从 JSON 文件导入'),
              onTap: () {
                Navigator.of(ctx).pop();
                _importData();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    final repo = CityStudyRepository.instance;
    final json = repo.exportToJson();

    // Copy to clipboard for now (in production would use share_plus)
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板')),
      );
    }
  }

  Future<void> _importData() async {
    // Simple paste import
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboard?.text == null || clipboard!.text!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板为空，请先复制 JSON 数据')),
        );
      }
      return;
    }

    final repo = CityStudyRepository.instance;
    final result = await repo.importFromJson(clipboard.text!);
    await ref.read(cityStudyProvider.notifier).load();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? '已导入 ${result.itemCount} 条精读记录'
                : '导入失败: ${result.message}',
          ),
        ),
      );
    }
  }
}
