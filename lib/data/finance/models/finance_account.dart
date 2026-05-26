/// 账户类型
enum AccountType {
  debitCard('储蓄卡', 'debit_card'),
  creditCard('信用卡', 'credit_card'),
  alipay('支付宝', 'alipay'),
  wechat('微信', 'wechat'),
  cash('现金', 'cash'),
  investment('理财/基金', 'investment'),
  loan('贷款', 'loan'),
  other('其他', 'other');

  final String label;
  final String dbValue;
  const AccountType(this.label, this.dbValue);

  static AccountType fromString(String value) {
    return AccountType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => AccountType.other,
    );
  }

  static AccountType fromLabel(String label) {
    return AccountType.values.firstWhere(
      (e) => e.label == label,
      orElse: () => AccountType.other,
    );
  }
}

/// 财务账户/渠道模型
class FinanceAccount {
  final String id;
  final String memberId;
  final String name;
  final AccountType type;
  final int sortOrder;

  const FinanceAccount({
    required this.id,
    required this.memberId,
    required this.name,
    required this.type,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'name': name,
        'type': type.dbValue,
        'sortOrder': sortOrder,
      };

  factory FinanceAccount.fromJson(Map<String, dynamic> json) => FinanceAccount(
        id: json['id'] as String,
        memberId: json['memberId'] as String,
        name: json['name'] as String,
        type: AccountType.fromString(json['type'] as String),
        sortOrder: json['sortOrder'] as int? ?? 0,
      );

  FinanceAccount copyWith({
    String? memberId,
    String? name,
    AccountType? type,
    int? sortOrder,
  }) {
    return FinanceAccount(
      id: id,
      memberId: memberId ?? this.memberId,
      name: name ?? this.name,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
