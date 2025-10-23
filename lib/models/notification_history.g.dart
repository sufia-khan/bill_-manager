// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotificationHistoryAdapter extends TypeAdapter<NotificationHistory> {
  @override
  final int typeId = 3;

  @override
  NotificationHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationHistory(
      id: fields[0] as String,
      title: fields[1] as String,
      body: fields[2] as String,
      sentAt: fields[3] as DateTime,
      billId: fields[4] as String?,
      billTitle: fields[5] as String?,
      isRead: fields[6] as bool,
      createdAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationHistory obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(3)
      ..write(obj.sentAt)
      ..writeByte(4)
      ..write(obj.billId)
      ..writeByte(5)
      ..write(obj.billTitle)
      ..writeByte(6)
      ..write(obj.isRead)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
