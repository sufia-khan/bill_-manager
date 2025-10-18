import 'package:hive_flutter/hive_flutter.dart';
import '../models/bill_hive.dart';
import '../models/sync_queue_item.dart';

class LocalDatabaseService {
  static const String billsBoxName = 'bills';
  static const String syncQueueBoxName = 'sync_queue';
  static const String metadataBoxName = 'metadata';

  Box<BillHive>? _billsBox;
  Box<SyncQueueItem>? _syncQueueBox;
  Box? _metadataBox;

  // Singleton pattern
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  // Initialize Hive
  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BillHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SyncQueueItemAdapter());
    }

    // Open boxes
    _billsBox = await Hive.openBox<BillHive>(billsBoxName);
    _syncQueueBox = await Hive.openBox<SyncQueueItem>(syncQueueBoxName);
    _metadataBox = await Hive.openBox(metadataBoxName);
  }

  Box<BillHive> get billsBox {
    if (_billsBox == null || !_billsBox!.isOpen) {
      throw Exception('Bills box not initialized. Call init() first.');
    }
    return _billsBox!;
  }

  Box<SyncQueueItem> get syncQueueBox {
    if (_syncQueueBox == null || !_syncQueueBox!.isOpen) {
      throw Exception('Sync queue box not initialized. Call init() first.');
    }
    return _syncQueueBox!;
  }

  Box get metadataBox {
    if (_metadataBox == null || !_metadataBox!.isOpen) {
      throw Exception('Metadata box not initialized. Call init() first.');
    }
    return _metadataBox!;
  }

  // Bills CRUD operations
  Future<void> saveBill(BillHive bill) async {
    final now = DateTime.now();
    bill.clientUpdatedAt = now;
    bill.updatedAt = now;
    bill.needsSync = true;

    await billsBox.put(bill.id, bill);
    await _addToSyncQueue(bill.id, 'update');
  }

  Future<void> deleteBill(String billId) async {
    final bill = billsBox.get(billId);
    if (bill != null) {
      final now = DateTime.now();
      bill.isDeleted = true;
      bill.clientUpdatedAt = now;
      bill.updatedAt = now;
      bill.needsSync = true;

      await billsBox.put(billId, bill);
      await _addToSyncQueue(billId, 'delete');
    }
  }

  BillHive? getBill(String billId) {
    return billsBox.get(billId);
  }

  List<BillHive> getAllBills({bool includeDeleted = false}) {
    final bills = billsBox.values.toList();
    if (includeDeleted) {
      return bills;
    }
    return bills.where((bill) => !bill.isDeleted).toList();
  }

  List<BillHive> getBillsByCategory(String category) {
    return billsBox.values
        .where((bill) => !bill.isDeleted && bill.category == category)
        .toList();
  }

  List<BillHive> getUpcomingBills() {
    final now = DateTime.now();
    return billsBox.values
        .where(
          (bill) => !bill.isDeleted && !bill.isPaid && bill.dueAt.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  List<BillHive> getOverdueBills() {
    final now = DateTime.now();
    return billsBox.values
        .where(
          (bill) => !bill.isDeleted && !bill.isPaid && bill.dueAt.isBefore(now),
        )
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  // Sync queue operations
  Future<void> _addToSyncQueue(String billId, String operation) async {
    // Check if already in queue
    final existing = syncQueueBox.values.firstWhere(
      (item) => item.billId == billId,
      orElse: () =>
          SyncQueueItem(billId: '', operation: '', queuedAt: DateTime.now()),
    );

    if (existing.billId.isEmpty) {
      // Add new item
      await syncQueueBox.add(
        SyncQueueItem(
          billId: billId,
          operation: operation,
          queuedAt: DateTime.now(),
        ),
      );
    } else {
      // Update existing item
      existing.operation = operation;
      existing.queuedAt = DateTime.now();
      await existing.save();
    }
  }

  List<SyncQueueItem> getSyncQueue() {
    return syncQueueBox.values.toList()
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
  }

  Future<void> removeSyncQueueItem(SyncQueueItem item) async {
    await item.delete();
  }

  Future<void> clearSyncQueue() async {
    await syncQueueBox.clear();
  }

  // Metadata operations
  DateTime? getLastPulledAt() {
    final timestamp = metadataBox.get('lastPulledAt');
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  Future<void> setLastPulledAt(DateTime timestamp) async {
    await metadataBox.put('lastPulledAt', timestamp.toIso8601String());
  }

  String? getUserId() {
    return metadataBox.get('userId');
  }

  Future<void> setUserId(String userId) async {
    await metadataBox.put('userId', userId);
  }

  // Clear all data (for logout)
  Future<void> clearAllData() async {
    await billsBox.clear();
    await syncQueueBox.clear();
    await metadataBox.clear();
  }

  // Close boxes
  Future<void> close() async {
    await _billsBox?.close();
    await _syncQueueBox?.close();
    await _metadataBox?.close();
  }
}
