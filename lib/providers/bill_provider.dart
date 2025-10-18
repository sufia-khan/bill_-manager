import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_hive.dart';
import '../services/hive_service.dart';
import '../services/firebase_service.dart';
import '../services/sync_service.dart';

class BillProvider with ChangeNotifier {
  List<BillHive> _bills = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<BillHive> get bills => _bills;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  // Initialize and load bills
  Future<void> initialize() async {
    // Prevent multiple initializations
    if (_isInitialized || _isLoading) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Load from local storage first
      _bills = HiveService.getAllBills();
      notifyListeners();

      // Sync with Firebase if user is authenticated
      if (FirebaseService.currentUserId != null) {
        await SyncService.initialSync();
        _bills = HiveService.getAllBills();
      }

      _error = null;
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
      print('Error initializing bills: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new bill
  Future<void> addBill({
    required String title,
    required String vendor,
    required double amount,
    required DateTime dueAt,
    String? notes,
    required String category,
    String repeat = 'monthly',
  }) async {
    try {
      final now = DateTime.now();
      final bill = BillHive(
        id: const Uuid().v4(),
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

      // Save to local storage
      await HiveService.saveBill(bill);

      // Update local list
      _bills = HiveService.getAllBills();
      notifyListeners();

      // Sync to Firebase in background
      if (FirebaseService.currentUserId != null) {
        SyncService.syncBills();
      }
    } catch (e) {
      _error = e.toString();
      print('Error adding bill: $e');
      rethrow;
    }
  }

  // Update bill
  Future<void> updateBill(BillHive bill) async {
    try {
      final updatedBill = bill.copyWith(
        updatedAt: DateTime.now(),
        clientUpdatedAt: DateTime.now(),
        needsSync: true,
      );

      await HiveService.saveBill(updatedBill);
      _bills = HiveService.getAllBills();
      notifyListeners();

      // Sync to Firebase in background
      if (FirebaseService.currentUserId != null) {
        SyncService.syncBills();
      }
    } catch (e) {
      _error = e.toString();
      print('Error updating bill: $e');
      rethrow;
    }
  }

  // Mark bill as paid
  Future<void> markBillAsPaid(String billId) async {
    try {
      final bill = HiveService.getBillById(billId);
      if (bill != null) {
        final updatedBill = bill.copyWith(
          isPaid: true,
          updatedAt: DateTime.now(),
          clientUpdatedAt: DateTime.now(),
          needsSync: true,
        );
        await HiveService.saveBill(updatedBill);
        _bills = HiveService.getAllBills();
        notifyListeners();

        // Sync to Firebase in background
        if (FirebaseService.currentUserId != null) {
          SyncService.syncBills();
        }
      }
    } catch (e) {
      _error = e.toString();
      print('Error marking bill as paid: $e');
      rethrow;
    }
  }

  // Delete bill
  Future<void> deleteBill(String billId) async {
    try {
      await HiveService.deleteBill(billId);
      _bills = HiveService.getAllBills();
      notifyListeners();

      // Sync to Firebase in background
      if (FirebaseService.currentUserId != null) {
        SyncService.syncBills();
      }
    } catch (e) {
      _error = e.toString();
      print('Error deleting bill: $e');
      rethrow;
    }
  }

  // Get bills by category
  List<BillHive> getBillsByCategory(String category) {
    if (category == 'All') {
      return _bills;
    }
    return _bills.where((bill) => bill.category == category).toList();
  }

  // Get upcoming bills
  List<BillHive> getUpcomingBills() {
    final now = DateTime.now();
    return _bills
        .where((bill) => !bill.isPaid && bill.dueAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  // Get overdue bills
  List<BillHive> getOverdueBills() {
    final now = DateTime.now();
    return _bills
        .where((bill) => !bill.isPaid && bill.dueAt.isBefore(now))
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  // Get paid bills
  List<BillHive> getPaidBills() {
    return _bills.where((bill) => bill.isPaid).toList()
      ..sort((a, b) => b.dueAt.compareTo(a.dueAt));
  }

  // Get total amount for this month
  double getThisMonthTotal() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return _bills
        .where(
          (bill) =>
              !bill.dueAt.isBefore(startOfMonth) &&
              !bill.dueAt.isAfter(endOfMonth),
        )
        .fold(0.0, (sum, bill) => sum + bill.amount);
  }

  // Get total amount for next 7 days
  double getNext7DaysTotal() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOf7Days = startOfToday.add(
      const Duration(days: 7, hours: 23, minutes: 59, seconds: 59),
    );

    return _bills
        .where(
          (bill) =>
              !bill.dueAt.isBefore(startOfToday) &&
              !bill.dueAt.isAfter(endOf7Days),
        )
        .fold(0.0, (sum, bill) => sum + bill.amount);
  }

  // Force sync with Firebase
  Future<void> forceSync() async {
    _isLoading = true;
    notifyListeners();

    try {
      await SyncService.forceSyncNow();
      _bills = HiveService.getAllBills();
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error syncing: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear all data (for logout)
  Future<void> clearAllData() async {
    await HiveService.clearAllData();
    _bills = [];
    _error = null;
    _isInitialized = false;
    notifyListeners();
  }
}
