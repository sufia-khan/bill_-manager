class Bill {
  final String id;
  final String title;
  final String vendor;
  final double amount;
  final String due;
  final String repeat;
  final String category;
  final String status;

  Bill({
    required this.id,
    required this.title,
    required this.vendor,
    required this.amount,
    required this.due,
    required this.repeat,
    required this.category,
    required this.status,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'],
      title: json['title'],
      vendor: json['vendor'],
      amount: (json['amount'] is String) ? double.parse(json['amount']) : (json['amount'] ?? 0.0).toDouble(),
      due: json['due'],
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
    String? repeat,
    String? category,
    String? status,
  }) {
    return Bill(
      id: id ?? this.id,
      title: title ?? this.title,
      vendor: vendor ?? this.vendor,
      amount: amount ?? this.amount,
      due: due ?? this.due,
      repeat: repeat ?? this.repeat,
      category: category ?? this.category,
      status: status ?? this.status,
    );
  }
}