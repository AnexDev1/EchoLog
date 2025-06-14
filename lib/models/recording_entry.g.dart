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
      duration: fields[3] as Duration,
      dateRecorded: fields[4] as DateTime,
      moodName: fields[5] as String,
      moodColor: fields[6] as Color,
      moodEmoji: fields[7] as String,
      moodIconColor: fields[8] as Color,
      isPlaying: fields[9] as bool,
      transcription: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RecordingEntry obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.filePath)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.duration)
      ..writeByte(4)
      ..write(obj.dateRecorded)
      ..writeByte(5)
      ..write(obj.moodName)
      ..writeByte(6)
      ..write(obj.moodColor)
      ..writeByte(7)
      ..write(obj.moodEmoji)
      ..writeByte(8)
      ..write(obj.moodIconColor)
      ..writeByte(9)
      ..write(obj.isPlaying)
      ..writeByte(10)
      ..write(obj.transcription);
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
