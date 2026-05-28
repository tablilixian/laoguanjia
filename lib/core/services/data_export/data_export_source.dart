import 'package:flutter/material.dart';

abstract class DataExportSource {
  String get id;
  String get name;
  String get description;
  IconData get icon;

  Future<bool> hasData();

  Future<Map<String, dynamic>> exportData();

  Future<ImportSummary> importData(Map<String, dynamic> data);
}

class ImportSummary {
  final bool success;
  final int itemCount;
  final String? message;

  const ImportSummary({
    required this.success,
    required this.itemCount,
    this.message,
  });
}
