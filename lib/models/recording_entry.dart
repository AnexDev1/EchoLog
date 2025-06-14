import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'recording_entry.g.dart';

@HiveType(typeId: 0)
class RecordingEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String filePath;

  @HiveField(2)
  String displayName;

  @HiveField(3)
  final int durationMillis; // Hive stores this int

  @HiveField(4)
  final DateTime dateRecorded;

  @HiveField(5)
  final String moodName;

  @HiveField(6)
  final int moodColorValue; // Hive stores this int

  @HiveField(7)
  final int moodIconColorValue; // Hive stores this int

  @HiveField(8)
  final String emoji;

  @HiveField(9, defaultValue: false)
  bool isPlaying;

  // Primary constructor: Takes primitive types that Hive stores.
  // The generated adapter will use this constructor.
  RecordingEntry({
    required this.id,
    required this.filePath,
    required this.displayName,
    required this.durationMillis, // Changed from Duration to int
    required this.dateRecorded,
    required this.moodName,
    required this.moodColorValue, // Changed from Color to int
    required this.moodIconColorValue, // Changed from Color to int
    required this.emoji,
    this.isPlaying = false,
  });

  // Factory constructor for creating instances in your app code
  // using Duration and Color objects.
  factory RecordingEntry.create({
    required String id,
    required String filePath,
    required String displayName,
    required Duration duration,
    required DateTime dateRecorded,
    required String moodName,
    required Color moodColor,
    required Color moodIconColor,
    required String emoji,
    bool isPlaying = false,
  }) {
    return RecordingEntry(
      id: id,
      filePath: filePath,
      displayName: displayName,
      durationMillis: duration.inMilliseconds, // Convert Duration to int
      dateRecorded: dateRecorded,
      moodName: moodName,
      moodColorValue: moodColor.value, // Convert Color to int
      moodIconColorValue: moodIconColor.value, // Convert Color to int
      emoji: emoji,
      isPlaying: isPlaying,
    );
  }

  // Getters to convert stored int values back to Duration/Color for app use
  Duration get duration => Duration(milliseconds: durationMillis);
  Color get moodColor => Color(moodColorValue);
  Color get moodIconColor => Color(moodIconColorValue);
}
