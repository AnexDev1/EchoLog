import 'package:hive/hive.dart';

part 'recording_item.g.dart'; // Hive will generate this file

@HiveType(typeId: 60) // Ensure typeId is unique across your Hive objects
class RecordingItem extends HiveObject {
  @HiveField(0)
  late String id; // Unique identifier, can be a UUID

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String filePath;

  @HiveField(3)
  late DateTime dateTime;

  @HiveField(4)
  late Duration duration;

  @HiveField(5)
  List<double>? waveformPoints; // For mini waveform preview, nullable

  @HiveField(6)
  String? summaryPreview; // For AI summary/transcript preview, nullable

  @HiveField(7)
  Map<String, dynamic>? category; // To store associated category data

  RecordingItem({
    required this.id,
    required this.title,
    required this.filePath,
    required this.dateTime,
    required this.duration,
    this.waveformPoints,
    this.summaryPreview,
    this.category,
  });

  // Optional: toMap and fromMap methods if you need to convert to/from plain Maps
  // (e.g., for Firestore or other non-Hive uses)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'dateTime': dateTime.toIso8601String(),
      'duration': duration.inMilliseconds,
      'waveformPoints': waveformPoints,
      'summaryPreview': summaryPreview,
      'category': category,
    };
  }

  factory RecordingItem.fromMap(Map<String, dynamic> map) {
    return RecordingItem(
      id: map['id'] as String,
      title: map['title'] as String,
      filePath: map['filePath'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
      duration: Duration(milliseconds: map['duration'] as int),
      waveformPoints: (map['waveformPoints'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      summaryPreview: map['summaryPreview'] as String?,
      category: map['category'] as Map<String, dynamic>?,
    );
  }
}
