import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_hive.dart';
import 'hive_service.dart';

/// Service to process pending recurring bills created by native AlarmReceiver
/// When app was closed, AlarmReceiver schedules next recurring alarms
/// This service syncs those pending bills to Hive when app opens
class PendingRecurringService {
  static const platform = MethodChannel('com.example.bill_manager/prefs');

  /// Process any pending recurring bills from native SharedPreferences
  static Future<int> processPendingRecurringBills() async {
    try {
      String? pendingData;

      try {
        pendingData = await platform.invokeMethod<String>(
          'getPendingRecurringBills',
        );
      } catch (e) {
        debugPrint('⚠️ Platform channel not available for recurring bills: $e');
        return 0;
      }

      if (pendingData == null || pendingData == '[]' || pendingData.isEmpty) {
        debugPrint('📭 No pending recurring bills to process');
        return 0;
      }

      debugPrint('📬 Processing pending recurring bills from native layer...');
      debugPrint('📋 Raw data: $pendingData');

      final List<dynamic> bills = jsonDecode(pendingData);
      int createdCount = 0;

      for (var billData in bills) {
        try {
          final billId = billData['billId'] as String;
          final title = billData['title'] as String;
          final amount = (billData['amount'] as num).toDouble();
          final vendor = billData['vendor'] as String;
          // userId is stored but not used currently - kept for future user filtering
          // final userId = billData['userId'] as String?;
          final recurringType = billData['recurringType'] as String;
          final sequence = billData['sequence'] as int;
          final repeatCount = billData['repeatCount'] as int;
          final dueTime = billData['dueTime'] as int;

          final dueAt = DateTime.fromMillisecondsSinceEpoch(dueTime);

          // Check if this bill instance already exists
          final existingBills = HiveService.getAllBills();
          final alreadyExists = existingBills.any(
            (b) =>
                b.parentBillId == billId &&
                b.recurringSequence == sequence &&
                !b.isDeleted,
          );

          if (alreadyExists) {
            debugPrint(
              '⏭️ Skipping existing recurring bill: $title seq=$sequence',
            );
            continue;
          }

          // Find parent bill to get category and other details
          final parentBill = existingBills.firstWhere(
            (b) => b.id == billId || b.parentBillId == billId,
            orElse: () => BillHive(
              id: billId,
              title: title,
              vendor: vendor,
              amount: amount,
              dueAt: dueAt,
              category: 'Other',
              isPaid: false,
              isDeleted: false,
              updatedAt: DateTime.now(),
              clientUpdatedAt: DateTime.now(),
              repeat: recurringType,
              needsSync: true,
            ),
          );

          // Create new bill instance
          final now = DateTime.now();
          final newBill = BillHive(
            id: const Uuid().v4(),
            title: title,
            vendor: vendor,
            amount: amount,
            dueAt: dueAt,
            notes: parentBill.notes,
            category: parentBill.category,
            isPaid: false,
            isDeleted: false,
            updatedAt: now,
            clientUpdatedAt: now,
            repeat: recurringType,
            needsSync: true,
            paidAt: null,
            isArchived: false,
            archivedAt: null,
            parentBillId: billId,
            recurringSequence: sequence,
            repeatCount: repeatCount > 0 ? repeatCount : null,
            reminderTiming: parentBill.reminderTiming ?? 'Same Day',
            notificationTime: parentBill.notificationTime,
          );

          await HiveService.saveBill(newBill);
          createdCount++;

          debugPrint(
            '✅ Created recurring bill from native: $title seq=$sequence due=$dueAt',
          );
        } catch (e) {
          debugPrint('❌ Error processing pending recurring bill: $e');
        }
      }

      // Clear the pending recurring bills
      try {
        await platform.invokeMethod('clearPendingRecurringBills');
      } catch (e) {
        debugPrint('⚠️ Failed to clear pending recurring bills: $e');
      }

      debugPrint('✅ Processed $createdCount pending recurring bill(s)');
      return createdCount;
    } catch (e) {
      debugPrint('❌ Error processing pending recurring bills: $e');
      return 0;
    }
  }
}
