import 'dart:ui';
import 'package:flutter/material.dart';

class TranscriptionProgressBar extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final String statusText;

  const TranscriptionProgressBar({
    Key? key,
    required this.progress,
    required this.statusText,
  }) : super(key: key);

  @override
  State<TranscriptionProgressBar> createState() =>
      _TranscriptionProgressBarState();
}

class _TranscriptionProgressBarState extends State<TranscriptionProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulsingController;

  @override
  void initState() {
    super.initState();
    _pulsingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulsingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      // Use a ClipRRect to contain the blur and give the capsule shape
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18.0,
              vertical: 14.0,
            ),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.15)
                  : Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Pulsing Icon
                FadeTransition(
                  opacity: Tween<double>(begin: 0.7, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _pulsingController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Icon(
                    Icons.mic_none_rounded,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Text and Progress Bar
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.statusText,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Custom Animated Progress Bar
                      _CustomProgressBar(progress: widget.progress),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A custom progress bar with a smoother animation and a more polished look.
class _CustomProgressBar extends StatelessWidget {
  final double progress;

  const _CustomProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.2)
                : Colors.black.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * progress,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              // Subtle shine effect
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: (constraints.maxWidth * progress) - 4,
                    height: 3,
                    margin: const EdgeInsets.only(left: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
