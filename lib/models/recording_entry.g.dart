// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecordingEntryAdapter extends TypeAdapter<RecordingEntry> {
  @override
  final int typeId = 0;

  @override
  RecordingEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecordingEntry(
      id: fields[0] as String,
      filePath: fields[1] as String,
      displayName: fields[2] as String,
      durationMillis: fields[3] as int,
      dateRecorded: fields[4] as DateTime,
      moodName: fields[5] as String,
      moodColorValue: fields[6] as int,
      moodIconColorValue: fields[7] as int,
      emoji: fields[8] as String,
      isPlaying: fields[9] == null ? false : fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RecordingEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.filePath)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.durationMillis)
      ..writeByte(4)
      ..write(obj.dateRecorded)
      ..writeByte(5)
      ..write(obj.moodName)
      ..writeByte(6)
      ..write(obj.moodColorValue)
      ..writeByte(7)
      ..write(obj.moodIconColorValue)
      ..writeByte(8)
      ..write(obj.emoji)
      ..writeByte(9)
      ..write(obj.isPlaying);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
