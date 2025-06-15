import 'package:flutter/material.dart';

class NeumorphicCategoryTag extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color categoryColor; // Color for the text
  final Color
  surfaceColor; // Background color of the parent surface, also button color
  final bool isSelected; // To visually indicate selection

  const NeumorphicCategoryTag({
    super.key,
    required this.label,
    required this.onTap,
    required this.categoryColor,
    this.surfaceColor = const Color(0xFFE0E0E0), // Default light grey surface
    this.isSelected = false,
  });

  @override
  State<NeumorphicCategoryTag> createState() => _NeumorphicCategoryTagState();
}

class _NeumorphicCategoryTagState extends State<NeumorphicCategoryTag>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 0.90),
            weight: 35.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.90, end: 1.05),
            weight: 35.0,
          ), // Overshoot is defined here
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.05, end: 1.0),
            weight: 30.0,
          ), // Settle back
        ]).animate(
          CurvedAnimation(
            parent: _bounceController,
            // --- THIS IS THE FIX ---
            // Ensure the curve used here does not output values outside [0.0, 1.0]
            // Curves.elasticOut was causing the issue because it overshoots.
            curve: Curves.easeInOut,
            // --- END FIX ---
          ),
        );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails? details) {
    setState(() {
      _isPressed = true;
    });
    _bounceController.reset();
    _bounceController.forward();
  }

  void _handleTapUp(TapUpDetails? details) {
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
      if (_bounceController.isAnimating) {
        _bounceController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      } else {
        _bounceController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkSurface =
        ThemeData.estimateBrightnessForColor(widget.surfaceColor) ==
        Brightness.dark;

    final Color darkShadowColor = isDarkSurface
        ? Colors.black.withOpacity(0.5)
        : Colors.grey.shade500;
    final Color lightShadowColor = isDarkSurface
        ? Colors.white.withOpacity(0.05)
        : Colors.white;

    List<BoxShadow> shadows;
    Color currentSurfaceColor = widget.surfaceColor;
    Color currentTextColor = widget.categoryColor;
    Border? borderStyle;

    if (widget.isSelected) {
      shadows = [
        BoxShadow(
          color: darkShadowColor.withOpacity(isDarkSurface ? 0.6 : 0.7),
          offset: const Offset(3, 3),
          blurRadius: 6,
          spreadRadius: -1,
        ),
        if (!isDarkSurface ||
            (isDarkSurface && lightShadowColor != Colors.transparent))
          BoxShadow(
            color: lightShadowColor.withOpacity(isDarkSurface ? 0.08 : 0.8),
            offset: const Offset(-3, -3),
            blurRadius: 6,
            spreadRadius: -1,
          ),
      ];
      borderStyle = Border.all(color: theme.colorScheme.primary, width: 2.2);
    } else if (_isPressed) {
      shadows = [
        BoxShadow(
          color: darkShadowColor,
          offset: const Offset(2, 2),
          blurRadius: 5,
        ),
        if (!isDarkSurface ||
            (isDarkSurface && lightShadowColor != Colors.transparent))
          BoxShadow(
            color: lightShadowColor,
            offset: const Offset(-2, -2),
            blurRadius: 5,
          ),
      ];
    } else {
      shadows = [
        BoxShadow(
          color: darkShadowColor,
          offset: const Offset(4, 4),
          blurRadius: 8,
        ),
        if (!isDarkSurface ||
            (isDarkSurface && lightShadowColor != Colors.transparent))
          BoxShadow(
            color: lightShadowColor,
            offset: const Offset(-4, -4),
            blurRadius: 8,
          ),
      ];
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: currentSurfaceColor,
            borderRadius: BorderRadius.circular(15),
            boxShadow: shadows,
            border: borderStyle,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: currentTextColor,
              fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
