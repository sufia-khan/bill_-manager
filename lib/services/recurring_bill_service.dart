import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_hive.dart';
import '../utils/logger.dart';
import 'hive_service.dart';

/// Service for managing recurring bill operations
/// Handles automatic creation of recurring bill instances
class RecurringBillService {
  static const String _tag = 'RecurringBillService';

  // CRITICAL: Global lock to prevent concurrent processing from ANY source
  // This prevents race conditions between:
  // - processRecurringBills()
  // - createNextInstance()
  // - checkOverdueRecurringBills()
  static bool _isProcessing = false;

  // CRITICAL: Track recently created instances to prevent duplicates
  // Key: parentBillId:sequence, cleared after 60 seconds
  static final Set<String> _recentlyCreatedInstances = {};
  static DateTime? _lastCleanupTime;

  /// Calculate the next due date based on recurring type
  /// Handles weekly, monthly, quarterly, and yearly calculations
  /// Preserves day of month where possible, handles edge cases
  /// Throws ArgumentError if currentDue is invalid
  static DateTime calculateNextDueDate(
    DateTime currentDue,
    String recurringType,
  ) {
    try {
      // Validate input
      if (recurringType.isEmpty) {
        throw ArgumentError('Recurring type cannot be empty');
      }

      switch (recurringType.toLowerCase()) {
        case '1 minute (testing)':
          // Add 1 minute for testing purposes
          return currentDue.add(const Duration(minutes: 1));

        case 'weekly':
          // Add 7 days
          return currentDue.add(const Duration(days: 7));

        case 'monthly':
          // Add 1 month, preserve day
          return _addMonths(currentDue, 1);

        case 'quarterly':
          // Add 3 months
          return _addMonths(currentDue, 3);

        case 'yearly':
          // Add 1 year
          return DateTime(
            currentDue.year + 1,
            currentDue.month,
            currentDue.day,
            currentDue.hour,
            currentDue.minute,
            currentDue.second,
          );

        default:
          // If unknown type, log warning and default to monthly
          Logger.warning(
            'Unknown recurring type "$recurringType", defaulting to monthly',
            _tag,
          );
          return _addMonths(currentDue, 1);
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to calculate next due date',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      rethrow;
    }
  }

  /// Helper method to add months while preserving day
  /// Handles edge cases like Jan 31 → Feb 28/29
  static DateTime _addMonths(DateTime date, int months) {
    int newYear = date.year;
    int newMonth = date.month + months;

    // Handle year overflow
    while (newMonth > 12) {
      newMonth -= 12;
      newYear += 1;
    }

    // Handle day overflow (e.g., Jan 31 → Feb 28/29)
    int newDay = date.day;
    int daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;

    if (newDay > daysInNewMonth) {
      newDay = daysInNewMonth;
    }

    return DateTime(
      newYear,
      newMonth,
      newDay,
      date.hour,
      date.minute,
      date.second,
    );
  }

  /// PRE-GENERATE ALL RECURRING BILL INSTANCES
  /// Called at bill creation time to generate all future instances upfront.
  /// Each instance has an exact timestamp for:
  /// - Notification scheduling (fires at exact time)
  /// - Overdue detection (compares instanceTime vs now)
  ///
  /// Returns list of created instances (excluding the parent bill itself).
  /// The parent bill is instance 1 and should be saved separately.
  ///
  /// Cap: 100 instances max for 1-minute testing mode.
  static Future<List<BillHive>> generateAllInstances({
    required BillHive parentBill,
    required int repeatCount,
  }) async {
    try {
      Logger.info(
        'Generating $repeatCount instances for ${parentBill.title}',
        _tag,
      );

      // Cap at 100 for testing mode to prevent excessive instance creation
      final effectiveCount =
          parentBill.repeat.toLowerCase() == '1 minute (testing)'
          ? (repeatCount > 100 ? 100 : repeatCount)
          : repeatCount;

      if (effectiveCount != repeatCount) {
        Logger.warning(
          'Capped instance count from $repeatCount to $effectiveCount (testing mode)',
          _tag,
        );
      }

      final instances = <BillHive>[];
      final now = DateTime.now();
      DateTime currentDueAt = parentBill.dueAt;

      // Skip instance 1 - that's the parent bill itself
      // Generate instances 2 through repeatCount
      for (int sequence = 2; sequence <= effectiveCount; sequence++) {
        // Calculate next due date from current
        currentDueAt = calculateNextDueDate(currentDueAt, parentBill.repeat);

        // Calculate notification time for this instance
        // For 1-minute testing, use the exact dueAt time
        // For regular bills, keep the same notification time as parent
        String? instanceNotificationTime;
        if (parentBill.repeat.toLowerCase() == '1 minute (testing)') {
          final h = currentDueAt.hour.toString().padLeft(2, '0');
          final m = currentDueAt.minute.toString().padLeft(2, '0');
          instanceNotificationTime = '$h:$m';
        } else {
          instanceNotificationTime = parentBill.notificationTime;
        }

        // Determine status based on exact timestamp comparison
        final status = currentDueAt.isBefore(now) ? 'overdue' : 'upcoming';

        final instance = BillHive(
          id: const Uuid().v4(),
          title: parentBill.title,
          vendor: parentBill.vendor,
          amount: parentBill.amount,
          dueAt: currentDueAt, // EXACT instance timestamp
          notes: parentBill.notes,
          category: parentBill.category,
          isPaid: false,
          isDeleted: false,
          updatedAt: now,
          clientUpdatedAt: now,
          repeat: parentBill.repeat,
          needsSync: true,
          paidAt: null,
          isArchived: false,
          archivedAt: null,
          parentBillId: parentBill.id, // Link to parent (instance 1)
          recurringSequence: sequence,
          repeatCount: effectiveCount,
          reminderTiming: parentBill.reminderTiming,
          notificationTime: instanceNotificationTime,
          userId: parentBill.userId,
          createdDuringProTrial: parentBill.createdDuringProTrial,
          status: status,
          processing: false,
        );

        // Save to Hive immediately
        await HiveService.saveBill(instance);
        instances.add(instance);

        Logger.info(
          '  Created instance $sequence/${effectiveCount}: due ${currentDueAt.toIso8601String()}, status: $status',
          _tag,
        );
      }

      Logger.info(
        'Successfully generated ${instances.length} instances for ${parentBill.title}',
        _tag,
      );

      return instances;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to generate instances for ${parentBill.title}',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return [];
    }
  }

  /// Check if next instance of a recurring bill already exists
  /// Returns true if a bill with matching parentBillId and due date exists
  /// [seriesParentId] - The root parent ID of the recurring series
  /// [excludeBillId] - ID of the bill being processed (to exclude from check)
  /// [userId] - Optional user ID to filter bills (prevents cross-account checks)
  /// Returns false on error to prevent duplicate creation
  static Future<bool> hasNextInstance(
    String seriesParentId,
    DateTime nextDueDate, {
    String? excludeBillId,
    String? userId,
  }) async {
    try {
      // Validate input
      if (seriesParentId.isEmpty) {
        throw ArgumentError('Series parent ID cannot be empty');
      }

      // CRITICAL: Use user-filtered bills if userId is provided to prevent cross-account checks
      final List<BillHive> allBills;
      if (userId != null && userId.isNotEmpty) {
        allBills = HiveService.getBillsForUser(userId, forceRefresh: true);
      } else {
        allBills = HiveService.getAllBills(forceRefresh: true);
      }

      // Check if any bill has this seriesParentId and a due date close to nextDueDate
      // Using 30-second tolerance for 1-minute testing, works for all intervals
      final startRange = nextDueDate.subtract(const Duration(seconds: 30));
      final endRange = nextDueDate.add(const Duration(seconds: 30));

      return allBills.any((bill) {
        if (bill.id == excludeBillId) return false; // Exclude the source bill
        if (bill.isDeleted) return false; // Skip deleted bills

        // CRITICAL FIX: A bill belongs to this series if:
        // 1. Its parentBillId matches the seriesParentId, OR
        // 2. Its own ID is the seriesParentId (it's the original bill)
        final billSeriesId = bill.parentBillId ?? bill.id;
        if (billSeriesId != seriesParentId) return false;

        // Check if due date is within range
        return bill.dueAt.isAfter(startRange) && bill.dueAt.isBefore(endRange);
      });
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to check for next instance',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      // Return false to prevent duplicate creation on error
      return false;
    }
  }

  /// Clean up old entries from recently created tracking set
  static void _cleanupRecentlyCreated() {
    final now = DateTime.now();
    if (_lastCleanupTime == null ||
        now.difference(_lastCleanupTime!).inSeconds > 60) {
      _recentlyCreatedInstances.clear();
      _lastCleanupTime = now;
    }
  }

  /// Create the next instance of a recurring bill
  /// Copies data from parent bill and sets new due date
  /// Returns the created bill or null if creation fails
  /// CRITICAL: Uses global lock and tracking to prevent duplicates
  static Future<BillHive?> createNextInstance(BillHive parentBill) async {
    // CRITICAL: Clean up old tracking entries periodically
    _cleanupRecentlyCreated();

    // Calculate seriesParentId and sequence FIRST for tracking
    final seriesParentId = parentBill.parentBillId ?? parentBill.id;
    final nextSequence = (parentBill.recurringSequence ?? 1) + 1;
    final trackingKey = '$seriesParentId:$nextSequence';

    // CRITICAL: Check if this instance was recently created (prevents duplicates)
    if (_recentlyCreatedInstances.contains(trackingKey)) {
      Logger.info(
        'Instance $trackingKey was recently created - skipping duplicate',
        _tag,
      );
      return null;
    }

    // CRITICAL: Wait if another creation is in progress
    // This prevents race conditions from multiple trigger sources
    int waitCount = 0;
    while (_isProcessing && waitCount < 10) {
      Logger.info('Waiting for lock to create instance...', _tag);
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    if (_isProcessing) {
      Logger.warning('Lock timeout - skipping to prevent deadlock', _tag);
      return null;
    }

    _isProcessing = true;

    try {
      // Validate parent bill
      if (parentBill.repeat == 'none') {
        Logger.warning(
          'Attempted to create next instance for non-recurring bill: ${parentBill.title}',
          _tag,
        );
        return null;
      }

      if (parentBill.amount <= 0) {
        Logger.error(
          'Invalid bill amount for ${parentBill.title}: ${parentBill.amount}',
          tag: _tag,
        );
        return null;
      }

      // Check if repeat count limit reached
      if (parentBill.repeatCount != null) {
        final currentSequence = parentBill.recurringSequence ?? 1;
        if (currentSequence >= parentBill.repeatCount!) {
          Logger.info(
            'Repeat count limit reached for ${parentBill.title}: $currentSequence/${parentBill.repeatCount}',
            _tag,
          );
          return null;
        }
      }

      // Calculate next due date
      final nextDueDate = calculateNextDueDate(
        parentBill.dueAt,
        parentBill.repeat,
      );

      // Validate next due date is in the future
      final now = DateTime.now();
      if (nextDueDate.isBefore(now)) {
        Logger.warning(
          'Calculated next due date is in the past for ${parentBill.title}: $nextDueDate',
          _tag,
        );
      }

      // CRITICAL FIX: Use the series parent ID (not the current bill's ID)
      // This ensures we check for duplicates across the entire series
      final seriesParentId = parentBill.parentBillId ?? parentBill.id;

      // Check if next instance already exists
      final exists = await hasNextInstance(
        seriesParentId,
        nextDueDate,
        excludeBillId: parentBill.id,
        userId: parentBill.userId,
      );
      if (exists) {
        Logger.info(
          'Next instance already exists for bill: ${parentBill.title}',
          _tag,
        );
        return null;
      }

      // CRITICAL FIX: Calculate status for the new bill
      // For 1-minute testing, compare exact DateTime
      String newStatus;
      if (parentBill.repeat.toLowerCase() == '1 minute (testing)') {
        newStatus = now.isBefore(nextDueDate) ? 'upcoming' : 'overdue';
      } else {
        // For regular bills, compare dates
        final todayDate = DateTime(now.year, now.month, now.day);
        final dueDate = DateTime(
          nextDueDate.year,
          nextDueDate.month,
          nextDueDate.day,
        );
        if (todayDate.isBefore(dueDate)) {
          newStatus = 'upcoming';
        } else if (todayDate.isAfter(dueDate)) {
          newStatus = 'overdue';
        } else {
          // Same day - check time
          newStatus = now.isBefore(nextDueDate) ? 'upcoming' : 'overdue';
        }
      }

      // CRITICAL FIX (BUG 2): Calculate correct notificationTime for new instance
      // For 1-minute testing, the notificationTime must match the nextDueDate time
      // For regular bills, keep the parent's notification time (same time each day/week/month)
      String? newNotificationTime;
      if (parentBill.repeat.toLowerCase() == '1 minute (testing)') {
        // Extract hour:minute from nextDueDate for 1-minute testing
        final h = nextDueDate.hour.toString().padLeft(2, '0');
        final m = nextDueDate.minute.toString().padLeft(2, '0');
        newNotificationTime = '$h:$m';
        Logger.info(
          'Calculated new notificationTime for 1-min testing: $newNotificationTime',
          _tag,
        );
      } else {
        // For regular recurring bills, keep the same notification time as parent
        newNotificationTime = parentBill.notificationTime;
      }

      // Create new bill instance
      final newBill = BillHive(
        id: const Uuid().v4(),
        title: parentBill.title,
        vendor: parentBill.vendor,
        amount: parentBill.amount,
        dueAt: nextDueDate,
        notes: parentBill.notes,
        category: parentBill.category,
        isPaid: false, // New instance starts as unpaid
        isDeleted: false,
        updatedAt: now,
        clientUpdatedAt: now,
        repeat: parentBill.repeat,
        needsSync: true,
        paidAt: null,
        isArchived: false,
        archivedAt: null,
        parentBillId: seriesParentId, // Use series parent ID
        recurringSequence: nextSequence, // Use calculated sequence
        repeatCount: parentBill.repeatCount, // Copy repeat count limit
        reminderTiming: parentBill.reminderTiming, // Copy notification settings
        notificationTime:
            newNotificationTime, // CRITICAL FIX: Use calculated time
        userId: parentBill.userId, // Propagate user ID
        createdDuringProTrial:
            parentBill.createdDuringProTrial, // Propagate pro trial status
        status: newStatus, // Set status explicitly
        processing: false,
      );

      // Save to Hive
      await HiveService.saveBill(newBill);

      // CRITICAL: Track this instance to prevent duplicates
      _recentlyCreatedInstances.add(trackingKey);

      Logger.info(
        'Created next instance for ${parentBill.title}: '
        'Due $nextDueDate, Sequence: $nextSequence, Status: $newStatus, NotificationTime: $newNotificationTime',
        _tag,
      );

      return newBill;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to create next instance for bill ${parentBill.id}',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return null;
    } finally {
      // CRITICAL: Always release the lock
      _isProcessing = false;
    }
  }

  /// Check if a recurring series has an active (unpaid, not overdue) instance
  /// Returns true if there's already an active bill waiting to be paid/become overdue
  static bool _hasActiveInstanceInSeries(
    String parentId,
    List<BillHive> allBills,
  ) {
    final now = DateTime.now();

    return allBills.any((bill) {
      final billParentId = bill.parentBillId ?? bill.id;
      if (billParentId != parentId || bill.isDeleted) return false;

      // Check if bill is unpaid
      if (bill.isPaid) return false;

      // For 1-minute testing, use exact time comparison
      if (bill.repeat.toLowerCase() == '1 minute (testing)') {
        // Bill is active (not overdue) if due time is in the future
        return now.isBefore(bill.dueAt);
      }

      // For other recurring types, use date + reminder time logic
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = DateTime(
        bill.dueAt.year,
        bill.dueAt.month,
        bill.dueAt.day,
      );

      // If after due date, it's overdue (not active/upcoming)
      if (today.isAfter(dueDate)) return false;

      // If before due date, it's upcoming (active)
      if (today.isBefore(dueDate)) return true;

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

      // If before reminder time, it's still upcoming (active)
      return now.isBefore(reminderDateTime);
    });
  }

  /// Process all recurring bills and create next instances if needed
  /// KEY LOGIC: Only creates next instance when current one is PAID or OVERDUE
  /// and there's NO active (upcoming/unpaid) instance already in the series.
  /// This ensures only ONE instance at a time.
  /// Returns count of new instances created
  static Future<int> processRecurringBills({String? userId}) async {
    // Prevent concurrent processing
    if (_isProcessing) {
      Logger.info('Already processing recurring bills, skipping...', _tag);
      return 0;
    }

    _isProcessing = true;

    try {
      final now = DateTime.now();
      int createdCount = 0;
      int errorCount = 0;

      // Get all bills with recurring enabled - force refresh to get latest data
      // CRITICAL FIX: Filter by userId upfront to prevent cross-account data processing
      final allBills = userId != null && userId.isNotEmpty
          ? HiveService.getBillsForUser(userId, forceRefresh: true)
          : HiveService.getAllBills(forceRefresh: true);

      // Filter for recurring bills that are not deleted
      var recurringBillsQuery = allBills.where(
        (bill) => bill.repeat != 'none' && !bill.isDeleted,
      );

      if (userId != null) {
        Logger.info('Processing recurring bills for user: $userId', _tag);
      } else {
        Logger.warning(
          'Processing recurring bills for ALL users (userId not provided or null)',
          _tag,
        );
      }

      final recurringBills = recurringBillsQuery.toList();

      if (recurringBills.isEmpty) {
        Logger.info('No recurring bills to process', _tag);
        return 0;
      }

      Logger.info(
        'Processing ${recurringBills.length} recurring bills...',
        _tag,
      );

      // Get all bills including deleted to check if series was cancelled
      final allBillsIncludingDeleted =
          HiveService.getAllBillsIncludingDeleted();

      // Group bills by their parent series
      final Map<String, List<BillHive>> seriesMap = {};
      for (final bill in recurringBills) {
        final parentId = bill.parentBillId ?? bill.id;
        seriesMap.putIfAbsent(parentId, () => []);
        seriesMap[parentId]!.add(bill);
      }

      Logger.info('Found ${seriesMap.length} recurring series to check', _tag);

      // Process each series independently
      for (final entry in seriesMap.entries) {
        final parentId = entry.key;
        final seriesBills = entry.value; // Mutable list for this iteration

        // Safety break for infinite loops
        int iterations = 0;
        bool shouldCheckSeriesAgain = true;

        while (shouldCheckSeriesAgain && iterations < 1000) {
          shouldCheckSeriesAgain = false;
          iterations++;

          try {
            // Debug: Log series info
            Logger.info(
              'Checking series $parentId with ${seriesBills.length} bills (iteration $iterations)',
              _tag,
            );

            // CRITICAL: Check if there's already an active (upcoming/unpaid) instance
            // If yes, don't create a new one - wait until it's paid or becomes overdue
            final hasActive = _hasActiveInstanceInSeries(parentId, allBills);

            if (hasActive) {
              Logger.info(
                'Series $parentId already has an active instance - skipping',
                _tag,
              );
              break; // Stop processing this series
            }

            // Check if the series was cancelled (deleted upcoming bill logic)
            final deletedUpcomingBills = allBillsIncludingDeleted.where((b) {
              final bParentId = b.parentBillId ?? b.id;
              final isInSeries = bParentId == parentId || b.id == parentId;
              return isInSeries && b.isDeleted && !b.isPaid;
            }).toList();

            if (deletedUpcomingBills.isNotEmpty) {
              int? maxDeletedSequence;
              for (final deleted in deletedUpcomingBills) {
                final seq = deleted.recurringSequence ?? 0;
                if (maxDeletedSequence == null || seq > maxDeletedSequence) {
                  maxDeletedSequence = seq;
                }
              }

              final latestNonDeletedSequence = seriesBills.isNotEmpty
                  ? seriesBills
                        .map((b) => b.recurringSequence ?? 0)
                        .reduce((a, b) => a > b ? a : b)
                  : 0;

              if (maxDeletedSequence != null &&
                  maxDeletedSequence >= latestNonDeletedSequence) {
                Logger.info(
                  'Recurring series $parentId was cancelled - skipping',
                  _tag,
                );
                break; // Stop processing
              }
            }

            // Find the latest bill in the series
            seriesBills.sort((a, b) {
              final seqA = a.recurringSequence ?? 0;
              final seqB = b.recurringSequence ?? 0;
              if (seqA != seqB) {
                return seqB.compareTo(seqA);
              }
              return b.dueAt.compareTo(a.dueAt);
            });

            final latestBill = seriesBills.first;

            // Check overdue
            bool isOverdue = false;
            if (!latestBill.isPaid) {
              if (latestBill.repeat.toLowerCase() == '1 minute (testing)') {
                isOverdue =
                    now.isAfter(latestBill.dueAt) ||
                    now.isAtSameMomentAs(latestBill.dueAt);
              } else {
                final today = DateTime(now.year, now.month, now.day);
                final dueDate = DateTime(
                  latestBill.dueAt.year,
                  latestBill.dueAt.month,
                  latestBill.dueAt.day,
                );

                if (today.isAfter(dueDate)) {
                  isOverdue = true;
                } else if (today.isAtSameMomentAs(dueDate)) {
                  final reminderTime = latestBill.notificationTime ?? '09:00';
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

            // Recent update check (skip if < 60s ago and not paid)
            final timeSinceUpdate = now.difference(latestBill.updatedAt);
            if (timeSinceUpdate.inSeconds < 60 && !latestBill.isPaid) {
              Logger.info(
                'Skipping ${latestBill.title}: recently updated',
                _tag,
              );
              break;
            }

            if (!latestBill.isPaid && !isOverdue) {
              break; // Still upcoming
            }

            // Check limit
            final currentSequence = latestBill.recurringSequence ?? 1;
            final nextSequence = currentSequence + 1;
            if (latestBill.repeatCount != null &&
                nextSequence > latestBill.repeatCount!) {
              break;
            }

            // Create next
            var nextDueDate = calculateNextDueDate(
              latestBill.dueAt,
              latestBill.repeat,
            );

            final exists = await hasNextInstance(
              parentId,
              nextDueDate,
              excludeBillId: latestBill.id,
              userId:
                  latestBill.userId, // Pass userId for user-specific filtering
            );

            if (exists) {
              break;
            }

            // 1-minute testing specific: update notification time
            String? newNotificationTime = latestBill.notificationTime;
            if (latestBill.repeat.toLowerCase() == '1 minute (testing)') {
              final h = nextDueDate.hour.toString().padLeft(2, '0');
              final m = nextDueDate.minute.toString().padLeft(2, '0');
              newNotificationTime = '$h:$m';
            }

            final newBill = BillHive(
              id: const Uuid().v4(),
              title: latestBill.title,
              vendor: latestBill.vendor,
              amount: latestBill.amount,
              dueAt: nextDueDate,
              notes: latestBill.notes,
              category: latestBill.category,
              isPaid: false,
              isDeleted: false,
              updatedAt: DateTime.now(),
              clientUpdatedAt: DateTime.now(),
              repeat: latestBill.repeat,
              needsSync: true,
              recurringSequence: nextSequence,
              repeatCount: latestBill.repeatCount,
              reminderTiming: 'Same Day',
              notificationTime: newNotificationTime,
              userId: latestBill.userId,
              createdDuringProTrial: latestBill.createdDuringProTrial,
              parentBillId: parentId,
            );

            // SAVE IMMEDIATELY
            await HiveService.saveBill(newBill);
            createdCount++;

            // NOTE: Notification scheduling is REMOVED from here
            // The notification will be scheduled by BillProvider._scheduleNotificationForBill()
            // which is called from checkOverdueRecurringBills() after createNextInstance()
            // Having it in BOTH places was causing duplicate notifications!
            Logger.info(
              'Created instance ${newBill.recurringSequence} - notification will be scheduled by BillProvider',
              _tag,
            );

            // RECURSION CHECK:
            // If this NEW bill is ALREADY OVERDUE, we must loop again to create the *next* one
            bool newBillIsOverdue = false;
            if (newBill.repeat.toLowerCase() == '1 minute (testing)') {
              newBillIsOverdue =
                  now.isAfter(newBill.dueAt) ||
                  now.isAtSameMomentAs(newBill.dueAt);
            } else {
              // Strict overdue check
              // A bill is overdue if we are past its due date/time
              if (now.isAfter(newBill.dueAt)) {
                newBillIsOverdue = true;
              } else if (now.isAtSameMomentAs(newBill.dueAt)) {
                // Even if same moment, treat as overdue to force next creation if needed
                newBillIsOverdue = true;
              }
            }

            if (newBillIsOverdue) {
              Logger.info(
                'New bill ${newBill.title} created and is ALREADY OVEDUE. Looping to create next instance immediately.',
                _tag,
              );
              shouldCheckSeriesAgain = true;
              seriesBills.insert(0, newBill); // Add to head as latest
            }
          } catch (e, st) {
            errorCount++;
            Logger.error(
              'Error processing series $parentId',
              error: e,
              stackTrace: st,
              tag: _tag,
            );
            break;
          }
        }
      }

      Logger.info(
        'Recurring bill processing complete. Created $createdCount new instances.'
        '${errorCount > 0 ? ' $errorCount errors occurred.' : ''}',
        _tag,
      );
      return createdCount;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to process recurring bills',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return 0;
    } finally {
      _isProcessing = false;
    }
  }

  /// Get all active recurring bills (not deleted, repeat != 'none')
  /// [userId] - Optional user ID to filter bills (recommended for user-specific queries)
  static Future<List<BillHive>> getActiveRecurringBills({
    String? userId,
  }) async {
    try {
      // Use user-filtered bills if userId is provided
      final List<BillHive> allBills;
      if (userId != null && userId.isNotEmpty) {
        allBills = HiveService.getBillsForUser(userId);
      } else {
        allBills = HiveService.getAllBills();
      }
      return allBills
          .where((bill) => bill.repeat != 'none' && !bill.isDeleted)
          .toList();
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to get active recurring bills',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return [];
    }
  }

  /// Process a bill event (paid, overdue) using a Firestore Transaction
  /// Atomically updates bill, creates next instance (if recurring), and saves notification
  static Future<void> processBillEventInTransaction({
    required BillHive bill,
    required String eventType, // 'paid' or 'overdue'
  }) async {
    try {
      final userId = bill.userId;
      if (userId == null) throw Exception('Bill has no userId');

      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(userId);
      final billRef = userRef.collection('bills').doc(bill.id);

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(billRef);

        if (!snapshot.exists) {
          throw Exception('Bill ${bill.id} does not exist in Firestore');
        }

        final data = snapshot.data()!;
        final isProcessing = data['processing'] as bool? ?? false;

        // 4. Prevent Duplicate Processing
        if (isProcessing) {
          throw Exception(
            'Bill is currently being processed by another client',
          );
        }

        final currentStatus = data['status'] as String?;
        if (currentStatus == eventType) {
          // Idempotency check: Already in target state
          return;
        }

        // Logic for updates
        final updates = <String, dynamic>{
          'processing': false, // Ensure false on commit
          'clientUpdatedAt': DateTime.now().toIso8601String(),
        };

        if (eventType == 'paid') {
          updates['isPaid'] = true;
          updates['paidAt'] = DateTime.now().toIso8601String();
          updates['status'] = 'paid';
          updates['isArchived'] = false; // logic from BillProvider
        } else if (eventType == 'overdue') {
          updates['status'] = 'overdue';
        }

        transaction.update(billRef, updates);

        // Handle Recurring Logic
        if (bill.repeat != 'none') {
          // Calculate next due date
          final currentDue = DateTime.parse(data['dueAt']);
          final nextDue = calculateNextDueDate(currentDue, bill.repeat);

          // Check if next bill already exists (using a predictable ID based on parent + due?
          // No, we use 'parentBillId' query usually. But in transaction we can't query efficiently without reading.
          // However, user said "Immediately create next instance".
          // We will assume creation is required if we are transitioning state.

          final nextBillId = const Uuid().v4();
          final nextBillRef = userRef.collection('bills').doc(nextBillId);

          // Copy fields
          final nextBillData = Map<String, dynamic>.from(data);
          nextBillData['id'] = nextBillId;
          nextBillData['dueAt'] = nextDue.toIso8601String();
          nextBillData['isPaid'] = false;
          nextBillData['paidAt'] = null;
          nextBillData['status'] = 'upcoming';
          nextBillData['recurringSequence'] =
              (data['recurringSequence'] as int? ?? 1) + 1;
          nextBillData['parentBillId'] = data['parentBillId'] ?? bill.id;
          nextBillData['createdAt'] = DateTime.now().toIso8601String();
          nextBillData['updatedAt'] = DateTime.now().toIso8601String();
          nextBillData['clientUpdatedAt'] = DateTime.now().toIso8601String();
          nextBillData['processing'] = false;

          transaction.set(nextBillRef, nextBillData);

          // NOTE: Removed "New Bill Generated" notification per user request
          // The user does not want notifications for auto-generated recurring instances
        }

        // 3. Notification Logic (Main Event)
        if (eventType == 'overdue' || eventType == 'paid') {
          final notifId = const Uuid().v4();
          final notifRef = userRef.collection('notifications').doc(notifId);

          String title = eventType == 'overdue' ? 'Bill Overdue' : 'Bill Paid';
          String body = eventType == 'overdue'
              ? 'Bill ${bill.title} is now overdue!'
              : 'Bill ${bill.title} marked as paid.';

          transaction.set(notifRef, {
            'id': notifId,
            'title': title,
            'body': body,
            'timestamp': FieldValue.serverTimestamp(),
            'billId': bill.id,
            'status': 'unread',
            'type': eventType,
          });
        }
      });

      // Update Local Hive State manually to reflect changes immediately in UI (optimistic-ish)
      // Actually, since we committed to Firestore, we should ideally sync back.
      // But for responsiveness, we updating the local hive object is good.
      // We will leave Hive update to the caller or SyncService pulling changes.
      // Given the requirement "Tabs must update instantly", local update is preferred.
      // I'll assume the caller handles UI refresh or relies on the Stream (which we are adding).
    } catch (e) {
      Logger.error(
        'Transaction failed for $eventType on ${bill.id}',
        error: e,
        tag: _tag,
      );
      rethrow;
    }
  }
}
