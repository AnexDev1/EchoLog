import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math' as math; // For PI

import '../models/custom_category.dart';
import '../main.dart'; // For customCategoriesBoxName
import 'add_category_dialog.dart';

class CategorySelectorWidget extends StatefulWidget {
  final List<Map<String, dynamic>> predefinedCategories;
  final Map<String, dynamic>? selectedCategoryData;
  final Function(Map<String, dynamic>?) onCategorySelected; // Allow null
  final bool isRecording;

  const CategorySelectorWidget({
    super.key,
    required this.predefinedCategories,
    this.selectedCategoryData,
    required this.onCategorySelected,
    required this.isRecording,
  });

  @override
  State<CategorySelectorWidget> createState() => _CategorySelectorWidgetState();
}

class _CategorySelectorWidgetState extends State<CategorySelectorWidget>
    with SingleTickerProviderStateMixin {
  String? _editingCategoryId;
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _shakeAnimation =
        Tween<double>(begin: -1.5, end: 1.5) // Degrees to shake
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeInOut,
              ),
            );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startEditMode(String categoryId) {
    if (widget.isRecording) return;
    setState(() {
      if (_editingCategoryId == categoryId) {
        _editingCategoryId = null;
        _animationController.stop();
        _animationController.reset();
      } else {
        _editingCategoryId = categoryId;
        _animationController.repeat(reverse: true);
      }
    });
  }

  void _stopEditMode() {
    if (_editingCategoryId != null) {
      setState(() {
        _editingCategoryId = null;
        _animationController.stop();
        _animationController.reset();
      });
    }
  }

  void _deleteCategory(Map<String, dynamic> category) {
    final categoryId = category['id'] as String?;
    if (categoryId == null) return;

    final box = Hive.box<CustomCategory>(customCategoriesBoxName);
    box.delete(categoryId);

    if (widget.selectedCategoryData?['id'] == categoryId) {
      widget.onCategorySelected(null);
    }
    _stopEditMode();
  }

  void _showAddCategoryDialog(BuildContext context) {
    _stopEditMode();
    showDialog(
      context: context,
      builder: (_) => const AddCategoryDialog(),
    ).then((newCategory) {
      if (newCategory != null && newCategory is CustomCategory) {
        widget.onCategorySelected(newCategory.toMap());
      }
    });
  }

  Color _getContrastingTextColor(Color backgroundColor) {
    return ThemeData.estimateBrightnessForColor(backgroundColor) ==
            Brightness.dark
        ? Colors.white.withOpacity(0.9)
        : Colors.black.withOpacity(0.8);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<Box<CustomCategory>>(
      valueListenable: Hive.box<CustomCategory>(
        customCategoriesBoxName,
      ).listenable(),
      builder: (context, customCategoryBox, _) {
        final customCategories = customCategoryBox.values
            .map((c) => c.toMap())
            .toList();
        final mappedPredefined = widget.predefinedCategories
            .map((c) => {...c, 'id': c['name'] as String, 'isCustom': false})
            .toList();
        final allCategories = [...mappedPredefined, ...customCategories];

        List<Widget> categoryWidgets = allCategories.map((category) {
          final String categoryId = category['id'] as String;
          final bool isCustom = category['isCustom'] as bool? ?? false;

          final String? selectedIdentifier =
              widget.selectedCategoryData?['id']?.toString() ??
              widget.selectedCategoryData?['name'] as String?;
          final bool isSelected = selectedIdentifier == categoryId;
          final bool isEditingThis = _editingCategoryId == categoryId;

          final String emoji = category['emoji'] as String? ?? '❓';
          final Color categorySpecificBackgroundColor =
              category['color'] as Color;
          final Color? categorySpecificIconColor =
              category['iconColor'] as Color?;

          // Content color is based on category's iconColor if provided,
          // otherwise, it's a contrasting color to the category's background.
          // If selected, iconColor takes precedence.
          Color currentContentColor;
          if (isSelected && categorySpecificIconColor != null) {
            currentContentColor = categorySpecificIconColor;
          } else if (categorySpecificIconColor != null) {
            // For unselected, if iconColor is defined, use it but maybe slightly less prominent
            // or just use it as is if that's the design. For now, let's use it as is.
            currentContentColor = categorySpecificIconColor;
          } else {
            currentContentColor = _getContrastingTextColor(
              categorySpecificBackgroundColor,
            );
          }

          Border? currentBorder;
          List<BoxShadow>? currentBoxShadow;

          if (isSelected) {
            currentBorder = Border.all(
              color: theme.colorScheme.primary,
              width: 2.8,
            ); // Prominent border for selected
            currentBoxShadow = [
              BoxShadow(
                color: theme.shadowColor.withOpacity(
                  0.25,
                ), // Slightly stronger shadow for selected
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ];
          } else {
            // Unselected items still show their color, but with a less prominent border/shadow
            currentBorder = Border.all(
              color: theme.dividerColor.withOpacity(
                0.3,
              ), // Very subtle border or Colors.transparent
              width: 1.0,
            );
            currentBoxShadow = [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1), // Subtle shadow
                spreadRadius: 0,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ];
          }

          Widget chipContent = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color:
                  categorySpecificBackgroundColor, // ALWAYS use category's specific color
              borderRadius: BorderRadius.circular(25),
              border: currentBorder,
              boxShadow: currentBoxShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: currentContentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  category['name'] as String,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: currentContentColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );

          if (isEditingThis && isCustom) {
            chipContent = AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _shakeAnimation.value * (math.pi / 180),
                  child: child,
                );
              },
              child: chipContent,
            );
          }

          return GestureDetector(
            onLongPress: isCustom && !widget.isRecording
                ? () => _startEditMode(categoryId)
                : null,
            onTap: () {
              if (widget.isRecording) return;
              if (isEditingThis) {
                _stopEditMode();
              } else {
                _stopEditMode();
                widget.onCategorySelected(category);
              }
            },
            child: Opacity(
              opacity: widget.isRecording && !isSelected && !isEditingThis
                  ? 0.5
                  : 1.0,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  chipContent,
                  if (isEditingThis && isCustom)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => _deleteCategory(category),
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.shadowColor.withOpacity(0.2),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList();

        // "Add New" button - This should still use theme colors to differentiate
        categoryWidgets.add(
          GestureDetector(
            onTap: widget.isRecording
                ? null
                : () => _showAddCategoryDialog(context),
            child: Opacity(
              opacity: widget.isRecording ? 0.5 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(
                    0.8,
                  ), // THEMED
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.7), // THEMED
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.05),
                      spreadRadius: 0,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.primary, // THEMED
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add New',
                      style: GoogleFonts.poppins(
                        color: theme.colorScheme.primary, // THEMED
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        return GestureDetector(
          onTap: _stopEditMode,
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              alignment: WrapAlignment.center,
              children: categoryWidgets,
            ),
          ),
        );
      },
    );
  }
}
