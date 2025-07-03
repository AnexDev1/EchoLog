import 'package:echolog/main.dart';
import 'package:echolog/models/custom_category.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emoji_selector/emoji_selector.dart'; // Import the new package
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({super.key});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  String _categoryName = '';
  String _selectedEmoji = '✨'; // Default placeholder emoji
  Color _selectedColor = Colors.grey.shade400;

  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openEmojiSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        // Optional: to match dialog style
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext bc) {
        return SizedBox(
          height:
              MediaQuery.of(context).size.height *
              0.45, // Adjust height as needed
          child: Column(
            // Added Column for potential title/padding
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Select an Emoji',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: EmojiSelector(
                  onSelected: (emoji) {
                    setState(() {
                      _selectedEmoji = emoji.char;
                    });
                    Navigator.pop(context); // Close the bottom sheet
                  },
                  // You can explore other properties of EmojiSelector for customization
                  // For example:
                  // columns: 8,
                  // skinToneSelector: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _pickColor(BuildContext context) {
    Color pickerColor = _selectedColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Pick a Category Color',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        contentPadding: const EdgeInsets.all(20.0),
        content: SingleChildScrollView(
          child: MaterialPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel', style: GoogleFonts.poppins()),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text('Select', style: GoogleFonts.poppins()),
            onPressed: () {
              setState(() => _selectedColor = pickerColor);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _saveCategory() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final Color iconColor =
          ThemeData.estimateBrightnessForColor(_selectedColor) ==
              Brightness.dark
          ? Colors.white
          : Colors.black;

      final newCategory = CustomCategory(
        id: const Uuid().v4(),
        name: _categoryName.trim(),
        emoji: _selectedEmoji, // Use the selected emoji
        colorValue: _selectedColor.value,
        iconColorValue: iconColor.value,
      );

      final box = Hive.box<CustomCategory>(customCategoriesBoxName);
      box.put(newCategory.id, newCategory);
      Navigator.of(context).pop(newCategory);
    }
  }

  Widget _buildPickerField({
    required BuildContext context,
    required String label,
    required Widget child,
    required VoidCallback onTap,
    IconData? trailingIcon,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color:
                  theme.inputDecorationTheme.fillColor ??
                  theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color:
                    theme
                        .inputDecorationTheme
                        .enabledBorder
                        ?.borderSide
                        .color ??
                    theme.colorScheme.outline,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: child),
                if (trailingIcon != null)
                  Icon(trailingIcon, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      title: Text(
        'Create New Mood Category',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: theme.colorScheme.onSurface,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      content: Form(
        // Removed SingleChildScrollView as AlertDialog is scrollable
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g., Productive, Relaxed',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a category name';
                }
                if (value.trim().length > 20) {
                  return 'Name too long (max 20 chars)';
                }
                final box = Hive.box<CustomCategory>(customCategoriesBoxName);
                if (box.values.any(
                  (cat) => cat.name.toLowerCase() == value.trim().toLowerCase(),
                )) {
                  return 'This category name already exists';
                }
                return null;
              },
              onSaved: (value) => _categoryName = value!,
              style: GoogleFonts.poppins(fontSize: 16),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),

            _buildPickerField(
              context: context,
              label: 'Emoji',
              onTap: () => _openEmojiSelector(context),
              trailingIcon: Icons.arrow_drop_down_rounded,
              child: Text(
                _selectedEmoji,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  color: theme.colorScheme.onSurface,
                ), // Made emoji larger
              ),
            ),
            const SizedBox(height: 24),

            _buildPickerField(
              context: context,
              label: 'Category Color',
              onTap: () => _pickColor(context),
              trailingIcon: Icons.arrow_drop_down_rounded,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    // Show hex code for color, e.g. #FF5733
                    '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}',
                    style: GoogleFonts.poppins(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      actionsAlignment: MainAxisAlignment.end,
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          onPressed: _saveCategory,
          child: Text(
            'Save Category',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
