import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/widgets/mini_waveform_painter.dart';
import 'package:echolog/widgets/animated_waveform_play_button.dart';

class RecordingCard extends StatelessWidget {
  final RecordingEntry recording;
  final VoidCallback onPlayToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onTranscribe;
  final VoidCallback? onMoveToVault;
  final VoidCallback? onViewTranscription;
  final bool isPlaying;
  final bool isSelected; // For multi-select or highlighting
  final VoidCallback? onSelect; // For multi-select
  final VoidCallback? onLongPress; // For multi-select or context menu

  // For seek functionality on the mini waveform within this card
  final double
  playbackProgressPercent; // Current playback progress (0.0 to 1.0) for this specific recording
  final Function(double)?
  onSeekRequest; // Callback when user interacts with waveform to seek (passes percentage)

  const RecordingCard({
    super.key,
    required this.recording,
    required this.onPlayToggle,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.onTranscribe,
    this.onMoveToVault,
    this.onViewTranscription,
    required this.isPlaying,
    this.isSelected = false,
    this.onSelect,
    this.onLongPress,
    this.playbackProgressPercent = 0.0, // Default to 0% progress
    this.onSeekRequest,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DateFormat dateFormat = DateFormat('MMM d, yyyy');
    final DateFormat timeFormat = DateFormat('h:mm a');

    // Use actual waveform points if available, otherwise generate placeholder
    final List<double> waveformData =
        recording.waveformPoints ??
        List.generate(
          50, // Number of points for placeholder
          (index) =>
              (math.sin(index * 0.3 + math.Random().nextDouble() * 0.5) + 1) /
                  2.2 +
              0.05,
        ).map((e) => e.clamp(0.05, 1.0)).toList(); // Ensure values are clamped

    final String? summaryPreview = recording.summaryPreview;
    final String? transcription = recording.transcription;
    final bool hasFullTranscription =
        transcription != null && transcription.isNotEmpty;

    // Define colors for the mini waveform based on mood color
    final Color baseWaveColor = recording.moodColor.withOpacity(
      0.65,
    ); // For unplayed part
    final Color progressWaveColor =
        recording.moodColor; // Solid mood color for played part
    // Slightly darker or modified mood color for the thumb for better visibility
    final Color thumbWaveColor = HSLColor.fromColor(recording.moodColor)
        .withLightness(
          (HSLColor.fromColor(recording.moodColor).lightness - 0.1).clamp(
            0.0,
            1.0,
          ),
        )
        .toColor();

    return Card(
      elevation: isSelected ? 6.0 : 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: isSelected
            ? BorderSide(color: recording.moodColor, width: 1.8)
            : BorderSide(
                color: theme.dividerColor.withOpacity(0.2),
                width: 0.8,
              ),
      ),
      child: InkWell(
        onTap:
            onSelect ??
            onPlayToggle, // If onSelect is provided, it takes precedence
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      recording.displayName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 36, // Increased touch target
                    height: 36, // Increased touch target
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.hintColor,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: "More options",
                      onSelected: (value) {
                        if (value == 'edit' && onEdit != null) onEdit!();
                        if (value == 'delete' && onDelete != null) onDelete!();
                        if (value == 'share' && onShare != null) onShare!();
                        if (value == 'transcribe' && onTranscribe != null)
                          onTranscribe!();
                        if (value == 'move_to_vault' && onMoveToVault != null)
                          onMoveToVault!();
                        if (value == 'view_transcription' &&
                            onViewTranscription != null)
                          onViewTranscription!();
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            if (onEdit != null)
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 20),
                                    SizedBox(width: 10),
                                    Text('Edit Title'),
                                  ],
                                ),
                              ),
                            if (onShare != null)
                              const PopupMenuItem<String>(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share_outlined, size: 20),
                                    SizedBox(width: 10),
                                    Text('Share'),
                                  ],
                                ),
                              ),
                            if (onTranscribe != null && !hasFullTranscription)
                              const PopupMenuItem<String>(
                                value: 'transcribe',
                                child: Row(
                                  children: [
                                    Icon(Icons.translate_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Text('Transcribe'),
                                  ],
                                ),
                              ),
                            if (hasFullTranscription &&
                                onViewTranscription != null)
                              const PopupMenuItem<String>(
                                value: 'view_transcription',
                                child: Row(
                                  children: [
                                    Icon(Icons.article_outlined, size: 20),
                                    SizedBox(width: 10),
                                    Text('View Transcription'),
                                  ],
                                ),
                              ),
                            if (onMoveToVault != null)
                              const PopupMenuItem<String>(
                                value: 'move_to_vault',
                                child: Row(
                                  children: [
                                    Icon(Icons.shield_outlined, size: 20),
                                    SizedBox(width: 10),
                                    Text('Move to Vault'),
                                  ],
                                ),
                              ),
                            if (onDelete != null)
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Colors.redAccent,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              if (summaryPreview != null && summaryPreview.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0, top: 2.0),
                  child: Text(
                    summaryPreview,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: theme.hintColor.withOpacity(0.9),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else if (transcription != null &&
                  transcription.isNotEmpty &&
                  summaryPreview == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0, top: 2.0),
                  child: Text(
                    transcription.length > 100
                        ? '${transcription.substring(0, 100)}...'
                        : transcription,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: theme.hintColor.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // The interactive waveform display
              if (waveformData.isNotEmpty)
                GestureDetector(
                  behavior: HitTestBehavior
                      .opaque, // Ensures taps are caught within the bounds
                  onTapDown: (details) {
                    // Allow seek only if this specific card's audio is playing
                    if (onSeekRequest != null && isPlaying) {
                      final RenderBox box =
                          context.findRenderObject() as RenderBox;
                      final localOffset = box.globalToLocal(
                        details.globalPosition,
                      );
                      final seekPercent = (localOffset.dx / box.size.width)
                          .clamp(0.0, 1.0);
                      onSeekRequest!(seekPercent);
                    } else if (!isPlaying) {
                      // If not playing, a tap on the waveform can also start playback
                      onPlayToggle();
                    }
                  },
                  onHorizontalDragUpdate: (details) {
                    // Allow seek only if this specific card's audio is playing
                    if (onSeekRequest != null && isPlaying) {
                      final RenderBox box =
                          context.findRenderObject() as RenderBox;
                      final localOffset = box.globalToLocal(
                        details.globalPosition,
                      );
                      final seekPercent = (localOffset.dx / box.size.width)
                          .clamp(0.0, 1.0);
                      onSeekRequest!(seekPercent);
                    }
                  },
                  child: Container(
                    height: 30.0, // Height of the waveform display area
                    margin: EdgeInsets.only(
                      top:
                          (summaryPreview != null &&
                                  summaryPreview.isNotEmpty) ||
                              (transcription != null &&
                                  transcription.isNotEmpty)
                          ? 6.0
                          : 2.0,
                      bottom: 8.0,
                    ),
                    width: double.infinity, // Take full width
                    child: CustomPaint(
                      painter: MiniWaveformPainter(
                        waveformData: waveformData,
                        waveColor: baseWaveColor,
                        strokeWidth:
                            1.8, // Slightly thicker for better visibility
                        // Pass progress only if this card is the one playing
                        progressPercent: isPlaying
                            ? playbackProgressPercent
                            : 0.0,
                        progressColor: progressWaveColor,
                        thumbColor: thumbWaveColor,
                      ),
                    ),
                  ),
                ),
              // Add a small spacer if no waveform and no text previews are shown
              if (waveformData.isEmpty &&
                  summaryPreview == null &&
                  (transcription == null || transcription.isEmpty))
                const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormat.format(recording.dateRecorded),
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: theme.hintColor.withOpacity(0.85),
                        ),
                      ),
                      Text(
                        timeFormat.format(recording.dateRecorded),
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: theme.hintColor.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDuration(recording.duration),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.9),
                    ),
                  ),
                  AnimatedWaveformPlayButton(
                    isPlaying: isPlaying,
                    onTap:
                        onPlayToggle, // This button still primarily handles play/pause toggle
                    activeColor: recording.moodColor,
                    inactiveColor: theme.hintColor.withOpacity(0.6),
                    size: const Size(32, 32), // Slightly larger play button
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
