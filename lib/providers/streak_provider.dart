import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recording_entry.dart';
import '../main.dart';

class StreakProvider extends ChangeNotifier {
  int _streak = 0;
  DateTime? _lastRecordedDate;
  bool _initialized = false;

  int get streak => _streak;
  DateTime? get lastRecordedDate => _lastRecordedDate;

  static const String _streakKey = 'streak';

  Future<void> initialize() async {
    if (_initialized) return;
    await _calculateStreak();
    _initialized = true;
  }

  Future<void> _saveStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_streakKey, _streak);
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    _streak = prefs.getInt(_streakKey) ?? 0;
    notifyListeners();
  }

  Future<void> _calculateStreak() async {
    final box = Hive.box<RecordingEntry>(recordingsBoxName);
    final List<RecordingEntry> all = box.values.toList();
    if (all.isEmpty) {
      await _loadStreak(); // Load from prefs if no recordings
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
      await _loadStreak(); // Load from prefs if no days
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
    await _saveStreak(); // Save to prefs
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
