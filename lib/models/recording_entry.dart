import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'recording_entry.g.dart'; // Ensure this line exists

@HiveType(
  typeId: 0,
) // Make sure your typeId is unique if you have other HiveObjects
class RecordingEntry extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String filePath;

  @HiveField(2)
  late String displayName;

  @HiveField(3)
  late Duration duration;

  @HiveField(4)
  late DateTime dateRecorded;

  @HiveField(5)
  late String moodName;

  @HiveField(6)
  late Color moodColor; // You'll need a TypeAdapter for Color or store it as int

  @HiveField(7)
  late String moodEmoji;

  @HiveField(8)
  late Color moodIconColor; // Same as moodColor regarding TypeAdapter

  @HiveField(9)
  bool isPlaying;

  @HiveField(10) // NEW FIELD
  String? transcription; // To store the transcription text

  RecordingEntry({
    required this.id,
    required this.filePath,
    required this.displayName,
    required this.duration,
    required this.dateRecorded,
    required this.moodName,
    required this.moodColor,
    required this.moodEmoji,
    required this.moodIconColor,
    this.isPlaying = false,
    this.transcription, // NEW
  });

  // If you don't have a ColorAdapter, you might store colors as int:
  // @HiveField(6)
  // late int moodColorValue;
  // @HiveField(8)
  // late int moodIconColorValue;
  // Color get moodColor => Color(moodColorValue);
  // Color get moodIconColor => Color(moodIconColorValue);
}
