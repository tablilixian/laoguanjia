import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_study.dart';
import '../data/china_divisions.dart';
import '../providers/city_study_provider.dart';
import 'city_study_edit_page.dart';

class CityStudyListPage extends ConsumerWidget {
  const CityStudyListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final store = ref.watch(cityStudyProvider);
    final studies = store.studies.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final completed = studies.where((s) => s.status == CityStudyStatus.completed).length;
    final inProgress = studies.where((s) => s.status == CityStudyStatus.inProgress).length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('精读记录'),
        centerTitle: true,
      ),
      body: studies.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    '还没有精读记录',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '在地图上选择一个城市开始吧',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Stats header
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A574).withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem(theme, '✅ 已完成', '$completed', const Color(0xFF81C784)),
                      _statItem(theme, '📝 进行中', '$inProgress', const Color(0xFFFFD54F)),
                      _statItem(theme, '📚 共', '${studies.length}', const Color(0xFFD4A574)),
                    ],
                  ),
                ),
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '搜索城市…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                    ),
                    onChanged: (query) {
                      // Filter could be implemented here
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: studies.length,
                    itemBuilder: (ctx, index) {
                      final study = studies[index];
                      return _StudyCard(study: study);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statItem(ThemeData theme, String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }
}

class _StudyCard extends ConsumerWidget {
  final CityStudy study;

  const _StudyCard({required this.study});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final divisions = ChinaDivisions.instance;
    final county = divisions.getCounty(study.adcode);
    final province = county != null
        ? divisions.getProvince(county.provinceAdcode)
        : null;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (study.status) {
      case CityStudyStatus.completed:
        statusColor = const Color(0xFF81C784);
        statusText = '已完成';
        statusIcon = Icons.check_circle;
      case CityStudyStatus.inProgress:
        statusColor = const Color(0xFFFFD54F);
        statusText = '进行中';
        statusIcon = Icons.edit;
      case CityStudyStatus.notStarted:
        statusColor = Colors.grey;
        statusText = '未开始';
        statusIcon = Icons.radio_button_unchecked;
    }

    final hasSections = study.sections.hasAnyContent;
    final sectionsDone = [
      if (study.sections.geography.content.isNotEmpty) 1,
      if (study.sections.history.content.isNotEmpty) 1,
      if (study.sections.figures.content.isNotEmpty) 1,
      if (study.sections.industry.content.isNotEmpty) 1,
    ].length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasSections
              ? const Color(0xFFD4A574).withAlpha(50)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CityStudyEditPage(
                adcode: study.adcode,
                countyName: study.name,
                province: study.province,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      study.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      province?.name ?? study.province,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasSections)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A574).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$sectionsDone/4',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFFD4A574),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
