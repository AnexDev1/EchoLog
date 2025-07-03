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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.22),
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
            color: isSelected ? color : color.withOpacity(0.85),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
