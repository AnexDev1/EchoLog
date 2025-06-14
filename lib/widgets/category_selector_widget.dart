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
  String?
  _editingCategoryId; // ID of the category currently being edited/shaken
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
    if (widget.isRecording) return; // Don't allow editing while recording
    setState(() {
      if (_editingCategoryId == categoryId) {
        // If already editing this one, toggle off
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

    // If the deleted category was the currently selected one, clear the selection
    if (widget.selectedCategoryData?['id'] == categoryId) {
      widget.onCategorySelected(null); // Pass null to clear selection
    }
    _stopEditMode(); // Also stops animation and hides delete icon
  }

  void _showAddCategoryDialog(BuildContext context) {
    _stopEditMode(); // Stop any editing before showing dialog
    showDialog(
      context: context,
      builder: (_) => const AddCategoryDialog(),
    ).then((newCategory) {
      if (newCategory != null && newCategory is CustomCategory) {
        widget.onCategorySelected(newCategory.toMap());
      }
    });
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
        // Ensure predefined categories have 'isCustom': false and a unique 'id' (can be name)
        final mappedPredefined = widget.predefinedCategories
            .map((c) => {...c, 'id': c['name'] as String, 'isCustom': false})
            .toList();
        final allCategories = [...mappedPredefined, ...customCategories];

        List<Widget> categoryWidgets = allCategories.map((category) {
          final String categoryId = category['id'] as String;
          final bool isCustom =
              category['isCustom'] as bool? ??
              false; // Default to false if null

          final String? selectedIdentifier =
              widget.selectedCategoryData?['id']?.toString() ??
              widget.selectedCategoryData?['name'] as String?;
          final bool isSelected = selectedIdentifier == categoryId;
          final bool isEditingThis = _editingCategoryId == categoryId;

          final String emoji = category['emoji'] as String? ?? '';
          final Color itemColor = category['color'] as Color;

          Widget chipContent = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? itemColor : itemColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(25),
              border: isSelected
                  ? Border.all(color: theme.colorScheme.secondary, width: 2.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: GoogleFonts.poppins(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  category['name'] as String,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
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
                  angle:
                      _shakeAnimation.value *
                      (math.pi / 180), // Convert degrees to radians
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
                // If tapping the item that's being edited
                _stopEditMode();
              } else {
                // Normal selection or stop editing if another item was being edited
                _stopEditMode();
                widget.onCategorySelected(category);
              }
            },
            child: Opacity(
              opacity: widget.isRecording && !isSelected && !isEditingThis
                  ? 0.5
                  : 1.0,
              child: Stack(
                clipBehavior:
                    Clip.none, // Allow delete icon to overflow slightly
                children: [
                  chipContent,
                  if (isEditingThis && isCustom)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Material(
                        // Material for InkWell ripple
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => _deleteCategory(category),
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme
                                  .colorScheme
                                  .errorContainer, // Or Colors.red
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: theme
                                  .colorScheme
                                  .onErrorContainer, // Or Colors.white
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

        // "Add New" button
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
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.8),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add New',
                      style: GoogleFonts.poppins(
                        color: theme.colorScheme.primary,
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
          // GestureDetector on the whole Wrap area to stop editing
          onTap: _stopEditMode, // Tapping empty space in the Wrap stops editing
          child: Container(
            // Ensure it has a background to be tappable if Wrap is empty
            color: Colors
                .transparent, // Or theme.scaffoldBackgroundColor if needed for hit testing
            child: Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              alignment: WrapAlignment.center,
              children: categoryWidgets,
            ),
          ),
        );
      },
    );
  }
}
