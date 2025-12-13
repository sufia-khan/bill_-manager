import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill_hive.dart';
import '../services/hive_service.dart';
import '../services/firebase_service.dart';
import '../services/sync_service.dart';
// FirebaseSyncService removed - using SyncService instead for proper needsSync flag handling
import '../services/recurring_bill_service.dart';
import '../services/bill_archival_service.dart';
import '../services/notification_service.dart';
import '../services/notification_history_service.dart';
import '../services/trial_service.dart';
import '../services/device_id_service.dart';
import '../models/bill.dart';
import '../utils/bill_status_helper.dart';
import '../providers/notification_settings_provider.dart';

class BillProvider with ChangeNotifier {
  List<BillHive> _bills = [];

  // Helper to load bills safely filtered by current user
  // CRITICAL: Uses HiveService.getBillsForUser for proper data isolation
  List<BillHive> _loadCurrentUsersBills({bool forceRefresh = false}) {
    final currentUserId = FirebaseService.currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      print(
        '⚠️ _loadCurrentUsersBills: No current user - returning empty list',
      );
      return [];
    }

    // Use the user-filtered method to ensure data isolation
    return HiveService.getBillsForUser(
      currentUserId,
      forceRefresh: forceRefresh,
    );
  }

  // Cached pre-processed lists for UI optimization
  List<Bill> _allProcessedBills = [];
  List<Bill> _upcomingBills = [];
  List<Bill> _overdueBills = [];
  List<Bill> _paidBills = [];

  // Cached totals
  double _totalUpcomingThisMonth = 0;
  double _totalUpcomingNext7Days = 0;
  int _countUpcomingThisMonth = 0;
  int _countUpcomingNext7Days = 0;

  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  String? _initializedForUserId; // Track which user we initialized for
  NotificationSettingsProvider? _notificationSettings;
  Timer? _statusRefreshTimer;

  List<BillHive> get bills => _bills;

  // Getters for cached UI data
  List<Bill> get allProcessedBills => _allProcessedBills;
  List<Bill> get upcomingBills => _upcomingBills;
  List<Bill> get overdueBills => _overdueBills;
  List<Bill> get paidBills => _paidBills;

  double get totalUpcomingThisMonth => _totalUpcomingThisMonth;
  double get totalUpcomingNext7Days => _totalUpcomingNext7Days;
  int get countUpcomingThisMonth => _countUpcomingThisMonth;
  int get countUpcomingNext7Days => _countUpcomingNext7Days;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  // Real-time Firestore Streams for Tabs (Requirement 1)
  Stream<List<Bill>> getUpcomingBillsStream() {
    final userId = FirebaseService.currentUserId;
    if (userId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('bills')
        .where('status', isEqualTo: 'upcoming')
        .orderBy('dueAt')
        .snapshots()
        .map((snapshot) => _mapSnapshotToBills(snapshot));
  }

  Stream<List<Bill>> getOverdueBillsStream() {
    final userId = FirebaseService.currentUserId;
    if (userId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('bills')
        .where('status', isEqualTo: 'overdue')
        .orderBy(
          'dueAt',
        ) // Sorting might be implicitly asc, but list logic usually handles or we can reverse
        .snapshots()
        .map((snapshot) => _mapSnapshotToBills(snapshot));
  }

  Stream<List<Bill>> getPaidBillsStream() {
    final userId = FirebaseService.currentUserId;
    if (userId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('bills')
        .where('status', isEqualTo: 'paid')
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((snapshot) => _mapSnapshotToBills(snapshot));
  }

  List<Bill> _mapSnapshotToBills(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Ensure ID is set from doc ID if missing
      data['id'] = doc.id;
      // Convert to BillHive then to Legacy Bill
      // We use BillHive.fromFirestore to parsing logic
      final billHive = BillHive.fromFirestore(data);
      final legacy = billHive.toLegacyBill();

      // Explicitly construct Bill object to ensure types
      return Bill(
        id: legacy['id'],
        title: legacy['title'],
        vendor: legacy['vendor'],
        amount: legacy['amount'],
        due: legacy['due'],
        dueAt: billHive.dueAt,
        repeat: legacy['repeat'],
        category: legacy['category'],
        status: legacy['status'],
        paidAt: billHive.paidAt,
      );
    }).toList();
  }

  // Set notification settings provider
  void setNotificationSettings(NotificationSettingsProvider settings) {
    _notificationSettings = settings;
  }

  // Reset provider state (called when user changes/logs out)
  // CRITICAL: Must clear ALL cached state to prevent data leaks between accounts
  void reset() {
    print('🔄 BillProvider.reset() - Clearing all cached state');
    _bills = [];
    _allProcessedBills = [];
    _upcomingBills = [];
    _overdueBills = [];
    _paidBills = [];
    _totalUpcomingThisMonth = 0;
    _totalUpcomingNext7Days = 0;
    _countUpcomingThisMonth = 0;
    _countUpcomingNext7Days = 0;
    _isLoading = false;
    _error = null;
    _isInitialized = false;
    _initializedForUserId = null;
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = null;

    // CRITICAL: Clear local bill tracking on logout
    // This ensures no notifications fire after logout
    HiveService.clearLocalBillTracking();

    // Stop sync service and Firestore listener
    SyncService.stop();

    notifyListeners();
  }

  // Refresh UI (called when external state changes like TrialService.testMode)
  void refreshUI() {
    _processBills(); // Re-process in case time/status changed (though usually time dependent)
    notifyListeners();
  }

  // Optimize UI performance by pre-processing bills in the provider
  // reducing work on the UI thread during build
  void _processBills() {
    final now = DateTime.now();

    // 1. Filter out archived and deleted bills from Hive source
    final activeBillsHive = _bills
        .where((billHive) => !billHive.isArchived && !billHive.isDeleted)
        .toList();

    // 2. Remove true duplicates: same title + same sequence number
    final Map<String, BillHive> uniqueBills = {};
    for (var billHive in activeBillsHive) {
      final seq = billHive.recurringSequence ?? 0;
      final key = '${billHive.title}_seq_$seq';

      if (uniqueBills.containsKey(key)) {
        final existing = uniqueBills[key]!;
        if (billHive.dueAt.isAfter(existing.dueAt)) {
          uniqueBills[key] = billHive;
        }
      } else {
        uniqueBills[key] = billHive;
      }
    }

    // 3. Convert to Bill format (Legacy UI Model)
    _allProcessedBills = uniqueBills.values.map((billHive) {
      final dueString = billHive.dueAt.toIso8601String().split('T')[0];
      return Bill(
        id: billHive.id,
        title: billHive.title,
        vendor: billHive.vendor,
        amount: billHive.amount,
        due: dueString,
        dueAt: billHive.dueAt,
        repeat: billHive.repeat,
        category: billHive.category,
        status: BillStatusHelper.calculateStatus(billHive),
        paidAt: billHive.paidAt,
      );
    }).toList();

    // 4. Split into category lists
    _upcomingBills = _allProcessedBills
        .where((b) => b.status == 'upcoming')
        .toList();
    _overdueBills = _allProcessedBills
        .where((b) => b.status == 'overdue')
        .toList();
    _paidBills = _allProcessedBills.where((b) => b.status == 'paid').toList();

    // 5. Sort lists
    // Upcoming: Ascending
    _upcomingBills.sort((a, b) {
      final dateCompare = a.dueAt.compareTo(b.dueAt);
      if (dateCompare != 0) return dateCompare;
      return a.title.compareTo(b.title);
    });

    // Overdue: Descending
    _overdueBills.sort((a, b) {
      final dateCompare = b.dueAt.compareTo(a.dueAt);
      if (dateCompare != 0) return dateCompare;
      return a.title.compareTo(b.title);
    });

    // Paid: Descending
    _paidBills.sort((a, b) {
      final dateA = a.paidAt ?? a.dueAt;
      final dateB = b.paidAt ?? b.dueAt;
      final dateCompare = dateB.compareTo(dateA);
      if (dateCompare != 0) return dateCompare;
      return a.title.compareTo(b.title);
    });

    // 6. Calculate Totals for Dashboard
    // Reuse 'now'
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOf7Days = startOfToday.add(
      const Duration(days: 7, hours: 23, minutes: 59, seconds: 59),
    );

    // Filter UPCOMING bills that fall into ranges
    // Note: We use _upcomingBills source which already filters by status='upcoming'
    final thisMonthBills = _upcomingBills.where((bill) {
      final dueDate = DateTime.parse('${bill.due}T00:00:00');
      return !dueDate.isBefore(startOfMonth) && !dueDate.isAfter(endOfMonth);
    }).toList();

    _countUpcomingThisMonth = thisMonthBills.length;
    _totalUpcomingThisMonth = thisMonthBills.fold(
      0.0,
      (sum, bill) => sum + bill.amount,
    );

    final next7DaysBills = _upcomingBills.where((bill) {
      final dueDate = DateTime.parse('${bill.due}T00:00:00');
      return !dueDate.isBefore(startOfToday) && !dueDate.isAfter(endOf7Days);
    }).toList();

    _countUpcomingNext7Days = next7DaysBills.length;
    _totalUpcomingNext7Days = next7DaysBills.fold(
      0.0,
      (sum, bill) => sum + bill.amount,
    );

    // Schedule automatic refresh for when next bill becomes overdue
    _scheduleStatusRefresh();
  }

  // Schedule a timer to refresh the UI when the next upcoming bill becomes overdue
  // This ensures the bill moves to the Overdue tab exactly when the notification time is reached
  void _scheduleStatusRefresh() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = null;

    if (_upcomingBills.isEmpty) return;

    DateTime? nextRefreshTime;
    final now = DateTime.now();

    for (final bill in _upcomingBills) {
      // Find the BillHive object corresponding to this Bill to get the overdue time
      // (Bill model is a simplified UI model, we need the raw data for calculation)
      // Since _allProcessedBills contains simplified objects, we might need to look up or recalculate
      // Actually, BillStatusHelper can accept BillHive.
      // Optimization: We can reconstruct the overdue time from the Bill object fields if possible,
      // or look up the original from _bills.
      // Lookup is safer:
      try {
        final originalBill = _bills.firstWhere((b) => b.id == bill.id);
        final overdueTime = BillStatusHelper.getOverdueTime(originalBill);

        // We only care about times in the future (transitions from upcoming -> overdue)
        if (overdueTime.isAfter(now)) {
          if (nextRefreshTime == null ||
              overdueTime.isBefore(nextRefreshTime)) {
            nextRefreshTime = overdueTime;
          }
        }
      } catch (e) {
        // Skip if bill not found (shouldn't happen)
      }
    }

    if (nextRefreshTime != null) {
      final duration = nextRefreshTime.difference(now);
      // Add a small buffer (1 second) to ensure we are definitely past the time when we refresh
      final buffer = const Duration(seconds: 1);

      _statusRefreshTimer = Timer(duration + buffer, () async {
        print(
          '⏰ Status refresh timer fired! Updating UI to reflect new overdue status...',
        );
        refreshUI();

        // Also check if we need to generate next recurring instance immediately
        print(
          '⏰ Checking for overdue recurring bills to generate next instances...',
        );
        await checkOverdueRecurringBills();
      });

      // Only log if the wait is reasonable (less than 24 hours) to avoid log spam
      if (duration.inHours < 24) {
        print(
          '⏰ Scheduled UI refresh in ${duration.inSeconds} seconds (at $nextRefreshTime)',
        );
      }
    }
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    super.dispose();
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
    print('\n🚀 ========== BILL PROVIDER INITIALIZE ==========');
    final currentUserId = FirebaseService.currentUserId;
    print('👤 Current User: $currentUserId');
    print('💾 Initialized For: $_initializedForUserId');
    print('✅ Is Initialized: $_isInitialized');
    print('⏳ Is Loading: $_isLoading');

    // Check if we need to reinitialize for a different user
    final needsReinit =
        _initializedForUserId != null && _initializedForUserId != currentUserId;

    // Prevent multiple initializations for the same user
    if ((_isInitialized && !needsReinit) || _isLoading) {
      print('⏭️ Skipping initialization (already initialized or loading)');
      print('================================================\n');
      return;
    }

    // CRITICAL FIX: If user changed, clear ALL cached state IMMEDIATELY
    // This prevents flash of old user's bills before new data loads
    if (needsReinit) {
      print('🔄 User changed, clearing ALL cached state IMMEDIATELY...');
      _bills = [];
      _allProcessedBills = [];
      _upcomingBills = [];
      _overdueBills = [];
      _paidBills = [];
      _totalUpcomingThisMonth = 0;
      _totalUpcomingNext7Days = 0;
      _countUpcomingThisMonth = 0;
      _countUpcomingNext7Days = 0;
      _isInitialized = false;
      _initializedForUserId = null;
      // Notify immediately to update UI with empty lists
      notifyListeners();
    }

    _isLoading = true;
    notifyListeners();

    try {
      // CRITICAL FIX: If this is first initialization but we have cached bills in memory,
      // clear them IMMEDIATELY to prevent flash of stale data
      // This handles the case where app restarts with different user
      if (_initializedForUserId == null && _bills.isNotEmpty) {
        print('⚠️ First init but have cached bills - clearing immediately');
        _bills = [];
        _allProcessedBills = [];
        _upcomingBills = [];
        _overdueBills = [];
        _paidBills = [];
        _totalUpcomingThisMonth = 0;
        _totalUpcomingNext7Days = 0;
        _countUpcomingThisMonth = 0;
        _countUpcomingNext7Days = 0;
        notifyListeners();
      }

      // CRITICAL: Set up remote changes callback BEFORE any sync operations
      // This allows SyncService to notify us when Firestore data changes
      SyncService.setOnRemoteChanges(() {
        print('📡 Remote changes callback triggered - refreshing from Hive');
        _bills = _loadCurrentUsersBills(forceRefresh: true);
        _processBills();
        notifyListeners();
      });

      // ONE-TIME MIGRATION: Mark existing Hive bills as local
      // This MUST run BEFORE initial sync to preserve notifications for existing users
      // Bills that exist in Hive before this update should continue to fire notifications
      await HiveService.migrateExistingBillsToLocal();

      // CRITICAL FIX: Check for user change and clear stale data BEFORE loading bills
      // This prevents bills from Account A appearing in Account B
      final storedUserId = HiveService.getUserData('currentUserId') as String?;

      final existingBillsCount = HiveService.getAllBills(
        forceRefresh: true,
      ).length;

      print('📊 Stored User ID: $storedUserId');
      print('📊 Current User ID: $currentUserId');
      print('📊 Existing bills in Hive: $existingBillsCount');

      // Detect if we need to clear stale data:
      // 1. Different user logged in (stored ID != current ID)
      // 2. Fresh login after logout (stored ID is null but there are bills, and a user is now logged in)
      final isDifferentUser =
          storedUserId != null && storedUserId != currentUserId;
      final isFreshLoginWithStaleData =
          storedUserId == null &&
          existingBillsCount > 0 &&
          currentUserId != null;

      if (isDifferentUser || isFreshLoginWithStaleData) {
        print('⚠️ USER CHANGE DETECTED - Clearing stale data BEFORE loading!');
        print('   isDifferentUser: $isDifferentUser');
        print('   isFreshLoginWithStaleData: $isFreshLoginWithStaleData');

        // Clear old bills SYNCHRONOUSLY before loading
        await HiveService.clearBillsOnly();

        // Also clear notification history and scheduled tracking to prevent cross-account leak
        await NotificationHistoryService.clearAll();
        await NotificationService().cancelAllNotifications();

        print('✅ Stale data cleared');
      }

      // Store current user ID for future checks
      if (currentUserId != null) {
        await HiveService.saveUserData('currentUserId', currentUserId);
      }

      // Load bills and filter by user ID (to prevent data leaks)
      var allBills = HiveService.getAllBills(forceRefresh: true);

      // MIGRATION: Assign current user ID to legacy bills (userId is null)
      // This assumes that if we are logged in, any unidentified bills belong to us
      // (since the previous version was single-user localized)
      if (currentUserId != null) {
        final legacyBills = allBills.where((b) => b.userId == null).toList();
        if (legacyBills.isNotEmpty) {
          print(
            '🛠️ Migrating ${legacyBills.length} legacy bills to user: $currentUserId',
          );
          for (var bill in legacyBills) {
            final updatedBill = bill.copyWith(userId: currentUserId);
            await HiveService.saveBill(updatedBill);
          }
          // Refresh list after migration
          allBills = HiveService.getAllBills(forceRefresh: true);
        }
      }

      // Filter bills to show ONLY those belonging to the current user
      if (currentUserId != null) {
        _bills = allBills.where((b) => b.userId == currentUserId).toList();
        print(
          '📱 Filtered: Showing ${_bills.length} bills for user $currentUserId (Total in box: ${allBills.length})',
        );

        // CRITICAL FIX: Delete bills belonging to OTHER users from local storage
        // This cleans up any leaked data from previous users
        final otherUserBills = allBills
            .where((b) => b.userId != null && b.userId != currentUserId)
            .toList();
        if (otherUserBills.isNotEmpty) {
          print(
            '🗑️ CLEANUP: Found ${otherUserBills.length} bills from OTHER users - deleting permanently',
          );
          for (var bill in otherUserBills) {
            print(
              '   - Deleting: "${bill.title}" (user: ${bill.userId?.substring(0, 8)}...)',
            );
            await HiveService.getBillsBox().delete(bill.id);
          }
          print(
            '✅ Cleanup complete - deleted ${otherUserBills.length} leaked bills',
          );
          // Refresh after cleanup
          allBills = HiveService.getAllBills(forceRefresh: true);
          _bills = allBills.where((b) => b.userId == currentUserId).toList();
        }
      } else {
        // If no user logged in, should theoretically show nothing or local-only bills?
        // Safe default: show nothing to enforce login
        print('⚠️ No user logged in - showing empty bill list');
        _bills = [];
      }

      for (var bill in _bills) {
        print(
          '   - ${bill.title} (${bill.id.substring(0, 8)}) [User: ${bill.userId}]',
        );
      }

      // MIGRATION / REPAIR: Ensure all Firestore documents have 'status' field
      if (currentUserId != null) {
        await _ensureFirestoreStatuses(currentUserId);
      }

      // Update UI immediately with local data
      _isLoading = false;
      _isInitialized = true;
      _initializedForUserId = currentUserId;
      _processBills(); // Process bills before notifying
      notifyListeners();

      // Sync with Firebase in background if user is authenticated
      if (currentUserId != null) {
        print('🔄 Starting background sync...');
        SyncService.initialSync()
            .then((_) {
              // Reload bills after sync completes
              _bills = _loadCurrentUsersBills(forceRefresh: true);
              _processBills();
              print(
                '✅ Background sync completed, UI updated with ${_bills.length} bills',
              );
              print(
                '✅ Background sync completed, UI updated with ${_bills.length} bills',
              );
              _processBills(); // Process bills after sync
              notifyListeners();
            })
            .catchError((e) {
              print('⚠️ Background sync failed: $e');
              print('💾 Continuing with local data');
              // Don't show error to user - offline mode is expected
            });
      }

      _error = null;

      print('✅ Initialization complete');
      print('================================================\n');

      // Run maintenance in background without any delay (fire-and-forget)
      // This ensures the UI is responsive during app startup
      Future.microtask(() async {
        try {
          // CRITICAL: Check for missed notifications FIRST (before maintenance)
          // This ensures notifications that fired while user was logged out are added
          // to history with their correct original scheduled times, before any
          // recurring bill maintenance creates new bills with adjusted times.
          if (currentUserId != null) {
            await NotificationHistoryService.checkMissedNotificationsForUser(
              userId: currentUserId,
              bills: _bills,
            );

            // Re-schedule notifications for all upcoming bills
            // This restores device alarms that were cancelled on logout
            print('🔄 Rescheduling notifications for user: $currentUserId');
            await rescheduleAllNotifications();
          }

          // Check for triggered notifications from tracking box
          await NotificationHistoryService.checkAndAddTriggeredNotifications(
            currentUserId: currentUserId,
          );

          // NOW run maintenance (may create new recurring bill instances)
          await runMaintenance();
          // Check for overdue recurring bills and create next instances
          await checkOverdueRecurringBills();

          // CRITICAL: Re-check for missed notifications AFTER maintenance
          // This catches any newly created recurring bills that were generated as overdue
          if (currentUserId != null) {
            print(
              '🔄 Re-checking missed notifications for user (post-maintenance)...',
            );
            // Must reload bills first to get the newly created ones?
            // runMaintenance reloads _bills, so we are good if we use _bills
            // But we need to be carefully accessing _bills which is on the provder
            // Accessing _bills here is safe as we are in the provider method
            await NotificationHistoryService.checkMissedNotificationsForUser(
              userId: currentUserId,
              bills: _bills,
            );
          }
        } catch (e) {
          print('Error running maintenance on initialization: $e');
          // Don't rethrow - maintenance failures shouldn't affect app initialization
        }
      });
    } catch (e) {
      _error = e.toString();
      print('❌ Error initializing bills: $e');
      print('================================================\n');
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
      // Check free tier bill limit (only counts bills created after trial expiration)
      if (!TrialService.canAccessProFeatures()) {
        // Fix: Must include deleted bills in the count because deleted paid/overdue bills
        // still count towards the limit (to prevent gaming the system)
        final allBills = HiveService.getAllBillsIncludingDeleted();
        final freeTierBillCount = TrialService.countFreeTierBills(allBills);

        if (freeTierBillCount >= TrialService.freeMaxBills) {
          throw Exception(
            'Free plan limit reached. You can add up to ${TrialService.freeMaxBills} bills. Upgrade to Pro for unlimited bills.',
          );
        }
      }

      final now = DateTime.now();

      // CRITICAL: Get device ID for multi-device notification architecture
      final currentDeviceId = await DeviceIdService.getDeviceId();

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
        recurringSequence: 1,
        repeatCount: repeatCount,
        reminderTiming: reminderTiming, // Save reminder timing
        notificationTime: notificationTime, // Save notification time
        createdDuringProTrial:
            TrialService.canAccessProFeatures(), // Store trial status
        userId: FirebaseService.currentUserId, // Associate with current user
        processing: false,
        createdDeviceId: currentDeviceId, // Device that created this bill
      );

      // Calculate initial status using the helper
      // This ensures the status respects reminder time from the start
      final initialStatus = BillStatusHelper.calculateStatus(bill);
      final billWithStatus = bill.copyWith(status: initialStatus);

      // Save to local storage
      await HiveService.saveBill(billWithStatus);

      // CRITICAL: Mark this bill as locally created on THIS device
      // Only locally-created bills will have notifications scheduled
      await HiveService.markBillAsLocal(billWithStatus.id);

      print('\n═══════════════════════════════════════════════════════');
      print('📝 BILL ADDED SUCCESSFULLY');
      print('═══════════════════════════════════════════════════════');
      print('Title: ${billWithStatus.title}');
      print('Amount: \$${billWithStatus.amount.toStringAsFixed(2)}');
      print('Due Date: ${billWithStatus.dueAt}');
      print('Category: ${billWithStatus.category}');
      print('Repeat: ${billWithStatus.repeat}');
      print(
        'Reminder Timing: ${billWithStatus.reminderTiming ?? "Using global settings"}',
      );
      print(
        'Notification Time: ${billWithStatus.notificationTime ?? "Using global settings"}',
      );
      print('═══════════════════════════════════════════════════════\n');

      // Schedule notification if enabled (force reschedule for new bills)
      await _scheduleNotificationForBill(billWithStatus, forceReschedule: true);

      print('\\n📝 ═══════════════════════════════════════════════════════');
      print('📝 RECURRING BILL CREATED');
      print('📝 ═══════════════════════════════════════════════════════');
      if (repeat.toLowerCase() != 'none' &&
          repeatCount != null &&
          repeatCount > 1) {
        print('   Title: ${billWithStatus.title}');
        print('   Repeat: $repeat');
        print('   Total planned occurrences: $repeatCount');
        print('   Created: Instance 1 of $repeatCount');
        print('   ℹ️  Next instance will be created automatically when:');
        print('      - Instance 1 is marked as paid, OR');
        print('      - Instance 1 becomes overdue');
        print('📝 ═══════════════════════════════════════════════════════\\n');
      }

      // Show all pending notifications
      await _showPendingNotifications();

      // Update local list
      _bills = _loadCurrentUsersBills();
      _processBills();

      // Debug: Verify the bill was saved correctly
      final savedBill = _bills.firstWhere(
        (b) => b.id == billWithStatus.id,
        orElse: () => billWithStatus,
      );
      print('\n🔍 ═══════════════════════════════════════════════════════');
      print('🔍 VERIFICATION - Bill read back from Hive:');
      print('🔍 ═══════════════════════════════════════════════════════');
      print('   Title: ${savedBill.title}');
      print('   DueAt (DateTime): ${savedBill.dueAt}');
      print('   DueAt ISO: ${savedBill.dueAt.toIso8601String()}');
      print(
        '   DueAt Date Only: ${savedBill.dueAt.toIso8601String().split('T')[0]}',
      );
      print('   DueAt Year: ${savedBill.dueAt.year}');
      print('   DueAt Month: ${savedBill.dueAt.month}');
      print('   DueAt Day: ${savedBill.dueAt.day}');
      print('🔍 ═══════════════════════════════════════════════════════\n');

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
      final now = DateTime.now();

      // CRITICAL: Recalculate status using centralized helper
      // This ensures consistent behavior across the app
      final calculatedStatus = BillStatusHelper.calculateStatus(bill);

      final updatedBill = bill.copyWith(
        updatedAt: now,
        clientUpdatedAt: now,
        needsSync: true,
        status: calculatedStatus, // Update status
      );

      // CRITICAL FIX: If this is a recurring bill, delete and regenerate all instances
      if (updatedBill.repeat.toLowerCase() != 'none' &&
          updatedBill.repeatCount != null &&
          updatedBill.repeatCount! > 1) {
        print('\n🔄 ═══════════════════════════════════════════════════════');
        print('🔄 UPDATING RECURRING BILL - REGENERATING INSTANCES');
        print('🔄 ═══════════════════════════════════════════════════════');
        print('   Title: ${updatedBill.title}');
        print('   Repeat: ${updatedBill.repeat}');
        print('   Total occurrences: ${updatedBill.repeatCount}');
        print('   Due date: ${updatedBill.dueAt}');
        print('   Status: $calculatedStatus');

        // Step 1: Find the parent ID of this series
        final seriesParentId = updatedBill.parentBillId ?? updatedBill.id;

        // Step 2: Find all instances in this series (excluding instance 1 - the parent)
        final allBills = HiveService.getAllBills(forceRefresh: true);
        final instancesToDelete = allBills.where((b) {
          final billParentId = b.parentBillId ?? b.id;
          final isInSeries =
              billParentId == seriesParentId || b.id == seriesParentId;
          final isNotParent =
              b.id != updatedBill.id; // Don't delete the bill being edited
          final isInstance =
              b.recurringSequence != null && b.recurringSequence! > 1;
          return isInSeries && isNotParent && isInstance && !b.isDeleted;
        }).toList();

        print(
          '   Found ${instancesToDelete.length} instances to delete and regenerate',
        );

        // Step 3: Delete all future instances
        for (final instance in instancesToDelete) {
          print(
            '   Deleting instance ${instance.recurringSequence}: ${instance.title} (${instance.id.substring(0, 8)})',
          );
          await NotificationService().cancelBillNotification(instance.id);
          await HiveService.deleteBill(instance.id);
        }

        // Step 4: Ensure the parent bill (instance 1) has correct sequence and repeatCount
        final parentBill = updatedBill.copyWith(
          recurringSequence: 1, // Ensure this is instance 1
          parentBillId: null, // Parent has no parent
        );

        await HiveService.saveBill(parentBill);
        print('   ✅ Saved updated parent bill (instance 1)');

        print(
          '   ℹ️  Future instances will be created one-at-a-time automatically',
        );
        print('🔄 ═══════════════════════════════════════════════════════\n');

        // Reschedule notification for the updated parent bill
        if (!parentBill.isPaid) {
          await _scheduleNotificationForBill(parentBill, forceReschedule: true);
        }
      } else {
        // Not a recurring bill or single occurrence - just update normally
        await HiveService.saveBill(updatedBill);

        print('\n═══════════════════════════════════════════════════════');
        print('✏️  BILL UPDATED');
        print('═══════════════════════════════════════════════════════');
        print('Title: ${updatedBill.title}');
        print('Amount: \$${updatedBill.amount.toStringAsFixed(2)}');
        print('Due Date: ${updatedBill.dueAt}');
        print('Is Paid: ${updatedBill.isPaid}');
        print('Status: ${updatedBill.status}');
        print('═══════════════════════════════════════════════════════\n');

        // Reschedule notification if bill is not paid (force reschedule on update)
        if (!updatedBill.isPaid) {
          await _scheduleNotificationForBill(
            updatedBill,
            forceReschedule: true,
          );
          await _showPendingNotifications();
        } else {
          // Cancel notification if bill is paid
          print('🔕 Cancelling notification for paid bill\n');
          await NotificationService().cancelBillNotification(updatedBill.id);
          await _showPendingNotifications();
        }
      }

      _bills = _loadCurrentUsersBills();
      _processBills();
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
  // CRITICAL: Updates local Hive immediately for responsive UI, then syncs to Firestore
  Future<void> markBillAsPaid(String billId) async {
    try {
      final bill = HiveService.getBillById(billId);
      if (bill != null) {
        final now = DateTime.now();

        // 1. IMMEDIATELY update local Hive state for responsive UI
        final updatedBill = bill.copyWith(
          isPaid: true,
          paidAt: now,
          status: 'paid',
          updatedAt: now,
          clientUpdatedAt: now,
          needsSync: true,
        );
        await HiveService.saveBill(updatedBill);

        // 2. Cancel notification for paid bill
        await NotificationService().cancelBillNotification(billId);

        // 3. Create next recurring instance IMMEDIATELY if applicable
        BillHive? nextInstance;
        if (bill.repeat != 'none') {
          nextInstance = await RecurringBillService.createNextInstance(bill);
          if (nextInstance != null) {
            print(
              '✅ Created next recurring instance: ${nextInstance.title} (seq: ${nextInstance.recurringSequence})',
            );

            // Schedule notification for the new instance
            await _scheduleNotificationForBill(
              nextInstance,
              forceReschedule: true,
            );

            // NOTE: Removed "New Bill Generated" notification per user request
            // The user does not want notifications for auto-generated recurring instances
          }
        }

        // 4. Refresh local UI state IMMEDIATELY
        _bills = _loadCurrentUsersBills(forceRefresh: true);
        _processBills();
        notifyListeners();

        // 5. Sync to Firestore in background (non-blocking)
        // Use a try-catch to handle offline/slow network gracefully
        _syncPaidBillToFirestore(updatedBill, nextInstance).catchError((e) {
          print('⚠️ Background Firestore sync failed (will retry later): $e');
          // Mark as needing sync so it gets picked up later
        });

        // Send paid notification
        await NotificationService().sendNotification(
          bill: updatedBill,
          type: 'paid',
        );
      }
    } catch (e) {
      _error = e.toString();
      print('Error marking bill as paid: $e');
      rethrow;
    }
  }

  // Helper method to sync paid bill and next instance to Firestore
  // Runs in background without blocking UI
  Future<void> _syncPaidBillToFirestore(
    BillHive paidBill,
    BillHive? nextInstance,
  ) async {
    try {
      // Sync the paid bill
      await FirebaseService.saveBill(paidBill);
      await HiveService.markBillAsSynced(paidBill.id);

      // Sync the next instance if created
      if (nextInstance != null) {
        await FirebaseService.saveBill(nextInstance);
        await HiveService.markBillAsSynced(nextInstance.id);
      }

      print('✅ Synced paid bill and next instance to Firestore');
    } catch (e) {
      print('⚠️ Failed to sync to Firestore: $e');
      // Don't rethrow - local state is already updated, sync will happen later
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

        // Reschedule notification for unpaid bill (force reschedule on undo)
        await _scheduleNotificationForBill(updatedBill, forceReschedule: true);

        // Force refresh to get latest data
        _bills = _loadCurrentUsersBills(forceRefresh: true);
        _processBills();
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
        _bills = _loadCurrentUsersBills(forceRefresh: true);
        _processBills();
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

  // Archive bill manually (PRO FEATURE)
  Future<void> archiveBill(String billId) async {
    // Check if user has Pro access
    if (!TrialService.canArchiveBills()) {
      throw Exception('Archive feature is only available for Pro users');
    }

    try {
      final bill = HiveService.getBillById(billId);
      if (bill != null) {
        await BillArchivalService.archiveBill(bill);

        // Force refresh to get latest data
        _bills = _loadCurrentUsersBills(forceRefresh: true);
        _processBills();
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

      // Check if bill is overdue
      bool isOverdue = false;
      if (!bill.isPaid) {
        // For 1-minute testing, use exact time comparison
        if (bill.repeat.toLowerCase() == '1 minute (testing)') {
          isOverdue =
              now.isAfter(bill.dueAt) || now.isAtSameMomentAs(bill.dueAt);
        } else {
          // For regular bills, use date + reminder time logic
          final today = DateTime(now.year, now.month, now.day);
          final dueDate = DateTime(
            bill.dueAt.year,
            bill.dueAt.month,
            bill.dueAt.day,
          );

          if (today.isAfter(dueDate)) {
            isOverdue = true;
          } else if (today.isAtSameMomentAs(dueDate)) {
            final reminderTime = bill.notificationTime ?? '09:00';
            final reminderParts = reminderTime.split(':');
            final reminderHour = int.parse(reminderParts[0]);
            final reminderMinute = int.parse(reminderParts[1]);

            final reminderDateTime = DateTime(
              now.year,
              now.month,
              now.day,
              reminderHour,
              reminderMinute,
            );

            isOverdue =
                now.isAfter(reminderDateTime) ||
                now.isAtSameMomentAs(reminderDateTime);
          }
        }
      }

      final isPaidOrOverdue = bill.isPaid || isOverdue;

      // If this is a PAID or OVERDUE bill, only delete this one
      // (It's just a history record, shouldn't affect future bills)
      if (isPaidOrOverdue) {
        print('🗑️ Deleting single paid/overdue bill: ${bill.title}');
        await NotificationService().cancelBillNotification(billId);
        await HiveService.deleteBill(billId);
      }
      // If this is an UPCOMING recurring bill, delete this + ALL future instances
      // This cancels the recurring series from this point forward
      else if (bill.repeat != 'none') {
        print(
          '🗑️ Deleting upcoming recurring bill + ALL future instances: ${bill.title}',
        );

        // Find the parent ID (the original bill that started the series)
        final parentId = bill.parentBillId ?? bill.id;
        final currentSequence = bill.recurringSequence ?? 0;

        print(
          '   Series parent ID: $parentId, Current sequence: $currentSequence',
        );
        if (bill.repeatCount != null) {
          print(
            '   Total occurrences in series: ${bill.repeatCount}, Remaining after this: ${bill.repeatCount! - currentSequence}',
          );
        } else {
          print('   Unlimited recurring series - will be cancelled');
        }

        // Find all UPCOMING (not paid, not overdue) bills in this series
        // with sequence >= current sequence
        final allBills = HiveService.getAllBillsIncludingDeleted();
        final billsToDelete = allBills.where((b) {
          final billParentId = b.parentBillId ?? b.id;
          final billSequence = b.recurringSequence ?? 0;
          final isInSeries = billParentId == parentId || b.id == parentId;
          final isFutureOrCurrent = billSequence >= currentSequence;
          final isUnpaid = !b.isPaid;

          // Check if bill is overdue using reminder time logic
          bool isBillOverdue = false;
          final today = DateTime(now.year, now.month, now.day);
          final dueDate = DateTime(b.dueAt.year, b.dueAt.month, b.dueAt.day);

          if (today.isAfter(dueDate)) {
            isBillOverdue = true;
          } else if (today.isAtSameMomentAs(dueDate)) {
            final reminderTime = b.notificationTime ?? '09:00';
            final reminderParts = reminderTime.split(':');
            final reminderHour = int.parse(reminderParts[0]);
            final reminderMinute = int.parse(reminderParts[1]);

            final reminderDateTime = DateTime(
              now.year,
              now.month,
              now.day,
              reminderHour,
              reminderMinute,
            );

            isBillOverdue =
                now.isAfter(reminderDateTime) ||
                now.isAtSameMomentAs(reminderDateTime);
          }

          final isNotOverdue = !isBillOverdue; // Keep overdue bills

          return isInSeries &&
              isFutureOrCurrent &&
              isUnpaid &&
              isNotOverdue &&
              !b.isDeleted;
        }).toList();

        print(
          '   Found ${billsToDelete.length} upcoming bills to delete (keeping paid & overdue history)',
        );

        // Delete all unpaid upcoming/future bills in the series
        // This soft-deletes them (isDeleted = true) which signals to
        // RecurringBillService to stop creating new instances
        for (final billToDelete in billsToDelete) {
          print(
            '   Deleting: ${billToDelete.title} (seq: ${billToDelete.recurringSequence}, due: ${billToDelete.dueAt})',
          );
          await NotificationService().cancelBillNotification(billToDelete.id);
          await HiveService.deleteBill(billToDelete.id);
        }

        print(
          '   ✅ Series cancelled from sequence $currentSequence onwards. No future instances will be created.',
        );
      } else {
        // Non-recurring upcoming bill - just delete this one
        await NotificationService().cancelBillNotification(billId);
        await HiveService.deleteBill(billId);
      }

      // Force refresh to update UI immediately
      _bills = _loadCurrentUsersBills(forceRefresh: true);
      _processBills();
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
      _bills = _loadCurrentUsersBills(forceRefresh: true);
      _processBills();
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
        _bills = _loadCurrentUsersBills(forceRefresh: true);
        _processBills();
        notifyListeners();

        // Reschedule notification with userId
        final currentUserId =
            HiveService.getUserData('currentUserId') as String?;
        await NotificationService().scheduleBillNotification(
          restoredBill,
          userId: currentUserId,
        );

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
  // Set forceReschedule to true when user explicitly changes settings
  Future<void> _scheduleNotificationForBill(
    BillHive bill, {
    bool forceReschedule = false,
  }) async {
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

      // CRITICAL: Only schedule notifications for bills created on THIS device
      // Bills synced from Firestore (other devices) should NOT trigger notifications
      if (!HiveService.isLocalBill(bill.id)) {
        print('❌ Bill is from another device - skipping notification');
        print('   (Only locally-created bills get notifications)');
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

      // Get current user ID from HiveService
      final currentUserId = HiveService.getUserData('currentUserId') as String?;

      await notificationService.scheduleBillNotification(
        bill,
        daysBeforeDue: daysOffset,
        notificationHour: notificationHour,
        notificationMinute: notificationMinute,
        userId: currentUserId,
        forceReschedule:
            forceReschedule, // Only cancel existing alarm if explicitly requested
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

  // Get upcoming bills (considering reminder time)
  List<BillHive> getUpcomingBills() {
    final now = DateTime.now();
    return _bills.where((bill) {
      if (bill.isPaid) return false;

      final today = DateTime(now.year, now.month, now.day);
      final dueDate = DateTime(
        bill.dueAt.year,
        bill.dueAt.month,
        bill.dueAt.day,
      );

      // If before due date, it's upcoming
      if (today.isBefore(dueDate)) return true;

      // If after due date, it's not upcoming
      if (today.isAfter(dueDate)) return false;

      // On due date - check reminder time
      final reminderTime = bill.notificationTime ?? '09:00';
      final reminderParts = reminderTime.split(':');
      final reminderHour = int.parse(reminderParts[0]);
      final reminderMinute = int.parse(reminderParts[1]);

      final reminderDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        reminderHour,
        reminderMinute,
      );

      return now.isBefore(reminderDateTime);
    }).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  // Get used slots for free tier (including deleted paid/overdue bills)
  int getFreeTierUsedCount() {
    final allBills = HiveService.getAllBillsIncludingDeleted();
    return TrialService.countFreeTierBills(allBills);
  }

  // Get remaining slots for free tier
  int getRemainingFreeTierBills() {
    // Use provider's bills list for consistency and reactivity
    // Need to include deleted bills for accurate count
    final allBills = HiveService.getAllBillsIncludingDeleted();
    final remaining = TrialService.getRemainingFreeTierBills(allBills);

    // Debug logging
    print('📊 getRemainingFreeTierBills called:');
    print('   Total bills (including deleted): ${allBills.length}');
    print('   Remaining slots: $remaining');
    print('   Can access pro: ${TrialService.canAccessProFeatures()}');

    return remaining;
  }

  // Get overdue bills (considering reminder time)
  List<BillHive> getOverdueBills() {
    final now = DateTime.now();
    return _bills.where((bill) {
      if (bill.isPaid) return false;

      final today = DateTime(now.year, now.month, now.day);
      final dueDate = DateTime(
        bill.dueAt.year,
        bill.dueAt.month,
        bill.dueAt.day,
      );

      // If after due date, it's overdue
      if (today.isAfter(dueDate)) return true;

      // If before due date, it's not overdue
      if (today.isBefore(dueDate)) return false;

      // On due date - check reminder time
      final reminderTime = bill.notificationTime ?? '09:00';
      final reminderParts = reminderTime.split(':');
      final reminderHour = int.parse(reminderParts[0]);
      final reminderMinute = int.parse(reminderParts[1]);

      final reminderDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        reminderHour,
        reminderMinute,
      );

      return now.isAfter(reminderDateTime) ||
          now.isAtSameMomentAs(reminderDateTime);
    }).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
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
      _bills = _loadCurrentUsersBills();
      _processBills();
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
  // NOTE: Instance creation is now handled at bill creation time via generateAllInstances()
  // This method is kept for backwards compatibility but no longer creates new instances
  Future<void> runRecurringBillMaintenance() async {
    try {
      print('Running recurring bill maintenance...');
      // DISABLED: processRecurringBills() - instances are now pre-generated at creation time
      // The old reactive system was creating unlimited instances and not respecting repeatCount
      print(
        'Recurring maintenance skipped - instances are now pre-generated at creation',
      );
    } catch (e) {
      print('Error running recurring bill maintenance: $e');
    }
  }

  // Check for overdue recurring bills and create next instances IMMEDIATELY
  // This is called when:
  // 1. Status refresh timer fires (bill just became overdue)
  // 2. App comes to foreground
  // 3. Bills are refreshed
  Future<void> checkOverdueRecurringBills() async {
    try {
      // Find all overdue recurring bills that haven't been paid
      final overdueRecurringBills = _bills
          .where(
            (bill) =>
                bill.repeat != 'none' &&
                !bill.isDeleted &&
                !bill.isPaid &&
                BillStatusHelper.calculateStatus(bill) == 'overdue',
          )
          .toList();

      if (overdueRecurringBills.isEmpty) {
        return;
      }

      print(
        '⏰ Found ${overdueRecurringBills.length} overdue recurring bills - processing IMMEDIATELY...',
      );

      int createdCount = 0;
      int statusUpdatedCount = 0;
      final currentUserId = FirebaseService.currentUserId;

      for (final overdueBill in overdueRecurringBills) {
        try {
          // CRITICAL FIX (BUG 1): Update the overdue bill's status in Hive immediately
          // This ensures it appears in the Overdue tab right away
          if (overdueBill.status != 'overdue') {
            final updatedOverdueBill = overdueBill.copyWith(
              status: 'overdue',
              updatedAt: DateTime.now(),
              clientUpdatedAt: DateTime.now(),
              needsSync: true,
            );
            await HiveService.saveBill(updatedOverdueBill);
            statusUpdatedCount++;
            print('   📌 Updated status to OVERDUE: ${overdueBill.title}');

            // Sync status update to Firestore in background
            if (currentUserId != null) {
              FirebaseService.saveBill(updatedOverdueBill).catchError((e) {
                print('   ⚠️ Failed to sync status update: $e');
              });
            }
          }

          // Check if repeat count limit reached
          if (overdueBill.repeatCount != null) {
            final currentSequence = overdueBill.recurringSequence ?? 1;
            if (currentSequence >= overdueBill.repeatCount!) {
              print(
                '   ⏭️ ${overdueBill.title}: Repeat limit reached, skipping',
              );
              continue;
            }
          }

          // Create next instance IMMEDIATELY
          final nextInstance = await RecurringBillService.createNextInstance(
            overdueBill,
          );

          if (nextInstance != null) {
            createdCount++;
            print(
              '   ✅ Created next instance: ${nextInstance.title} (seq: ${nextInstance.recurringSequence}) due ${nextInstance.dueAt} notificationTime: ${nextInstance.notificationTime}',
            );

            // Schedule notification for the new instance
            await _scheduleNotificationForBill(
              nextInstance,
              forceReschedule: true,
            );

            // NOTE: Removed "New Bill Generated" notification per user request
            // The user does not want notifications for auto-generated recurring instances

            // Sync the new instance to Firestore in background
            if (currentUserId != null) {
              FirebaseService.saveBill(nextInstance)
                  .then((_) {
                    HiveService.markBillAsSynced(nextInstance.id);
                    print('   ☁️ Synced ${nextInstance.title} to Firestore');
                  })
                  .catchError((e) {
                    print('   ⚠️ Failed to sync to Firestore (will retry): $e');
                  });
            }
          } else {
            print(
              '   ⏭️ ${overdueBill.title}: Next instance already exists or limit reached',
            );
          }
        } catch (e) {
          print(
            '   ❌ Error creating next instance for ${overdueBill.title}: $e',
          );
        }
      }

      // CRITICAL FIX (BUG 1): Always refresh UI if any status was updated OR new instances created
      if (createdCount > 0 || statusUpdatedCount > 0) {
        print(
          '⏰ Created $createdCount new instances, updated $statusUpdatedCount statuses',
        );

        // Reload bills and update UI IMMEDIATELY
        _bills = _loadCurrentUsersBills(forceRefresh: true);
        _processBills();
        notifyListeners();
      }
    } catch (e) {
      print('Error checking overdue recurring bills: $e');
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
        _bills = _loadCurrentUsersBills();
        _processBills();
        notifyListeners();

        // Trigger debounced sync
        _triggerSync();

        print(
          'Archived $archivedCount bills, auto-deleted $deletedCount old bills',
        );
      }

      // Check for overdue bills to notify (Requirement 3: Overdue Notification)
      // This runs after maintenance to ensure everything is up to date
      await _checkAndNotifyOverdueBills();
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
          userId: FirebaseService.currentUserId, // Associate with current user
        );

        importedBills.add(bill);
      }

      // Save all bills to Hive
      for (final bill in importedBills) {
        await HiveService.saveBill(bill);
      }

      // Update local list
      _bills = _loadCurrentUsersBills();
      _processBills();
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
      // Pass current user ID to ensure isolate processes only this user's bills
      final currentUserId = FirebaseService.currentUserId;
      final params = {'userId': currentUserId};

      final results = await compute(_runMaintenanceInIsolate, params);

      final duration = DateTime.now().difference(startTime);
      print(
        'Maintenance complete in ${duration.inMilliseconds}ms: '
        '${results['billsCreated']} bills created, '
        '${results['billsArchived']} bills archived',
      );

      // Reload bills if any changes were made
      if (results['billsCreated']! > 0 || results['billsArchived']! > 0) {
        _bills = _loadCurrentUsersBills();
        _processBills();
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

  // Check for overdue bills and trigger notifications + state updates using Transactions
  Future<void> _checkAndNotifyOverdueBills() async {
    final now = DateTime.now();

    // Filter for bills that are overdue but NOT processed yet
    // 'status' might be null in legacy bills, so check date
    final overdueCandidates = _bills.where((b) {
      if (b.isPaid || b.isDeleted) return false;
      return now.isAfter(b.dueAt);
    }).toList();

    for (final bill in overdueCandidates) {
      // If already 'overdue' status, skip (idempotency handled here to avoid RPC calls)
      if (bill.status == 'overdue') continue;

      try {
        print('🔒 Processing overdue transaction for ${bill.title}...');
        await RecurringBillService.processBillEventInTransaction(
          bill: bill,
          eventType: 'overdue',
        );
      } catch (e) {
        print('Error processing overdue bill ${bill.id}: $e');
      }
    }
  }

  // Ensure all bills in Firestore have a valid 'status' field
  // This is a self-healing Step to fix legacy data for the new Real-time Queries
  Future<void> _ensureFirestoreStatuses(String userId) async {
    try {
      print('🔧 Verifying Firestore data integrity for user: $userId');
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('bills');

      // Get all bills (optimized: maybe check for missing status?
      // Firestore doesn't support "where field is missing". So fetch all.)
      final snapshot = await collection.get();

      final batch = FirebaseFirestore.instance.batch();
      bool needsCommit = false;
      int fixedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['status'] == null) {
          // Calculate status
          final isPaid = data['isPaid'] == true;
          final dueAtStr = data['dueAt'] as String?;
          final dueAt = dueAtStr != null
              ? DateTime.parse(dueAtStr)
              : DateTime.now();

          String status;
          if (isPaid) {
            status = 'paid';
          } else if (DateTime.now().isAfter(dueAt)) {
            status = 'overdue';
          } else {
            status = 'upcoming';
          }

          batch.update(doc.reference, {'status': status});
          needsCommit = true;
          fixedCount++;
        }
      }

      if (needsCommit) {
        print(
          '🔧 Fixing $fixedCount bills with missing status in Firestore...',
        );
        await batch.commit();
        print('✅ Firestore data repair complete.');
      } else {
        print('✅ Firestore data is healthy.');
      }
    } catch (e) {
      print('⚠️ Error during Firestore status repair: $e');
      // Non-fatal, proceed
    }
  }

  static Future<Map<String, int>> _runMaintenanceInIsolate(
    Map<String, dynamic>? params,
  ) async {
    try {
      final userId = params?['userId'] as String?;

      // Initialize Hive in the isolate
      await HiveService.init();

      // Debug: Print bill statistics before processing
      HiveService.printBillStats();

      // Purge soft-deleted bills to prevent any stale data issues
      await HiveService.purgeDeletedBills();

      // DISABLED: processRecurringBills() - instances are now pre-generated at creation time
      // The old reactive system was creating unlimited instances and not respecting repeatCount
      final billsCreated = 0; // No longer creating instances reactively

      // Process archival
      final billsArchived = await BillArchivalService.processArchival();

      return {'billsCreated': billsCreated, 'billsArchived': billsArchived};
    } catch (e) {
      print('Error in maintenance isolate: $e');
      return {'billsCreated': 0, 'billsArchived': 0};
    }
  }
}
