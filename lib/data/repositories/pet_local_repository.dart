import 'package:flutter/foundation.dart';
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
    final filename = _filename(petId);
    debugPrint('尝试读取文件：$filename');
    final data = await _storage.readJsonFile(filename);
    if (data == null) {
      debugPrint('文件不存在或为空：$filename');
      return null;
    }
    debugPrint('文件读取成功：$filename');
    return PetLocalData.fromJson(data);
  }

  /// 写入完整数据 (覆盖写)
  Future<void> saveData(PetLocalData data) async {
    final filename = _filename(data.petId);
    debugPrint('尝试保存宠物数据到：$filename');
    try {
      await _storage.writeJsonFile(filename, data.toJson());
      debugPrint('宠物数据保存成功：$filename');
    } catch (e) {
      debugPrint('保存宠物数据失败：$filename, 错误：$e');
      rethrow;
    }
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
