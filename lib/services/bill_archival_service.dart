import '../models/bill_hive.dart';
import '../utils/logger.dart';
import '../services/hive_service.dart';

/// Service for managing automatic archival of paid bills immediately
class BillArchivalService {
  static const String _tag = 'BillArchivalService';

  /// Check if a bill is eligible for archival
  /// Returns true if the bill is paid and 2 days have passed since payment
  /// Returns false on error or invalid data
  static bool isEligibleForArchival(BillHive bill) {
    try {
      // Must be paid
      if (!bill.isPaid) {
        return false;
      }

      // Must have a payment date
      if (bill.paidAt == null) {
        Logger.warning(
          'Bill ${bill.id} (${bill.title}) is marked as paid but has no payment date',
          _tag,
        );
        return false;
      }

      // Must not already be archived
      if (bill.isArchived) {
        return false;
      }

      // Validate payment date is not in the future
      final now = DateTime.now();
      if (bill.paidAt!.isAfter(now)) {
        Logger.warning(
          'Bill ${bill.id} (${bill.title}) has payment date in the future',
          _tag,
        );
        return false;
      }

      // Must wait 30 days after payment before archiving
      final daysSincePayment = now.difference(bill.paidAt!).inDays;
      return daysSincePayment >= 30;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to check archival eligibility for bill ${bill.id}',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return false;
    }
  }

  /// Archive a single bill
  /// Sets isArchived to true, sets archivedAt timestamp, and marks for sync
  /// Throws exception if archival fails
  static Future<void> archiveBill(BillHive bill) async {
    try {
      // Validate bill is eligible for archival
      if (!bill.isPaid) {
        throw ArgumentError('Cannot archive unpaid bill: ${bill.title}');
      }

      if (bill.paidAt == null) {
        throw ArgumentError(
          'Cannot archive bill without payment date: ${bill.title}',
        );
      }

      if (bill.isArchived) {
        Logger.warning(
          'Bill ${bill.id} (${bill.title}) is already archived',
          _tag,
        );
        return;
      }

      final now = DateTime.now();

      final archivedBill = bill.copyWith(
        isArchived: true,
        archivedAt: now,
        updatedAt: now,
        clientUpdatedAt: now,
        needsSync: true,
      );

      await HiveService.saveBill(archivedBill);

      Logger.info('Archived bill ${bill.id} (${bill.title})', _tag);
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to archive bill ${bill.id} (${bill.title})',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      rethrow;
    }
  }

  /// Process all paid bills and archive those eligible for archival
  /// Returns the count of bills that were archived
  /// Optimized with batch processing and early filtering
  static Future<int> processArchival() async {
    try {
      final now = DateTime.now();

      // Get all paid bills that are not archived - use cached version
      final allBills = HiveService.getAllBills();
      final paidBills = allBills
          .where(
            (bill) => bill.isPaid && !bill.isArchived && bill.paidAt != null,
          )
          .toList();

      if (paidBills.isEmpty) {
        Logger.info('No paid bills to process for archival', _tag);
        return 0;
      }

      Logger.info(
        'Processing ${paidBills.length} paid bills for archival...',
        _tag,
      );

      // Bills are eligible for archival 30 days after payment
      final eligibleBills = paidBills.where((bill) {
        final daysSincePayment = now.difference(bill.paidAt!).inDays;
        return daysSincePayment >= 30;
      }).toList();

      if (eligibleBills.isEmpty) {
        Logger.info('No bills eligible for archival', _tag);
        return 0;
      }

      Logger.info(
        'Found ${eligibleBills.length} bills eligible for archival',
        _tag,
      );

      int archivedCount = 0;
      int errorCount = 0;

      // Batch archive eligible bills
      for (final bill in eligibleBills) {
        try {
          final archivedBill = bill.copyWith(
            isArchived: true,
            archivedAt: now,
            updatedAt: now,
            clientUpdatedAt: now,
            needsSync: true,
          );

          await HiveService.saveBill(archivedBill);
          archivedCount++;

          Logger.info('Archived bill ${bill.id} (${bill.title})', _tag);
        } catch (e, stackTrace) {
          errorCount++;
          Logger.error(
            'Failed to archive bill ${bill.id} (${bill.title})',
            error: e,
            stackTrace: stackTrace,
            tag: _tag,
          );
          // Continue processing other bills
        }
      }

      Logger.info(
        'Archival processing complete. Archived $archivedCount bills.'
        '${errorCount > 0 ? ' $errorCount errors occurred.' : ''}',
        _tag,
      );

      return archivedCount;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to process archival',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return 0;
    }
  }

  /// Get all archived bills with optional filtering
  /// Supports filtering by date range and category
  /// Returns bills sorted by payment date descending (most recent first)
  static List<BillHive> getArchivedBills({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    try {
      // Validate date range if provided
      if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
        Logger.warning(
          'Invalid date range: start date is after end date',
          _tag,
        );
        return [];
      }

      return HiveService.getArchivedBills(
        startDate: startDate,
        endDate: endDate,
        category: category,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to get archived bills',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return [];
    }
  }

  /// Auto-delete archived bills that are older than 90 days
  /// Returns the count of bills that were deleted
  static Future<int> processAutoDeletion() async {
    try {
      final now = DateTime.now();

      // Get all archived bills
      final archivedBills = HiveService.getArchivedBills();

      if (archivedBills.isEmpty) {
        Logger.info('No archived bills to process for auto-deletion', _tag);
        return 0;
      }

      Logger.info(
        'Processing ${archivedBills.length} archived bills for auto-deletion...',
        _tag,
      );

      // Bills are eligible for deletion 90 days after archival
      final eligibleBills = archivedBills.where((bill) {
        if (bill.archivedAt == null) return false;
        final daysSinceArchival = now.difference(bill.archivedAt!).inDays;
        return daysSinceArchival >= 90;
      }).toList();

      if (eligibleBills.isEmpty) {
        Logger.info('No bills eligible for auto-deletion', _tag);
        return 0;
      }

      Logger.info(
        'Found ${eligibleBills.length} bills eligible for auto-deletion',
        _tag,
      );

      int deletedCount = 0;
      int errorCount = 0;

      // Delete eligible bills
      for (final bill in eligibleBills) {
        try {
          await HiveService.deleteBill(bill.id);
          deletedCount++;

          Logger.info(
            'Auto-deleted bill ${bill.id} (${bill.title}) - archived ${now.difference(bill.archivedAt!).inDays} days ago',
            _tag,
          );
        } catch (e, stackTrace) {
          errorCount++;
          Logger.error(
            'Failed to auto-delete bill ${bill.id} (${bill.title})',
            error: e,
            stackTrace: stackTrace,
            tag: _tag,
          );
          // Continue processing other bills
        }
      }

      Logger.info(
        'Auto-deletion processing complete. Deleted $deletedCount bills.'
        '${errorCount > 0 ? ' $errorCount errors occurred.' : ''}',
        _tag,
      );

      return deletedCount;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to process auto-deletion',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return 0;
    }
  }

  // Note: Bills are archived 30 days after payment and auto-deleted 90 days after archival
}
