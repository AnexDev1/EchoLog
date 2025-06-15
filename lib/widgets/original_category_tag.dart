import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OriginalCategoryTag extends StatefulWidget {
  final String emoji;
  final String name;
  final Color categoryColor; // Main background color of the tag
  final Color contentColor; // Color for text and emoji
  final bool isSelected;
  final VoidCallback? onTap;

  const OriginalCategoryTag({
    super.key,
    required this.emoji,
    required this.name,
    required this.categoryColor,
    required this.contentColor,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<OriginalCategoryTag> createState() => _OriginalCategoryTagState();
}

class _OriginalCategoryTagState extends State<OriginalCategoryTag>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;
  bool _isPressed =
      false; // To manage visual state during press if needed beyond scale

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600), // Bounce duration
      vsync: this,
    );

    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 0.92),
            weight: 40.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.92, end: 1.03),
            weight: 30.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.03, end: 1.0),
            weight: 30.0,
          ),
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
    if (mounted) {
      setState(() {
        _isPressed = false;
      });
    }
    // Trigger the external onTap callback after the animation starts or completes
    // For simplicity, triggering it here.
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (mounted) {
      setState(() {
        _isPressed = false;
      });
      if (_bounceController.isAnimating) {
        _bounceController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 50),
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

    Border? currentBorder = widget.isSelected
        ? Border.all(color: theme.colorScheme.primary, width: 2.8)
        : Border.all(color: theme.dividerColor.withOpacity(0.3), width: 1.0);

    List<BoxShadow>? currentBoxShadow = widget.isSelected
        ? [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.25),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ]
        : [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ];

    // If you want the border or shadow to change instantly on press before animation:
    if (_isPressed && !widget.isSelected) {
      // Example: Slightly more pronounced shadow on press
      currentBoxShadow = [
        BoxShadow(
          color: theme.shadowColor.withOpacity(0.15),
          spreadRadius: 1,
          blurRadius: 4,
          offset: const Offset(0, 2),
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
          // Manages animated changes to border, shadow, color
          duration: const Duration(
            milliseconds: 150,
          ), // Duration for non-scale changes
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: widget.categoryColor,
            borderRadius: BorderRadius.circular(13),
            border: currentBorder,
            boxShadow: currentBoxShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.emoji,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: widget.contentColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: widget.contentColor,
                  fontWeight: widget.isSelected
                      ? FontWeight.bold
                      : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
