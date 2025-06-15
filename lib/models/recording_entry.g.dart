// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecordingEntryAdapter extends TypeAdapter<RecordingEntry> {
  @override
  final int typeId = 1;

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
      moodIconColor: fields[7] as Color,
      moodEmoji: fields[8] as String,
      transcription: fields[9] as String?,
      waveformPoints: (fields[10] as List?)?.cast<double>(),
      summaryPreview: fields[11] as String?,
      isPlaying: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RecordingEntry obj) {
    writer
      ..writeByte(13)
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
      ..write(obj.moodIconColor)
      ..writeByte(8)
      ..write(obj.moodEmoji)
      ..writeByte(9)
      ..write(obj.transcription)
      ..writeByte(10)
      ..write(obj.waveformPoints)
      ..writeByte(11)
      ..write(obj.summaryPreview)
      ..writeByte(12)
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
