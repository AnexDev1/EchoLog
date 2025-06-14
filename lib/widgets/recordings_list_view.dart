import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import '../models/recording_entry.dart';
import '../models/filter_state.dart';
import 'recording_list_item_widget.dart';

class RecordingsListView extends StatelessWidget {
  final ValueListenable<Box<RecordingEntry>> recordingsBoxListenable;
  final FilterState currentFilters;
  final String? currentlyPlayingFileId;
  final Function(RecordingEntry) onShare; // Callback for sharing recordings
  final Function(RecordingEntry) onMoveToVault;
  final Future<void> Function(
    RecordingEntry entry,
    List<RecordingEntry> currentList,
  )
  onTogglePlay;
  final void Function(RecordingEntry entry)
  onDismissRecording; // Callback for when a recording is dismissed

  const RecordingsListView({
    super.key,
    required this.recordingsBoxListenable,
    required this.currentFilters,
    required this.currentlyPlayingFileId,
    required this.onTogglePlay,
    required this.onDismissRecording,
    required this.onMoveToVault,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<Box<RecordingEntry>>(
      valueListenable: recordingsBoxListenable,
      builder: (context, box, _) {
        List<RecordingEntry> recordings = box.values.toList();

        // Apply filters
        if (currentFilters.moodName != null) {
          recordings = recordings
              .where((entry) => entry.moodName == currentFilters.moodName)
              .toList();
        }
        if (currentFilters.searchNameQuery != null &&
            currentFilters.searchNameQuery!.isNotEmpty) {
          final query = currentFilters.searchNameQuery!.toLowerCase();
          recordings = recordings
              .where((entry) => entry.displayName.toLowerCase().contains(query))
              .toList();
        }
        if (currentFilters.durationRangeSeconds != null) {
          recordings = recordings.where((entry) {
            final durationInSeconds = entry.duration.inSeconds.toDouble();
            return durationInSeconds >=
                    currentFilters.durationRangeSeconds!.start &&
                durationInSeconds <= currentFilters.durationRangeSeconds!.end;
          }).toList();
        }
        if (currentFilters.dateRecordedRange != null) {
          recordings = recordings.where((entry) {
            final recordDate = DateTime(
              entry.dateRecorded.year,
              entry.dateRecorded.month,
              entry.dateRecorded.day,
            );
            final startDate = DateTime(
              currentFilters.dateRecordedRange!.start.year,
              currentFilters.dateRecordedRange!.start.month,
              currentFilters.dateRecordedRange!.start.day,
            );
            final endDate = DateTime(
              currentFilters.dateRecordedRange!.end.year,
              currentFilters.dateRecordedRange!.end.month,
              currentFilters.dateRecordedRange!.end.day,
            );
            return !recordDate.isBefore(startDate) &&
                !recordDate.isAfter(endDate);
          }).toList();
        }

        // Update isPlaying status for items not currently playing
        for (var rec in recordings) {
          if (rec.id != currentlyPlayingFileId) {
            rec.isPlaying = false;
          }
        }
        // Sort recordings by date
        recordings.sort((a, b) => b.dateRecorded.compareTo(a.dateRecorded));

        if (recordings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                currentFilters.isAnyFilterActive
                    ? 'No recordings match your filters.\nTry adjusting or clearing them.'
                    : 'No recordings yet.\nTap the microphone to start!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: recordings.length,
          itemBuilder: (context, index) {
            final entry = recordings[index];
            return Dismissible(
              key: ValueKey(entry.id),
              direction: DismissDirection.endToStart,
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                child: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              onDismissed: (direction) {
                onDismissRecording(entry); // Call the callback
              },
              child: RecordingListItemWidget(
                onShare: onShare,
                onMoveToVault: onMoveToVault,
                entry: entry,
                onPlayPause: (selectedEntry) =>
                    onTogglePlay(selectedEntry, recordings),
              ),
            );
          },
        );
      },
    );
  }
}
