import 'package:flutter/material.dart';
import 'package:echolog/widgets/recording_card.dart';
import '../models/recording_entry.dart';

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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                isPlaying: isActuallyPlaying,
                isSelected: isSelected,
                playbackProgressPercent: percent,
                onPlayToggle: () => onPlayPause(entry),
                onShare: () => onShare(entry),
                onTranscribe: () => onTranscribe(entry),
                onMoveToVault: () => onMoveToVault(entry),
                onDelete: () => onDelete(entry),
                onSeekRequest: onSeekRequest,
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
    );
  }
}
