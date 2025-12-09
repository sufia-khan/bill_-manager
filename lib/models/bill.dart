class Bill {
  final String id;
  final String title;
  final String vendor;
  final double amount;
  final String due;
  final DateTime dueAt; // Full datetime for precise sorting
  final String repeat;
  final String category;
  final String status;
  final DateTime? paidAt;

  Bill({
    required this.id,
    required this.title,
    required this.vendor,
    required this.amount,
    required this.due,
    required this.dueAt,
    required this.repeat,
    required this.category,
    required this.status,
    this.paidAt,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    final dueString = json['due'] as String;
    return Bill(
      id: json['id'],
      title: json['title'],
      vendor: json['vendor'],
      amount: (json['amount'] is String)
          ? double.parse(json['amount'])
          : (json['amount'] ?? 0.0).toDouble(),
      due: dueString,
      dueAt: json['dueAt'] != null
          ? DateTime.parse(json['dueAt'])
          : DateTime.parse('${dueString}T00:00:00'),
      repeat: json['repeat'],
      category: json['category'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'vendor': vendor,
      'amount': amount,
      'due': due,
      'repeat': repeat,
      'category': category,
      'status': status,
    };
  }

  Bill copyWith({
    String? id,
    String? title,
    String? vendor,
    double? amount,
    String? due,
    DateTime? dueAt,
    String? repeat,
    String? category,
    String? status,
    DateTime? paidAt,
  }) {
    return Bill(
      id: id ?? this.id,
      title: title ?? this.title,
      vendor: vendor ?? this.vendor,
      amount: amount ?? this.amount,
      due: due ?? this.due,
      dueAt: dueAt ?? this.dueAt,
      repeat: repeat ?? this.repeat,
      category: category ?? this.category,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
