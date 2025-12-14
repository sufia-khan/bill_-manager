// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotificationHiveAdapter extends TypeAdapter<NotificationHive> {
  @override
  final int typeId = 2;

  @override
  NotificationHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationHive(
      id: fields[0] as String,
      occurrenceId: fields[1] as String,
      billId: fields[2] as String,
      billTitle: fields[3] as String,
      type: fields[4] as String,
      title: fields[5] as String,
      message: fields[6] as String,
      scheduledFor: fields[7] as DateTime,
      createdAt: fields[8] as DateTime,
      isRecurring: fields[9] as bool,
      recurringSequence: fields[10] as int?,
      repeatCount: fields[13] as int?,
      seen: fields[11] as bool,
      userId: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationHive obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.occurrenceId)
      ..writeByte(2)
      ..write(obj.billId)
      ..writeByte(3)
      ..write(obj.billTitle)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.title)
      ..writeByte(6)
      ..write(obj.message)
      ..writeByte(7)
      ..write(obj.scheduledFor)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.isRecurring)
      ..writeByte(10)
      ..write(obj.recurringSequence)
      ..writeByte(11)
      ..write(obj.seen)
      ..writeByte(12)
      ..write(obj.userId)
      ..writeByte(13)
      ..write(obj.repeatCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
