import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/providers/transcription_status_provider.dart';
import 'package:echolog/widgets/recording_card.dart';
// Make sure this import path is correct and that the RecordingCard widget exists at this location.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecordingListItemWidget extends StatelessWidget {
  final RecordingEntry entry;
  final bool isPlaying;
  final bool isSelected;
  final Function(RecordingEntry) onPlayPause;
  final Function(RecordingEntry) onMoveToVault;
  final Function(RecordingEntry) onShare;
  final Function(RecordingEntry) onTranscribe;
  final Function(RecordingEntry) onDelete;
  final ValueNotifier<Duration>? playbackProgressNotifier;
  final ValueNotifier<bool>? isActuallyPlayingNotifier;
  final Duration? totalDuration;
  final Function(double)? onSeekRequest;
  final double? transcriptionProgress;
  final String? transcriptionStatusText;
  final bool isTranscribing;
  final bool isTranscriptionExpanded;
  final bool isTranscriptionHidden;
  final VoidCallback onToggleTranscription;
  final VoidCallback onToggleTranscriptionVisibility;
  final VoidCallback? onViewTranscription;

  const RecordingListItemWidget({
    Key? key,
    required this.entry,
    required this.isPlaying,
    required this.isSelected,
    required this.onPlayPause,
    required this.onMoveToVault,
    required this.onShare,
    required this.onTranscribe,
    required this.onDelete,
    this.playbackProgressNotifier,
    this.isActuallyPlayingNotifier,
    this.totalDuration,
    this.onSeekRequest,
    this.transcriptionProgress,
    this.transcriptionStatusText,
    this.isTranscribing = false,
    required this.isTranscriptionExpanded,
    required this.isTranscriptionHidden,
    required this.onToggleTranscription,
    required this.onToggleTranscriptionVisibility,
    this.onViewTranscription,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final transcriptionStatus = Provider.of<TranscriptionStatusProvider>(
      context,
    );
    final bool isTranscribingThis =
        transcriptionStatus.isTranscribing &&
        transcriptionStatus.currentEntryId == entry.id;
    final double? effectiveTranscriptionProgress = isTranscribingThis
        ? transcriptionStatus.progress
        : transcriptionProgress;
    final String? effectiveTranscriptionStatusText = isTranscribingThis
        ? transcriptionStatus.statusText
        : transcriptionStatusText;

    if (isPlaying &&
        playbackProgressNotifier != null &&
        isActuallyPlayingNotifier != null &&
        totalDuration != null) {
      return ValueListenableBuilder<Duration>(
        valueListenable: playbackProgressNotifier!,
        builder: (context, progress, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: isActuallyPlayingNotifier!,
            builder: (context, isActuallyPlaying, __) {
              double percent = 0.0;
              if (totalDuration!.inMilliseconds > 0) {
                percent =
                    (progress.inMilliseconds / totalDuration!.inMilliseconds)
                        .clamp(0.0, 1.0);
              }
              return RecordingCard(
                key: ValueKey(entry.id),
                recording: entry,
                isPlaying: isPlaying,
                isSelected: isSelected,
                playbackProgressPercent: percent,
                onPlayToggle: () => onPlayPause(entry),
                onShare: () => onShare(entry),
                onTranscribe: () => onTranscribe(entry),
                onMoveToVault: () => onMoveToVault(entry),
                onDelete: () => onDelete(entry),
                onSeekRequest: onSeekRequest,

                onViewTranscription: onViewTranscription,
              );
            },
          );
        },
      );
    }
    // Otherwise, render static card
    return RecordingCard(
      key: ValueKey(entry.id),
      recording: entry,
      isPlaying: false,
      isSelected: isSelected,
      playbackProgressPercent: 0.0,
      onPlayToggle: () => onPlayPause(entry),
      onShare: () => onShare(entry),
      onTranscribe: () => onTranscribe(entry),
      onMoveToVault: () => onMoveToVault(entry),
      onDelete: () => onDelete(entry),
      onSeekRequest: onSeekRequest, // Ensure seek is always passed

      onViewTranscription: onViewTranscription,
    );
  }
}
