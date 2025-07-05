import 'package:flutter/material.dart';

class ShadowChipCategoryTag extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isSelected;

  const ShadowChipCategoryTag({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define colors based on theme and selection state
    final unselectedBackgroundColor = isDarkMode
        ? const Color(0xFF2C2C2E)
        : Colors.white;
    final selectedBackgroundColor = color.withOpacity(0.18);

    final unselectedTextColor = isDarkMode
        ? Colors.white.withOpacity(0.7)
        : color.withOpacity(0.85);
    final selectedTextColor = color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedBackgroundColor
              : unselectedBackgroundColor,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDarkMode ? 0.3 : 0.22),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? selectedTextColor : unselectedTextColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
