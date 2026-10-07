enum BillType { expense, income }

extension BillTypeText on BillType {
  String get label => this == BillType.expense ? '支出' : '收入';

  String get databaseValue => name;

  static BillType fromDatabase(String value) {
    return value == BillType.income.name ? BillType.income : BillType.expense;
  }
}

class Bill {
  const Bill({
    this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.createdAt,
    this.remark = '',
  });

  final int? id;
  final double amount;
  final BillType type;
  final String category;
  final DateTime date;
  final DateTime? createdAt;
  final String remark;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type.databaseValue,
      'category': category,
      'date': _dateTime(date),
      'created_at': _dateTime(createdAt ?? date),
      'remark': remark,
    };
  }

  factory Bill.fromMap(Map<String, Object?> map) {
    return Bill(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      type: BillTypeText.fromDatabase(map['type'] as String),
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
      remark: (map['remark'] as String?) ?? '',
    );
  }

  static String _dateTime(DateTime value) {
    return value.toIso8601String().split('.').first;
  }
}
