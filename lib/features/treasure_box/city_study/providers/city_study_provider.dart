import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/china_divisions.dart';
import '../data/city_study_repository.dart';
import '../models/city_study.dart';

final chinaDivisionsProvider = FutureProvider<void>((ref) async {
  await ChinaDivisions.instance.load();
});

final cityStudyRepositoryProvider = Provider<CityStudyRepository>((ref) {
  return CityStudyRepository.instance;
});

final cityStudyStoreProvider =
    FutureProvider<CityStudyStore>((ref) async {
  final repo = ref.watch(cityStudyRepositoryProvider);
  await repo.ensureLoaded();
  return repo.store;
});

class CityStudyNotifier extends StateNotifier<CityStudyStore> {
  final CityStudyRepository _repo;

  CityStudyNotifier(this._repo) : super(CityStudyStore());

  Future<void> load() async {
    await _repo.ensureLoaded();
    state = _repo.store;
  }

  Future<CityStudy> startStudy(
      int adcode, String name, String province) async {
    final study = await _repo.startStudy(adcode, name, province);
    state = _repo.store;
    return study;
  }

  Future<void> updateStudy(CityStudy study) async {
    await _repo.updateStudy(study);
    state = _repo.store;
  }

  Future<void> updateSection(
      int adcode, String sectionKey, CityStudySection section) async {
    await _repo.updateStudySection(adcode, sectionKey, section);
    state = _repo.store;
  }

  Future<void> updateStatus(int adcode, CityStudyStatus status) async {
    await _repo.updateStatus(adcode, status);
    state = _repo.store;
  }

  Future<void> updateNotes(int adcode, String notes) async {
    await _repo.updateNotes(adcode, notes);
    state = _repo.store;
  }

  Future<void> updateTags(int adcode, List<String> tags) async {
    await _repo.updateTags(adcode, tags);
    state = _repo.store;
  }

  Future<void> deleteStudy(int adcode) async {
    await _repo.deleteStudy(adcode);
    state = _repo.store;
  }

  CityStudy? getStudy(int adcode) => state.studies[adcode];

  int getCompletedCount(int provinceAdcode) {
    final provinceCountyCodes = ChinaDivisions.instance
        .getCountiesInProvince(provinceAdcode)
        .map((c) => c.adcode)
        .toSet();
    return state.studies.values
        .where((s) =>
            provinceCountyCodes.contains(s.adcode) &&
            s.status == CityStudyStatus.completed)
        .length;
  }

  int getInProgressCount(int provinceAdcode) {
    final provinceCountyCodes = ChinaDivisions.instance
        .getCountiesInProvince(provinceAdcode)
        .map((c) => c.adcode)
        .toSet();
    return state.studies.values
        .where((s) =>
            provinceCountyCodes.contains(s.adcode) &&
            s.status == CityStudyStatus.inProgress)
        .length;
  }

  int getTotalCounties(int provinceAdcode) {
    return ChinaDivisions.instance
        .getCountiesInProvince(provinceAdcode)
        .length;
  }

  double getProvinceCompletion(int provinceAdcode) {
    final total = getTotalCounties(provinceAdcode);
    if (total == 0) return 0;
    return getCompletedCount(provinceAdcode) / total;
  }
}

final cityStudyProvider =
    StateNotifierProvider<CityStudyNotifier, CityStudyStore>((ref) {
  final repo = ref.watch(cityStudyRepositoryProvider);
  return CityStudyNotifier(repo);
});
