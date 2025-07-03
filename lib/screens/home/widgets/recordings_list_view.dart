import 'package:echolog/models/filter_state.dart';
import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/screens/home/widgets/recording_list_item_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

class RecordingsListView extends StatefulWidget {
  final ValueListenable<Box<RecordingEntry>> recordingsBoxListenable;
  final FilterState currentFilters;
  final Function(RecordingEntry, List<RecordingEntry>) onTogglePlay;
  final Function(RecordingEntry) onDismissRecording; // For delete
  final String? currentlyPlayingFileId; // ID of the recording currently playing
  final Function(RecordingEntry) onTranscribe;
  final Function(RecordingEntry) onShare;
  final Function(RecordingEntry) onMoveToVault;
  final Function(RecordingEntry)? onViewTranscription;
  final bool showOnlyRecent;
  final ValueNotifier<bool>
  isActuallyPlaying; // <-- Use ValueNotifier, not bool

  // For seek functionality on mini waveforms within RecordingCards
  final ValueNotifier<Duration>
  currentPlaybackProgress; // Overall current progress of the player
  final Duration
  currentTotalDuration; // Overall total duration of the playing track
  final Function(double)?
  onSeekRequest; // Callback to HomeScreen to perform seek

  const RecordingsListView({
    super.key,
    required this.recordingsBoxListenable,
    required this.currentFilters,
    required this.onTogglePlay,
    required this.onDismissRecording,
    this.currentlyPlayingFileId,
    required this.onTranscribe,
    required this.onShare,
    required this.onMoveToVault,
    this.onViewTranscription,
    required this.currentPlaybackProgress,
    required this.currentTotalDuration,
    this.onSeekRequest,
    this.showOnlyRecent = false,
    required this.isActuallyPlaying, // <-- Use ValueNotifier
  });

  @override
  State<RecordingsListView> createState() => _RecordingsListViewState();
}

class _RecordingsListViewState extends State<RecordingsListView> {
  List<RecordingEntry> _filterAndSortRecordings(Box<RecordingEntry> box) {
    var recordings = box.values.toList();

    // Apply filters
    if (widget.currentFilters.moodName != null &&
        widget.currentFilters.moodName!.isNotEmpty) {
      recordings = recordings
          .where((r) => r.moodName == widget.currentFilters.moodName)
          .toList();
    }

    if (widget.currentFilters.dateRecordedRange != null) {
      final startDate = widget.currentFilters.dateRecordedRange!.start;
      // Inclusive end date by taking the start of the next day
      final inclusiveEndDate = widget.currentFilters.dateRecordedRange!.end.add(
        const Duration(days: 1),
      );
      recordings = recordings.where((r) {
        final recordDate = r.dateRecorded;
        return !recordDate.isBefore(startDate) &&
            recordDate.isBefore(inclusiveEndDate);
      }).toList();
    }

    if (widget.currentFilters.searchNameQuery != null &&
        widget.currentFilters.searchNameQuery!.trim().isNotEmpty) {
      final query = widget.currentFilters.searchNameQuery!.toLowerCase().trim();
      recordings = recordings.where((r) {
        return r.displayName.toLowerCase().contains(query) ||
            (r.transcription?.toLowerCase().contains(query) ?? false) ||
            (r.summaryPreview?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply sorting: Newest recordings on top
    recordings.sort((a, b) => b.dateRecorded.compareTo(a.dateRecorded));

    // Only show the 2 most recent if requested
    if (widget.showOnlyRecent) {
      recordings = recordings.take(2).toList();
    }

    return recordings;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<Box<RecordingEntry>>(
      valueListenable: widget.recordingsBoxListenable,
      builder: (context, box, _) {
        final filteredAndSortedRecordings = _filterAndSortRecordings(box);

        if (filteredAndSortedRecordings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                widget.currentFilters.isAnyFilterActive
                    ? 'No recordings match your current filters.'
                    : 'No recordings yet.\nTap the microphone to start a new one!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: theme.hintColor.withOpacity(0.8),
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            bottom: 80.0, // Padding for FAB or bottom controls
            top: 8.0,
            left: 8.0, // Added horizontal padding for consistency
            right: 8.0, // Added horizontal padding for consistency
          ),
          itemCount: filteredAndSortedRecordings.length,
          itemBuilder: (context, index) {
            final entry = filteredAndSortedRecordings[index];
            final bool isThisCardPlaying =
                widget.currentlyPlayingFileId == entry.id;
            return RecordingListItemWidget(
              entry: entry,
              isPlaying: isThisCardPlaying,
              isSelected: false, // Add selection logic if needed
              onPlayPause: (e) =>
                  widget.onTogglePlay(e, filteredAndSortedRecordings),
              onMoveToVault: widget.onMoveToVault,
              onShare: widget.onShare,
              onTranscribe: widget.onTranscribe,
              playbackProgressNotifier: isThisCardPlaying
                  ? widget.currentPlaybackProgress
                  : null,
              isActuallyPlayingNotifier: isThisCardPlaying
                  ? widget.isActuallyPlaying
                  : null,
              onDelete: widget.onDismissRecording,
              totalDuration: isThisCardPlaying
                  ? widget.currentTotalDuration
                  : null,
              onSeekRequest: isThisCardPlaying ? widget.onSeekRequest : null,
            );
          },
        );
      },
    );
  }
}
