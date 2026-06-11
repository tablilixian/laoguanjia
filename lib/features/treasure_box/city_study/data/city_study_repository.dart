import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/city_study.dart';
import 'package:home_manager/core/services/data_export/data_export_source.dart' show ImportSummary;

class CityStudyRepository {
  static CityStudyRepository? _instance;
  CityStudyStore? _store;
  bool _loaded = false;

  CityStudyRepository._();

  static CityStudyRepository get instance {
    _instance ??= CityStudyRepository._();
    return _instance!;
  }

  String get _fileName => 'city_studies.json';

  Future<String> get _filePath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_fileName';
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final path = await _filePath;
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          _store = CityStudyStore.fromJsonString(content);
        }
      }
    } catch (e) {
      _store = CityStudyStore();
    }
    _store ??= CityStudyStore();
    _loaded = true;
  }

  Future<void> _save() async {
    if (_store == null) return;
    try {
      final path = await _filePath;
      final file = File(path);
      await file.writeAsString(_store!.toJsonString());
    } catch (e) {
      // Silently fail on save errors
    }
  }

  CityStudyStore get store {
    assert(_loaded, 'Call load() first');
    return _store!;
  }

  CityStudy? getStudy(int adcode) => _store?.studies[adcode];

  List<CityStudy> getAllStudies() =>
      _store?.studies.values.toList() ?? [];

  int get completedCount => _store?.completedCount ?? 0;
  int get inProgressCount => _store?.inProgressCount ?? 0;
  int get totalCount => _store?.totalCount ?? 0;

  Future<CityStudy> startStudy(int adcode, String name, String province) async {
    await ensureLoaded();
    if (_store!.studies.containsKey(adcode)) {
      return _store!.studies[adcode]!;
    }
    final study = CityStudy(
      adcode: adcode,
      name: name,
      province: province,
      status: CityStudyStatus.inProgress,
    );
    _store!.studies[adcode] = study;
    await _save();
    return study;
  }

  Future<void> updateStudy(CityStudy study) async {
    await ensureLoaded();
    study.updatedAt = DateTime.now();
    _store!.studies[study.adcode] = study;
    await _save();
  }

  Future<void> updateStudySection(
    int adcode,
    String sectionKey,
    CityStudySection section,
  ) async {
    await ensureLoaded();
    final study = _store!.studies[adcode];
    if (study == null) return;
    switch (sectionKey) {
      case 'geography':
        study.sections.geography = section;
      case 'history':
        study.sections.history = section;
      case 'figures':
        study.sections.figures = section;
      case 'industry':
        study.sections.industry = section;
    }
    study.updatedAt = DateTime.now();
    if (study.status == CityStudyStatus.notStarted &&
        study.sections.hasAnyContent) {
      study.status = CityStudyStatus.inProgress;
    }
    await _save();
  }

  Future<void> updateStatus(int adcode, CityStudyStatus status) async {
    await ensureLoaded();
    final study = _store!.studies[adcode];
    if (study == null) return;
    study.status = status;
    study.updatedAt = DateTime.now();
    await _save();
  }

  Future<void> updateNotes(int adcode, String notes) async {
    await ensureLoaded();
    final study = _store!.studies[adcode];
    if (study == null) return;
    study.notes = notes;
    study.updatedAt = DateTime.now();
    await _save();
  }

  Future<void> updateTags(int adcode, List<String> tags) async {
    await ensureLoaded();
    final study = _store!.studies[adcode];
    if (study == null) return;
    study.tags = tags;
    study.updatedAt = DateTime.now();
    await _save();
  }

  Future<void> deleteStudy(int adcode) async {
    await ensureLoaded();
    _store!.studies.remove(adcode);
    await _save();
  }

  String exportToJson() => _store?.toJsonString() ?? '{}';

  Future<ImportSummary> importFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final imported = CityStudyStore.fromJson(data);
      int count = 0;
      for (final entry in imported.studies.entries) {
        _store!.studies[entry.key] = entry.value;
        count++;
      }
      await _save();
      return ImportSummary(success: true, itemCount: count);
    } catch (e) {
      return ImportSummary(success: false, itemCount: 0, message: '$e');
    }
  }

  Future<void> ensureLoaded() async {
    if (!_loaded) await load();
  }
}


