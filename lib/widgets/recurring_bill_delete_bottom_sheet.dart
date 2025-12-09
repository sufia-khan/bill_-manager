import 'package:flutter/material.dart';
import '../models/bill_hive.dart';

enum RecurringDeleteOption { thisOccurrence, thisAndFuture, entireSeries }

class RecurringBillDeleteBottomSheet {
  static Future<RecurringDeleteOption?> show(
    BuildContext context,
    BillHive bill,
  ) async {
    final repeatCount = bill.repeatCount;
    final sequence = bill.recurringSequence ?? 0;

    // Calculate remaining occurrences
    int? remainingOccurrences;
    if (repeatCount != null && sequence > 0) {
      remainingOccurrences = repeatCount - sequence;
    }

    return showModalBottomSheet<RecurringDeleteOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFEF4444),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Delete Recurring Bill',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Bill info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRecurrenceDescription(
                          bill.repeat,
                          repeatCount,
                          sequence,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Description
                Text(
                  'Choose how you want to delete this recurring bill:',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),

                // Option 1: Delete only this occurrence
                _buildOption(
                  context,
                  icon: Icons.event_busy,
                  title: 'Delete only this occurrence',
                  description: _getThisOccurrenceDescription(
                    remainingOccurrences,
                  ),
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.pop(
                    context,
                    RecurringDeleteOption.thisOccurrence,
                  ),
                ),
                const SizedBox(height: 12),

                // Option 2: Delete this and future
                if (remainingOccurrences == null || remainingOccurrences > 0)
                  _buildOption(
                    context,
                    icon: Icons.event_repeat,
                    title: 'Delete this and all future',
                    description: _getThisAndFutureDescription(
                      remainingOccurrences,
                    ),
                    color: const Color(0xFFEF4444),
                    onTap: () => Navigator.pop(
                      context,
                      RecurringDeleteOption.thisAndFuture,
                    ),
                  ),
                if (remainingOccurrences == null || remainingOccurrences > 0)
                  const SizedBox(height: 12),

                // Option 3: Delete entire series
                _buildOption(
                  context,
                  icon: Icons.delete_forever,
                  title: 'Delete entire series',
                  description:
                      'Permanently delete all past, current, and future occurrences',
                  color: const Color(0xFF991B1B),
                  onTap: () => Navigator.pop(
                    context,
                    RecurringDeleteOption.entireSeries,
                  ),
                ),
                const SizedBox(height: 16),

                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  static String _getRecurrenceDescription(
    String repeat,
    int? repeatCount,
    int sequence,
  ) {
    final repeatText = repeat == 'none'
        ? 'One-time'
        : repeat.substring(0, 1).toUpperCase() + repeat.substring(1);

    if (repeatCount == null) {
      return '$repeatText • Recurring';
    } else {
      final remaining = repeatCount - sequence;
      return '$repeatText • ${sequence + 1} of $repeatCount ($remaining remaining)';
    }
  }

  static String _getThisOccurrenceDescription(int? remainingOccurrences) {
    if (remainingOccurrences == null) {
      return 'Future bills will continue as scheduled';
    } else if (remainingOccurrences == 0) {
      return 'This is the last occurrence';
    } else if (remainingOccurrences == 1) {
      return '1 future occurrence will remain';
    } else {
      return '$remainingOccurrences future occurrences will remain';
    }
  }

  static String _getThisAndFutureDescription(int? remainingOccurrences) {
    if (remainingOccurrences == null) {
      return 'Stop all future recurring bills';
    } else if (remainingOccurrences == 1) {
      return 'Delete this and 1 future occurrence';
    } else {
      return 'Delete this and $remainingOccurrences future occurrences';
    }
  }
}
