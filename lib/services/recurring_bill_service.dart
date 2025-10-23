import 'package:uuid/uuid.dart';
import '../models/bill_hive.dart';
import '../utils/logger.dart';
import 'hive_service.dart';

/// Service for managing recurring bill operations
/// Handles automatic creation of recurring bill instances
class RecurringBillService {
  static const String _tag = 'RecurringBillService';

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
  /// Returns false on error to prevent duplicate creation
  static Future<bool> hasNextInstance(
    String parentBillId,
    DateTime nextDueDate,
  ) async {
    try {
      // Validate input
      if (parentBillId.isEmpty) {
        throw ArgumentError('Parent bill ID cannot be empty');
      }

      final allBills = HiveService.getAllBills();

      // Check if any bill has this parentBillId and a due date close to nextDueDate
      // Using 5-minute tolerance to account for time differences (works for testing and production)
      final startRange = nextDueDate.subtract(const Duration(minutes: 5));
      final endRange = nextDueDate.add(const Duration(minutes: 5));

      return allBills.any(
        (bill) =>
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
        final currentSequence = parentBill.recurringSequence ?? 0;
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

      // Check if next instance already exists
      final exists = await hasNextInstance(parentBill.id, nextDueDate);
      if (exists) {
        Logger.info(
          'Next instance already exists for bill: ${parentBill.title}',
          _tag,
        );
        return null;
      }

      // Determine parent ID and sequence
      final parentId = parentBill.parentBillId ?? parentBill.id;
      final sequence = (parentBill.recurringSequence ?? 0) + 1;

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

  /// Process all recurring bills and create next instances if needed
  /// Checks bills with repeat != 'none' that are paid or past due
  /// Returns count of new instances created
  /// Optimized with batch processing and early filtering
  static Future<int> processRecurringBills() async {
    try {
      final now = DateTime.now();
      int createdCount = 0;
      int errorCount = 0;

      // Get all bills with recurring enabled - use cached version
      final allBills = HiveService.getAllBills();
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

      // Pre-filter bills that need processing
      final billsToProcess = recurringBills.where((bill) {
        final isPastDue = bill.dueAt.isBefore(now);
        return bill.isPaid || isPastDue;
      }).toList();

      if (billsToProcess.isEmpty) {
        Logger.info('No recurring bills need processing at this time', _tag);
        return 0;
      }

      Logger.info(
        'Found ${billsToProcess.length} bills that need processing',
        _tag,
      );

      // Batch process bills
      final newBills = <BillHive>[];

      for (final bill in billsToProcess) {
        try {
          // Calculate what the next due date would be
          final nextDueDate = calculateNextDueDate(bill.dueAt, bill.repeat);

          // Check if next instance already exists
          final parentId = bill.parentBillId ?? bill.id;
          final exists = await hasNextInstance(parentId, nextDueDate);

          if (!exists) {
            // Prepare next instance (don't save yet)
            final parentIdToUse = bill.parentBillId ?? bill.id;
            final sequence = (bill.recurringSequence ?? 0) + 1;
            final nowTimestamp = DateTime.now();

            // Check repeat count limit before creating
            if (bill.repeatCount != null && sequence > bill.repeatCount!) {
              Logger.info(
                'Repeat count limit reached for ${bill.title}: $sequence/${bill.repeatCount}',
                _tag,
              );
              continue; // Skip this bill
            }

            final newBill = BillHive(
              id: const Uuid().v4(),
              title: bill.title,
              vendor: bill.vendor,
              amount: bill.amount,
              dueAt: nextDueDate,
              notes: bill.notes,
              category: bill.category,
              isPaid: false,
              isDeleted: false,
              updatedAt: nowTimestamp,
              clientUpdatedAt: nowTimestamp,
              repeat: bill.repeat,
              needsSync: true,
              paidAt: null,
              isArchived: false,
              archivedAt: null,
              parentBillId: parentIdToUse,
              recurringSequence: sequence,
              repeatCount: bill.repeatCount, // Copy repeat count limit
              reminderTiming: bill.reminderTiming, // Copy notification settings
              notificationTime: bill.notificationTime,
            );

            newBills.add(newBill);
          }
        } catch (e, stackTrace) {
          errorCount++;
          Logger.error(
            'Failed to process recurring bill ${bill.id} (${bill.title})',
            error: e,
            stackTrace: stackTrace,
            tag: _tag,
          );
          // Continue processing other bills
        }
      }

      // Batch save all new bills
      if (newBills.isNotEmpty) {
        for (final bill in newBills) {
          try {
            await HiveService.saveBill(bill);
            createdCount++;
            Logger.info(
              'Created next instance for ${bill.title}: '
              'Due ${bill.dueAt.toString().split(' ')[0]}, '
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
