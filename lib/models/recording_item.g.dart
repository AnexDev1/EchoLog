// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecordingItemAdapter extends TypeAdapter<RecordingItem> {
  @override
  final int typeId = 60;

  @override
  RecordingItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecordingItem(
      id: fields[0] as String,
      title: fields[1] as String,
      filePath: fields[2] as String,
      dateTime: fields[3] as DateTime,
      duration: fields[4] as Duration,
      waveformPoints: (fields[5] as List?)?.cast<double>(),
      summaryPreview: fields[6] as String?,
      category: (fields[7] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, RecordingItem obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.dateTime)
      ..writeByte(4)
      ..write(obj.duration)
      ..writeByte(5)
      ..write(obj.waveformPoints)
      ..writeByte(6)
      ..write(obj.summaryPreview)
      ..writeByte(7)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
