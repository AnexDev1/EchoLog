import 'dart:math' as math;

import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/widgets/animated_waveform_play_button.dart';
import 'package:echolog/widgets/mini_waveform_painter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RecordingCard extends StatefulWidget {
  final RecordingEntry recording;
  final VoidCallback onPlayToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onTranscribe;
  final VoidCallback? onMoveToVault;
  final VoidCallback? onViewTranscription;
  final VoidCallback? onHideTranscription;
  final VoidCallback? onShowTranscription;
  final bool isPlaying;
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback? onLongPress;
  final double playbackProgressPercent;
  final Function(double)? onSeekRequest;
  final bool isOut;

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
    this.onHideTranscription,
    this.onShowTranscription,
    required this.isPlaying,
    this.isSelected = false,
    this.onSelect,
    this.onLongPress,
    this.playbackProgressPercent = 0.0,
    this.onSeekRequest,
    this.isOut = false,
  });

  @override
  State<RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends State<RecordingCard>
    with TickerProviderStateMixin {
  bool _isTranscriptionExpanded = false;
  bool _isTranscriptionHidden = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isPlaying) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(RecordingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_animationController.isAnimating) {
          _animationController.repeat();
        }
      } else {
        if (_animationController.isAnimating) {
          _animationController.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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

  void _showDeleteConfirmationDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            "Delete Recording?",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            "Are you sure you want to permanently delete \"${widget.recording.displayName}\"?\n\nThis action cannot be undone.",
            style: GoogleFonts.poppins(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Delete",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (widget.onDelete != null) {
                  widget.onDelete!();
                }
              },
            ),
          ],
        );
      },
    );
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

    String transcriptionTextToShow = "";
    bool canExpand = false;
    const int collapsedPreviewMaxLines = 2;
    const int collapsedPreviewLength = 120;

    if (!_isTranscriptionHidden) {
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
      }
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
    if (widget.playbackProgressPercent > 0) {
      final totalMilliseconds = widget.recording.duration.inMilliseconds;
      final elapsedMilliseconds =
          (totalMilliseconds * widget.playbackProgressPercent).round();
      elapsedDuration = Duration(milliseconds: elapsedMilliseconds);
    }

    String durationToDisplay;
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
                          _showDeleteConfirmationDialog(context);
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
                        if (value == 'hide_transcription') {
                          setState(() {
                            _isTranscriptionHidden = true;
                          });
                          if (widget.onHideTranscription != null) {
                            widget.onHideTranscription!();
                          }
                        }
                        if (value == 'show_transcription') {
                          setState(() {
                            _isTranscriptionHidden = false;
                          });
                          if (widget.onShowTranscription != null) {
                            widget.onShowTranscription!();
                          }
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
                            if (hasFullTranscription && !_isTranscriptionHidden)
                              const PopupMenuItem<String>(
                                value: 'hide_transcription',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Text('Hide Transcription'),
                                  ],
                                ),
                              ),
                            if (hasFullTranscription && _isTranscriptionHidden)
                              const PopupMenuItem<String>(
                                value: 'show_transcription',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility_outlined, size: 20),
                                    SizedBox(width: 10),
                                    Text('Show Transcription'),
                                  ],
                                ),
                              ),
                            if (widget.onMoveToVault != null)
                              PopupMenuItem<String>(
                                value: 'move_to_vault',
                                child: Row(
                                  children: [
                                    const Icon(Icons.shield_outlined, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      widget.isOut
                                          ? 'Move Out of Vault'
                                          : 'Move to Vault',
                                    ),
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
                    if (widget.onSeekRequest != null) {
                      final RenderBox box =
                          context.findRenderObject() as RenderBox;
                      final localOffset = box.globalToLocal(
                        details.globalPosition,
                      );
                      final seekPercent = (localOffset.dx / box.size.width)
                          .clamp(0.0, 1.0);
                      widget.onSeekRequest!(seekPercent);
                    } else if (!widget.isPlaying) {
                      widget.onPlayToggle();
                    }
                  },
                  onHorizontalDragUpdate: (details) {
                    if (widget.onSeekRequest != null) {
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
                        strokeWidth: 3,
                        progressPercent: widget.playbackProgressPercent,
                        progressColor: progressWaveColor,
                        thumbColor: thumbWaveColor,
                        isAnimating: widget.isPlaying,
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
                  Expanded(
                    child: Text(
                      durationToDisplay,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedWaveformPlayButton(
                    isPlaying: widget.isPlaying,
                    onTap: widget.onPlayToggle,
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
