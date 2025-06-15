import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:home_widget/home_widget.dart'; // Import home_widget
import 'package:echolog/models/recording_entry.dart'; // Adjust path if your model is elsewhere
import 'package:echolog/main.dart'; // For WIDGET_METHOD_CHANNEL_NAME and recordingsBoxName

// This channel name must match the one used in MainActivity.kt
const MethodChannel _widgetMethodChannel = MethodChannel(
  WIDGET_METHOD_CHANNEL_NAME,
);

/// Fetches the most recent recording and/or uses the provided [recentEntry]
/// to save data via HomeWidget and then trigger a native widget update.
Future<void> updateWidgetWithRecentRecording({
  RecordingEntry? recentEntry,
}) async {
  try {
    RecordingEntry? entryToDisplay = recentEntry;

    if (entryToDisplay == null) {
      final box = Hive.box<RecordingEntry>(recordingsBoxName);
      if (box.isNotEmpty) {
        var sortedEntries = box.values.toList();
        sortedEntries.sort((a, b) => b.dateRecorded.compareTo(a.dateRecorded));
        if (sortedEntries.isNotEmpty) {
          entryToDisplay = sortedEntries.first;
        }
      }
    }

    if (entryToDisplay != null) {
      print(
        "[RecordingService] Preparing to update widget data for: ${entryToDisplay.displayName}",
      );

      // 1. Save data using HomeWidget. These keys MUST match what RecentRecordingWidget.kt expects.
      await HomeWidget.saveWidgetData<bool>('has_recent_recording', true);
      await HomeWidget.saveWidgetData<String>(
        'recent_recording_title',
        entryToDisplay.displayName,
      );
      await HomeWidget.saveWidgetData<String>(
        'recent_recording_duration',
        formatDuration(entryToDisplay.duration),
      );
      await HomeWidget.saveWidgetData<String>(
        'recent_recording_id',
        entryToDisplay.id,
      );
      // Save any other data your widget might need from HomeWidgetPlugin.getData()

      print(
        "[RecordingService] Data saved via HomeWidget for ID: ${entryToDisplay.id}",
      );

      // 2. Tell HomeWidget to update the widget view.
      // This should trigger the onUpdate method in your RecentRecordingWidget.kt
      await HomeWidget.updateWidget(
        name:
            'RecentRecordingWidget', // The class name of your AppWidgetProvider
        androidName: 'RecentRecordingWidget', // Explicitly for Android
        // iOSName: 'YourWidgetExtensionName', // If you had an iOS widget
      );
      print("[RecordingService] HomeWidget.updateWidget() called.");

      // 3. Optionally, still invoke the platform channel if HomeWidget.updateWidget()
      // doesn't cover all update scenarios or if MainActivity needs a direct signal
      // for other reasons. For now, let's assume HomeWidget.updateWidget() is sufficient
      // to trigger the native widget's onUpdate. If not, uncomment the line below.
      // The arguments to 'forceWidgetUpdate' are no longer strictly needed by MainActivity
      // if it's just a trigger and widget reads from HomeWidget.
      // await _widgetMethodChannel.invokeMethod('forceWidgetUpdate');
      // print("[RecordingService] Platform channel 'forceWidgetUpdate' invoked (as a trigger).");
    } else {
      print(
        "[RecordingService] No recording to display. Clearing widget data via HomeWidget.",
      );
      // 1. Clear data or set defaults using HomeWidget
      await HomeWidget.saveWidgetData<bool>('has_recent_recording', false);
      await HomeWidget.saveWidgetData<String>(
        'recent_recording_title',
        null,
      ); // Use null to clear
      await HomeWidget.saveWidgetData<String>(
        'recent_recording_duration',
        null,
      );
      await HomeWidget.saveWidgetData<String>('recent_recording_id', null);

      print("[RecordingService] Widget data cleared via HomeWidget.");

      // 2. Tell HomeWidget to update the widget view
      await HomeWidget.updateWidget(
        name: 'RecentRecordingWidget',
        androidName: 'RecentRecordingWidget',
      );
      print(
        "[RecordingService] HomeWidget.updateWidget() called to reflect cleared data.",
      );

      // 3. Optionally, invoke platform channel as a trigger.
      // await _widgetMethodChannel.invokeMethod('forceWidgetUpdate', null);
      // print("[RecordingService] Platform channel 'forceWidgetUpdate' invoked with null (as a trigger).");
    }
  } on PlatformException catch (e) {
    print(
      "[RecordingService] PlatformException during widget update: '${e.message}'. Details: ${e.details}",
    );
  } catch (e) {
    print(
      "[RecordingService] A general error occurred in updateWidgetWithRecentRecording: $e",
    );
  }
}

// Helper function to format Duration. Ensure this matches your needs.
String formatDuration(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
  if (d.inHours > 0) {
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
  return "$twoDigitMinutes:$twoDigitSeconds";
}

Future<RecordingEntry?> getRecordingById(String id) async {
  try {
    final box = Hive.box<RecordingEntry>(recordingsBoxName);
    return box.get(id);
  } catch (e) {
    print("[RecordingService] Error fetching recording by ID $id: $e");
    return null;
  }
}
