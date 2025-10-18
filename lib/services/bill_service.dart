import 'package:uuid/uuid.dart';
import '../models/bill_hive.dart';
import 'local_database_service.dart';
import 'firebase_sync_service.dart';
import 'notification_service.dart';

class BillService {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final FirebaseSyncService _syncService = FirebaseSyncService();
  final NotificationService _notificationService = NotificationService();
  final Uuid _uuid = const Uuid();

  // Singleton pattern
  static final BillService _instance = BillService._internal();
  factory BillService() => _instance;
  BillService._internal();

  // Create a new bill
  Future<BillHive> createBill({
    required String title,
    required String vendor,
    required double amount,
    required DateTime dueAt,
    String? notes,
    required String category,
    String repeat = 'monthly',
  }) async {
    final now = DateTime.now();
    final bill = BillHive(
      id: _uuid.v4(),
      title: title,
      vendor: vendor,
      amount: amount,
      dueAt: dueAt,
      notes: notes,
      category: category,
      isPaid: false,
      isDeleted: false,
      updatedAt: now,
      clientUpdatedAt: now,
      repeat: repeat,
      needsSync: true,
    );

    await _localDb.saveBill(bill);
    await _notificationService.scheduleBillNotification(bill);
    _syncService.triggerSync();

    return bill;
  }

  // Update an existing bill
  Future<void> updateBill(BillHive bill) async {
    await _localDb.saveBill(bill);

    // Update notification
    if (bill.isDeleted || bill.isPaid) {
      await _notificationService.cancelBillNotification(bill.id);
    } else {
      await _notificationService.scheduleBillNotification(bill);
    }

    _syncService.triggerSync();
  }

  // Mark bill as paid
  Future<void> markBillAsPaid(String billId) async {
    final bill = _localDb.getBill(billId);
    if (bill != null) {
      final updatedBill = bill.copyWith(
        isPaid: true,
        updatedAt: DateTime.now(),
        clientUpdatedAt: DateTime.now(),
        needsSync: true,
      );
      await _localDb.saveBill(updatedBill);
      await _notificationService.cancelBillNotification(billId);
      _syncService.triggerSync();
    }
  }

  // Delete a bill (soft delete)
  Future<void> deleteBill(String billId) async {
    await _localDb.deleteBill(billId);
    await _notificationService.cancelBillNotification(billId);
    _syncService.triggerSync();
  }

  // Get all bills
  List<BillHive> getAllBills() {
    return _localDb.getAllBills();
  }

  // Get bills by category
  List<BillHive> getBillsByCategory(String category) {
    return _localDb.getBillsByCategory(category);
  }

  // Get upcoming bills
  List<BillHive> getUpcomingBills() {
    return _localDb.getUpcomingBills();
  }

  // Get overdue bills
  List<BillHive> getOverdueBills() {
    return _localDb.getOverdueBills();
  }

  // Get bills for this month
  List<BillHive> getThisMonthBills() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return _localDb
        .getAllBills()
        .where(
          (bill) =>
              bill.dueAt.isAfter(startOfMonth) &&
              bill.dueAt.isBefore(endOfMonth.add(const Duration(days: 1))),
        )
        .toList();
  }

  // Get bills due in next 7 days
  List<BillHive> getNext7DaysBills() {
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 7));

    return _localDb
        .getAllBills()
        .where(
          (bill) => bill.dueAt.isAfter(now) && bill.dueAt.isBefore(endDate),
        )
        .toList();
  }

  // Calculate total amount for bills
  double calculateTotal(List<BillHive> bills) {
    return bills.fold(0.0, (sum, bill) => sum + bill.amount);
  }

  // Reschedule all notifications (useful after app restart)
  Future<void> rescheduleAllNotifications() async {
    final bills = _localDb.getAllBills();
    for (final bill in bills) {
      if (!bill.isPaid && !bill.isDeleted) {
        await _notificationService.scheduleBillNotification(bill);
      }
    }
  }
}
