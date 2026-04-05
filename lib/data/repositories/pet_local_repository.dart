import 'package:home_manager/core/services/local_storage_service.dart';
import 'package:home_manager/data/models/pet_local_data.dart';

/// 宠物本地数据仓库
///
/// 操作本地 JSON 文件，提供 CRUD 和归档能力。
/// 文件路径: `pets/pet_{petId}_YYYY-MM.json`
class PetLocalRepository {
  final LocalStorageService _storage = LocalStorageService.instance;

  /// 读取当月完整数据
  Future<PetLocalData?> loadData(String petId) async {
    final data = await _storage.readJsonFile(_filename(petId));
    if (data == null) return null;
    return PetLocalData.fromJson(data);
  }

  /// 写入完整数据 (覆盖写)
  Future<void> saveData(PetLocalData data) async {
    await _storage.writeJsonFile(_filename(data.petId), data.toJson());
  }

  /// 原子更新: 读取 → 修改 → 写回
  Future<PetLocalData> update(
    String petId,
    PetLocalData Function(PetLocalData) mutator,
  ) async {
    final data = await loadData(petId) ?? PetLocalData.empty(petId);
    final updated = mutator(data);
    await saveData(updated);
    return updated;
  }

  /// 删除宠物本地数据 (当前月文件)
  Future<void> deleteData(String petId) async {
    await _storage.deleteFile(_filename(petId));
  }

  /// 列出宠物的所有本地文件 (含归档)
  Future<List<String>> listFiles(String petId) async {
    final files = await _storage.listFiles();
    return files
        .where((f) => f.contains('pet_$petId') && f.endsWith('.json'))
        .toList();
  }

  /// 归档当前月数据到 archive 目录
  Future<void> archiveCurrentMonth(String petId, PetLocalData data) async {
    final archiveName =
        'pets/archive/pet_${petId}_${data.month}_archived.json';
    await _storage.writeJsonFile(archiveName, data.toJson());
  }

  String _filename(String petId) {
    final now = DateTime.now();
    return 'pets/pet_${petId}_${now.year}-${now.month.toString().padLeft(2, '0')}.json';
  }
}
