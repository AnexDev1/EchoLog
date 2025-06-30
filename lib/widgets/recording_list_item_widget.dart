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

  const RecordingListItemWidget({
    Key? key,
    required this.entry,
    required this.isPlaying,
    required this.isSelected,
    required this.onPlayPause,
    required this.onMoveToVault,
    required this.onShare,
    required this.onTranscribe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RecordingCard(
      key: ValueKey(entry.id),
      recording: entry,
      isPlaying: isPlaying,
      isSelected: isSelected,
      playbackProgressPercent: 0.0,
      onPlayToggle: () => onPlayPause(entry),
      onShare: () => onShare(entry),
      onTranscribe: () => onTranscribe(entry),
      onMoveToVault: () => onMoveToVault(entry),
    );
  }
}
