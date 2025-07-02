import 'dart:async';

import 'package:echolog/models/recording_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  final bool isVaultAvailable; // New prop to control vault menu visibility

  const RecordingCard({
    required Key key,
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
    this.isVaultAvailable = true, // Default to true for backward compatibility
  }) : super(key: key);

  @override
  State<RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends State<RecordingCard>
    with TickerProviderStateMixin {
  bool _isTranscriptionExpanded = false;
  bool _isTranscriptionHidden = false;

  Ticker? _realtimeTicker;

  @override
  void initState() {
    super.initState();
    // No PlayerController needed for progress bar
    _maybeStartOrStopTicker();
  }

  @override
  void didUpdateWidget(RecordingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No local state for progress or play/pause; always use parent props for UI.
    _maybeStartOrStopTicker();
  }

  @override
  void dispose() {
    _realtimeTicker?.dispose();
    super.dispose();
  }

  void _maybeStartOrStopTicker() {
    if (widget.isPlaying) {
      if (_realtimeTicker == null) {
        _realtimeTicker = createTicker((_) {
          if (mounted) setState(() {});
        });
        _realtimeTicker!.start();
      } else if (!_realtimeTicker!.isActive) {
        _realtimeTicker!.start();
      }
    } else {
      _realtimeTicker?.stop();
    }
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

    // Removed waveformData and math usage
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
                (fullTranscription.length > collapsedPreviewLength)
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

    // --- Real-time progress update fix ---
    // If the parent is not rebuilding this widget in real time, force a rebuild using an AnimationController
    // This is a workaround for when the parent does not use ValueListenableBuilder/StreamBuilder for progress.
    // Only do this for the currently playing card (isPlaying == true)
    if (widget.isPlaying && widget.onSeekRequest != null) {
      // Use a ticker to force rebuild every 100ms
      return _RealtimeProgressWrapper(
        builder: (context) => _buildCardContent(
          context,
          theme,
          dateFormat,
          timeFormat,
          transcriptionTextToShow,
          canExpand,
          elapsedDuration,
          durationToDisplay,
          fullTranscription,
          summaryPreview,
        ),
      );
    } else {
      return _buildCardContent(
        context,
        theme,
        dateFormat,
        timeFormat,
        transcriptionTextToShow,
        canExpand,
        elapsedDuration,
        durationToDisplay,
        fullTranscription,
        summaryPreview,
      );
    }
  }

  Widget _buildCardContent(
    BuildContext context,
    ThemeData theme,
    DateFormat dateFormat,
    DateFormat timeFormat,
    String transcriptionTextToShow,
    bool canExpand,
    Duration elapsedDuration,
    String durationToDisplay,
    String? fullTranscription,
    String? summaryPreview,
  ) {
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
                                !(fullTranscription != null &&
                                    fullTranscription.isNotEmpty))
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
                            if ((fullTranscription != null &&
                                    fullTranscription.isNotEmpty) &&
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
                            if ((fullTranscription != null &&
                                    fullTranscription.isNotEmpty) &&
                                !_isTranscriptionHidden)
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
                            if ((fullTranscription != null &&
                                    fullTranscription.isNotEmpty) &&
                                _isTranscriptionHidden)
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
                            if (widget.onMoveToVault != null &&
                                widget.isVaultAvailable)
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
                      child: GestureDetector(
                        onTap: canExpand
                            ? () {
                                setState(() {
                                  _isTranscriptionExpanded =
                                      !_isTranscriptionExpanded;
                                });
                              }
                            : null,
                        child: Text(
                          transcriptionTextToShow,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: _isTranscriptionExpanded
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.hintColor.withOpacity(0.9),
                            fontStyle: !_isTranscriptionExpanded && canExpand
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          maxLines: _isTranscriptionExpanded ? null : 2,
                          overflow: _isTranscriptionExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16.0,
                  ),
                  activeTrackColor: widget.recording.moodColor,
                  inactiveTrackColor: widget.recording.moodColor.withOpacity(
                    0.25,
                  ),
                  thumbColor: widget.recording.moodColor,
                ),
                child: Slider(
                  min: 0.0,
                  max: 1.0,
                  value: widget.playbackProgressPercent.clamp(0.0, 1.0),
                  onChanged: widget.onSeekRequest,
                  onChangeEnd: widget.onSeekRequest,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeFormat.format(widget.recording.dateRecorded),
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: theme.hintColor.withOpacity(0.85),
                        ),
                      ),
                      Text(
                        dateFormat.format(widget.recording.dateRecorded),
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
                  IconButton(
                    icon: Icon(
                      widget.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: widget.recording.moodColor,
                      size: 32,
                    ),
                    onPressed: widget.onPlayToggle,
                    tooltip: widget.isPlaying ? 'Pause' : 'Play',
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

// --- Helper widget to force rebuild for real-time progress ---
class _RealtimeProgressWrapper extends StatefulWidget {
  final WidgetBuilder builder;
  const _RealtimeProgressWrapper({required this.builder});
  @override
  State<_RealtimeProgressWrapper> createState() =>
      _RealtimeProgressWrapperState();
}

class _RealtimeProgressWrapperState extends State<_RealtimeProgressWrapper>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
