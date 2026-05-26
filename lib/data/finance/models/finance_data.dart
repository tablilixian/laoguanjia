import 'finance_account.dart';
import 'finance_snapshot.dart';

/// 家庭财务数据容器
///
/// 对应一个 JSON 文件，包含该家庭的所有账户和快照数据。
class FinanceData {
  final int schemaVersion;
  DateTime updatedAt;
  final List<FinanceAccount> accounts;
  final List<FinanceSnapshot> snapshots;

  FinanceData({
    this.schemaVersion = 1,
    DateTime? updatedAt,
    List<FinanceAccount>? accounts,
    List<FinanceSnapshot>? snapshots,
  })  : updatedAt = updatedAt ?? DateTime.now(),
        accounts = accounts ?? [],
        snapshots = snapshots ?? [];

  /// 创建空数据（首次使用）
  factory FinanceData.empty() => FinanceData();

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'updatedAt': updatedAt.toIso8601String(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'snapshots': snapshots.map((s) => s.toJson()).toList(),
      };

  factory FinanceData.fromJson(Map<String, dynamic> json) => FinanceData(
        schemaVersion: json['schemaVersion'] as int? ?? 1,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        accounts: (json['accounts'] as List<dynamic>?)
                ?.map((e) =>
                    FinanceAccount.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        snapshots: (json['snapshots'] as List<dynamic>?)
                ?.map((e) =>
                    FinanceSnapshot.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
