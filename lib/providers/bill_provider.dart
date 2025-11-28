import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_hive.dart';
import '../services/hive_service.dart';
import '../services/firebase_service.dart';
import '../services/sync_service.dart';
// FirebaseSyncService removed - using SyncService instead for proper needsSync flag handling
import '../services/recurring_bill_service.dart';
import '../services/bill_archival_service.dart';
import '../services/notification_service.dart';
import '../services/notification_history_service.dart';
import '../providers/notification_settings_provider.dart';

class BillProvider with ChangeNotifier {
  List<BillHive> _bills = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  String? _initializedForUserId; // Track which user we initialized for
  NotificationSettingsProvider? _notificationSettings;

  List<BillHive> get bills => _bills;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  // Set notification settings provider
  void setNotificationSettings(NotificationSettingsProvider settings) {
    _notificationSettings = settings;
  }

  // Reset provider state (called when user changes/logs out)
  void reset() {
    _bills = [];
    _isLoading = false;
    _error = null;
    _isInitialized = false;
    _initializedForUserId = null;
    notifyListeners();
  }

  // Trigger sync after changes - uses SyncService which reads needsSync flag from Hive
  // Fire-and-forget: sync happens in background without blocking UI
  void _triggerSync() {
    // Use SyncService.syncBills() which properly reads bills with needsSync=true from Hive
    // FirebaseSyncService uses a different sync queue system that's not populated by HiveService
    SyncService.syncBills().catchError((e) {
      print('Background sync error: $e');
    });
  }

  // Initialize and load bills
  Future<void> initialize() async {
    final currentUserId = FirebaseService.currentUserId;

    // Check if we need to reinitialize for a different user
    final needsReinit =
        _initializedForUserId != null && _initializedForUserId != currentUserId;

    // Prevent multiple initializations for the same user
    if ((_isInitialized && !needsReinit) || _isLoading) {
      return;
    }

    // If user changed, reset state first
    if (needsReinit) {
      print('🔄 User changed, reinitializing BillProvider...');
      _bills = [];
      _isInitialized = false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Sync with Firebase if user is authenticated (this clears and reloads bills)
      if (currentUserId != null) {
        await SyncService.initialSync();
      }

      // Load from local storage after sync
      _bills = HiveService.getAllBills();
      notifyListeners();

      _error = null;
      _isInitialized = true;
      _initializedForUserId = currentUserId;

      // Run maintenance after a delay to avoid blocking UI
      // This ensures the UI is responsive during app startup
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          await runMaintenance();
          // Check for triggered notifications and add to history
          await NotificationHistoryService.checkAndAddTriggeredNotifications();
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
    String? reminderTiming,
    String? notificationTime,
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
        reminderTiming: reminderTiming,
        notificationTime: notificationTime,
        // Set recurringSequence to 1 for the first bill if it's recurring with a count
        recurringSequence: (repeat != 'none' && repeatCount != null) ? 1 : null,
      );

      // Save to local storage
      await HiveService.saveBill(bill);

      print('\n═══════════════════════════════════════════════════════');
      print('📝 BILL ADDED SUCCESSFULLY');
      print('═══════════════════════════════════════════════════════');
      print('Title: ${bill.title}');
      print('Amount: \$${bill.amount.toStringAsFixed(2)}');
      print('Due Date: ${bill.dueAt}');
      print('Category: ${bill.category}');
      print('Repeat: ${bill.repeat}');
      print(
        'Reminder Timing: ${bill.reminderTiming ?? "Using global settings"}',
      );
      print(
        'Notification Time: ${bill.notificationTime ?? "Using global settings"}',
      );
      print('═══════════════════════════════════════════════════════\n');

      // Schedule notification if enabled
      await _scheduleNotificationForBill(bill);

      // Show all pending notifications
      await _showPendingNotifications();

      // Update local list
      _bills = HiveService.getAllBills();
      notifyListeners();

      // Trigger debounced sync
      _triggerSync();
    } catch (e) {
      _error = e.toString();
      ('Error adding bill: $e');
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

      print('\n═══════════════════════════════════════════════════════');
      print('✏️  BILL UPDATED');
      print('═══════════════════════════════════════════════════════');
      print('Title: ${updatedBill.title}');
      print('Amount: \$${updatedBill.amount.toStringAsFixed(2)}');
      print('Due Date: ${updatedBill.dueAt}');
      print('Is Paid: ${updatedBill.isPaid}');
      print('═══════════════════════════════════════════════════════\n');

      // Reschedule notification if bill is not paid
      if (!updatedBill.isPaid) {
        await _scheduleNotificationForBill(updatedBill);
        await _showPendingNotifications();
      } else {
        // Cancel notification if bill is paid
        print('🔕 Cancelling notification for paid bill\n');
        await NotificationService().cancelBillNotification(updatedBill.id);
        await _showPendingNotifications();
      }

      _bills = HiveService.getAllBills();
      notifyListeners();

      // Trigger debounced sync
      _triggerSync();
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
        final isRecurring = bill.repeat != 'none';

        // Mark as paid but keep visible in paid tab (not archived)
        final updatedBill = bill.copyWith(
          isPaid: true,
          paidAt: now,
          isArchived: false, // Keep visible in paid tab
          archivedAt: null,
          updatedAt: now,
          clientUpdatedAt: now,
          needsSync: true,
        );
        await HiveService.saveBill(updatedBill);

        // Cancel notification for paid bill
        await NotificationService().cancelBillNotification(billId);

        // Run recurring maintenance immediately to create next instance
        if (isRecurring) {
          print('Creating next instance for recurring bill: ${bill.title}');
          await runRecurringBillMaintenance();
        }

        // Force refresh to get latest data after all operations
        _bills = HiveService.getAllBills(forceRefresh: true);
        notifyListeners();

        // Trigger debounced sync
        _triggerSync();
      }
    } catch (e) {
      _error = e.toString();
      print('Error marking bill as paid: $e');
      rethrow;
    }
  }

  // Undo bill payment
  Future<void> undoBillPayment(String billId) async {
    try {
      final bill = HiveService.getBillById(billId);
      if (bill != null && bill.isPaid) {
        final now = DateTime.now();

        // Mark as unpaid and restore to appropriate status
        final updatedBill = bill.copyWith(
          isPaid: false,
          paidAt: null,
          isArchived: false,
          archivedAt: null,
          updatedAt: now,
          clientUpdatedAt: now,
          needsSync: true,
        );
        await HiveService.saveBill(updatedBill);

        // Reschedule notification for unpaid bill
        await _scheduleNotificationForBill(updatedBill);

        // Force refresh to get latest data
        _bills = HiveService.getAllBills(forceRefresh: true);
        notifyListeners();

        // Trigger debounced sync
        _triggerSync();
      }
    } catch (e) {
      _error = e.toString();
      print('Error undoing bill payment: $e');
      rethrow;
    }
  }

  // Restore archived bill
  Future<void> restoreBill(String billId) async {
    try {
      final bill = HiveService.getBillById(billId);
      if (bill != null && bill.isArchived) {
        final now = DateTime.now();

        // Unarchive the bill - keep it as paid
        final updatedBill = bill.copyWith(
          isArchived: false,
          archivedAt: null,
          updatedAt: now,
          clientUpdatedAt: now,
          needsSync: true,
        );
        await HiveService.saveBill(updatedBill);

        // Force refresh to get latest data
        _bills = HiveService.getAllBills(forceRefresh: true);
        notifyListeners();

        // Trigger debounced sync
        _triggerSync();
      }
    } catch (e) {
      _error = e.toString();
      print('Error restoring bill: $e');
      rethrow;
    }
  }

  // Archive bill manually
  Future<void> archiveBill(String billId) async {
    try {
      final bill = HiveService.getBillById(billId);
      if (bill != null) {
        await BillArchivalService.archiveBill(bill);

        // Force refresh to get latest data
        _bills = HiveService.getAllBills(forceRefresh: true);
        notifyListeners();

        // Trigger debounced sync
        _triggerSync();
      }
    } catch (e) {
      _error = e.toString();
      print('Error archiving bill: $e');
      rethrow;
    }
  }

  // Delete bill with smart recurring logic:
  // - PAID/OVERDUE bill: Only delete that one bill (history record)
  // - UPCOMING bill: Delete this + all future unpaid bills in series
  Future<void> deleteBill(String billId) async {
    try {
      final bill = HiveService.getBillById(billId);

      // Safety check
      if (bill == null) {
        throw Exception('Bill not found');
      }

      final now = DateTime.now();
      final isPaidOrOverdue = bill.isPaid || bill.dueAt.isBefore(now);

      // If this is a PAID or OVERDUE bill, only delete this one
      // (It's just a history record, shouldn't affect future bills)
      if (isPaidOrOverdue) {
        print('🗑️ Deleting single paid/overdue bill: ${bill.title}');
        await NotificationService().cancelBillNotification(billId);
        await HiveService.deleteBill(billId);
      }
      // If this is an UPCOMING recurring bill, delete this + future unpaid bills
      else if (bill.repeat != 'none') {
        print(
          '🗑️ Deleting upcoming recurring bill + future instances: ${bill.title}',
        );

        // Find the parent ID
        final parentId = bill.parentBillId ?? bill.id;
        final currentSequence = bill.recurringSequence ?? 0;

        // Find all UPCOMING (not paid, not overdue) bills in this series
        final allBills = HiveService.getAllBillsIncludingDeleted();
        final billsToDelete = allBills.where((b) {
          final billParentId = b.parentBillId ?? b.id;
          final billSequence = b.recurringSequence ?? 0;
          final isInSeries = billParentId == parentId || b.id == parentId;
          final isFutureOrCurrent = billSequence >= currentSequence;
          final isUnpaid = !b.isPaid;
          final isNotOverdue = !b.dueAt.isBefore(now); // Keep overdue bills

          return isInSeries &&
              isFutureOrCurrent &&
              isUnpaid &&
              isNotOverdue &&
              !b.isDeleted;
        }).toList();

        print(
          '   Found ${billsToDelete.length} upcoming bills to delete (keeping paid & overdue)',
        );

        // Delete all unpaid future bills in the series
        for (final billToDelete in billsToDelete) {
          await NotificationService().cancelBillNotification(billToDelete.id);
          await HiveService.deleteBill(billToDelete.id);
        }
      } else {
        // Non-recurring upcoming bill - just delete this one
        await NotificationService().cancelBillNotification(billId);
        await HiveService.deleteBill(billId);
      }

      // Force refresh to update UI immediately
      _bills = HiveService.getAllBills(forceRefresh: true);
      notifyListeners();

      // Trigger debounced sync
      _triggerSync();
    } catch (e) {
      _error = e.toString();
      print('Error deleting bill: $e');
      rethrow;
    }
  }

  // Permanently delete archived bill (for past bills screen)
  Future<void> deleteArchivedBill(String billId) async {
    try {
      final bill = HiveService.getBillById(billId);

      if (bill == null) {
        throw Exception('Bill not found');
      }

      if (!bill.isArchived) {
        throw Exception(
          'Bill is not archived. Only archived bills can be permanently deleted.',
        );
      }

      // Cancel notification
      await NotificationService().cancelBillNotification(billId);

      // Permanently delete from Hive
      final box = HiveService.getBillsBox();
      await box.delete(billId);

      // Force refresh
      _bills = HiveService.getAllBills(forceRefresh: true);
      notifyListeners();

      // Trigger debounced sync
      _triggerSync();
    } catch (e) {
      _error = e.toString();
      print('Error deleting archived bill: $e');
      rethrow;
    }
  }

  // Undo delete bill
  Future<void> undoDelete(String billId) async {
    try {
      final box = HiveService.getBillsBox();
      final bill = box.get(billId);
      if (bill != null && bill.isDeleted) {
        final restoredBill = bill.copyWith(
          isDeleted: false,
          needsSync: true,
          updatedAt: DateTime.now(),
          clientUpdatedAt: DateTime.now(),
        );
        await box.put(billId, restoredBill);

        // Force refresh to get the restored bill immediately
        _bills = HiveService.getAllBills(forceRefresh: true);
        notifyListeners();

        // Reschedule notification
        await NotificationService().scheduleBillNotification(restoredBill);

        // Trigger debounced sync
        _triggerSync();
      }
    } catch (e) {
      _error = e.toString();
      print('Error undoing delete: $e');
      rethrow;
    }
  }

  // Schedule notification for a bill based on user settings
  Future<void> _scheduleNotificationForBill(BillHive bill) async {
    try {
      print('\n🔔 ATTEMPTING TO SCHEDULE NOTIFICATION');
      print('─────────────────────────────────────────────────────');

      // Skip if notifications are disabled globally
      if (_notificationSettings == null ||
          !_notificationSettings!.notificationsEnabled) {
        print('❌ Notifications are disabled globally');
        print('─────────────────────────────────────────────────────\n');
        return;
      }

      // Skip if bill is already paid or deleted
      if (bill.isPaid || bill.isDeleted) {
        print('❌ Bill is paid or deleted - skipping notification');
        print('─────────────────────────────────────────────────────\n');
        return;
      }

      final notificationService = NotificationService();

      // Use per-bill settings if available, otherwise use global settings
      int daysOffset;
      int notificationHour;
      int notificationMinute;

      if (bill.reminderTiming != null && bill.notificationTime != null) {
        // Use per-bill settings
        daysOffset = _getReminderDaysOffsetFromString(bill.reminderTiming!);
        final timeParts = bill.notificationTime!.split(':');
        notificationHour = int.parse(timeParts[0]);
        notificationMinute = int.parse(timeParts[1]);
        print('📋 Using per-bill notification settings');
      } else {
        // Use global settings
        daysOffset = _notificationSettings!.getReminderDaysOffset();
        final notificationTime = _notificationSettings!.notificationTime;
        notificationHour = notificationTime.hour;
        print('🌐 Using global notification settings');
        notificationMinute = notificationTime.minute;
      }

      print('Bill: ${bill.title}');
      print('Due Date: ${bill.dueAt}');
      print('Days Before Due: $daysOffset');
      print(
        'Notification Time: $notificationHour:${notificationMinute.toString().padLeft(2, '0')}',
      );

      final notificationDate = bill.dueAt.subtract(Duration(days: daysOffset));
      final calculatedNotificationDateTime = DateTime(
        notificationDate.year,
        notificationDate.month,
        notificationDate.day,
        notificationHour,
        notificationMinute,
      );

      print(
        'Calculated Notification Date: $notificationDate at $notificationHour:${notificationMinute.toString().padLeft(2, '0')}',
      );
      print('Full Notification DateTime: $calculatedNotificationDateTime');
      print('Current Time: ${DateTime.now()}');

      final now = DateTime.now();
      if (calculatedNotificationDateTime.isBefore(now)) {
        print(
          '⚠️⚠️⚠️ WARNING: Notification time is ${now.difference(calculatedNotificationDateTime).inMinutes} minutes in the PAST!',
        );
        print('⚠️ This notification will NOT be scheduled!');
        print(
          '⚠️ Solution: Set the time to at least 1-2 minutes in the future',
        );
      } else {
        print(
          '✅ Notification time is ${calculatedNotificationDateTime.difference(now).inMinutes} minutes in the FUTURE',
        );
        print('✅ This notification WILL be scheduled');
      }
      print('─────────────────────────────────────────────────────\n');

      await notificationService.scheduleBillNotification(
        bill,
        daysBeforeDue: daysOffset,
        notificationHour: notificationHour,
        notificationMinute: notificationMinute,
      );
    } catch (e) {
      print('❌ Error scheduling notification for bill: $e');
      print('─────────────────────────────────────────────────────\n');
      // Don't rethrow - notification failures shouldn't block bill operations
    }
  }

  // Show all pending notifications (for debugging)
  Future<void> _showPendingNotifications() async {
    try {
      final notificationService = NotificationService();
      final pending = await notificationService.getPendingNotifications();

      print('\n📋 PENDING NOTIFICATIONS LIST');
      print('═══════════════════════════════════════════════════════');
      if (pending.isEmpty) {
        print('⚠️  No notifications scheduled');
      } else {
        print('Total: ${pending.length} notification(s) scheduled\n');
        for (var i = 0; i < pending.length; i++) {
          final notification = pending[i];
          print('${i + 1}. ID: ${notification.id}');
          print('   Title: ${notification.title}');
          print('   Body: ${notification.body}');
          print('   Payload: ${notification.payload}');
          print('');
        }
      }
      print('═══════════════════════════════════════════════════════\n');
    } catch (e) {
      print('❌ Error fetching pending notifications: $e\n');
    }
  }

  // Helper method to convert reminder timing string to days offset
  int _getReminderDaysOffsetFromString(String timing) {
    switch (timing) {
      case '1 Day Before':
        return 1;
      case '2 Days Before':
        return 2;
      case '1 Week Before':
        return 7;
      case 'Same Day':
      default:
        return 0;
    }
  }

  // Reschedule all notifications (useful when settings change)
  Future<void> rescheduleAllNotifications() async {
    try {
      if (_notificationSettings == null) return;

      if (!_notificationSettings!.notificationsEnabled) {
        // Cancel all notifications if disabled
        await NotificationService().cancelAllNotifications();
        return;
      }

      // Reschedule for all unpaid bills
      for (final bill in _bills) {
        if (!bill.isPaid && !bill.isDeleted) {
          await _scheduleNotificationForBill(bill);
        }
      }
    } catch (e) {
      print('Error rescheduling notifications: $e');
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

  // Get paid bills (excluding archived)
  List<BillHive> getPaidBills() {
    return _bills.where((bill) => bill.isPaid && !bill.isArchived).toList()
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
      print(
        'Recurring maintenance complete. Created $createdCount new instances.',
      );

      if (createdCount > 0) {
        // Reload bills if new instances were created
        _bills = HiveService.getAllBills(forceRefresh: true);
        print('Bills reloaded. Total bills: ${_bills.length}');
        notifyListeners();

        // Trigger debounced sync
        _triggerSync();
      }
    } catch (e) {
      print('Error running recurring bill maintenance: $e');
      // Don't rethrow - maintenance failures shouldn't block other operations
    }
  }

  // Run archival maintenance
  // Processes all paid bills and archives those eligible (30+ days after payment)
  // Also auto-deletes archived bills older than 90 days
  Future<void> runArchivalMaintenance() async {
    try {
      print('Running archival maintenance...');
      final archivedCount = await BillArchivalService.processArchival();

      // Auto-delete old archived bills (90+ days)
      final deletedCount = await BillArchivalService.processAutoDeletion();

      if (archivedCount > 0 || deletedCount > 0) {
        // Reload bills if any were archived or deleted
        _bills = HiveService.getAllBills();
        notifyListeners();

        // Trigger debounced sync
        _triggerSync();

        print(
          'Archived $archivedCount bills, auto-deleted $deletedCount old bills',
        );
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

        // For imported past bills, check if 2 days have passed since payment
        final daysSincePayment = now.difference(paymentDate).inDays;
        final shouldArchive = daysSincePayment >= 2;

        // Create bill with appropriate archived status
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
          isArchived: shouldArchive, // Archive only if 2+ days have passed
          archivedAt: shouldArchive
              ? now
              : null, // Set archival timestamp only if archived
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

      // Trigger debounced sync
      _triggerSync();

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
        // Trigger debounced sync
        _triggerSync();
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

      // Debug: Print bill statistics before processing
      HiveService.printBillStats();

      // Purge soft-deleted bills to prevent any stale data issues
      await HiveService.purgeDeletedBills();

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
