import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:echolog/models/recording_entry.dart'; // Adjust path if your model is elsewhere
import 'package:echolog/main.dart'; // For WIDGET_METHOD_CHANNEL_NAME and recordingsBoxName

// This channel name must match the one used in MainActivity.kt/java and main.dart
const MethodChannel _widgetMethodChannel = MethodChannel(
  WIDGET_METHOD_CHANNEL_NAME,
);

/// Fetches the most recent recording and/or uses the provided [recentEntry]
/// to tell the native Android side to update the app widget.
Future<void> updateWidgetWithRecentRecording({
  RecordingEntry? recentEntry,
}) async {
  try {
    RecordingEntry? entryToDisplay = recentEntry;

    // If no specific entry is provided, try to get the most recent one from Hive.
    if (entryToDisplay == null) {
      final box = Hive.box<RecordingEntry>(recordingsBoxName);
      if (box.isNotEmpty) {
        // A simple way to get the "latest" is to sort by dateRecorded descending.
        // This assumes dateRecorded is reliable and set correctly.
        var sortedEntries = box.values.toList();
        // Sort in descending order of dateRecorded
        sortedEntries.sort((a, b) => b.dateRecorded.compareTo(a.dateRecorded));
        if (sortedEntries.isNotEmpty) {
          entryToDisplay = sortedEntries.first;
        }
      }
    }

    if (entryToDisplay != null) {
      print(
        "[RecordingService] Invoking 'forceWidgetUpdate' with ID: ${entryToDisplay.id}, Name: ${entryToDisplay.displayName}",
      );
      // Prepare the data to be sent to the native side.
      // The native side will use this data to update the widget.
      // It's often good to store this data in SharedPreferences on the native side
      // so the widget can access it during its update cycle.
      await _widgetMethodChannel.invokeMethod('forceWidgetUpdate', {
        'recordingId': entryToDisplay.id,
        'displayName': entryToDisplay.displayName,
        'filePath':
            entryToDisplay.filePath, // Widget might need this for PendingIntent
        'dateRecorded': entryToDisplay.dateRecorded
            .toIso8601String(), // Send as ISO string
        // Add any other data your widget might need
      });
    } else {
      // If there are no recordings, or no specific one to show,
      // you might want to tell the widget to display a default state.
      print(
        "[RecordingService] No recording to display, invoking 'forceWidgetUpdate' with null arguments.",
      );
      await _widgetMethodChannel.invokeMethod(
        'forceWidgetUpdate',
        null,
      ); // Send null or an empty map
    }
  } on PlatformException catch (e) {
    print(
      "[RecordingService] Failed to force widget update via platform channel: '${e.message}'. Details: ${e.details}",
    );
  } catch (e) {
    print(
      "[RecordingService] A general error occurred in updateWidgetWithRecentRecording: $e",
    );
  }
}

// Example of another function you might have in a recording service.
// This is not directly used by the widget update logic above but shows
// how you might structure other service calls.
Future<RecordingEntry?> getRecordingById(String id) async {
  try {
    final box = Hive.box<RecordingEntry>(recordingsBoxName);
    return box.get(id);
  } catch (e) {
    print("[RecordingService] Error fetching recording by ID $id: $e");
    return null;
  }
}

// You could add other functions here related to recording management if needed.
