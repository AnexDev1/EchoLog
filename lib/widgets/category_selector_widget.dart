import 'package:echolog/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math' as math; // For PI
import 'package:provider/provider.dart';

import '../models/custom_category.dart';
import '../main.dart'; // For customCategoriesBoxName
import 'add_category_dialog.dart';
import 'neumorphic_category_tag.dart';
import 'glassmorphic_category_tag.dart';
import 'original_category_tag.dart';
import 'pill_category_tag.dart';
import 'shadow_chip_category_tag.dart';

class CategorySelectorWidget extends StatefulWidget {
  final List<Map<String, dynamic>> predefinedCategories;
  final Map<String, dynamic>? selectedCategoryData;
  final Function(Map<String, dynamic>?) onCategorySelected;
  final bool isRecording;

  // New properties for conditional vertical scrolling
  final int maxItemsBeforeVerticalScroll;
  final double scrollHeightWhenWrapped;

  const CategorySelectorWidget({
    super.key,
    required this.predefinedCategories,
    this.selectedCategoryData,
    required this.onCategorySelected,
    required this.isRecording,
    this.maxItemsBeforeVerticalScroll = 10, // After 5 items, make it scrollable
    this.scrollHeightWhenWrapped = 150.0, // Height of the scrollable area
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
    _shakeAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTagStyle = themeProvider.categoryTagStyle;

    final isDarkTheme = theme.brightness == Brightness.dark;
    final Color neumorphicButtonSurfaceColor = isDarkTheme
        ? Colors.grey.shade800
        : Colors.grey.shade200;

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

        List<Widget> allDisplayItems = allCategories.map((category) {
          final String categoryId = category['id'] as String;
          final bool isCustom = category['isCustom'] as bool? ?? false;
          final String? selectedIdentifier =
              widget.selectedCategoryData?['id']?.toString() ??
              widget.selectedCategoryData?['name'] as String?;
          final bool isSelected = selectedIdentifier == categoryId;
          final bool isEditingThis = _editingCategoryId == categoryId;
          final String emojiString = category['emoji'] as String? ?? '❓';
          final String categoryName = category['name'] as String;
          final Color categoryMainColor = category['color'] as Color;

          Widget tagContentWidget;

          if (currentTagStyle == CategoryTagStyle.neumorphic) {
            tagContentWidget = NeumorphicCategoryTag(
              key: ValueKey("neumorphic-tag-$categoryId"),
              label: '$emojiString $categoryName',
              onTap: () {
                if (widget.isRecording) return;
                if (isEditingThis) {
                  _stopEditMode();
                } else {
                  _stopEditMode();
                  widget.onCategorySelected(category);
                }
              },
              categoryColor: categoryMainColor,
              surfaceColor: neumorphicButtonSurfaceColor,
              isSelected: isSelected,
            );
          } else if (currentTagStyle == CategoryTagStyle.glassmorphic) {
            tagContentWidget = GlassmorphicCategoryTag(
              key: ValueKey("glassmorphic-tag-$categoryId"),
              label: '$emojiString $categoryName',
              onTap: () {
                if (widget.isRecording) return;
                if (isEditingThis) {
                  _stopEditMode();
                } else {
                  _stopEditMode();
                  widget.onCategorySelected(category);
                }
              },
              isSelected: isSelected,
              defaultTextColor: isDarkTheme
                  ? Colors.white.withOpacity(0.85)
                  : Colors.black.withOpacity(0.75),
            );
          } else if (currentTagStyle == CategoryTagStyle.pill) {
            tagContentWidget = PillCategoryTag(
              key: ValueKey("pill-tag-$categoryId"),
              label: '$emojiString $categoryName',
              onTap: () {
                if (widget.isRecording) return;
                if (isEditingThis) {
                  _stopEditMode();
                } else {
                  _stopEditMode();
                  widget.onCategorySelected(category);
                }
              },
              color: categoryMainColor,
              isSelected: isSelected,
            );
          } else if (currentTagStyle == CategoryTagStyle.shadowChip) {
            tagContentWidget = ShadowChipCategoryTag(
              key: ValueKey("shadowchip-tag-$categoryId"),
              label: '$emojiString $categoryName',
              onTap: () {
                if (widget.isRecording) return;
                if (isEditingThis) {
                  _stopEditMode();
                } else {
                  _stopEditMode();
                  widget.onCategorySelected(category);
                }
              },
              color: categoryMainColor,
              isSelected: isSelected,
            );
          } else {
            Color currentContentColor =
                category['iconColor'] as Color? ??
                _getContrastingTextColor(categoryMainColor);
            tagContentWidget = OriginalCategoryTag(
              key: ValueKey("original-tag-$categoryId"),
              emoji: emojiString,
              name: categoryName,
              categoryColor: categoryMainColor,
              contentColor: currentContentColor,
              isSelected: isSelected,
              onTap: () {
                if (widget.isRecording) return;
                if (isEditingThis) {
                  _stopEditMode();
                } else {
                  _stopEditMode();
                  widget.onCategorySelected(category);
                }
              },
            );
          }

          Widget finalTagStructure;
          if (isEditingThis && isCustom) {
            Widget animatedTag = AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (BuildContext context, Widget? animChild) =>
                  Transform.rotate(
                    angle: _shakeAnimation.value * (math.pi / 180),
                    child: animChild,
                  ),
              child: tagContentWidget,
            );
            finalTagStructure = Stack(
              key: ValueKey("stack-$categoryId"),
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                animatedTag,
                Positioned(
                  top: -10,
                  right: -10,
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      onTap: () => _deleteCategory(category),
                      customBorder: const CircleBorder(),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            finalTagStructure = tagContentWidget;
          }

          bool shouldDim =
              widget.isRecording && !isSelected && !(isEditingThis && isCustom);

          return GestureDetector(
            key: ValueKey("outer-gesture-$categoryId"),
            onLongPress: isCustom && !widget.isRecording
                ? () => _startEditMode(categoryId)
                : null,
            child: Opacity(
              opacity: shouldDim ? 0.5 : 1.0,
              child: finalTagStructure,
            ),
          );
        }).toList();

        Widget addNewButtonWidget;
        if (currentTagStyle == CategoryTagStyle.neumorphic) {
          addNewButtonWidget = NeumorphicCategoryTag(
            label: '➕ Add New',
            onTap: widget.isRecording
                ? () {}
                : () => _showAddCategoryDialog(context),
            categoryColor: theme.colorScheme.primary,
            surfaceColor: neumorphicButtonSurfaceColor,
            isSelected: false,
          );
        } else if (currentTagStyle == CategoryTagStyle.glassmorphic) {
          addNewButtonWidget = GlassmorphicCategoryTag(
            label: '➕ Add New',
            onTap: widget.isRecording
                ? () {}
                : () => _showAddCategoryDialog(context),
            isSelected: false,
            defaultTextColor: isDarkTheme
                ? Colors.white.withOpacity(0.85)
                : Colors.black.withOpacity(0.75),
          );
        } else if (currentTagStyle == CategoryTagStyle.pill) {
          addNewButtonWidget = PillCategoryTag(
            label: '➕ Add New',
            onTap: widget.isRecording
                ? () {}
                : () => _showAddCategoryDialog(context),
            color: theme.colorScheme.primary,
            isSelected: false,
          );
        } else if (currentTagStyle == CategoryTagStyle.shadowChip) {
          addNewButtonWidget = ShadowChipCategoryTag(
            label: '➕ Add New',
            onTap: widget.isRecording
                ? () {}
                : () => _showAddCategoryDialog(context),
            color: theme.colorScheme.primary,
            isSelected: false,
          );
        } else {
          addNewButtonWidget = GestureDetector(
            onTap: widget.isRecording
                ? null
                : () => _showAddCategoryDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.8),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.7),
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
          );
        }

        allDisplayItems.add(
          GestureDetector(
            key: const ValueKey("add-new-outer-gesture"),
            behavior: HitTestBehavior.opaque,
            onTap: addNewButtonWidget is GestureDetector
                ? null
                : (widget.isRecording
                      ? null
                      : () => _showAddCategoryDialog(context)),
            child: Opacity(
              key: const ValueKey("add-new-wrapper-opacity"),
              opacity: widget.isRecording ? 0.5 : 1.0,
              child: addNewButtonWidget,
            ),
          ),
        );

        // The core Wrap widget that displays the items
        Widget wrapLayout = Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          alignment: WrapAlignment.center,
          children: allDisplayItems,
        );

        Widget finalLayoutWidget;

        // Conditionally make the Wrap scrollable if item count exceeds threshold
        if (allDisplayItems.length > widget.maxItemsBeforeVerticalScroll) {
          finalLayoutWidget = SizedBox(
            height: widget.scrollHeightWhenWrapped,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              // Add some internal padding for the scrollable content if needed
              // padding: const EdgeInsets.only(bottom: 8.0),
              child: wrapLayout,
            ),
          );
        } else {
          finalLayoutWidget = wrapLayout;
        }

        return GestureDetector(
          onTap: _stopEditMode,
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 8.0,
            ),
            child: finalLayoutWidget,
          ),
        );
      },
    );
  }
}
