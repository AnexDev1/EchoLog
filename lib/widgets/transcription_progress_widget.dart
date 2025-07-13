import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum TranscriptionState { processing, completed, failed }

class TranscriptionProgressWidget extends StatefulWidget {
  final Duration recordingDuration;
  final Color accentColor;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final bool isDark;
  final Future<void> Function()? transcriptionTask;

  const TranscriptionProgressWidget({
    Key? key,
    required this.recordingDuration,
    required this.accentColor,
    this.onCancel,
    this.onRetry,
    this.isDark = false,
    this.transcriptionTask,
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
  TranscriptionState _state = TranscriptionState.processing;
  String? _errorMessage;

  final List<TranscriptionStage> _stages = [
    TranscriptionStage(
      title: "Initializing",
      description: "Preparing audio analysis...",
      duration: Duration(milliseconds: 1600),
      icon: Icons.settings_outlined,
    ),
    TranscriptionStage(
      title: "Detecting Language",
      description: "Analyzing speech patterns...",
      duration: Duration(milliseconds: 2200),
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
      duration: Duration(milliseconds: 2800),
      icon: Icons.auto_fix_high_outlined,
    ),
    TranscriptionStage(
      title: "Finalizing",
      description: "Preparing transcription...",
      duration: Duration(milliseconds: 1700),
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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1900),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
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

    // If a transcription task is provided, execute it
    if (widget.transcriptionTask != null) {
      widget.transcriptionTask!()
          .then((_) {
            if (mounted) {
              _completeTranscription();
            }
          })
          .catchError((error) {
            if (mounted) {
              _failTranscription(error.toString());
            }
          });
    }

    // Start overall progress timer
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _state != TranscriptionState.processing) return;

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

      if (_overallProgress >= 1.0 && widget.transcriptionTask == null) {
        timer.cancel();
        _completeTranscription();
      }
    });
  }

  void _advanceStage() {
    if (_currentStage >= _stages.length ||
        _state != TranscriptionState.processing)
      return;

    _progressController.forward(from: 0.0);

    _stageTimer?.cancel();
    _stageTimer = Timer(_stages[_currentStage].duration, () {
      if (!mounted || _state != TranscriptionState.processing) return;

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
      _state = TranscriptionState.completed;
      _overallProgress = 1.0;
    });

    _pulseController.stop();
    _progressController.forward();

    // Auto-dismiss after showing completion
    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _failTranscription(String error) {
    String displayError = error;
    if (error.contains('409')) {
      displayError =
          '🚫 Gemini API quota exceeded. Please try again later or check your usage limits.';
    } else if (error.contains('400')) {
      displayError =
          '❗️ Invalid Gemini API key. Please check your key and try again.';
    }
    setState(() {
      _state = TranscriptionState.failed;
      _errorMessage = displayError;
    });

    _pulseController.stop();
    _progressController.stop();

    // Stop timers
    _stageTimer?.cancel();
    _progressTimer?.cancel();
  }

  void _retryTranscription() {
    setState(() {
      _state = TranscriptionState.processing;
      _currentStage = 0;
      _overallProgress = 0.0;
      _errorMessage = null;
    });

    _pulseController.repeat(reverse: true);
    _startTranscription();
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

  Color get _stateColor {
    switch (_state) {
      case TranscriptionState.processing:
        return widget.accentColor;
      case TranscriptionState.completed:
        return Colors.green;
      case TranscriptionState.failed:
        return Colors.red;
    }
  }

  IconData get _stateIcon {
    switch (_state) {
      case TranscriptionState.processing:
        return _currentStage < _stages.length
            ? _stages[_currentStage].icon
            : Icons.mic_outlined;
      case TranscriptionState.completed:
        return Icons.check_circle;
      case TranscriptionState.failed:
        return Icons.error_outline;
    }
  }

  String get _stateTitle {
    switch (_state) {
      case TranscriptionState.processing:
        return _currentStage < _stages.length
            ? _stages[_currentStage].title
            : "Processing...";
      case TranscriptionState.completed:
        return "Transcription Complete!";
      case TranscriptionState.failed:
        return "Transcription Failed";
    }
  }

  String get _stateDescription {
    switch (_state) {
      case TranscriptionState.processing:
        return _currentStage < _stages.length
            ? _stages[_currentStage].description
            : "Processing your audio...";
      case TranscriptionState.completed:
        return "Your audio has been successfully transcribed";
      case TranscriptionState.failed:
        return _errorMessage ?? "An error occurred during transcription";
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF1C1C1E).withOpacity(0.95)
                : Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _state == TranscriptionState.failed
                  ? Colors.red.withOpacity(0.3)
                  : widget.isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: _state == TranscriptionState.failed
                    ? Colors.red.withOpacity(0.2)
                    : Colors.black.withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with animated icon
              FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedBuilder(
                  animation: _state == TranscriptionState.processing
                      ? _pulseAnimation
                      : _fadeAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _stateColor.withOpacity(0.2),
                            _stateColor.withOpacity(0.05),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _stateColor.withOpacity(
                              _state == TranscriptionState.processing
                                  ? 0.3 + (_pulseAnimation.value * 0.2)
                                  : 0.3,
                            ),
                            blurRadius: _state == TranscriptionState.processing
                                ? 20 + (_pulseAnimation.value * 10)
                                : 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _stateColor.withOpacity(0.1),
                        ),
                        child: Icon(_stateIcon, size: 40, color: _stateColor),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // State title
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _stateTitle,
                  key: ValueKey(_stateTitle),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),

              // State description
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _stateDescription,
                  key: ValueKey(_stateDescription),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: (widget.isDark ? Colors.white : Colors.black87)
                        .withOpacity(0.7),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 32),

              // Progress bar (hidden when failed)
              if (_state != TranscriptionState.failed) ...[
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
                            colors: [_stateColor, _stateColor.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Animated shimmer effect
                      if (_state == TranscriptionState.processing)
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
              ],

              // Progress percentage and stage indicator or action buttons
              if (_state == TranscriptionState.processing) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${(_overallProgress * 100).toInt()}%",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _stateColor,
                      ),
                    ),
                    Text(
                      "Stage ${_currentStage + 1} of ${_stages.length}",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: (widget.isDark ? Colors.white : Colors.black87)
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Cancel button
                TextButton(
                  onPressed:
                      widget.onCancel ?? () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ] else if (_state == TranscriptionState.failed) ...[
                const SizedBox(height: 8),
                // Action buttons for failed state
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: widget.isDark
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: widget.onRetry ?? _retryTranscription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Retry',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
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

// Helper function to use sin
double sin(double x) {
  // Simple sine approximation using Taylor series
  double x2 = x * x;
  return x - (x2 * x) / 6 + (x2 * x2 * x) / 120 - (x2 * x2 * x2 * x) / 5040;
}
