import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_personality.dart';
import 'package:home_manager/data/models/pet_memory.dart';
import 'package:home_manager/data/models/pet_relationship.dart';

class PetExportData {
  final String version;
  final DateTime exportedAt;
  final Pet pet;
  final PetPersonality? personality;
  final List<PetMemory> memories;
  final PetRelationship? relationship;

  PetExportData({
    required this.version,
    required this.exportedAt,
    required this.pet,
    this.personality,
    required this.memories,
    this.relationship,
  });

  factory PetExportData.fromJson(Map<String, dynamic> json) {
    return PetExportData(
      version: json['version'] ?? '1.0',
      exportedAt: DateTime.parse(json['exportedAt']),
      pet: Pet.fromJson(json['pet']),
      personality: json['personality'] != null
          ? PetPersonality.fromJson(json['personality'])
          : null,
      memories: (json['memories'] as List? ?? [])
          .map((m) => PetMemory.fromJson(m))
          .toList(),
      relationship: json['relationship'] != null
          ? PetRelationship.fromJson(json['relationship'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'pet': pet.toJson(),
      'personality': personality?.toJson(),
      'memories': memories.map((m) => m.toJson()).toList(),
      'relationship': relationship?.toJson(),
    };
  }

  String toJsonString() {
    return '{"version":"$version","exportedAt":"${exportedAt.toIso8601String()}","pet":${_encodeJson(pet.toJson())},"personality":${personality != null ? _encodeJson(personality!.toJson()) : "null"},"memories":${_encodeJsonList(memories.map((m) => m.toJson()).toList())},"relationship":${relationship != null ? _encodeJson(relationship!.toJson()) : "null"}}';
  }

  static String _encodeJson(Map<String, dynamic> json) {
    final buffer = StringBuffer('{');
    var first = true;
    json.forEach((key, value) {
      if (!first) buffer.write(',');
      first = false;
      buffer.write('"$key":');
      if (value is String) {
        buffer.write('"$value"');
      } else if (value is num || value is bool) {
        buffer.write('$value');
      } else if (value == null) {
        buffer.write('null');
      } else if (value is List) {
        buffer.write(_encodeJsonList(value));
      } else {
        buffer.write('"$value"');
      }
    });
    buffer.write('}');
    return buffer.toString();
  }

  static String _encodeJsonList(List list) {
    final buffer = StringBuffer('[');
    for (var i = 0; i < list.length; i++) {
      if (i > 0) buffer.write(',');
      if (list[i] is Map) {
        buffer.write(_encodeJson(list[i]));
      } else if (list[i] is String) {
        buffer.write('"${list[i]}"');
      } else {
        buffer.write('${list[i]}');
      }
    }
    buffer.write(']');
    return buffer.toString();
  }
}
