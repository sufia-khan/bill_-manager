import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/sync_provider.dart';

/// Widget to display sync statistics and status
/// Shows online/offline status, pending changes, last sync time, and Firebase usage
class SyncStatsWidget extends StatelessWidget {
  const SyncStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_sync,
                    color: syncProvider.isOnline
                        ? const Color(0xFF059669)
                        : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sync Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: syncProvider.isOnline
                          ? const Color(0xFF059669).withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      syncProvider.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: syncProvider.isOnline
                            ? const Color(0xFF059669)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatRow(
                'Pending Changes',
                '${syncProvider.pendingChanges}',
                Icons.pending_actions,
                syncProvider.pendingChanges > 0
                    ? const Color(0xFFFF8C00)
                    : Colors.grey,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                'Last Sync',
                syncProvider.lastSyncTime != null
                    ? timeago.format(syncProvider.lastSyncTime!)
                    : 'Never',
                Icons.access_time,
                Colors.grey,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                'Firebase Reads',
                '${syncProvider.totalReads}',
                Icons.download,
                const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                'Firebase Writes',
                '${syncProvider.totalWrites}',
                Icons.upload,
                const Color(0xFF8B5CF6),
              ),
              if (syncProvider.isSyncing) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF8C00),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Syncing...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
              if (syncProvider.pendingChanges > 0 &&
                  !syncProvider.isSyncing &&
                  syncProvider.isOnline) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => syncProvider.triggerSync(),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sync Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
