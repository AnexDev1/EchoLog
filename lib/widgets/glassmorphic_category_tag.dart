import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';

class GlassmorphicCategoryTag extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color defaultTextColor;
  final bool isSelected;
  final double blurStrength;
  final double backgroundOpacity;
  final double borderOpacity;
  final double defaultBorderWidth;

  const GlassmorphicCategoryTag({
    super.key,
    required this.label,
    required this.onTap,
    this.defaultTextColor = Colors.white,
    this.isSelected = false,
    this.blurStrength = 5.0,
    this.backgroundOpacity = 0.12,
    this.borderOpacity = 0.2,
    this.defaultBorderWidth = 1.0,
  });

  @override
  State<GlassmorphicCategoryTag> createState() =>
      _GlassmorphicCategoryTagState();
}

class _GlassmorphicCategoryTagState extends State<GlassmorphicCategoryTag>
    with SingleTickerProviderStateMixin {
  // Add SingleTickerProviderStateMixin
  bool _isPressed = false;

  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600), // Duration of the bounce
      vsync: this,
    );

    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 0.92),
            weight: 40.0,
          ), // Scale down
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.92, end: 1.03),
            weight: 30.0,
          ), // Overshoot
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.03, end: 1.0),
            weight: 30.0,
          ), // Settle back
        ]).animate(
          CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _bounceController.reset();
    _bounceController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    // The animation will complete on its own.
    // If the animation is still running when _isPressed becomes false,
    // the AnimatedContainer might start animating other properties.
    // We can delay setting _isPressed to false slightly or ensure animation finishes.
    // For simplicity, let's set it here. The visual impact should be minimal.
    if (mounted) {
      setState(() {
        _isPressed = false;
      });
    }
    widget.onTap();
  }

  void _handleTapCancel() {
    if (mounted) {
      setState(() {
        _isPressed = false;
      });
      // If animation is running, let it complete or quickly reverse/reset
      if (_bounceController.isAnimating) {
        _bounceController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
        ); // Quickly go back to start (scale 1.0)
      } else {
        _bounceController.reset(); // Ensure scale is 1.0
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isLightTheme = theme.brightness == Brightness.light;

    Color currentBorderColor;
    double currentBorderWidth = widget.defaultBorderWidth;
    FontWeight currentFontWeight = FontWeight.w600;
    Color currentTextColor = widget.defaultTextColor;
    double currentBackgroundOpacity = widget.backgroundOpacity;
    // Scale is now handled by _scaleAnimation

    if (widget.isSelected) {
      currentBorderColor = theme.colorScheme.primary;
      currentBorderWidth = 2.2;
      currentFontWeight = FontWeight.bold;
      currentTextColor = theme.colorScheme.primary;
    } else if (_isPressed) {
      // _isPressed can still control other aspects like border/opacity during the tap
      currentBorderColor = isLightTheme
          ? Colors.black.withOpacity(widget.borderOpacity + 0.1)
          : Colors.white.withOpacity(widget.borderOpacity + 0.15);
      currentBackgroundOpacity = widget.backgroundOpacity + 0.03;
      currentTextColor = widget.defaultTextColor.withOpacity(0.8);
    } else {
      currentBorderColor = isLightTheme
          ? Colors.black.withOpacity(widget.borderOpacity * 0.75)
          : Colors.white.withOpacity(widget.borderOpacity);
    }

    if (currentTextColor == Colors.white &&
        isLightTheme &&
        !widget.isSelected &&
        !_isPressed) {
      currentTextColor = Colors.black.withOpacity(0.7);
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        // Use AnimatedBuilder to listen to _scaleAnimation
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: AnimatedContainer(
          // This animates color, border, opacity changes
          duration: const Duration(
            milliseconds: 100,
          ), // Faster duration for non-scale changes
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            // No specific decoration here, it's inside ClipRRect > BackdropFilter > Container
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blurStrength,
                sigmaY: widget.blurStrength,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      (isLightTheme &&
                          !widget.isSelected &&
                          !_isPressed // Make glass pane slightly darker in light mode for better visibility
                      ? Colors.white.withOpacity(
                          currentBackgroundOpacity + 0.05,
                        )
                      : Colors.white.withOpacity(currentBackgroundOpacity)),
                  borderRadius: BorderRadius.circular(15.0),
                  border: Border.all(
                    color: currentBorderColor,
                    width: currentBorderWidth,
                  ),
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: currentTextColor,
                    fontWeight: currentFontWeight,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
