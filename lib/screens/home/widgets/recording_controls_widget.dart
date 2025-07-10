import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Professional recording controls widget with modern design patterns
class RecordingControlsWidget extends StatelessWidget {
  const RecordingControlsWidget({
    super.key,
    required this.state,
    required this.onStartStop,
    required this.onTogglePause,
    this.category,
  });

  final RecordingState state;
  final VoidCallback onStartStop;
  final VoidCallback onTogglePause;
  final RecordingCategory? category;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _Constants.animationDuration,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: state.isRecording
          ? _RecordingBar(
              key: const ValueKey('recording'),
              state: state,
              category: category,
              onStop: onStartStop,
              onTogglePause: onTogglePause,
            )
          : _RecordButton(
              key: const ValueKey('button'),
              state: state,
              category: category,
              onStart: onStartStop,
            ),
    );
  }
}

/// Immutable state object for recording controls
class RecordingState {
  const RecordingState({
    required this.isRecording,
    required this.isPaused,
    required this.duration,
    required this.isInitialized,
  });

  final bool isRecording;
  final bool isPaused;
  final Duration duration;
  final bool isInitialized;

  bool get canRecord => isInitialized && !isRecording;
  bool get isActive => isRecording || canRecord;
}

/// Category configuration for recording
class RecordingCategory {
  const RecordingCategory({
    required this.name,
    required this.color,
    required this.iconColor,
  });

  final String name;
  final Color color;
  final Color iconColor;
}

/// Constants for consistent styling
class _Constants {
  static const double buttonSize = 72.0;
  static const double iconSize = 32.0;
  static const double barHeight = 56.0;
  static const double barMinWidth = 200.0;
  static const double stopButtonSize = 24.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
  );
}

/// Circular record button component
class _RecordButton extends StatelessWidget {
  const _RecordButton({
    super.key,
    required this.state,
    required this.onStart,
    this.category,
  });

  final RecordingState state;
  final VoidCallback onStart;
  final RecordingCategory? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canInteract = _canInteract;

    return GestureDetector(
      onTap: canInteract ? onStart : () => _showError(context),
      child: AnimatedContainer(
        duration: _Constants.animationDuration,
        curve: Curves.easeOutCubic,
        width: _Constants.buttonSize,
        height: _Constants.buttonSize,
        decoration: BoxDecoration(
          color: _buttonColor(theme),
          shape: BoxShape.circle,
          boxShadow: _buttonShadow(theme, canInteract),
        ),
        child: Icon(
          Icons.mic_rounded,
          size: _Constants.iconSize,
          color: _iconColor(theme, canInteract),
        ),
      ),
    );
  }

  bool get _canInteract => state.canRecord && category != null;

  Color _buttonColor(ThemeData theme) {
    if (!state.isInitialized || category == null) {
      return theme.colorScheme.surfaceContainerHighest;
    }
    return theme.colorScheme.surface;
  }

  Color _iconColor(ThemeData theme, bool canInteract) {
    if (!canInteract) {
      return theme.colorScheme.onSurfaceVariant.withOpacity(0.5);
    }
    return category?.iconColor ?? theme.colorScheme.primary;
  }

  List<BoxShadow> _buttonShadow(ThemeData theme, bool canInteract) {
    return [
      BoxShadow(
        color: theme.shadowColor.withOpacity(canInteract ? 0.2 : 0.1),
        blurRadius: canInteract ? 8 : 4,
        offset: Offset(0, canInteract ? 4 : 2),
      ),
    ];
  }

  void _showError(BuildContext context) {
    final message = !state.isInitialized
        ? 'Initializing recorder...'
        : 'Please select a category first';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

/// Recording bar with controls
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    super.key,
    required this.state,
    required this.onStop,
    required this.onTogglePause,
    this.category,
  });

  final RecordingState state;
  final VoidCallback onStop;
  final VoidCallback onTogglePause;
  final RecordingCategory? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedContainer(
      duration: _Constants.animationDuration,
      curve: Curves.easeOutCubic,
      width: (screenWidth * 0.5).clamp(_Constants.barMinWidth, 300.0),
      height: _Constants.barHeight,
      decoration: BoxDecoration(
        color: _barColor(theme),
        borderRadius: BorderRadius.circular(_Constants.barHeight / 2),
        boxShadow: _barShadow(theme),
      ),
      child: Padding(
        padding: _Constants.contentPadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StopButton(onStop: onStop),
            _DurationDisplay(duration: state.duration),
            _PauseButton(
              isPaused: state.isPaused,
              onToggle: onTogglePause,
              iconColor: _iconColor(theme),
            ),
          ],
        ),
      ),
    );
  }

  Color _barColor(ThemeData theme) {
    return category?.color.withOpacity(0.1) ??
        theme.colorScheme.surfaceContainerHigh;
  }

  Color _iconColor(ThemeData theme) {
    return category?.iconColor ?? theme.colorScheme.onSurface;
  }

  List<BoxShadow> _barShadow(ThemeData theme) {
    return [
      BoxShadow(
        color: theme.shadowColor.withOpacity(0.15),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ];
  }
}

/// Stop recording button
class _StopButton extends StatelessWidget {
  const _StopButton({required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onStop,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.error.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.stop_rounded,
          color: theme.colorScheme.onError,
          size: _Constants.stopButtonSize,
        ),
      ),
    );
  }
}

/// Duration display component
class _DurationDisplay extends StatelessWidget {
  const _DurationDisplay({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      _formatDuration(duration),
      style: GoogleFonts.inter(
        color: theme.colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Pause/play toggle button
class _PauseButton extends StatelessWidget {
  const _PauseButton({
    required this.isPaused,
    required this.onToggle,
    required this.iconColor,
  });

  final bool isPaused;
  final VoidCallback onToggle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggle,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          key: ValueKey(isPaused),
          color: iconColor,
          size: 28,
        ),
      ),
      tooltip: isPaused ? 'Resume' : 'Pause',
    );
  }
}
