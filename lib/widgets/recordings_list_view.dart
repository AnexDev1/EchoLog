import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/models/filter_state.dart'; // Assuming you have this for filters
import 'package:echolog/widgets/recording_card.dart';

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

  // For seek functionality on mini waveforms within RecordingCards
  final Duration
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
  });

  @override
  State<RecordingsListView> createState() => _RecordingsListViewState();
}

class _RecordingsListViewState extends State<RecordingsListView> {
  List<RecordingEntry> _filterAndSortRecordings(Box<RecordingEntry> box) {
    var recordings = box.values
        .where(
          (entry) => true,
        ) // FIXME: entry.isVaulted is not defined on RecordingEntry. Assuming not vaulted for now.
        .toList()
        .cast<RecordingEntry>(); // Exclude vaulted

    // Apply filters
    if (widget.currentFilters.moodName != null &&
        widget.currentFilters.moodName!.isNotEmpty) {
      recordings = recordings.where((r) {
        return r.moodName == widget.currentFilters.moodName;
      }).toList();
    }
    if (widget.currentFilters.dateRecordedRange != null) {
      recordings = recordings.where((r) {
        final recordDate = r.dateRecorded;
        return !recordDate.isBefore(
          widget.currentFilters.dateRecordedRange!.start,
        );
      }).toList();
    }
    if (widget.currentFilters.dateRecordedRange != null) {
      recordings = recordings.where((r) {
        final recordDate = r.dateRecorded;
        // Inclusive end date by adding a day and checking if before
        final inclusiveEndDate = widget.currentFilters.dateRecordedRange!.end
            .add(const Duration(days: 1));
        return recordDate.isBefore(inclusiveEndDate);
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

    // Apply sorting
    // recordings.sort((a, b) {
    //   int comparison;
    //   switch (widget.currentFilters.sortBy) {
    //     case SortByType.date:
    //       comparison = a.dateRecorded.compareTo(b.dateRecorded);
    //       break;
    //     case SortByType.duration:
    //       comparison = a.duration.compareTo(b.duration);
    //       break;
    //     case SortByType.name:
    //     default:
    //       comparison = a.displayName.toLowerCase().compareTo(
    //         b.displayName.toLowerCase(),
    //       );
    //       break;
    //   }
    //   return widget.currentFilters.sortOrder == SortOrder.ascending
    //       ? comparison
    //       : -comparison;
    // });
    return recordings;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<RecordingEntry>>(
      valueListenable: widget.recordingsBoxListenable,
      builder: (context, box, _) {
        final filteredRecordings = _filterAndSortRecordings(box);

        if (filteredRecordings.isEmpty) {
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
                  color: Theme.of(context).hintColor.withOpacity(0.8),
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            bottom: 80.0,
            top: 8.0,
          ), // Padding for FAB or bottom controls
          itemCount: filteredRecordings.length,
          itemBuilder: (context, index) {
            final entry = filteredRecordings[index];
            // Determine if this specific card's audio is the one currently playing
            final bool isThisEntryPlaying =
                widget.currentlyPlayingFileId == entry.id && entry.isPlaying;

            double progressPercentForThisCard = 0.0;
            if (isThisEntryPlaying &&
                widget.currentTotalDuration.inMilliseconds > 0) {
              progressPercentForThisCard =
                  (widget.currentPlaybackProgress.inMilliseconds /
                          widget.currentTotalDuration.inMilliseconds)
                      .clamp(0.0, 1.0);
            }

            return RecordingCard(
              // Using ValueKey ensures widget rebuilds if crucial data like isPlaying changes
              key: ValueKey(
                'recording_card_${entry.id}_${entry.moodColor.value}_$isThisEntryPlaying',
              ),
              recording: entry,
              isPlaying: isThisEntryPlaying,
              onPlayToggle: () =>
                  widget.onTogglePlay(entry, filteredRecordings),
              onShare: () => widget.onShare(entry),
              onTranscribe: () => widget.onTranscribe(entry),
              onMoveToVault: () => widget.onMoveToVault(entry),
              onDelete: () => widget.onDismissRecording(entry),
              onViewTranscription: widget.onViewTranscription != null
                  ? () => widget.onViewTranscription!(entry)
                  : null,
              // Pass the calculated progress and seek request handler to the card
              playbackProgressPercent: progressPercentForThisCard,
              // Only allow seek if this card is the one playing and a seek handler is provided
              onSeekRequest: isThisEntryPlaying && widget.onSeekRequest != null
                  ? widget.onSeekRequest
                  : null,
            );
          },
        );
      },
    );
  }
}
