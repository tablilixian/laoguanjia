import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_study.dart';
import '../providers/city_study_provider.dart';
import '../providers/city_ai_provider.dart';
import '../providers/city_ai_prompts.dart';
import '../widgets/section_editor_card.dart';

class CityStudyEditPage extends ConsumerStatefulWidget {
  final int adcode;
  final String countyName;
  final String province;

  const CityStudyEditPage({
    super.key,
    required this.adcode,
    required this.countyName,
    required this.province,
  });

  @override
  ConsumerState<CityStudyEditPage> createState() => _CityStudyEditPageState();
}

class _CityStudyEditPageState extends ConsumerState<CityStudyEditPage> {
  late CityStudy _study;
  bool _initialized = false;
  bool _isSaving = false;
  final Set<String> _loadingSections = {};

  static const List<String> _availableTags = [
    '人文', '产业', '推荐', '自然风光', '美食', '古建筑', '沿海', '山区', '平原', '边境',
  ];

  @override
  void initState() {
    super.initState();
    _initStudy();
  }

  Future<void> _initStudy() async {
    final notifier = ref.read(cityStudyProvider.notifier);
    final study = await notifier.startStudy(
      widget.adcode,
      widget.countyName,
      widget.province,
    );
    if (mounted) {
      setState(() {
        _study = study;
        _initialized = true;
      });
    }
  }

  Future<void> _saveSection(String key, CityStudySection section) async {
    if (!mounted) return;
    await ref
        .read(cityStudyProvider.notifier)
        .updateSection(widget.adcode, key, section);
  }

  Future<void> _saveNotes() async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    await ref
        .read(cityStudyProvider.notifier)
        .updateNotes(widget.adcode, _study.notes);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _saveTags() async {
    if (!mounted) return;
    await ref
        .read(cityStudyProvider.notifier)
        .updateTags(widget.adcode, _study.tags);
  }

  Future<void> _generateSection(String key) async {
    setState(() => _loadingSections.add(key));

    final aiService = ref.read(cityAiServiceProvider);
    try {
      String result;
      switch (key) {
        case 'geography':
          result = await aiService.generateGeography(
              widget.countyName, widget.province);
        case 'history':
          result = await aiService.generateHistory(
              widget.countyName, widget.province);
        case 'figures':
          result = await aiService.generateFigures(
              widget.countyName, widget.province);
        case 'industry':
          result = await aiService.generateIndustry(
              widget.countyName, widget.province);
        default:
          return;
      }

      final section = CityStudySection(content: result, aiGenerated: true);
      setState(() {
        switch (key) {
          case 'geography':
            _study.sections.geography = section;
          case 'history':
            _study.sections.history = section;
          case 'figures':
            _study.sections.figures = section;
          case 'industry':
            _study.sections.industry = section;
        }
      });
      await _saveSection(key, section);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSections.remove(key));
    }
  }

  Future<void> _generateAll() async {
    setState(() {
      _loadingSections.addAll(['geography', 'history', 'figures', 'industry']);
    });

    final aiService = ref.read(cityAiServiceProvider);
    try {
      final generators = [
        ('geography', aiService.generateGeography(widget.countyName, widget.province)),
        ('history', aiService.generateHistory(widget.countyName, widget.province)),
        ('figures', aiService.generateFigures(widget.countyName, widget.province)),
        ('industry', aiService.generateIndustry(widget.countyName, widget.province)),
      ];

      for (final (key, future) in generators) {
        final result = await future;
        final section = CityStudySection(content: result, aiGenerated: true);
        setState(() {
          switch (key) {
            case 'geography':
              _study.sections.geography = section;
            case 'history':
              _study.sections.history = section;
            case 'figures':
              _study.sections.figures = section;
            case 'industry':
              _study.sections.industry = section;
          }
        });
        await _saveSection(key, section);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSections.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_initialized) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.countyName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.countyName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: theme.colorScheme.primary),
                  )
                : const Icon(Icons.check),
            tooltip: '保存',
            onPressed: () async {
              await _saveNotes();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('已保存'),
                      duration: Duration(seconds: 1)),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD4A574).withAlpha(25),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('📍', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.countyName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              widget.province,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusChip(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatBox(
                          '已完成', Icons.check_circle, const Color(0xFF81C784)),
                      const SizedBox(width: 8),
                      _buildStatBox('进行中', Icons.edit,
                          const Color(0xFFFFD54F)),
                      const SizedBox(width: 8),
                      _buildStatBox(
                        '精读数',
                        Icons.map,
                        const Color(0xFFD4A574),
                        value:
                            '${ref.read(cityStudyProvider).completedCount}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // AI Generate All button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loadingSections.length == 4
                      ? null
                      : _generateAll,
                  icon: _loadingSections.length == 4
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _loadingSections.length == 4
                        ? '生成中…'
                        : '🤖 AI 一键生成完整精读',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A574),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),

            // Sections
            ...CityAISectionInfo.sections.map((info) {
              final section = _getSection(info.key);
              return SectionEditorCard(
                section: section,
                info: info,
                isLoading: _loadingSections.contains(info.key),
                onAiGenerate: () => _generateSection(info.key),
                onContentChanged: (value) {
                  final newSection =
                      CityStudySection(content: value, aiGenerated: false);
                  _setSection(info.key, newSection);
                  _saveSection(info.key, newSection);
                },
              );
            }),

            const SizedBox(height: 8),

            // Tags
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🏷️ 标签',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _availableTags.map((tag) {
                      final selected = _study.tags.contains(tag);
                      return FilterChip(
                        label: Text(tag, style: const TextStyle(fontSize: 13)),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _study.tags = [..._study.tags, tag];
                            } else {
                              _study.tags =
                                  _study.tags.where((t) => t != tag).toList();
                            }
                          });
                          _saveTags();
                        },
                        selectedColor:
                            const Color(0xFFD4A574).withAlpha(40),
                        checkmarkColor: const Color(0xFFD4A574),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFFD4A574)
                              : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Notes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📝 自由笔记',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        maxLines: 5,
                        minLines: 3,
                        decoration: InputDecoration(
                          hintText: '补充你的观察和感悟…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                        ),
                        controller: TextEditingController(text: _study.notes),
                        onChanged: (value) {
                          _study.notes = value;
                          _saveNotes();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Complete button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _study.sections.hasAnyContent
                      ? () async {
                          await ref
                              .read(cityStudyProvider.notifier)
                              .updateStatus(
                                  widget.adcode, CityStudyStatus.completed);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '🎉 完成 ${widget.countyName} 的精读！'),
                                backgroundColor: const Color(0xFF81C784),
                              ),
                            );
                            Navigator.of(context).pop();
                          }
                        }
                      : null,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('标记为已完成'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81C784),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  CityStudySection _getSection(String key) {
    switch (key) {
      case 'geography':
        return _study.sections.geography;
      case 'history':
        return _study.sections.history;
      case 'figures':
        return _study.sections.figures;
      case 'industry':
        return _study.sections.industry;
      default:
        return CityStudySection();
    }
  }

  void _setSection(String key, CityStudySection section) {
    switch (key) {
      case 'geography':
        _study.sections.geography = section;
      case 'history':
        _study.sections.history = section;
      case 'figures':
        _study.sections.figures = section;
      case 'industry':
        _study.sections.industry = section;
    }
  }

  Widget _buildStatusChip() {
    Color bgColor;
    Color textColor;
    String label;

    if (_study.status == CityStudyStatus.completed) {
      bgColor = const Color(0xFF81C784).withAlpha(30);
      textColor = const Color(0xFF4CAF50);
      label = '✅ 已完成';
    } else if (_study.sections.hasAnyContent) {
      bgColor = const Color(0xFFFFD54F).withAlpha(30);
      textColor = const Color(0xFFF9A825);
      label = '📝 进行中';
    } else {
      bgColor = Colors.grey.withAlpha(30);
      textColor = Colors.grey;
      label = '⬜ 未开始';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildStatBox(
      String label, IconData icon, Color color, {String? value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value ??
                  '${ref.read(cityStudyProvider).completedCount}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
