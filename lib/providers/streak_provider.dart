import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/recording_entry.dart';
import '../main.dart';

class StreakProvider extends ChangeNotifier {
  int _streak = 0;
  DateTime? _lastRecordedDate;
  bool _initialized = false;

  int get streak => _streak;
  DateTime? get lastRecordedDate => _lastRecordedDate;

  Future<void> initialize() async {
    if (_initialized) return;
    await _calculateStreak();
    _initialized = true;
  }

  Future<void> _calculateStreak() async {
    final box = Hive.box<RecordingEntry>(recordingsBoxName);
    final List<RecordingEntry> all = box.values.toList();
    if (all.isEmpty) {
      _streak = 0;
      _lastRecordedDate = null;
      notifyListeners();
      return;
    }
    // Get all unique days with at least one recording
    final Set<DateTime> days = all
        .map(
          (e) => DateTime(
            e.dateRecorded.year,
            e.dateRecorded.month,
            e.dateRecorded.day,
          ),
        )
        .toSet();

    if (days.isEmpty) {
      _streak = 0;
      _lastRecordedDate = null;
      notifyListeners();
      return;
    }

    // Sort days descending
    final List<DateTime> sortedDays = days.toList()
      ..sort((a, b) => b.compareTo(a));
    _lastRecordedDate = sortedDays.first;

    // Calculate streak
    int streak = 0;
    DateTime today = DateTime.now();
    DateTime current = DateTime(today.year, today.month, today.day);

    for (final day in sortedDays) {
      if (current.difference(day).inDays == 0) {
        streak++;
        current = current.subtract(const Duration(days: 1));
      } else if (current.difference(day).inDays == 1) {
        streak++;
        current = current.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    _streak = streak;
    notifyListeners();
  }

  // Call this after a new recording is added
  Future<void> onNewRecording() async {
    await _calculateStreak();
  }

  // Optionally, call this after a recording is deleted
  Future<void> onRecordingDeleted() async {
    await _calculateStreak();
  }
}
