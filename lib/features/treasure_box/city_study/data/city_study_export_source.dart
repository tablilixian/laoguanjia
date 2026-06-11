import 'package:flutter/material.dart';
import 'package:home_manager/core/services/data_export/data_export_source.dart';
import 'city_study_repository.dart';

class CityStudyExportSource implements DataExportSource {
  final CityStudyRepository _repo = CityStudyRepository.instance;

  @override
  String get id => 'city_study';

  @override
  String get name => '城市精读';

  @override
  String get description => '县域精读笔记记录';

  @override
  IconData get icon => Icons.map_outlined;

  @override
  Future<bool> hasData() async {
    await _repo.ensureLoaded();
    return _repo.totalCount > 0;
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    await _repo.ensureLoaded();
    return {
      'city_study': {
        'data': _repo.exportToJson(),
        '_meta': {
          'totalCount': _repo.totalCount,
          'completedCount': _repo.completedCount,
        },
      },
    };
  }

  @override
  Future<ImportSummary> importData(Map<String, dynamic> data) async {
    try {
      final jsonStr = data['data'] as String;
      final result = await _repo.importFromJson(jsonStr);
      return ImportSummary(
        success: result.success,
        itemCount: result.itemCount,
        message: result.message ?? '已导入 ${result.itemCount} 条城市精读记录',
      );
    } catch (e) {
      return ImportSummary(
        success: false,
        itemCount: 0,
        message: '导入城市精读失败: $e',
      );
    }
  }
}
