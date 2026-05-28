import 'package:flutter/material.dart';
import 'data_export_source.dart';
import 'sources/finance_source.dart';
import 'sources/chat_source.dart';
import 'sources/pet_interaction_source.dart';
import 'sources/pet_memory_source.dart';

class DataExportRegistry {
  DataExportRegistry._();

  /// 所有数据源列表。
  /// 新增数据源只需在列表中追加一项，页面和服务会自动处理。
  static final List<DataExportSource Function()> sourceFactories = [
    () => ChatSource(),
    () => PetInteractionSource(),
    () => PetMemorySource(),
  ];

  /// 需要 householdId 的数据源工厂
  static final List<DataExportSource Function(String householdId)> householdSourceFactories = [
    (householdId) => FinanceSource(householdId: householdId),
  ];

  static List<DataExportSource> createSources({String? householdId}) {
    final sources = <DataExportSource>[];
    for (final factory in sourceFactories) {
      sources.add(factory());
    }
    if (householdId != null) {
      for (final factory in householdSourceFactories) {
        sources.add(factory(householdId));
      }
    }
    return sources;
  }

  static Map<String, DataExportSource> createSourceMap({String? householdId}) {
    final map = <String, DataExportSource>{};
    for (final source in createSources(householdId: householdId)) {
      map[source.id] = source;
    }
    return map;
  }
}
