import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/hive_service.dart';

/// Widget that shows offline indicator and pending sync count
class OfflineIndicator extends StatefulWidget {
  const OfflineIndicator({super.key});

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  bool _isOnline = true;
  int _pendingChanges = 0;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenToConnectivity();
    _checkPendingChanges();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = !result.contains(ConnectivityResult.none);
      });
    }
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isOnline = !result.contains(ConnectivityResult.none);
        });
        _checkPendingChanges();
      }
    });
  }

  void _checkPendingChanges() {
    try {
      final bills = HiveService.getBillsNeedingSync();
      if (mounted) {
        setState(() {
          _pendingChanges = bills.length;
        });
      }
    } catch (e) {
      // Ignore errors - might happen if Hive not initialized yet
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show indicator if offline OR if there are pending changes
    if (_isOnline && _pendingChanges == 0) {
      return const SizedBox.shrink();
    }

    final isOffline = !_isOnline;
    final hasPending = _pendingChanges > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isOffline ? Colors.orange.shade100 : Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(
            color: isOffline ? Colors.orange.shade300 : Colors.blue.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOffline ? Icons.cloud_off_rounded : Icons.sync,
            size: 16,
            color: isOffline ? Colors.orange.shade700 : Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOffline
                  ? 'Working offline - Changes will sync when back online'
                  : hasPending
                  ? 'Syncing $_pendingChanges change${_pendingChanges != 1 ? 's' : ''}...'
                  : 'All changes synced',
              style: TextStyle(
                fontSize: 12,
                color: isOffline
                    ? Colors.orange.shade900
                    : Colors.blue.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
