import 'package:hive/hive.dart';

part 'sync_queue_item.g.dart';

@HiveType(typeId: 1)
class SyncQueueItem extends HiveObject {
  @HiveField(0)
  String billId;

  @HiveField(1)
  String operation; // 'create', 'update', 'delete'

  @HiveField(2)
  DateTime queuedAt;

  @HiveField(3)
  int retryCount;

  @HiveField(4)
  DateTime? lastAttemptAt;

  SyncQueueItem({
    required this.billId,
    required this.operation,
    required this.queuedAt,
    this.retryCount = 0,
    this.lastAttemptAt,
  });
}
