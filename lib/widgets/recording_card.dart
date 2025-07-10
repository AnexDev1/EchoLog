// import 'dart:async';
import 'dart:async';
import 'dart:ui';

import 'package:echolog/models/recording_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

// Import the TranscriptionProgressWidget (move to a shared location if needed)
import 'package:echolog/widgets/transcription_progress_widget.dart';
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
  final bool isVaultAvailable;

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
    this.isVaultAvailable = true,
  }) : super(key: key);

  @override
  State<RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends State<RecordingCard>
    with TickerProviderStateMixin {
  late final ValueNotifier<double> _progressNotifier;
  bool _wasPlayingBeforeDrag = false;
  bool _isTranscriptionExpanded = false;
  bool _isTranscriptionHidden = false;
  bool _isHovered = false;
  bool _isPlayingLocal = false;
  double _playbackProgressPercentLocal = 0.0;
  double _dragProgress = 0.0;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  Ticker? _realtimeTicker;
  Duration? _lastTickElapsed;
  Duration? _seekedTo;

  @override
  void initState() {
    super.initState();
    _progressNotifier = ValueNotifier<double>(0.0);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _slideController.forward();
    _isPlayingLocal = widget.isPlaying;
    _playbackProgressPercentLocal = widget.playbackProgressPercent;
    _progressNotifier.value = _playbackProgressPercentLocal;
    _maybeStartOrStopTicker();
  }

  @override
  void didUpdateWidget(RecordingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      _isPlayingLocal = widget.isPlaying;
      if (_isPlayingLocal) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
    if (widget.playbackProgressPercent != oldWidget.playbackProgressPercent) {
      _playbackProgressPercentLocal = widget.playbackProgressPercent;
      // Avoid updating during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _progressNotifier.value = _playbackProgressPercentLocal;
      });
    }
    _maybeStartOrStopTicker();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _realtimeTicker?.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  void _maybeStartOrStopTicker() {
    if (_isPlayingLocal) {
      if (_realtimeTicker == null) {
        _realtimeTicker = createTicker((Duration elapsed) {
          if (!mounted) return;
          final totalMs = widget.recording.duration.inMilliseconds;
          if (totalMs > 0) {
            Duration base = _seekedTo ?? Duration.zero;
            Duration sinceSeek = elapsed - (_lastTickElapsed ?? Duration.zero);
            double progress = (base + sinceSeek).inMilliseconds / totalMs;
            progress = progress.clamp(0.0, 1.0);
            if (progress >= 1.0) {
              progress = 1.0;
              _isPlayingLocal = false;
              _pulseController.stop();
              _realtimeTicker?.stop();
            }
            _playbackProgressPercentLocal = progress;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                _progressNotifier.value = _playbackProgressPercentLocal;
            });
          }
        });
        _lastTickElapsed = Duration.zero;
        _seekedTo = Duration(
          milliseconds:
              (_playbackProgressPercentLocal *
                      widget.recording.duration.inMilliseconds)
                  .round(),
        );
        _realtimeTicker!.start();
      } else if (!_realtimeTicker!.isActive) {
        _lastTickElapsed = Duration.zero;
        _seekedTo = Duration(
          milliseconds:
              (_playbackProgressPercentLocal *
                      widget.recording.duration.inMilliseconds)
                  .round(),
        );
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
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E).withOpacity(0.95)
                    : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Delete Recording?",
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "This will permanently delete \"${widget.recording.displayName}\". This action cannot be undone.",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _ModernButton(
                          text: "Cancel",
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          isSecondary: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModernButton(
                          text: "Delete",
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            if (widget.onDelete != null) {
                              widget.onDelete!();
                            }
                          },
                          isDestructive: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final DateFormat dateFormat = DateFormat('MMM d, yyyy');
    final DateFormat timeFormat = DateFormat('h:mm a');

    final String? summaryPreview = widget.recording.summaryPreview;
    final String? fullTranscription = widget.recording.transcription;
    final bool hasFullTranscription =
        fullTranscription != null && fullTranscription.isNotEmpty;
    final bool hasSummary = summaryPreview != null && summaryPreview.isNotEmpty;

    String transcriptionTextToShow = "";
    bool canExpand = false;
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
    if (_playbackProgressPercentLocal > 0) {
      final totalMilliseconds = widget.recording.duration.inMilliseconds;
      final elapsedMilliseconds =
          (totalMilliseconds * _playbackProgressPercentLocal).round();
      elapsedDuration = Duration(milliseconds: elapsedMilliseconds);
    }

    String durationToDisplay;
    if (_playbackProgressPercentLocal > 0) {
      durationToDisplay =
          '${_formatDuration(elapsedDuration)} / ${_formatDuration(widget.recording.duration)}';
    } else {
      durationToDisplay = _formatDuration(widget.recording.duration);
    }

    if (widget.isPlaying && widget.onSeekRequest != null) {
      return _RealtimeProgressWrapper(
        builder: (context) => _buildCardContent(
          context,
          theme,
          isDark,
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
        isDark,
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
    bool isDark,
    DateFormat dateFormat,
    DateFormat timeFormat,
    String transcriptionTextToShow,
    bool canExpand,
    Duration elapsedDuration,
    String durationToDisplay,
    String? fullTranscription,
    String? summaryPreview,
  ) {
    return SlideTransition(
      position: _slideAnimation,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? widget.recording.moodColor.withOpacity(0.3)
                  : isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.04),
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.08),
                blurRadius: _isHovered ? 24 : 16,
                offset: Offset(0, _isHovered ? 12 : 8),
              ),
              if (widget.isSelected)
                BoxShadow(
                  color: widget.recording.moodColor.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onSelect ?? widget.onPlayToggle,
              onLongPress: widget.onLongPress,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title and menu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.recording.displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_outlined,
                                    size: 14,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${timeFormat.format(widget.recording.dateRecorded)} • ${dateFormat.format(widget.recording.dateRecorded)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        _ModernMenuButton(
                          onSelected: (value) => _handleMenuAction(
                            value,
                            context,
                            fullTranscription,
                          ),
                          items: _buildMenuItems(fullTranscription),
                          isDark: isDark,
                        ),
                      ],
                    ),

                    // Transcription section
                    if (transcriptionTextToShow.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildTranscriptionSection(
                        transcriptionTextToShow,
                        canExpand,
                        theme,
                        isDark,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Progress bar
                    ValueListenableBuilder<double>(
                      valueListenable: _progressNotifier,
                      builder: (context, value, _) =>
                          _buildProgressBar(theme, isDark, value),
                    ),

                    const SizedBox(height: 16),

                    // Controls row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          durationToDisplay,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                        _buildPlayButton(theme, isDark),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptionSection(
    String transcriptionTextToShow,
    bool canExpand,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.recording.moodColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Transcription',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.recording.moodColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (canExpand)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isTranscriptionExpanded = !_isTranscriptionExpanded;
                    });
                  },
                  child: Icon(
                    _isTranscriptionExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: canExpand
                ? () {
                    setState(() {
                      _isTranscriptionExpanded = !_isTranscriptionExpanded;
                    });
                  }
                : null,
            child: Text(
              transcriptionTextToShow,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                height: 1.5,
              ),
              maxLines: _isTranscriptionExpanded ? null : 3,
              overflow: _isTranscriptionExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    ThemeData theme,
    bool isDark,
    double currentProgress,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barHeight = 6.0;
        final thumbRadius = 8.0;
        final thumbVisible =
            _isPlayingLocal || _playbackProgressPercentLocal > 0.02;
        // currentProgress is now passed in from ValueListenableBuilder
        final progressWidth =
            constraints.maxWidth * currentProgress.clamp(0.0, 1.0);
        return SizedBox(
          height: 24,
          child: Stack(
            children: [
              // Background track
              Positioned(
                left: 0,
                right: 0,
                top: (24 - barHeight) / 2,
                child: Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Progress track
              Positioned(
                left: 0,
                top: (24 - barHeight) / 2,
                child: Container(
                  width: progressWidth,
                  height: barHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.recording.moodColor,
                        widget.recording.moodColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Thumb (visible when dragging or hovering)
              if (thumbVisible)
                Positioned(
                  left: progressWidth - thumbRadius,
                  top: (24 / 2) - thumbRadius,
                  child: Container(
                    width: thumbRadius * 2,
                    height: thumbRadius * 2,
                    decoration: BoxDecoration(
                      color: widget.recording.moodColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.recording.moodColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              // Gesture detector for seeking
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (details) {
                    final progress =
                        details.localPosition.dx / constraints.maxWidth;
                    setState(() {
                      _playbackProgressPercentLocal = progress.clamp(0.0, 1.0);
                    });
                  },
                  onPanStart: (details) {
                    final progress =
                        details.localPosition.dx / constraints.maxWidth;
                    _wasPlayingBeforeDrag = _isPlayingLocal;
                    setState(() {
                      _dragProgress = progress.clamp(0.0, 1.0);
                      // Only pause if it was playing
                      if (_isPlayingLocal) {
                        _isPlayingLocal = false;
                        _pulseController.stop();
                        _realtimeTicker?.stop();
                      }
                    });
                  },
                  onPanUpdate: (details) {
                    final progress =
                        details.localPosition.dx / constraints.maxWidth;
                    setState(() {
                      _dragProgress = progress.clamp(0.0, 1.0);
                      _playbackProgressPercentLocal = _dragProgress;
                      _progressNotifier.value = _playbackProgressPercentLocal;
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _playbackProgressPercentLocal = _dragProgress;
                      _progressNotifier.value = _playbackProgressPercentLocal;
                      // Update ticker base for seamless resume
                      _seekedTo = Duration(
                        milliseconds:
                            (_playbackProgressPercentLocal *
                                    widget.recording.duration.inMilliseconds)
                                .round(),
                      );
                      _lastTickElapsed = Duration.zero;
                      if (_wasPlayingBeforeDrag) {
                        _isPlayingLocal = true;
                        _pulseController.repeat(reverse: true);
                        _maybeStartOrStopTicker();
                      } else {
                        _isPlayingLocal = false;
                        _pulseController.stop();
                        _realtimeTicker?.stop();
                      }
                    });
                    widget.onSeekRequest?.call(_dragProgress);
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayButton(ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                widget.recording.moodColor,
                widget.recording.moodColor.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.recording.moodColor.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              if (_isPlayingLocal)
                BoxShadow(
                  color: widget.recording.moodColor.withOpacity(
                    0.4 + (_pulseAnimation.value * 0.3),
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_isPlayingLocal) {
                    _isPlayingLocal = false;
                    _pulseController.stop();
                    _realtimeTicker?.stop();
                  } else {
                    _isPlayingLocal = true;
                    _pulseController.repeat(reverse: true);
                    // If at end, reset progress
                    if (_playbackProgressPercentLocal >= 1.0) {
                      _playbackProgressPercentLocal = 0.0;
                    }
                    _maybeStartOrStopTicker();
                  }
                });
                widget.onPlayToggle();
              },
              borderRadius: BorderRadius.circular(28),
              child: Icon(
                _isPlayingLocal
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(String? fullTranscription) {
    final List<PopupMenuEntry<String>> items = [];

    if (widget.onEdit != null) {
      items.add(_buildMenuItem('edit', Icons.edit_outlined, 'Edit Title'));
    }

    if (widget.onShare != null) {
      items.add(_buildMenuItem('share', Icons.share_outlined, 'Share'));
    }

    if (widget.onTranscribe != null &&
        !(fullTranscription != null && fullTranscription.isNotEmpty)) {
      items.add(_buildMenuItem('transcribe', Icons.mic_outlined, 'Transcribe'));
    }

    if (fullTranscription != null && fullTranscription.isNotEmpty) {
      if (widget.onViewTranscription != null) {
        items.add(
          _buildMenuItem(
            'view_transcription',
            Icons.article_outlined,
            'View Full Text',
          ),
        );
      }

      if (!_isTranscriptionHidden) {
        items.add(
          _buildMenuItem(
            'hide_transcription',
            Icons.visibility_off_outlined,
            'Hide Transcription',
          ),
        );
      } else {
        items.add(
          _buildMenuItem(
            'show_transcription',
            Icons.visibility_outlined,
            'Show Transcription',
          ),
        );
      }
    }

    if (widget.onMoveToVault != null && widget.isVaultAvailable) {
      items.add(
        _buildMenuItem(
          'move_to_vault',
          Icons.shield_outlined,
          widget.isOut ? 'Remove from Vault' : 'Move to Vault',
        ),
      );
    }

    if (items.isNotEmpty && widget.onDelete != null) {
      items.add(const PopupMenuDivider());
    }

    if (widget.onDelete != null) {
      items.add(
        _buildMenuItem(
          'delete',
          Icons.delete_outline,
          'Delete',
          isDestructive: true,
        ),
      );
    }

    return items;
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String text, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDestructive ? Colors.red : null),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDestructive ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(
    String value,
    BuildContext context,
    String? fullTranscription,
  ) {
    switch (value) {
      case 'edit':
        widget.onEdit?.call();
        break;
      case 'delete':
        _showDeleteConfirmationDialog(context);
        break;
      case 'share':
        widget.onShare?.call();
        break;
      case 'transcribe':
        _showTranscriptionProgress(context);
        // Delay the actual transcription logic until after the dialog is shown
        // (optionally, you can start transcription immediately if needed)
        Future.delayed(const Duration(milliseconds: 100), () {
          widget.onTranscribe?.call();
        });
        break;
      case 'move_to_vault':
        widget.onMoveToVault?.call();
        break;
      case 'view_transcription':
        widget.onViewTranscription?.call();
        break;
      case 'hide_transcription':
        setState(() => _isTranscriptionHidden = true);
        widget.onHideTranscription?.call();
        break;
      case 'show_transcription':
        setState(() => _isTranscriptionHidden = false);
        widget.onShowTranscription?.call();
        break;
    }
  }

  // Show the transcription progress dialog
  void _showTranscriptionProgress(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: TranscriptionProgressWidget(
            recordingDuration: widget.recording.duration,
            accentColor: widget.recording.moodColor,
            isDark: theme.brightness == Brightness.dark,
            onCancel: () {
              Navigator.of(context).pop();
              // Optionally: handle cancellation logic here
            },
          ),
        );
      },
    );
  }
}

// Modern menu button component
class _ModernMenuButton extends StatelessWidget {
  final Function(String) onSelected;
  final List<PopupMenuEntry<String>> items;
  final bool isDark;

  const _ModernMenuButton({
    required this.onSelected,
    required this.items,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: PopupMenuButton<String>(
        onSelected: onSelected,
        itemBuilder: (context) => items,
        icon: Icon(
          Icons.more_horiz,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          size: 20,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 20,
        offset: const Offset(0, 8),
      ),
    );
  }
}

// Modern button component for dialogs
class _ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isSecondary;
  final bool isDestructive;

  const _ModernButton({
    required this.text,
    required this.onPressed,
    this.isSecondary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isSecondary
            ? (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05))
            : (isDestructive ? Colors.red : theme.colorScheme.primary),
        borderRadius: BorderRadius.circular(12),
        border: isSecondary
            ? Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSecondary ? theme.colorScheme.onSurface : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Real-time progress wrapper
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

class TranscriptionProgressWidget extends StatefulWidget {
  final Duration recordingDuration;
  final Color accentColor;
  final VoidCallback? onCancel;
  final bool isDark;

  const TranscriptionProgressWidget({
    Key? key,
    required this.recordingDuration,
    required this.accentColor,
    this.onCancel,
    this.isDark = false,
  }) : super(key: key);

  @override
  State<TranscriptionProgressWidget> createState() =>
      _TranscriptionProgressWidgetState();
}

class _TranscriptionProgressWidgetState
    extends State<TranscriptionProgressWidget>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  int _currentStage = 0;
  Timer? _stageTimer;
  Timer? _progressTimer;
  double _overallProgress = 0.0;
  bool _isCompleted = false;

  final List<TranscriptionStage> _stages = [
    TranscriptionStage(
      title: "Initializing",
      description: "Preparing audio analysis...",
      duration: Duration(milliseconds: 1200),
      icon: Icons.settings_outlined,
    ),
    TranscriptionStage(
      title: "Detecting Language",
      description: "Analyzing speech patterns...",
      duration: Duration(milliseconds: 1800),
      icon: Icons.language_outlined,
    ),
    TranscriptionStage(
      title: "Processing Audio",
      description: "Enhancing audio quality...",
      duration: Duration(milliseconds: 2200),
      icon: Icons.graphic_eq_outlined,
    ),
    TranscriptionStage(
      title: "Transcribing Speech",
      description: "Converting speech to text...",
      duration: Duration(milliseconds: 3500),
      icon: Icons.mic_outlined,
    ),
    TranscriptionStage(
      title: "Refining Results",
      description: "Improving accuracy and formatting...",
      duration: Duration(milliseconds: 1800),
      icon: Icons.auto_fix_high_outlined,
    ),
    TranscriptionStage(
      title: "Finalizing",
      description: "Preparing transcription...",
      duration: Duration(milliseconds: 1000),
      icon: Icons.check_circle_outline,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startTranscription();
  }

  void _setupAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }

  void _startTranscription() {
    _advanceStage();

    // Start overall progress timer
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;

      final totalDuration = _stages.fold<int>(
        0,
        (sum, stage) => sum + stage.duration.inMilliseconds,
      );

      final currentStageStartTime = _stages
          .take(_currentStage)
          .fold<int>(0, (sum, stage) => sum + stage.duration.inMilliseconds);

      final elapsedInCurrentStage = timer.tick * 50;
      final totalElapsed = currentStageStartTime + elapsedInCurrentStage;

      setState(() {
        _overallProgress = (totalElapsed / totalDuration).clamp(0.0, 1.0);
      });

      if (_overallProgress >= 1.0) {
        timer.cancel();
        _completeTranscription();
      }
    });
  }

  void _advanceStage() {
    if (_currentStage >= _stages.length) return;

    _progressController.forward(from: 0.0);

    _stageTimer?.cancel();
    _stageTimer = Timer(_stages[_currentStage].duration, () {
      if (!mounted) return;

      if (_currentStage < _stages.length - 1) {
        setState(() {
          _currentStage++;
        });
        _advanceStage();
      }
    });
  }

  void _completeTranscription() {
    setState(() {
      _isCompleted = true;
      _overallProgress = 1.0;
    });

    _pulseController.stop();
    _progressController.forward();

    // Auto-dismiss after showing completion
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _stageTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStage = _currentStage < _stages.length
        ? _stages[_currentStage]
        : _stages.last;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF1C1C1E).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with pulsing icon
          FadeTransition(
            opacity: _fadeAnimation,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.accentColor.withOpacity(0.2),
                        widget.accentColor.withOpacity(0.05),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(
                          0.3 + (_pulseAnimation.value * 0.2),
                        ),
                        blurRadius: 20 + (_pulseAnimation.value * 10),
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accentColor.withOpacity(0.1),
                    ),
                    child: Icon(
                      _isCompleted ? Icons.check_circle : currentStage.icon,
                      size: 40,
                      color: widget.accentColor,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Stage title
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _isCompleted ? "Transcription Complete!" : currentStage.title,
              key: ValueKey(_isCompleted ? "completed" : currentStage.title),
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 8),

          // Stage description
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _isCompleted
                  ? "Your audio has been successfully transcribed"
                  : currentStage.description,
              key: ValueKey(
                _isCompleted ? "completed_desc" : currentStage.description,
              ),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: (widget.isDark ? Colors.white : Colors.black87)
                    .withOpacity(0.7),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 32),

          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                // Overall progress
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width:
                      MediaQuery.of(context).size.width *
                      0.6 *
                      _overallProgress,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.accentColor,
                        widget.accentColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Animated shimmer effect
                if (!_isCompleted)
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Positioned(
                        left:
                            (MediaQuery.of(context).size.width *
                                0.6 *
                                _overallProgress) -
                            20,
                        child: Container(
                          width: 40,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.3),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Progress percentage and stage indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${(_overallProgress * 100).toInt()}%",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.accentColor,
                ),
              ),
              Text(
                "Stage ${_currentStage + 1} of ${_stages.length}",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: (widget.isDark ? Colors.white : Colors.black87)
                      .withOpacity(0.6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Stage indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_stages.length, (index) {
              final isActive = index == _currentStage;
              final isCompleted = index < _currentStage || _isCompleted;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? widget.accentColor
                      : isActive
                      ? widget.accentColor.withOpacity(0.5)
                      : (widget.isDark ? Colors.white : Colors.black87)
                            .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // Cancel button (only show if not completed)
          if (!_isCompleted && widget.onCancel != null)
            TextButton(
              onPressed: widget.onCancel,
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: (widget.isDark ? Colors.white : Colors.black87)
                      .withOpacity(0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TranscriptionStage {
  final String title;
  final String description;
  final Duration duration;
  final IconData icon;

  TranscriptionStage({
    required this.title,
    required this.description,
    required this.duration,
    required this.icon,
  });
}

// Usage example: Add this method to your RecordingCard class
void _showTranscriptionProgress(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: TranscriptionProgressWidget(
          recordingDuration: Duration(seconds: 10), // Example duration
          accentColor: Colors.blue,
          isDark: Theme.of(context).brightness == Brightness.dark,
          onCancel: () {
            Navigator.of(context).pop();
            // Handle cancellation logic here
          },
        ),
      );
    },
  );
}
