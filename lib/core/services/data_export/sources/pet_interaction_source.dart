import 'package:flutter/material.dart';
import 'package:home_manager/core/services/pet_local_storage.dart';
import 'package:home_manager/data/models/pet.dart';
import '../data_export_source.dart';

class PetInteractionSource implements DataExportSource {
  final PetInteractionLocalStorage _storage = PetInteractionLocalStorage();

  @override
  String get id => 'pet_logs';

  @override
  String get name => '宠物互动日志';

  @override
  String get description => '宠物喂养、玩耍、聊天等互动记录';

  @override
  IconData get icon => Icons.pets_outlined;

  @override
  Future<bool> hasData() async {
    return _storage.hasInteractions();
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    final interactions = await _storage.loadAllInteractions();
    return {
      'pet_logs': {
        'interactions': interactions.map((i) => i.toJson()).toList(),
        '_meta': {'totalInteractions': interactions.length},
      },
    };
  }

  @override
  Future<ImportSummary> importData(Map<String, dynamic> data) async {
    try {
      final interactions = data['interactions'] as List;
      int imported = 0;
      for (final json in interactions) {
        final map = json as Map<String, dynamic>;
        await _storage.saveInteraction(PetInteraction.fromJson(map));
        imported++;
      }
      return ImportSummary(
        success: true,
        itemCount: imported,
        message: '已导入 $imported 条宠物互动记录',
      );
    } catch (e) {
      return ImportSummary(success: false, itemCount: 0, message: '导入宠物日志失败: $e');
    }
  }
}
