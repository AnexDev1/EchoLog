import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/duration_formatter.dart'; // Import the formatter

class RecordingControlsWidget extends StatelessWidget {
  final bool isRecording;
  final bool isRecordingPaused;
  final Duration recordingDuration;
  final Map<String, dynamic>? selectedCategoryData;
  final bool isRecorderInitialized;
  final VoidCallback onStartStopRecording;
  final VoidCallback onTogglePausePlayRecording;

  // Sizing constants
  static const double _buttonCircularDiameter = 80.0;
  static const double _iconSize = 40.0;
  static const Duration _animationDuration = Duration(milliseconds: 400);

  const RecordingControlsWidget({
    super.key,
    required this.isRecording,
    required this.isRecordingPaused,
    required this.recordingDuration,
    required this.selectedCategoryData,
    required this.isRecorderInitialized,
    required this.onStartStopRecording,
    required this.onTogglePausePlayRecording,
    required Color waveformColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    bool categorySelected = selectedCategoryData != null;

    double targetWidth = _buttonCircularDiameter;
    double targetHeight = _buttonCircularDiameter;
    BorderRadius targetBorderRadius = BorderRadius.circular(
      _buttonCircularDiameter / 2,
    );

    Color targetBackgroundColor;
    List<BoxShadow> targetBoxShadow;

    bool isActiveState =
        (categorySelected && isRecorderInitialized && !isRecording) ||
        isRecording;

    if (isRecording) {
      targetWidth = MediaQuery.of(context).size.width * 0.5;
      targetHeight = 65.0;
      targetBorderRadius = BorderRadius.circular(35.0);

      if (theme.brightness == Brightness.light) {
        // THEMED: Use a more distinct background for the recording bar in light theme
        targetBackgroundColor = theme.colorScheme.surfaceContainerHigh;
      } else {
        // For dark theme, the original surface color with opacity works well
        targetBackgroundColor = theme.colorScheme.surface.withOpacity(0.95);
      }

      targetBoxShadow = [
        BoxShadow(
          color: theme.shadowColor.withOpacity(0.35),
          blurRadius: 8,
          spreadRadius: 1,
          offset: const Offset(0, 3),
        ),
      ];
    } else {
      // Circular state
      if (categorySelected && isRecorderInitialized) {
        targetBackgroundColor = theme.colorScheme.secondary;
      } else {
        targetBackgroundColor = theme.colorScheme.surfaceVariant;
      }
      targetBoxShadow = [
        BoxShadow(
          color: theme.shadowColor.withOpacity(isActiveState ? 0.25 : 0.15),
          blurRadius: isActiveState ? 6 : 4,
          spreadRadius: isActiveState ? 1 : 0,
          offset: const Offset(0, 2),
        ),
      ];
    }

    bool canInteractOverall =
        (categorySelected || isRecording) && isRecorderInitialized;

    return GestureDetector(
      onTap: canInteractOverall
          ? onStartStopRecording
          : () {
              if (!isRecorderInitialized) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Initializing recorder. Please wait or check permissions.',
                    ),
                  ),
                );
              } else if (!categorySelected && !isRecording) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a mood category first.'),
                  ),
                );
              }
            },
      child: AnimatedContainer(
        duration: _animationDuration,
        curve: Curves.easeInOutCubic,
        width: targetWidth,
        height: targetHeight,
        decoration: BoxDecoration(
          color: targetBackgroundColor,
          borderRadius: targetBorderRadius,
          boxShadow: targetBoxShadow,
        ),
        child: isRecording
            ? _buildRecordingBarContent(context, theme, targetBackgroundColor)
            : _buildCircularButtonContent(
                theme: theme,
                isActive: categorySelected && isRecorderInitialized,
              ),
      ),
    );
  }

  Widget _buildCircularButtonContent({
    required ThemeData theme,
    required bool isActive,
  }) {
    Color currentIconColor;
    if (isActive) {
      currentIconColor = theme.colorScheme.onSecondary;
    } else {
      currentIconColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.6);
    }

    return Center(
      child: Icon(Icons.mic, color: currentIconColor, size: _iconSize),
    );
  }

  Widget _buildRecordingBarContent(
    BuildContext context,
    ThemeData theme,
    Color targetBackgroundColor,
  ) {
    Color iconColorOnBar =
        selectedCategoryData?['iconColor'] as Color? ??
        theme.colorScheme.primary;
    // Text color on the recording bar should contrast with its background
    // If bar is surfaceContainerHigh (light theme) or surface (dark theme), onSurface should work.
    Color durationTextColor = theme.colorScheme.onSurface;
    if (theme.brightness == Brightness.light &&
        targetBackgroundColor == theme.colorScheme.surfaceContainerHigh) {
      // Ensure text contrasts with surfaceContainerHigh. onSurface should be fine.
      // If surfaceContainerHigh was very dark, we might need theme.colorScheme.onSurfaceVariant or similar.
      // But typically onSurface is designed to work on these container colors.
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          GestureDetector(
            onTap: onStartStopRecording,
            child: Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onError,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                formatDuration(recordingDuration),
                style: GoogleFonts.poppins(
                  color: durationTextColor, // Using determined text color
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isRecordingPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              color: iconColorOnBar,
              size: 34,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: isRecordingPaused ? 'Resume' : 'Pause',
            onPressed: onTogglePausePlayRecording,
          ),
        ],
      ),
    );
  }
}
