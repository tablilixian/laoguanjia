/// 资产快照模型
///
/// 记录某个账户在某个时间点的资产/负债快照。
/// 通过比较两次快照的净资产变化，结合 activeIncome，
/// 可以拆解出主动收入、被动收入和支出。
class FinanceSnapshot {
  final String id;
  final String accountId;
  final DateTime recordDate;
  final double assetAmount;
  final double liabilityAmount;
  final double activeIncome; // 用户确认的主动收入，默认 0
  final String? notes;

  const FinanceSnapshot({
    required this.id,
    required this.accountId,
    required this.recordDate,
    required this.assetAmount,
    required this.liabilityAmount,
    this.activeIncome = 0,
    this.notes,
  });

  /// 净资产 = 资产 - 负债
  double get netWorth => assetAmount - liabilityAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'recordDate': recordDate.toIso8601String(),
        'assetAmount': assetAmount,
        'liabilityAmount': liabilityAmount,
        'activeIncome': activeIncome,
        'notes': notes,
      };

  factory FinanceSnapshot.fromJson(Map<String, dynamic> json) =>
      FinanceSnapshot(
        id: json['id'] as String,
        accountId: json['accountId'] as String,
        recordDate: DateTime.parse(json['recordDate'] as String),
        assetAmount: (json['assetAmount'] as num).toDouble(),
        liabilityAmount: (json['liabilityAmount'] as num).toDouble(),
        activeIncome: (json['activeIncome'] as num?)?.toDouble() ?? 0,
        notes: json['notes'] as String?,
      );
}
