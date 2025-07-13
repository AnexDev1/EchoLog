// import 'dart:async';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:echolog/main.dart';
import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/services/api_key_service.dart';
import 'package:echolog/services/security_service.dart';
import 'package:echolog/widgets/transcription_progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// Helper for url_launcher LaunchMode (for backward compatibility)
// Remove this if LaunchMode is already available in your url_launcher version
enum _LaunchMode { platformDefault, inAppWebView, externalApplication }

Future<void> _launchApiKeyUrl() async {
  final url = Uri.parse('https://aistudio.google.com/apikey');
  // Try to use LaunchMode if available, otherwise fallback
  try {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    await launch(url.toString());
  }
}

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
  bool _isDragging = false;
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

  String? _aiResponse;
  bool _isGettingAIResponse = false;
  bool _isAIResponseHidden = false;
  Stream<String>? _aiResponseStream;
  String _streamedAIResponse = '';

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
    // Only update local progress from parent if not dragging
    if (!_isDragging &&
        widget.playbackProgressPercent != oldWidget.playbackProgressPercent) {
      _playbackProgressPercentLocal = widget.playbackProgressPercent;
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
          if (_isDragging)
            return; // Prevent ticker from updating progress while dragging
          final totalMs = widget.recording.duration.inMilliseconds;
          if (totalMs > 0) {
            Duration base = _seekedTo ?? Duration.zero;
            Duration sinceSeek = elapsed;
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
              if (mounted && !_isDragging) {
                _progressNotifier.value = _playbackProgressPercentLocal;
              }
            });
          }
        });
      }
      // Always reset ticker base and seekedTo when starting playback
      _realtimeTicker!.stop();
      _lastTickElapsed = Duration.zero;
      _seekedTo = Duration(
        milliseconds:
            (_playbackProgressPercentLocal *
                    widget.recording.duration.inMilliseconds)
                .round(),
      );
      _realtimeTicker!.start();
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
    final String? transcriptionError = widget.recording.transcriptionError;
    final bool hasFullTranscription =
        fullTranscription != null && fullTranscription.isNotEmpty;
    final bool hasSummary = summaryPreview != null && summaryPreview.isNotEmpty;

    String transcriptionTextToShow = "";
    bool canExpand = false;
    const int collapsedPreviewLength = 120;

    if (!_isTranscriptionHidden) {
      if (transcriptionError != null && transcriptionError.isNotEmpty) {
        transcriptionTextToShow = transcriptionError;
        canExpand = false;
      } else if (hasFullTranscription) {
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

    // Remove audio playing feature when card is clicked
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
              // Only allow selection, not play/pause on card tap
              onTap: widget.onSelect,
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

  Stream<String> _getAIResponseStream(String transcription) async* {
    final gemini = Gemini.instance;
    final prompt = [
      Part.text(
        'Analyze the following transcription. If it is a question, answer it. If it describes an achievement, congratulate and give tips. If it expresses sadness, give appreciation and encouragement. Always reply in the same language as the transcription., be friendly , feel like natural and human generated , use icons and emojis as needed',
      ),
      Part.text(transcription),
    ];
    try {
      await for (final value in gemini.promptStream(parts: prompt)) {
        yield value?.output ?? '';
      }
    } catch (e) {
      if (e.toString().contains('429')) {
        yield '🚫 Gemini API quota exceeded. Please try again later or check your usage limits.';
      } else {
        yield '❗️ An error occurred: ${e.toString()}';
      }
    }
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
                IconButton(
                  icon: Icon(
                    _isTranscriptionExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 22,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  onPressed: () {
                    setState(() {
                      _isTranscriptionExpanded = !_isTranscriptionExpanded;
                    });
                  },
                  tooltip: _isTranscriptionExpanded ? 'Collapse' : 'Expand',
                ),
            ],
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canExpand
                ? () {
                    setState(() {
                      _isTranscriptionExpanded = !_isTranscriptionExpanded;
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: AnimatedCrossFade(
                firstChild: Text(
                  transcriptionTextToShow,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                secondChild: Text(
                  transcriptionTextToShow,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    height: 1.5,
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
                crossFadeState: _isTranscriptionExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ),
          ),
          if (_isGettingAIResponse)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF232347)
                      : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.smart_toy_outlined,
                      color: isDark
                          ? const Color(0xFF90CAF9)
                          : const Color(0xFF1976D2),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _streamedAIResponse.isEmpty
                            ? AnimatedTextKit(
                                animatedTexts: [
                                  TypewriterAnimatedText(
                                    'Generating response...',
                                    textStyle: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: isDark
                                          ? const Color(0xFF90CAF9)
                                          : const Color(0xFF1976D2),
                                      fontWeight: FontWeight.w600,
                                      height: 1.5,
                                    ),
                                    speed: const Duration(milliseconds: 60),
                                  ),
                                ],
                                isRepeatingAnimation: true,
                                repeatForever: true,
                              )
                            : MarkdownBody(
                                data: _streamedAIResponse,
                                styleSheet:
                                    MarkdownStyleSheet.fromTheme(
                                      Theme.of(context),
                                    ).copyWith(
                                      p: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: isDark
                                            ? const Color(0xFF90CAF9)
                                            : const Color(0xFF1976D2),
                                        fontWeight: FontWeight.w600,
                                        height: 1.5,
                                      ),
                                    ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_aiResponse != null &&
              !_isAIResponseHidden &&
              !_isGettingAIResponse)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF232347)
                      : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.smart_toy_outlined,
                      color: isDark
                          ? const Color(0xFF90CAF9)
                          : const Color(0xFF1976D2),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: MarkdownBody(
                          data: _aiResponse!,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(
                                Theme.of(context),
                              ).copyWith(
                                p: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFF90CAF9)
                                      : const Color(0xFF1976D2),
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
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
            _isDragging ||
            _isPlayingLocal ||
            _playbackProgressPercentLocal > 0.02;
        // Use drag progress if dragging, otherwise use currentProgress
        // Only update _playbackProgressPercentLocal from drag, not from ticker, while dragging
        final double progressValue = _isDragging
            ? _dragProgress
            : currentProgress;
        final progressWidth =
            constraints.maxWidth * progressValue.clamp(0.0, 1.0);
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
                      _isDragging = true;
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
                      // Do NOT update _playbackProgressPercentLocal here, only update the notifier for UI
                      _progressNotifier.value = _dragProgress;
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isDragging = false;
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
                    // If at end, reset progress
                    if (_playbackProgressPercentLocal >= 1.0) {
                      _playbackProgressPercentLocal = 0.0;
                      _progressNotifier.value = 0.0;
                    }
                    _isPlayingLocal = true;
                    _pulseController.repeat(reverse: true);
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

      if (_aiResponse == null) {
        items.add(
          _buildMenuItem(
            'get_ai_response',
            Icons.smart_toy_outlined,
            'Get AI Response',
          ),
        );
      } else {
        if (_isAIResponseHidden) {
          items.add(
            _buildMenuItem(
              'show_ai_response',
              Icons.visibility_outlined,
              'Show AI Response',
            ),
          );
        } else {
          items.add(
            _buildMenuItem(
              'hide_ai_response',
              Icons.visibility_off_outlined,
              'Hide AI Response',
            ),
          );
        }
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
        _handleTranscribeWithApiKey(context);
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
      case 'get_ai_response':
        if (fullTranscription != null && fullTranscription.isNotEmpty) {
          setState(() {
            _isAIResponseHidden = false;
            _isGettingAIResponse = true;
            _aiResponse = null;
            _aiResponseStream = _getAIResponseStream(fullTranscription);
            _streamedAIResponse = '';
          });
          _aiResponseStream?.listen(
            (chunk) {
              setState(() {
                _streamedAIResponse += chunk;
              });
            },
            onDone: () {
              setState(() {
                _aiResponse = _streamedAIResponse;
                _isGettingAIResponse = false;
                _aiResponseStream = null;
                // TODO: Persist AI response for this recording
              });
            },
          );
        }
        break;
      case 'show_ai_response':
        setState(() {
          _isAIResponseHidden = false;
        });
        break;
      case 'hide_ai_response':
        setState(() {
          _isAIResponseHidden = true;
        });
        break;
    }
  }

  Future<void> _handleTranscribeWithApiKey(BuildContext context) async {
    // Always fetch the latest API key and re-init Gemini before every transcription
    final apiKey = await ApiKeyService.getApiKey();
    String? errorMsg;
    // Always clear Gemini instance before checking key (handles cleared key at runtime)
    // Gemini.init(apiKey: '');
    if (apiKey == null || apiKey.isEmpty) {
      // Show user-friendly dialog to enter API key
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          final theme = Theme.of(dialogContext);
          final isDark = theme.brightness == Brightness.dark;
          final TextEditingController _apiKeyController =
              TextEditingController();
          return StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C1C1E).withOpacity(0.98)
                        : Colors.white.withOpacity(0.98),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.vpn_key_rounded,
                            color: theme.colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Enter Gemini API Key',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'To transcribe audio, you need a Gemini API key. You can get one for free from Google AI Studio.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _launchApiKeyUrl,
                        child: Text(
                          'Get an API key',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Gemini API Key',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        style: GoogleFonts.inter(fontSize: 15),
                        autofocus: true,
                        onSubmitted: (_) async {
                          if (_apiKeyController.text.trim().isNotEmpty) {
                            await ApiKeyService.saveApiKey(
                              _apiKeyController.text.trim(),
                            );
                            Navigator.of(dialogContext).pop();
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _ModernButton(
                              text: 'Cancel',
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                              },
                              isSecondary: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ModernButton(
                              text: 'Save & Retry',
                              onPressed: () async {
                                if (_apiKeyController.text.trim().isNotEmpty) {
                                  await ApiKeyService.saveApiKey(
                                    _apiKeyController.text.trim(),
                                  );
                                  Navigator.of(dialogContext).pop();
                                  // Retry transcription after saving
                                  _handleTranscribeWithApiKey(context);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
      return;
    } else {
      try {
        Gemini.init(apiKey: apiKey);
      } catch (e) {
        errorMsg = 'Failed to initialize Gemini: $e';
      }
    }
    if (errorMsg != null) {
      final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
      final updatedEntry = widget.recording.copyWith(
        transcriptionError: errorMsg,
      );
      await recordingsBox.put(widget.recording.id, updatedEntry);
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
      return;
    }

    // Show transcription progress dialog with all logic (including Gemini.init)
    _showTranscriptionProgress(context, () async {
      // Always re-init Gemini with the latest key before every transcription
      Gemini.init(apiKey: apiKey!);
      final entry = widget.recording;
      if (entry.filePath.isEmpty) {
        final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
        final updatedEntry = entry.copyWith(
          transcriptionError: 'Recording file path is missing.',
        );
        await recordingsBox.put(entry.id, updatedEntry);
        if (mounted) setState(() {});
        throw Exception('Recording file path is missing.');
      }
      String entryFilePath = entry.filePath;
      bool isEncrypted = entryFilePath.endsWith('.enc');
      String fileToTranscribe = entryFilePath;
      File? tempDecryptedFile;
      if (isEncrypted) {
        final tempDir = await Directory.systemTemp.createTemp(
          'echolog_transcribe',
        );
        final tempFilePath =
            '${tempDir.path}/transcribe_${entry.id}_${DateTime.now().millisecondsSinceEpoch}.aac';
        try {
          await SecurityService().decryptFile(entryFilePath, tempFilePath);
          fileToTranscribe = tempFilePath;
          tempDecryptedFile = File(tempFilePath);
        } catch (e) {
          final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
          final updatedEntry = entry.copyWith(
            transcriptionError: 'Error decrypting for transcription.',
          );
          await recordingsBox.put(entry.id, updatedEntry);
          if (mounted) setState(() {});
          throw Exception('Error decrypting for transcription.');
        }
      }
      final audioFile = File(fileToTranscribe);
      if (!await audioFile.exists()) {
        if (tempDecryptedFile != null && await tempDecryptedFile.exists()) {
          await tempDecryptedFile.delete();
        }
        final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
        final updatedEntry = entry.copyWith(
          transcriptionError: 'Recording file not found.',
        );
        await recordingsBox.put(entry.id, updatedEntry);
        if (mounted) setState(() {});
        throw Exception('Recording file not found.');
      }
      final bytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(bytes);
      final prompt = [
        Part.text(
          'Transcribe the following audio. If the speaker uses multiple languages (e.g., English and Amharic), transcribe each part in the language it was spoken. Do not translate. The output should include all languages as spoken in the audio, make sure you recognize afan oromoo or tigigna or any other ethiopian languages really well.',
        ),
        Part.inline(InlineData(data: base64Audio, mimeType: 'audio/aac')),
      ];
      final gemini = Gemini.instance;
      try {
        final response = await gemini.prompt(parts: prompt);
        if (tempDecryptedFile != null && await tempDecryptedFile.exists()) {
          await tempDecryptedFile.delete();
        }
        final transcriptText = response?.output;
        final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
        if (transcriptText != null && transcriptText.trim().isNotEmpty) {
          final updatedEntry = entry.copyWith(
            transcription: transcriptText,
            transcriptionError: null,
          );
          await recordingsBox.put(entry.id, updatedEntry);
          if (widget.onTranscribe != null) {
            widget.onTranscribe!();
          }
          return transcriptText;
        } else {
          final updatedEntry = entry.copyWith(
            transcriptionError: 'Transcription text not found.',
          );
          await recordingsBox.put(entry.id, updatedEntry);
          if (mounted) setState(() {});
          throw Exception('Transcription text not found.');
        }
      } catch (e) {
        String errMsg = e.toString();
        if (errMsg.contains('429')) {
          errMsg =
              '🚫 Gemini API quota exceeded. Please try again later or check your usage limits.';
        }
        final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
        final updatedEntry = entry.copyWith(transcriptionError: errMsg);
        await recordingsBox.put(entry.id, updatedEntry);
        if (mounted) setState(() {});
        throw Exception(errMsg);
      }
    });
  }

  // Show the transcription progress dialog
  void _showTranscriptionProgress(
    BuildContext context,
    Future<String> Function() transcriptionTask,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return Dialog(
          key: const ValueKey('transcription-progress-dialog'),
          backgroundColor: Colors.transparent,
          child: TranscriptionProgressWidget(
            key: const ValueKey('transcription-progress-widget'),
            recordingDuration: widget.recording.duration,
            accentColor: widget.recording.moodColor,
            isDark: theme.brightness == Brightness.dark,
            transcriptionTask: transcriptionTask,
            onCancel: () {
              Navigator.of(context).pop();
              // Optionally: handle cancellation logic here
            },
          ),
        );
      },
    );
  }

  // Add this method to RecordingCardState
  Future<void> _showAIResponseDialog(
    BuildContext context,
    String transcription,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: FutureBuilder<String>(
            future: _getAIResponse(transcription),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dialogBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text('Getting AI response...'),
                    ],
                  ),
                );
              } else if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dialogBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Error: \\${snapshot.error}'),
                );
              } else {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dialogBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(snapshot.data ?? ''),
                );
              }
            },
          ),
        );
      },
    );
  }

  // Add this method to RecordingCardState
  Future<String> _getAIResponse(String transcription) async {
    // Use Gemini to analyze the transcription and generate a context-aware response
    // The prompt should instruct Gemini to answer questions, congratulate achievements, give tips, or provide appreciation/support, and reply in the same language
    final gemini = Gemini.instance;
    final prompt = [
      Part.text(
        'Analyze the following transcription. If it is a question, answer it. If it describes an achievement, congratulate and give tips. If it expresses sadness, give appreciation and encouragement. Always reply in the same language as the transcription.',
      ),
      Part.text(transcription),
    ];
    final response = await gemini.prompt(parts: prompt);
    return response?.output ?? 'No response.';
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
