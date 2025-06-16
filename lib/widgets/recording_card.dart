import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/widgets/mini_waveform_painter.dart';
import 'package:echolog/widgets/animated_waveform_play_button.dart';

class RecordingCard extends StatefulWidget {
  final RecordingEntry recording;
  final VoidCallback onPlayToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onTranscribe;
  final VoidCallback? onMoveToVault;
  final VoidCallback? onViewTranscription;
  final bool isPlaying; // True if actively playing, FALSE IF PAUSED OR STOPPED
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback? onLongPress;
  // IMPORTANT: This value MUST be maintained by the parent (HomeScreen)
  // when the audio is PAUSED. It should NOT be reset to 0.0 on pause.
  // It should only be 0.0 when playback is fully stopped or at the very beginning.
  final double playbackProgressPercent;
  final Function(double)? onSeekRequest;

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
    required this.isPlaying, // This tells the button its icon (play/pause)
    this.isSelected = false,
    this.onSelect,
    this.onLongPress,
    this.playbackProgressPercent = 0.0, // Default if not provided
    this.onSeekRequest,
  });

  @override
  State<RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends State<RecordingCard> {
  bool _isTranscriptionExpanded = false;

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

    final List<double> waveformData =
        widget.recording.waveformPoints ??
        List.generate(
          50,
          (index) =>
              (math.sin(index * 0.3 + math.Random().nextDouble() * 0.5) + 1) /
                  2.2 +
              0.05,
        ).map((e) => e.clamp(0.05, 1.0)).toList();

    final String? summaryPreview = widget.recording.summaryPreview;
    final String? fullTranscription = widget.recording.transcription;
    final bool hasFullTranscription =
        fullTranscription != null && fullTranscription.isNotEmpty;
    final bool hasSummary = summaryPreview != null && summaryPreview.isNotEmpty;

    String transcriptionTextToShow;
    bool canExpand = false;
    const int collapsedPreviewMaxLines = 2;
    const int collapsedPreviewLength = 120;

    if (hasFullTranscription) {
      if (_isTranscriptionExpanded) {
        transcriptionTextToShow = fullTranscription;
      } else {
        if (hasSummary) {
          transcriptionTextToShow = summaryPreview;
        } else {
          transcriptionTextToShow =
              fullTranscription.length > collapsedPreviewLength
              ? '${fullTranscription.substring(0, collapsedPreviewLength)}...'
              : fullTranscription;
        }
      }
      if (fullTranscription.length > transcriptionTextToShow.length ||
          (hasSummary && fullTranscription != summaryPreview) ||
          _isTranscriptionExpanded) {
        canExpand = true;
      }
    } else if (hasSummary) {
      transcriptionTextToShow = summaryPreview;
      canExpand = false;
    } else {
      transcriptionTextToShow = "";
      canExpand = false;
    }

    final Color baseWaveColor = widget.recording.moodColor.withOpacity(0.65);
    final Color progressWaveColor = widget.recording.moodColor;
    final Color thumbWaveColor = HSLColor.fromColor(widget.recording.moodColor)
        .withLightness(
          (HSLColor.fromColor(widget.recording.moodColor).lightness - 0.1)
              .clamp(0.0, 1.0),
        )
        .toColor();

    Duration elapsedDuration = Duration.zero;
    // Calculate elapsed duration if there's any progress (playing OR PAUSED)
    if (widget.playbackProgressPercent > 0) {
      final totalMilliseconds = widget.recording.duration.inMilliseconds;
      final elapsedMilliseconds =
          (totalMilliseconds * widget.playbackProgressPercent).round();
      elapsedDuration = Duration(milliseconds: elapsedMilliseconds);
    }

    String durationToDisplay;
    // If there's progress (widget.playbackProgressPercent > 0), it means the track
    // has been played at least some amount and could be currently playing OR PAUSED.
    // In this case, show "elapsed / total".
    // Otherwise (stopped/not started, widget.playbackProgressPercent is 0), show total duration.
    if (widget.playbackProgressPercent > 0) {
      durationToDisplay =
          '${_formatDuration(elapsedDuration)} / ${_formatDuration(widget.recording.duration)}';
    } else {
      durationToDisplay = _formatDuration(widget.recording.duration);
    }

    return Card(
      elevation: widget.isSelected ? 6.0 : 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: widget.isSelected
            ? BorderSide(color: widget.recording.moodColor, width: 1.8)
            : BorderSide(
                color: theme.dividerColor.withOpacity(0.2),
                width: 0.8,
              ),
      ),
      child: InkWell(
        onTap: widget.onSelect ?? widget.onPlayToggle,
        onLongPress: widget.onLongPress,
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
                      widget.recording.displayName,
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
                    width: 36,
                    height: 36,
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.hintColor,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: "More options",
                      onSelected: (value) {
                        if (value == 'edit' && widget.onEdit != null) {
                          widget.onEdit!();
                        }
                        if (value == 'delete' && widget.onDelete != null) {
                          widget.onDelete!();
                        }
                        if (value == 'share' && widget.onShare != null) {
                          widget.onShare!();
                        }
                        if (value == 'transcribe' &&
                            widget.onTranscribe != null) {
                          widget.onTranscribe!();
                        }
                        if (value == 'move_to_vault' &&
                            widget.onMoveToVault != null) {
                          widget.onMoveToVault!();
                        }
                        if (value == 'view_transcription' &&
                            widget.onViewTranscription != null) {
                          widget.onViewTranscription!();
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            if (widget.onEdit != null)
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
                            if (widget.onShare != null)
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
                            if (widget.onTranscribe != null &&
                                !hasFullTranscription)
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
                                widget.onViewTranscription != null &&
                                !canExpand)
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
                            if (widget.onMoveToVault != null)
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
                            if (widget.onDelete != null)
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

              if (transcriptionTextToShow.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0, top: 2.0),
                      child: SelectableText(
                        transcriptionTextToShow,
                        style:
                            GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: _isTranscriptionExpanded
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.hintColor.withOpacity(0.9),
                              fontStyle: !_isTranscriptionExpanded && hasSummary
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ).copyWith(
                              overflow: _isTranscriptionExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                            ),
                        maxLines: _isTranscriptionExpanded
                            ? null
                            : collapsedPreviewMaxLines,
                        onTap: canExpand
                            ? () {
                                setState(() {
                                  _isTranscriptionExpanded =
                                      !_isTranscriptionExpanded;
                                });
                              }
                            : null,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),

              if (waveformData.isNotEmpty)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    if (widget.onSeekRequest != null && widget.isPlaying) {
                      final RenderBox box =
                          context.findRenderObject() as RenderBox;
                      final localOffset = box.globalToLocal(
                        details.globalPosition,
                      );
                      final seekPercent = (localOffset.dx / box.size.width)
                          .clamp(0.0, 1.0);
                      widget.onSeekRequest!(seekPercent);
                    } else if (!widget.isPlaying) {
                      // If PAUSED or STOPPED
                      widget.onPlayToggle(); // Parent handles resume or start
                    }
                  },
                  onHorizontalDragUpdate: (details) {
                    if (widget.onSeekRequest != null && widget.isPlaying) {
                      final RenderBox box =
                          context.findRenderObject() as RenderBox;
                      final localOffset = box.globalToLocal(
                        details.globalPosition,
                      );
                      final seekPercent = (localOffset.dx / box.size.width)
                          .clamp(0.0, 1.0);
                      widget.onSeekRequest!(seekPercent);
                    }
                  },
                  child: Container(
                    height: 30.0,
                    margin: EdgeInsets.only(
                      top: (transcriptionTextToShow.isNotEmpty) ? 6.0 : 2.0,
                      bottom: 8.0,
                    ),
                    width: double.infinity,
                    child: CustomPaint(
                      painter: MiniWaveformPainter(
                        waveformData: waveformData,
                        waveColor: baseWaveColor,
                        strokeWidth: 1.8,
                        // CRITICAL: The painter uses the playbackProgressPercent
                        // directly. If this value is correctly maintained by the
                        // parent widget (HomeScreen) during pause (i.e., NOT reset
                        // to 0.0), the dot will stay where it was paused.
                        // If the dot disappears, it means widget.playbackProgressPercent
                        // is becoming 0.0 when you pause, which is an issue in the
                        // PARENT WIDGET'S state management.
                        progressPercent: widget.playbackProgressPercent,
                        progressColor: progressWaveColor,
                        thumbColor: thumbWaveColor,
                      ),
                    ),
                  ),
                ),
              if (waveformData.isEmpty && transcriptionTextToShow.isEmpty)
                const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormat.format(widget.recording.dateRecorded),
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: theme.hintColor.withOpacity(0.85),
                        ),
                      ),
                      Text(
                        timeFormat.format(widget.recording.dateRecorded),
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: theme.hintColor.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    durationToDisplay, // This correctly shows elapsed/total if progress > 0
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.end,
                  ),
                  AnimatedWaveformPlayButton(
                    // isPlaying is true if actively playing, false if paused/stopped.
                    // This controls the button's icon.
                    isPlaying: widget.isPlaying,
                    onTap: widget
                        .onPlayToggle, // Parent handles actual play/pause/resume
                    activeColor: widget.recording.moodColor,
                    inactiveColor: theme.hintColor.withOpacity(0.6),
                    size: const Size(32, 32),
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
