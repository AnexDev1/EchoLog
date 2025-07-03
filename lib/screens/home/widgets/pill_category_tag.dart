import 'package:flutter/material.dart';

class PillCategoryTag extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isSelected;

  const PillCategoryTag({
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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: color, width: isSelected ? 2.2 : 1.2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
