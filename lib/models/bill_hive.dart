import 'package:hive/hive.dart';

part 'bill_hive.g.dart';

@HiveType(typeId: 0)
class BillHive extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String vendor;

  @HiveField(3)
  double amount;

  @HiveField(4)
  DateTime dueAt;

  @HiveField(5)
  String? notes;

  @HiveField(6)
  String category;

  @HiveField(7)
  bool isPaid;

  @HiveField(8)
  bool isDeleted;

  @HiveField(9)
  DateTime updatedAt;

  @HiveField(10)
  DateTime clientUpdatedAt;

  @HiveField(11)
  String repeat; // 'none', 'daily', 'weekly', 'monthly', 'yearly'

  @HiveField(12)
  bool needsSync;

  @HiveField(13)
  DateTime? paidAt; // Timestamp when bill was marked as paid

  @HiveField(14)
  bool isArchived; // Flag indicating if bill is in Past Bills

  @HiveField(15)
  DateTime? archivedAt; // Timestamp when bill was archived

  @HiveField(16)
  String? parentBillId; // Links to original recurring bill

  @HiveField(17)
  int? recurringSequence; // Sequence number for recurring instances

  @HiveField(18)
  int? repeatCount; // How many times to repeat (null = unlimited)

  BillHive({
    required this.id,
    required this.title,
    required this.vendor,
    required this.amount,
    required this.dueAt,
    this.notes,
    required this.category,
    this.isPaid = false,
    this.isDeleted = false,
    required this.updatedAt,
    required this.clientUpdatedAt,
    this.repeat = 'monthly',
    this.needsSync = true,
    this.paidAt,
    this.isArchived = false,
    this.archivedAt,
    this.parentBillId,
    this.recurringSequence,
    this.repeatCount,
  });

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'vendor': vendor,
      'amount': amount,
      'dueAt': dueAt.toIso8601String(),
      'notes': notes,
      'category': category,
      'isPaid': isPaid,
      'isDeleted': isDeleted,
      'updatedAt': updatedAt.toIso8601String(),
      'clientUpdatedAt': clientUpdatedAt.toIso8601String(),
      'repeat': repeat,
      'paidAt': paidAt?.toIso8601String(),
      'isArchived': isArchived,
      'archivedAt': archivedAt?.toIso8601String(),
      'parentBillId': parentBillId,
      'recurringSequence': recurringSequence,
      'repeatCount': repeatCount,
    };
  }

  // Create from Firestore
  factory BillHive.fromFirestore(Map<String, dynamic> data) {
    return BillHive(
      id: data['id'] as String,
      title: data['title'] as String,
      vendor: data['vendor'] as String,
      amount: (data['amount'] as num).toDouble(),
      dueAt: DateTime.parse(data['dueAt'] as String),
      notes: data['notes'] as String?,
      category: data['category'] as String,
      isPaid: data['isPaid'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      updatedAt: DateTime.parse(data['updatedAt'] as String),
      clientUpdatedAt: DateTime.parse(data['clientUpdatedAt'] as String),
      repeat: data['repeat'] as String? ?? 'monthly',
      needsSync: false,
      paidAt: data['paidAt'] != null
          ? DateTime.parse(data['paidAt'] as String)
          : null,
      isArchived: data['isArchived'] as bool? ?? false,
      archivedAt: data['archivedAt'] != null
          ? DateTime.parse(data['archivedAt'] as String)
          : null,
      parentBillId: data['parentBillId'] as String?,
      recurringSequence: data['recurringSequence'] as int?,
      repeatCount: data['repeatCount'] as int?,
    );
  }

  // Convert to legacy Bill model for UI compatibility
  Map<String, dynamic> toLegacyBill() {
    return {
      'id': id,
      'title': title,
      'vendor': vendor,
      'amount': amount,
      'due': dueAt.toIso8601String().split('T')[0],
      'repeat': repeat,
      'category': category,
      'status': isPaid
          ? 'paid'
          : (dueAt.isBefore(DateTime.now()) ? 'overdue' : 'upcoming'),
    };
  }

  BillHive copyWith({
    String? id,
    String? title,
    String? vendor,
    double? amount,
    DateTime? dueAt,
    String? notes,
    String? category,
    bool? isPaid,
    bool? isDeleted,
    DateTime? updatedAt,
    DateTime? clientUpdatedAt,
    String? repeat,
    bool? needsSync,
    DateTime? paidAt,
    bool? isArchived,
    DateTime? archivedAt,
    String? parentBillId,
    int? recurringSequence,
    int? repeatCount,
  }) {
    return BillHive(
      id: id ?? this.id,
      title: title ?? this.title,
      vendor: vendor ?? this.vendor,
      amount: amount ?? this.amount,
      dueAt: dueAt ?? this.dueAt,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      isPaid: isPaid ?? this.isPaid,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      repeat: repeat ?? this.repeat,
      needsSync: needsSync ?? this.needsSync,
      paidAt: paidAt ?? this.paidAt,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      parentBillId: parentBillId ?? this.parentBillId,
      recurringSequence: recurringSequence ?? this.recurringSequence,
      repeatCount: repeatCount ?? this.repeatCount,
    );
  }
}
