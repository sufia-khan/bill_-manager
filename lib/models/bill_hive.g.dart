// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BillHiveAdapter extends TypeAdapter<BillHive> {
  @override
  final int typeId = 0;

  @override
  BillHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillHive(
      id: fields[0] as String,
      title: fields[1] as String,
      vendor: fields[2] as String,
      amount: fields[3] as double,
      dueAt: fields[4] as DateTime,
      notes: fields[5] as String?,
      category: fields[6] as String,
      isPaid: fields[7] as bool,
      isDeleted: fields[8] as bool,
      updatedAt: fields[9] as DateTime,
      clientUpdatedAt: fields[10] as DateTime,
      repeat: fields[11] as String,
      needsSync: fields[12] as bool,
      paidAt: fields[13] as DateTime?,
      isArchived: fields[14] as bool,
      archivedAt: fields[15] as DateTime?,
      parentBillId: fields[16] as String?,
      recurringSequence: fields[17] as int?,
      repeatCount: fields[18] as int?,
      reminderTiming: fields[19] as String?,
      notificationTime: fields[20] as String?,
      isPinned: fields[21] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BillHive obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.vendor)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.dueAt)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.isPaid)
      ..writeByte(8)
      ..write(obj.isDeleted)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.clientUpdatedAt)
      ..writeByte(11)
      ..write(obj.repeat)
      ..writeByte(12)
      ..write(obj.needsSync)
      ..writeByte(13)
      ..write(obj.paidAt)
      ..writeByte(14)
      ..write(obj.isArchived)
      ..writeByte(15)
      ..write(obj.archivedAt)
      ..writeByte(16)
      ..write(obj.parentBillId)
      ..writeByte(17)
      ..write(obj.recurringSequence)
      ..writeByte(18)
      ..write(obj.repeatCount)
      ..writeByte(19)
      ..write(obj.reminderTiming)
      ..writeByte(20)
      ..write(obj.notificationTime)
      ..writeByte(21)
      ..write(obj.isPinned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
