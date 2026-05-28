import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_manager/data/finance/finance_storage.dart';
import 'package:home_manager/data/finance/models/finance_data.dart';
import '../data_export_source.dart';

class FinanceSource implements DataExportSource {
  final FinanceStorage _storage = FinanceStorage.instance;
  final String householdId;

  FinanceSource({required this.householdId});

  @override
  String get id => 'finance';

  @override
  String get name => '财务数据';

  @override
  String get description => '账户信息与快照记录';

  @override
  IconData get icon => Icons.account_balance_wallet_outlined;

  @override
  Future<bool> hasData() async {
    final data = await _storage.load(householdId);
    return data.accounts.isNotEmpty || data.snapshots.isNotEmpty;
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    final data = await _storage.load(householdId);
    final json = data.toJson();
    return {
      'finance': {
        'data': json,
        '_meta': {
          'accountCount': data.accounts.length,
          'snapshotCount': data.snapshots.length,
        },
      },
    };
  }

  @override
  Future<ImportSummary> importData(Map<String, dynamic> data) async {
    try {
      final financeData = data['data'] as Map<String, dynamic>;
      final imported = FinanceData.fromJson(financeData);
      await _storage.save(householdId, imported);
      return ImportSummary(
        success: true,
        itemCount: imported.accounts.length + imported.snapshots.length,
        message: '财务数据已覆盖（${imported.accounts.length} 个账户，${imported.snapshots.length} 条快照）',
      );
    } catch (e) {
      return ImportSummary(success: false, itemCount: 0, message: '导入财务数据失败: $e');
    }
  }
}
