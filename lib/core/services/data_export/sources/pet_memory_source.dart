import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_manager/core/services/local_storage_service.dart';
import 'package:home_manager/core/services/pet_memory_local_storage.dart';
import 'package:home_manager/data/models/pet_memory.dart';
import '../data_export_source.dart';

class PetMemorySource implements DataExportSource {
  final PetMemoryLocalStorage _memoryStorage = PetMemoryLocalStorage();
  final LocalStorageService _fileStorage = LocalStorageService.instance;

  @override
  String get id => 'pet_memories';

  @override
  String get name => '宠物记忆';

  @override
  String get description => '宠物的长期记忆数据';

  @override
  IconData get icon => Icons.memory;

  @override
  Future<bool> hasData() async {
    final files = await _fileStorage.listFiles();
    return files.any((f) => f.startsWith('pet_memories_') && f.endsWith('.json'));
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    final files = await _fileStorage.listFiles();
    final memoryFiles = files
        .where((f) => f.startsWith('pet_memories_') && f.endsWith('.json'))
        .toList();

    final allMemories = <String, dynamic>{};
    int totalMemories = 0;

    for (final file in memoryFiles) {
      try {
        final fileData = await _fileStorage.readJsonFile(file);
        if (fileData != null) {
          final petId = fileData['pet_id'] as String?;
          final memories = fileData['memories'] as List?;
          if (petId != null && memories != null) {
            final simplified = memories.map((m) {
              final memory = m as Map<String, dynamic>;
              return {
                'memory_type': memory['memory_type'],
                'title': memory['title'],
                'description': memory['description'],
                'emotion': memory['emotion'],
                'importance': memory['importance'],
                'occurred_at': memory['occurred_at'],
              };
            }).toList();

            allMemories[petId] = {
              'memories': simplified,
              'statistics': fileData['statistics'],
            };
            totalMemories += memories.length;
          }
        }
      } catch (_) {}
    }

    return {
      'pet_memories': {
        'pets': allMemories,
        '_meta': {
          'totalPets': allMemories.length,
          'totalMemories': totalMemories,
        },
      },
    };
  }

  @override
  Future<ImportSummary> importData(Map<String, dynamic> data) async {
    try {
      final pets = data['pets'] as Map<String, dynamic>;
      int totalImported = 0;

      for (final entry in pets.entries) {
        final petId = entry.key;
        final petData = entry.value as Map<String, dynamic>;
        final memories = petData['memories'] as List;

        for (final m in memories) {
          final memoryMap = m as Map<String, dynamic>;
          final memory = PetMemory.fromJson({
            'id': 'import_${DateTime.now().millisecondsSinceEpoch}_${totalImported}',
            'pet_id': petId,
            'memory_type': memoryMap['memory_type'] ?? 'conversation',
            'title': memoryMap['title'] ?? '',
            'description': memoryMap['description'] ?? '',
            'emotion': memoryMap['emotion'],
            'participants': <String>[],
            'importance': memoryMap['importance'] ?? 3,
            'is_summarized': false,
            'interaction_id': null,
            'occurred_at': memoryMap['occurred_at'] ?? DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          });
          await _memoryStorage.saveMemory(memory);
          totalImported++;
        }
      }

      return ImportSummary(
        success: true,
        itemCount: totalImported,
        message: '已导入 $totalImported 条宠物记忆',
      );
    } catch (e) {
      return ImportSummary(success: false, itemCount: 0, message: '导入宠物记忆失败: $e');
    }
  }
}
