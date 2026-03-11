import 'package:home_manager/core/services/local_storage_service.dart';
import 'package:home_manager/data/models/pet.dart';

/// 宠物互动日志本地存储
/// 使用 JSONL 格式（每行一个 JSON）实现增量写入
class PetInteractionLocalStorage {
  final LocalStorageService _storage = LocalStorageService.instance;

  /// 获取当前月份的互动日志文件名称
  String _getCurrentFilename() {
    final now = DateTime.now();
    return 'pet_interactions_${now.year}-${now.month.toString().padLeft(2, '0')}.jsonl';
  }

  /// 根据日期获取文件名称
  String _getFilenameForDate(DateTime date) {
    return 'pet_interactions_${date.year}-${date.month.toString().padLeft(2, '0')}.jsonl';
  }

  /// 保存单条互动记录
  Future<void> saveInteraction(PetInteraction interaction) async {
    await _storage.appendJsonLine(
      _getCurrentFilename(),
      _interactionToJson(interaction),
    );
  }

  /// 加载指定宠物的所有互动记录
  Future<List<PetInteraction>> loadInteractions({String? petId}) async {
    final data = await _storage.readJsonLines(_getCurrentFilename());
    var interactions = data.map((json) => _interactionFromJson(json)).toList();
    
    // 如果指定了宠物 ID，过滤
    if (petId != null) {
      interactions = interactions.where((i) => i.petId == petId).toList();
    }
    
    // 按时间倒序排列
    interactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return interactions;
  }

  /// 加载所有月份的互动记录
  Future<List<PetInteraction>> loadAllInteractions() async {
    final files = await _storage.listFiles();
    final interactionFiles = files
        .where((f) => f.startsWith('pet_interactions_') && f.endsWith('.jsonl'));
    
    final allInteractions = <PetInteraction>[];
    
    for (final file in interactionFiles) {
      final data = await _storage.readJsonLines(file);
      allInteractions.addAll(data.map((json) => _interactionFromJson(json)));
    }
    
    // 按时间倒序排列
    allInteractions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return allInteractions;
  }

  /// 导出互动记录到指定路径
  Future<String> exportToFile(String destinationPath) async {
    final interactions = await loadAllInteractions();
    final data = interactions.map((i) => _interactionToJson(i)).toList();
    
    // 导出为标准 JSON 数组格式
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'totalInteractions': interactions.length,
      'interactions': data,
    };
    
    final filename = 'pet_logs_export_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}.json';
    final fullPath = '$destinationPath/$filename';
    
    await _storage.writeJsonFile('exports/$filename', exportData);
    
    return fullPath;
  }

  /// 从文件导入互动记录
  Future<int> importFromFile(String sourcePath) async {
    final data = await _storage.importJsonLines(sourcePath);
    
    int imported = 0;
    for (final json in data) {
      try {
        final interaction = _interactionFromJson(json);
        await saveInteraction(interaction);
        imported++;
      } catch (e) {
        // 跳过无效记录
      }
    }
    
    return imported;
  }

  /// 获取当前文件大小
  Future<int> getCurrentFileSize() async {
    return await _storage.getFileSize(_getCurrentFilename());
  }

  /// 检查是否有互动记录
  Future<bool> hasInteractions() async {
    return await _storage.fileExists(_getCurrentFilename());
  }

  /// 清空指定月份的互动记录
  Future<void> clearInteractions({int? year, int? month}) async {
    String filename;
    if (year != null && month != null) {
      filename = 'pet_interactions_${year}-${month.toString().padLeft(2, '0')}.jsonl';
    } else {
      filename = _getCurrentFilename();
    }
    await _storage.deleteFile(filename);
  }

  Map<String, dynamic> _interactionToJson(PetInteraction interaction) {
    return {
      'id': interaction.id,
      'petId': interaction.petId,
      'type': interaction.type,
      'value': interaction.value,
      'createdAt': interaction.createdAt.toIso8601String(),
    };
  }

  PetInteraction _interactionFromJson(Map<String, dynamic> json) {
    return PetInteraction(
      id: json['id'] as String,
      petId: json['petId'] as String,
      type: json['type'] as String,
      value: json['value'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
