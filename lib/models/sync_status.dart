/// Sync status for bills
enum SyncStatus {
  synced, // ✅ Synced with Firebase
  pending, // 🔄 Waiting to sync
  syncing, // ⏳ Currently syncing
  error, // ❌ Sync failed
  offline, // 📵 Offline (will sync when online)
}

extension SyncStatusExtension on SyncStatus {
  String get emoji {
    switch (this) {
      case SyncStatus.synced:
        return '✅';
      case SyncStatus.pending:
        return '🔄';
      case SyncStatus.syncing:
        return '⏳';
      case SyncStatus.error:
        return '❌';
      case SyncStatus.offline:
        return '📵';
    }
  }

  String get label {
    switch (this) {
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.pending:
        return 'Pending';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.error:
        return 'Error';
      case SyncStatus.offline:
        return 'Offline';
    }
  }
}
