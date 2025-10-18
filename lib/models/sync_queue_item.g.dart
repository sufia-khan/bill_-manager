// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_queue_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncQueueItemAdapter extends TypeAdapter<SyncQueueItem> {
  @override
  final int typeId = 1;

  @override
  SyncQueueItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncQueueItem(
      billId: fields[0] as String,
      operation: fields[1] as String,
      queuedAt: fields[2] as DateTime,
      retryCount: fields[3] as int,
      lastAttemptAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SyncQueueItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.billId)
      ..writeByte(1)
      ..write(obj.operation)
      ..writeByte(2)
      ..write(obj.queuedAt)
      ..writeByte(3)
      ..write(obj.retryCount)
      ..writeByte(4)
      ..write(obj.lastAttemptAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
