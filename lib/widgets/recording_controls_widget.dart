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
  final ThemeData theme;

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
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    bool categorySelected = selectedCategoryData != null;
    // bool isActiveCircular = categorySelected && isRecorderInitialized && !isRecording; // Not directly used for targetBackgroundColor anymore

    double targetWidth = _buttonCircularDiameter;
    double targetHeight = _buttonCircularDiameter;
    BorderRadius targetBorderRadius = BorderRadius.circular(
      _buttonCircularDiameter / 2,
    );

    Color targetBackgroundColor; // Will be set below

    List<BoxShadow> targetBoxShadow = [
      BoxShadow(
        color: Colors.black.withOpacity(
          (categorySelected && isRecorderInitialized && !isRecording) ||
                  isRecording
              ? 0.35
              : 0.25,
        ),
        blurRadius:
            (categorySelected && isRecorderInitialized && !isRecording) ||
                isRecording
            ? 6
            : 4,
        spreadRadius:
            (categorySelected && isRecorderInitialized && !isRecording) ||
                isRecording
            ? 1
            : 0,
        offset: const Offset(0, 2),
      ),
    ];

    if (isRecording) {
      targetWidth =
          MediaQuery.of(context).size.width * 0.5; // FURTHER REDUCED WIDTH
      targetHeight = 65.0;
      targetBorderRadius = BorderRadius.circular(35.0);
      targetBackgroundColor = theme.colorScheme.surface.withOpacity(
        0.95,
      ); // Recording bar color
      targetBoxShadow = [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 8,
          spreadRadius: 1,
          offset: const Offset(0, 3),
        ),
      ];
    } else {
      // Circular state
      if (categorySelected && isRecorderInitialized) {
        targetBackgroundColor =
            theme.colorScheme.secondary; // Active circular is light blue/teal
      } else {
        targetBackgroundColor =
            Colors.grey.shade700; // Disabled circular is grey
      }
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
            ? _buildRecordingBarContent(context)
            : _buildCircularButtonContent(
                isActive: categorySelected && isRecorderInitialized,
              ),
      ),
    );
  }

  Widget _buildCircularButtonContent({required bool isActive}) {
    Color currentIconColor;
    if (isActive) {
      currentIconColor = theme.colorScheme.onSecondary;
    } else {
      currentIconColor = Colors.grey.shade400;
    }

    return Center(
      child: Icon(Icons.mic, color: currentIconColor, size: _iconSize),
    );
  }

  Widget _buildRecordingBarContent(BuildContext context) {
    Color iconColorOnBar =
        selectedCategoryData?['iconColor'] as Color? ?? Colors.white;
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
                color: Colors.red.withOpacity(0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
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
                  color: Colors.white,
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
            onPressed: onTogglePausePlayRecording,
          ),
        ],
      ),
    );
  }
}
