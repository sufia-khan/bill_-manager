import 'package:flutter/material.dart';
import '../models/sync_status.dart';

/// Small sync status indicator widget
/// Shows sync status with emoji and optional tooltip
class SyncStatusIndicator extends StatelessWidget {
  final SyncStatus status;
  final bool showLabel;
  final double size;

  const SyncStatusIndicator({
    super.key,
    required this.status,
    this.showLabel = false,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: status.label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status.emoji, style: TextStyle(fontSize: size)),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              status.label,
              style: TextStyle(
                fontSize: size * 0.75,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
