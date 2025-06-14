import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/recording_entry.dart';
import '../utils/duration_formatter.dart';
import 'package:flutter/services.dart'; // For Clipboard

enum TranscriptionDisplayState { hidden, preview, full }

class RecordingListItemWidget extends StatefulWidget {
  final RecordingEntry entry;
  final Function(RecordingEntry) onPlayPause;
  final Function(RecordingEntry) onMoveToVault;
  final Function(RecordingEntry) onShare;
  final Function(RecordingEntry) onTranscribe;

  const RecordingListItemWidget({
    super.key,
    required this.entry,
    required this.onPlayPause,
    required this.onMoveToVault,
    required this.onShare,
    required this.onTranscribe,
  });

  @override
  State<RecordingListItemWidget> createState() =>
      _RecordingListItemWidgetState();
}

class _RecordingListItemWidgetState extends State<RecordingListItemWidget> {
  TranscriptionDisplayState _transcriptionDisplay =
      TranscriptionDisplayState.hidden;
  final int _previewMaxLines = 3;

  @override
  void initState() {
    super.initState();
    if (widget.entry.transcription == null ||
        widget.entry.transcription!.trim().isEmpty) {
      _transcriptionDisplay = TranscriptionDisplayState.hidden;
    }
  }

  @override
  void didUpdateWidget(RecordingListItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.transcription != oldWidget.entry.transcription) {
      if (widget.entry.transcription == null ||
          widget.entry.transcription!.trim().isEmpty) {
        setState(() {
          _transcriptionDisplay = TranscriptionDisplayState.hidden;
        });
      } else if (oldWidget.entry.transcription == null ||
          oldWidget.entry.transcription!.trim().isEmpty) {
        setState(() {
          _transcriptionDisplay = TranscriptionDisplayState.hidden;
        });
      }
    }
  }

  void _showMoveToVaultDialog(BuildContext context, RecordingEntry itemToMove) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor:
              theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          shape:
              theme.dialogTheme.shape ??
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Text(
            'Move to Vault?',
            style:
                theme.dialogTheme.titleTextStyle ??
                GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
          ),
          content: Text(
            'Are you sure you want to move "${itemToMove.displayName}" to the secret vault? It will be hidden from this list.',
            style:
                theme.dialogTheme.contentTextStyle ??
                GoogleFonts.poppins(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
          ),
          actions: <Widget>[
            TextButton(
              style: theme.textButtonTheme.style,
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: theme.textButtonTheme.style?.copyWith(
                foregroundColor: MaterialStateProperty.all(
                  theme.colorScheme.primary,
                ),
              ),
              child: const Text('Move to Vault'),
              onPressed: () {
                widget.onMoveToVault(itemToMove);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildVisibleTranscriptionControls(
    ThemeData theme,
    RecordingEntry entry,
  ) {
    if (entry.transcription == null ||
        entry.transcription!.trim().isEmpty ||
        _transcriptionDisplay == TranscriptionDisplayState.hidden) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Transcription:",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              TextButton.icon(
                icon: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: theme.colorScheme.primary.withOpacity(0.8),
                ),
                label: Text(
                  "Copy",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: theme.colorScheme.primary.withOpacity(0.8),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: entry.transcription!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Transcription copied!")),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.transcription!,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withOpacity(0.75),
              height: 1.45,
            ),
            maxLines: _transcriptionDisplay == TranscriptionDisplayState.full
                ? null
                : _previewMaxLines,
            overflow: _transcriptionDisplay == TranscriptionDisplayState.full
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  _transcriptionDisplay == TranscriptionDisplayState.preview
                      ? "Show More"
                      : "Show Less",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _transcriptionDisplay =
                        _transcriptionDisplay ==
                            TranscriptionDisplayState.preview
                        ? TranscriptionDisplayState.full
                        : TranscriptionDisplayState.preview;
                  });
                },
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  "Hide",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _transcriptionDisplay = TranscriptionDisplayState.hidden;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RecordingEntry entry = widget.entry;

    final Color moodTagTextColor =
        ThemeData.estimateBrightnessForColor(entry.moodColor) == Brightness.dark
        ? Colors.white.withOpacity(0.9)
        : entry.moodColor;

    bool hasValidTranscription =
        entry.transcription != null && entry.transcription!.trim().isNotEmpty;

    return GestureDetector(
      onLongPress: () {
        if (!entry.isPlaying) {
          _showMoveToVaultDialog(context, entry);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stop playback before moving to vault.'),
            ),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: entry.moodColor.withOpacity(0.6), width: 1.5),
        ),
        elevation: theme.cardTheme.elevation ?? 2.0,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Main Content (Icon, Text Info, Play/Pause) and Share Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Graphic Icon
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, right: 12.0),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: entry.moodIconColor.withOpacity(0.9),
                      size: 28,
                    ),
                  ),
                  // Text Info (Title, Date, Mood) and Play/Pause Button
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment
                          .center, // Vertically center the text column and the play button
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize
                                .min, // Ensure column takes minimum vertical space
                            children: [
                              Text(
                                entry.displayName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${formatDuration(entry.duration)} • ${DateFormat('MMM d, yyyy').format(entry.dateRecorded)}',
                                style: GoogleFonts.poppins(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 6.0),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: entry.moodColor.withOpacity(
                                    theme.brightness == Brightness.dark
                                        ? 0.25
                                        : 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  entry.moodName,
                                  style: GoogleFonts.poppins(
                                    color: moodTagTextColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Play/Pause Button
                        IconButton(
                          icon: Icon(
                            entry.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: theme.colorScheme.primary,
                            size: 48.0, // INCREASED ICON SIZE
                          ),
                          splashRadius: 30.0, // Adjusted splash radius
                          tooltip: entry.isPlaying ? 'Pause' : 'Play',
                          // Add padding to ensure the tap target is reasonable if icon is very large
                          // padding: EdgeInsets.zero, // Or some small padding if needed
                          // constraints: BoxConstraints(), // To remove default constraints if necessary
                          onPressed: () => widget.onPlayPause(entry),
                        ),
                      ],
                    ),
                  ),
                  // Share Button (Top Right of the entire card content)
                  IconButton(
                    icon: Icon(
                      Icons.share_outlined,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      size: 24,
                    ),
                    tooltip: 'Share Recording',
                    splashRadius: 20.0,
                    onPressed: () => widget.onShare(entry),
                  ),
                ],
              ),

              // Visible Transcription Controls
              _buildVisibleTranscriptionControls(theme, entry),

              const SizedBox(height: 8),

              // Bottom Row: Transcription Toggle (Show/Transcribe)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  if (!hasValidTranscription)
                    IconButton(
                      icon: Icon(
                        Icons.notes_rounded,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        size: 24,
                      ),
                      tooltip: 'Transcribe Recording',
                      splashRadius: 20.0,
                      onPressed: () {
                        if (!entry.isPlaying) {
                          widget.onTranscribe(entry);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Stop playback before transcribing.',
                              ),
                            ),
                          );
                        }
                      },
                    )
                  else if (_transcriptionDisplay ==
                      TranscriptionDisplayState.hidden)
                    TextButton.icon(
                      icon: Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text(
                        "Show Transcription",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          _transcriptionDisplay =
                              TranscriptionDisplayState.preview;
                        });
                      },
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
