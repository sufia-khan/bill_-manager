import 'package:uuid/uuid.dart';
import '../models/bill_hive.dart';
import '../utils/logger.dart';
import 'hive_service.dart';
import 'notification_service.dart';

/// Service for managing recurring bill operations
/// Handles automatic creation of recurring bill instances
class RecurringBillService {
  static const String _tag = 'RecurringBillService';

  // Lock to prevent concurrent processing
  static bool _isProcessing = false;

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

  /// Check if next instance of a recurring bill already exists
  /// Returns true if a bill with matching parentBillId and due date exists
  /// [excludeBillId] - ID of the bill being processed (to exclude from check)
  /// Returns false on error to prevent duplicate creation
  static Future<bool> hasNextInstance(
    String parentBillId,
    DateTime nextDueDate, {
    String? excludeBillId,
  }) async {
    try {
      // Validate input
      if (parentBillId.isEmpty) {
        throw ArgumentError('Parent bill ID cannot be empty');
      }

      final allBills = HiveService.getAllBills();

      // Check if any bill has this parentBillId and a due date close to nextDueDate
      // Using 30-second tolerance for 1-minute testing, works for all intervals
      final startRange = nextDueDate.subtract(const Duration(seconds: 30));
      final endRange = nextDueDate.add(const Duration(seconds: 30));

      return allBills.any(
        (bill) =>
            bill.id != excludeBillId && // Exclude the source bill
            bill.parentBillId == parentBillId &&
            bill.dueAt.isAfter(startRange) &&
            bill.dueAt.isBefore(endRange) &&
            !bill.isDeleted,
      );
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

  /// Create the next instance of a recurring bill
  /// Copies data from parent bill and sets new due date
  /// Returns the created bill or null if creation fails
  static Future<BillHive?> createNextInstance(BillHive parentBill) async {
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
      if (nextDueDate.isBefore(DateTime.now())) {
        Logger.warning(
          'Calculated next due date is in the past for ${parentBill.title}',
          _tag,
        );
      }

      // Check if next instance already exists (exclude current bill from check)
      final exists = await hasNextInstance(
        parentBill.id,
        nextDueDate,
        excludeBillId: parentBill.id,
      );
      if (exists) {
        Logger.info(
          'Next instance already exists for bill: ${parentBill.title}',
          _tag,
        );
        return null;
      }

      // Determine parent ID and sequence
      final parentId = parentBill.parentBillId ?? parentBill.id;
      final sequence = (parentBill.recurringSequence ?? 1) + 1;

      // Create new bill instance
      final now = DateTime.now();
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
        parentBillId: parentId,
        recurringSequence: sequence,
        repeatCount: parentBill.repeatCount, // Copy repeat count limit
        reminderTiming: parentBill.reminderTiming, // Copy notification settings
        notificationTime: parentBill.notificationTime,
      );

      // Save to Hive
      await HiveService.saveBill(newBill);

      Logger.info(
        'Created next instance for ${parentBill.title}: '
        'Due ${nextDueDate.toString().split(' ')[0]}, Sequence: $sequence',
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
  static Future<int> processRecurringBills() async {
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
      final allBills = HiveService.getAllBills(forceRefresh: true);
      final recurringBills = allBills
          .where((bill) => bill.repeat != 'none' && !bill.isDeleted)
          .toList();

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

      // Batch process - collect new bills to create
      final newBills = <BillHive>[];

      for (final entry in seriesMap.entries) {
        final parentId = entry.key;
        final seriesBills = entry.value;

        try {
          // Debug: Log series info
          Logger.info(
            'Checking series $parentId with ${seriesBills.length} bills',
            _tag,
          );
          for (final b in seriesBills) {
            Logger.info(
              '  - ${b.title} seq=${b.recurringSequence} paid=${b.isPaid} due=${b.dueAt}',
              _tag,
            );
          }

          // CRITICAL: Check if there's already an active (upcoming/unpaid) instance
          // If yes, don't create a new one - wait until it's paid or becomes overdue
          final hasActive = _hasActiveInstanceInSeries(parentId, allBills);
          Logger.info('Series $parentId hasActiveInstance=$hasActive', _tag);

          if (hasActive) {
            Logger.info(
              'Series $parentId already has an active instance - skipping',
              _tag,
            );
            continue;
          }

          // Check if the series was cancelled (deleted upcoming bill)
          // A series is cancelled if ANY upcoming (unpaid) bill in the series was deleted
          // This prevents creating new instances after user deletes an upcoming bill
          final deletedUpcomingBills = allBillsIncludingDeleted.where((b) {
            final bParentId = b.parentBillId ?? b.id;
            final isInSeries = bParentId == parentId || b.id == parentId;
            return isInSeries && b.isDeleted && !b.isPaid;
          }).toList();

          if (deletedUpcomingBills.isNotEmpty) {
            // Find the highest sequence number among deleted upcoming bills
            // This tells us from which point the series was cancelled
            int? maxDeletedSequence;
            for (final deleted in deletedUpcomingBills) {
              final seq = deleted.recurringSequence ?? 0;
              if (maxDeletedSequence == null || seq > maxDeletedSequence) {
                maxDeletedSequence = seq;
              }
            }

            // Get the latest non-deleted bill's sequence
            final latestNonDeletedSequence = seriesBills.isNotEmpty
                ? seriesBills
                      .map((b) => b.recurringSequence ?? 0)
                      .reduce((a, b) => a > b ? a : b)
                : 0;

            // If the deleted sequence is >= latest non-deleted, series is cancelled
            // This means user deleted the current/future bills, so stop creating more
            if (maxDeletedSequence != null &&
                maxDeletedSequence >= latestNonDeletedSequence) {
              Logger.info(
                'Recurring series $parentId was cancelled at sequence $maxDeletedSequence - skipping',
                _tag,
              );
              continue;
            }

            // If deleted sequence is less than latest, it was just a single occurrence deletion
            // (e.g., user deleted occurrence 2 but kept 3, 4, etc.)
            Logger.info(
              'Series $parentId has deleted occurrence(s) but continues from sequence $latestNonDeletedSequence',
              _tag,
            );
          }

          // Find the latest bill in the series (highest sequence or most recent due date)
          seriesBills.sort((a, b) {
            final seqA = a.recurringSequence ?? 0;
            final seqB = b.recurringSequence ?? 0;
            if (seqA != seqB) {
              return seqB.compareTo(seqA); // Higher sequence first
            }
            return b.dueAt.compareTo(a.dueAt); // More recent due date first
          });

          final latestBill = seriesBills.first;

          // Check if latest bill is paid or overdue
          bool isOverdue = false;
          if (!latestBill.isPaid) {
            // For 1-minute testing, use exact time comparison
            if (latestBill.repeat.toLowerCase() == '1 minute (testing)') {
              // Bill is overdue if current time is past the due time
              isOverdue =
                  now.isAfter(latestBill.dueAt) ||
                  now.isAtSameMomentAs(latestBill.dueAt);
            } else {
              // For other recurring types, use date + reminder time logic
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

          Logger.info(
            'Latest bill ${latestBill.title}: isPaid=${latestBill.isPaid}, isOverdue=$isOverdue, dueAt=${latestBill.dueAt}, now=$now',
            _tag,
          );

          // Only create next instance if latest bill is PAID or OVERDUE
          if (!latestBill.isPaid && !isOverdue) {
            Logger.info(
              'Skipping ${latestBill.title}: not paid and not overdue yet',
              _tag,
            );
            continue; // Bill is still upcoming - wait
          }

          Logger.info(
            'Will create next instance for ${latestBill.title} (paid=${latestBill.isPaid}, overdue=$isOverdue)',
            _tag,
          );

          // Check repeat count limit
          final currentSequence = latestBill.recurringSequence ?? 1;
          final nextSequence = currentSequence + 1;

          if (latestBill.repeatCount != null &&
              nextSequence > latestBill.repeatCount!) {
            Logger.info(
              'Repeat count limit reached for ${latestBill.title}: $currentSequence/${latestBill.repeatCount}',
              _tag,
            );
            continue;
          }

          // Calculate next due date from the latest bill
          var nextDueDate = calculateNextDueDate(
            latestBill.dueAt,
            latestBill.repeat,
          );

          // For 1-minute testing, if next due date is in the past,
          // set it to 1 minute from now to catch up
          if (latestBill.repeat.toLowerCase() == '1 minute (testing)') {
            if (nextDueDate.isBefore(now) ||
                nextDueDate.isAtSameMomentAs(now)) {
              // Set next due date to 1 minute from now
              nextDueDate = now.add(const Duration(minutes: 1));
              Logger.info(
                'Adjusted next due date for ${latestBill.title} to $nextDueDate (was in past)',
                _tag,
              );
            }
          }

          // Double-check no instance exists for this due date
          final exists = await hasNextInstance(
            parentId,
            nextDueDate,
            excludeBillId: latestBill.id,
          );

          if (exists) {
            Logger.info(
              'Next instance already exists for ${latestBill.title}',
              _tag,
            );
            continue;
          }

          // Create the next instance
          final nowTimestamp = DateTime.now();

          // For 1-minute testing, update notification time to match the new due time
          // This ensures notifications are scheduled correctly for each instance
          String? newNotificationTime = latestBill.notificationTime;
          if (latestBill.repeat.toLowerCase() == '1 minute (testing)') {
            // Set notification time to the due time of the new instance
            final hour = nextDueDate.hour.toString().padLeft(2, '0');
            final minute = nextDueDate.minute.toString().padLeft(2, '0');
            newNotificationTime = '$hour:$minute';
            Logger.info(
              'Updated notification time for 1-minute recurring: $newNotificationTime',
              _tag,
            );
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
            updatedAt: nowTimestamp,
            clientUpdatedAt: nowTimestamp,
            repeat: latestBill.repeat,
            needsSync: true,
            paidAt: null,
            isArchived: false,
            archivedAt: null,
            parentBillId: parentId,
            recurringSequence: nextSequence,
            repeatCount: latestBill.repeatCount,
            reminderTiming: 'Same Day', // For 1-minute testing, always same day
            notificationTime: newNotificationTime,
          );

          newBills.add(newBill);

          Logger.info(
            'Queued next instance for ${latestBill.title}: '
            'Due ${nextDueDate.toString().split(' ')[0]}, Sequence: $nextSequence',
            _tag,
          );
        } catch (e, stackTrace) {
          errorCount++;
          Logger.error(
            'Failed to process recurring series $parentId',
            error: e,
            stackTrace: stackTrace,
            tag: _tag,
          );
        }
      }

      // Batch save all new bills and schedule notifications
      if (newBills.isNotEmpty) {
        final notificationService = NotificationService();
        final currentUserId =
            HiveService.getUserData('currentUserId') as String?;

        for (final bill in newBills) {
          try {
            await HiveService.saveBill(bill);
            createdCount++;

            // Schedule notification for the new recurring instance
            // For 1-minute testing, use the exact due time for notification
            if (bill.repeat.toLowerCase() == '1 minute (testing)') {
              // Use exact due time for 1-minute testing
              await notificationService.scheduleBillNotification(
                bill,
                daysBeforeDue: 0,
                notificationHour: bill.dueAt.hour,
                notificationMinute: bill.dueAt.minute,
                userId: currentUserId,
              );
            } else {
              // For regular recurring bills, use reminder settings
              int notificationHour = 9;
              int notificationMinute = 0;
              if (bill.notificationTime != null) {
                final parts = bill.notificationTime!.split(':');
                notificationHour = int.parse(parts[0]);
                notificationMinute = int.parse(parts[1]);
              }

              // Get days offset from reminder timing
              int daysOffset = 0;
              if (bill.reminderTiming != null) {
                switch (bill.reminderTiming) {
                  case '1 Day Before':
                    daysOffset = 1;
                    break;
                  case '2 Days Before':
                    daysOffset = 2;
                    break;
                  case '1 Week Before':
                    daysOffset = 7;
                    break;
                  case 'Same Day':
                  default:
                    daysOffset = 0;
                }
              }

              await notificationService.scheduleBillNotification(
                bill,
                daysBeforeDue: daysOffset,
                notificationHour: notificationHour,
                notificationMinute: notificationMinute,
                userId: currentUserId,
              );
            }

            Logger.info(
              'Created next instance for ${bill.title}: '
              'Due ${bill.dueAt}, '
              'Sequence: ${bill.recurringSequence}',
              _tag,
            );
          } catch (e, stackTrace) {
            errorCount++;
            Logger.error(
              'Failed to save new bill instance',
              error: e,
              stackTrace: stackTrace,
              tag: _tag,
            );
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
  static Future<List<BillHive>> getActiveRecurringBills() async {
    try {
      final allBills = HiveService.getAllBills();
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
}
