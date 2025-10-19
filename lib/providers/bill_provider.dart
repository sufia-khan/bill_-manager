import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_hive.dart';
import '../services/hive_service.dart';
import '../services/firebase_service.dart';
import '../services/sync_service.dart';
import '../services/recurring_bill_service.dart';
import '../services/bill_archival_service.dart';

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

      // Run maintenance after a delay to avoid blocking UI
      // This ensures the UI is responsive during app startup
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          await runMaintenance();
        } catch (e) {
          print('Error running maintenance on initialization: $e');
          // Don't rethrow - maintenance failures shouldn't affect app initialization
        }
      });
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
    int? repeatCount, // null = unlimited
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
        repeatCount: repeatCount,
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
        final now = DateTime.now();
        // Mark as paid AND archive immediately
        final updatedBill = bill.copyWith(
          isPaid: true,
          paidAt: now,
          isArchived: true, // Archive immediately
          archivedAt: now,
          updatedAt: now,
          clientUpdatedAt: now,
          needsSync: true,
        );
        await HiveService.saveBill(updatedBill);

        // Force refresh to get latest data
        _bills = HiveService.getAllBills(forceRefresh: true);
        notifyListeners();

        // DON'T run recurring maintenance immediately - let it run on next app startup
        // This prevents creating a new instance right after marking as paid
        // The user will see the bill disappear cleanly

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

  // Run recurring bill maintenance
  // Processes all recurring bills and creates next instances if needed
  Future<void> runRecurringBillMaintenance() async {
    try {
      print('Running recurring bill maintenance...');
      final createdCount = await RecurringBillService.processRecurringBills();

      if (createdCount > 0) {
        // Reload bills if new instances were created
        _bills = HiveService.getAllBills();
        notifyListeners();

        // Sync new bills to Firebase
        if (FirebaseService.currentUserId != null) {
          SyncService.syncBills();
        }
      }
    } catch (e) {
      print('Error running recurring bill maintenance: $e');
      // Don't rethrow - maintenance failures shouldn't block other operations
    }
  }

  // Run archival maintenance
  // Processes all paid bills and archives those eligible (30+ days after payment)
  Future<void> runArchivalMaintenance() async {
    try {
      print('Running archival maintenance...');
      final archivedCount = await BillArchivalService.processArchival();

      if (archivedCount > 0) {
        // Reload bills if any were archived
        _bills = HiveService.getAllBills();
        notifyListeners();

        // Sync archived bills to Firebase
        if (FirebaseService.currentUserId != null) {
          SyncService.syncBills();
        }

        print('Archived $archivedCount bills');
      }
    } catch (e) {
      print('Error running archival maintenance: $e');
      // Don't rethrow - maintenance failures shouldn't block other operations
    }
  }

  // Get archived bills with optional filtering
  List<BillHive> getArchivedBills({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    return BillArchivalService.getArchivedBills(
      startDate: startDate,
      endDate: endDate,
      category: category,
    );
  }

  // Get paginated archived bills for lazy loading (optimized)
  List<BillHive> getArchivedBillsPaginated({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    int page = 0,
    int pageSize = 50,
  }) {
    return HiveService.getArchivedBillsPaginated(
      startDate: startDate,
      endDate: endDate,
      category: category,
      page: page,
      pageSize: pageSize,
    );
  }

  // Get count of archived bills (for pagination)
  int getArchivedBillsCount({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    return HiveService.getArchivedBillsCount(
      startDate: startDate,
      endDate: endDate,
      category: category,
    );
  }

  // Note: Near archival warnings removed - bills now archive immediately when paid

  /// Import past bills
  /// Validates bill data, checks dates are within 1 year past,
  /// sets bills as paid and archived, and saves to Hive
  Future<void> importPastBills(List<Map<String, dynamic>> billsData) async {
    try {
      final now = DateTime.now();
      final oneYearAgo = now.subtract(const Duration(days: 365));
      final importedBills = <BillHive>[];

      for (final billData in billsData) {
        // Validate required fields
        if (billData['title'] == null ||
            billData['vendor'] == null ||
            billData['amount'] == null ||
            billData['dueDate'] == null ||
            billData['paymentDate'] == null ||
            billData['category'] == null) {
          throw Exception('Missing required fields in bill data');
        }

        final dueDate = billData['dueDate'] as DateTime;
        final paymentDate = billData['paymentDate'] as DateTime;

        // Validate dates are within 1 year past
        if (dueDate.isBefore(oneYearAgo)) {
          throw Exception(
            'Due date for "${billData['title']}" is more than 1 year in the past',
          );
        }

        if (paymentDate.isBefore(oneYearAgo)) {
          throw Exception(
            'Payment date for "${billData['title']}" is more than 1 year in the past',
          );
        }

        // Validate amount is positive
        final amount = billData['amount'] as double;
        if (amount <= 0) {
          throw Exception(
            'Amount for "${billData['title']}" must be greater than 0',
          );
        }

        // Create bill with archived status
        final bill = BillHive(
          id: const Uuid().v4(),
          title: billData['title'] as String,
          vendor: billData['vendor'] as String,
          amount: amount,
          dueAt: dueDate,
          notes: billData['notes'] as String?,
          category: billData['category'] as String,
          isPaid: true, // Mark as paid
          isDeleted: false,
          updatedAt: now,
          clientUpdatedAt: now,
          repeat: 'none', // Past bills don't repeat
          needsSync: true,
          paidAt: paymentDate, // Set payment date
          isArchived: true, // Mark as archived
          archivedAt: now, // Set archival timestamp
          parentBillId: null,
          recurringSequence: null,
        );

        importedBills.add(bill);
      }

      // Save all bills to Hive
      for (final bill in importedBills) {
        await HiveService.saveBill(bill);
      }

      // Update local list
      _bills = HiveService.getAllBills();
      notifyListeners();

      // Sync to Firebase in background
      if (FirebaseService.currentUserId != null) {
        SyncService.syncBills();
      }

      print('Successfully imported ${importedBills.length} past bills');
    } catch (e) {
      print('Error importing past bills: $e');
      rethrow;
    }
  }

  /// Run complete maintenance process
  /// Processes recurring bills and archival in background isolate for performance
  /// Returns a map with counts of bills created and archived
  Future<Map<String, int>> runMaintenance() async {
    try {
      print('Starting maintenance runner...');
      final startTime = DateTime.now();

      // Run maintenance in background isolate for better performance
      // Note: For Flutter apps, we use compute() which handles isolate creation
      final results = await compute(_runMaintenanceInIsolate, null);

      final duration = DateTime.now().difference(startTime);
      print(
        'Maintenance complete in ${duration.inMilliseconds}ms: '
        '${results['billsCreated']} bills created, '
        '${results['billsArchived']} bills archived',
      );

      // Reload bills if any changes were made
      if (results['billsCreated']! > 0 || results['billsArchived']! > 0) {
        _bills = HiveService.getAllBills();
        notifyListeners();

        // Sync changes to Firebase
        if (FirebaseService.currentUserId != null) {
          SyncService.syncBills();
        }
      }

      return results;
    } catch (e) {
      print('Error running maintenance: $e');
      // Return zero counts on error
      return {'billsCreated': 0, 'billsArchived': 0};
    }
  }

  /// Static method to run maintenance in isolate
  /// This method is called by compute() and runs in a separate isolate
  static Future<Map<String, int>> _runMaintenanceInIsolate(void _) async {
    try {
      // Initialize Hive in the isolate
      await HiveService.init();

      // Process recurring bills
      final billsCreated = await RecurringBillService.processRecurringBills();

      // Process archival
      final billsArchived = await BillArchivalService.processArchival();

      return {'billsCreated': billsCreated, 'billsArchived': billsArchived};
    } catch (e) {
      print('Error in maintenance isolate: $e');
      return {'billsCreated': 0, 'billsArchived': 0};
    }
  }
}
