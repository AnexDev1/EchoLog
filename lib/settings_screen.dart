// Ensure correct path
import 'package:echolog/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ensure this key is consistent with its usage in HomeScreen
const String PREF_HIDDEN_ACCESS_METHOD = 'selectedHiddenAccessTriggerMethod';

enum HiddenAccessTriggerMethod {
  longPressAppBar, // "Hold" on AppBar
  tripleTapAppBar,
  pinchInScreen,
  pinchOutScreen,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  HiddenAccessTriggerMethod _selectedHiddenAccessMethod =
      HiddenAccessTriggerMethod.longPressAppBar;

  @override
  void initState() {
    super.initState();
    _loadHiddenAccessPreference();
  }

  Future<void> _loadHiddenAccessPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final methodName = prefs.getString(PREF_HIDDEN_ACCESS_METHOD);
    HiddenAccessTriggerMethod loadedMethod =
        HiddenAccessTriggerMethod.longPressAppBar; // Default
    if (methodName != null) {
      try {
        loadedMethod = HiddenAccessTriggerMethod.values.firstWhere(
          (e) => e.toString() == methodName,
          orElse: () => HiddenAccessTriggerMethod.longPressAppBar,
        );
      } catch (e) {
        loadedMethod = HiddenAccessTriggerMethod.longPressAppBar;
      }
    }
    if (!HiddenAccessTriggerMethod.values.contains(loadedMethod)) {
      loadedMethod = HiddenAccessTriggerMethod.longPressAppBar;
    }

    if (mounted) {
      setState(() {
        _selectedHiddenAccessMethod = loadedMethod;
      });
    }
  }

  Future<void> _saveHiddenAccessPreference(
    HiddenAccessTriggerMethod method,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PREF_HIDDEN_ACCESS_METHOD, method.toString());
    if (mounted) {
      setState(() {
        _selectedHiddenAccessMethod = method;
      });
    }
  }

  String _getHiddenAccessMethodDescription(HiddenAccessTriggerMethod method) {
    switch (method) {
      case HiddenAccessTriggerMethod.longPressAppBar:
        return "Long-press (Hold) App Bar";
      case HiddenAccessTriggerMethod.tripleTapAppBar:
        return "Triple-tap App Bar";
      case HiddenAccessTriggerMethod.pinchInScreen:
        return "Pinch In on Screen";
      case HiddenAccessTriggerMethod.pinchOutScreen:
        return "Pinch Out on Screen";
    }
  }

  void _showHiddenAccessMethodSelectionDialog() {
    showDialog<HiddenAccessTriggerMethod>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(
            'Select Access Method',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          children: HiddenAccessTriggerMethod.values.map((method) {
            return RadioListTile<HiddenAccessTriggerMethod>(
              title: Text(
                _getHiddenAccessMethodDescription(method),
                style: GoogleFonts.poppins(),
              ),
              value: method,
              groupValue: _selectedHiddenAccessMethod,
              onChanged: (HiddenAccessTriggerMethod? value) {
                if (value != null) {
                  Navigator.pop(context, value);
                }
              },
              activeColor: Theme.of(context).colorScheme.primary,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
            );
          }).toList(),
        );
      },
    ).then((selectedValue) {
      if (selectedValue != null) {
        _saveHiddenAccessPreference(selectedValue);
      }
    });
  }

  void _showThemeSelectionDialog(ThemeProvider themeProvider) {
    showDialog<ThemeMode>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(
            'Select Theme',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              title: Text(
                themeProvider.getThemeModeString(mode),
                style: GoogleFonts.poppins(),
              ),
              value: mode,
              groupValue: themeProvider.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  Navigator.pop(context, value);
                }
              },
              activeColor: Theme.of(context).colorScheme.primary,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
            );
          }).toList(),
        );
      },
    ).then((selectedValue) {
      if (selectedValue != null) {
        themeProvider.setThemeMode(selectedValue);
      }
    });
  }

  void _showCategoryTagStyleSelectionDialog(ThemeProvider themeProvider) {
    showDialog<CategoryTagStyle>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(
            'Select Category Tag Style',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          // This will automatically include 'glassmorphic' if it's in the CategoryTagStyle enum
          children: CategoryTagStyle.values.map((style) {
            // Capitalize the first letter of the enum name for display
            String styleName = style.name.replaceFirstMapped(
              style.name[0],
              (match) => style.name[0].toUpperCase(),
            );
            return RadioListTile<CategoryTagStyle>(
              title: Text(
                styleName, // e.g., "Original", "Neumorphic", "Glassmorphic"
                style: GoogleFonts.poppins(),
              ),
              value: style,
              groupValue: themeProvider.categoryTagStyle,
              onChanged: (CategoryTagStyle? value) {
                if (value != null) {
                  Navigator.pop(context, value);
                }
              },
              activeColor: Theme.of(context).colorScheme.primary,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
            );
          }).toList(),
        );
      },
    ).then((selectedValue) {
      if (selectedValue != null) {
        themeProvider.setCategoryTagStyle(selectedValue);
      }
    });
  }

  Widget _buildSettingsSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 24.0,
        bottom: 8.0,
        left: 16.0,
        right: 16.0,
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color ?? theme.cardColor,
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.secondary),
        title: Text(title, style: GoogleFonts.poppins(fontSize: 16)),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: theme.hintColor,
                ),
              )
            : null,
        trailing:
            trailing ??
            Icon(Icons.chevron_right, color: theme.hintColor.withOpacity(0.7)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: <Widget>[
          _buildSettingsSectionTitle(context, 'SECRET VAULT'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.cardColor,
              borderRadius: BorderRadius.circular(
                theme.cardTheme.shape is RoundedRectangleBorder
                    ? ((theme.cardTheme.shape as RoundedRectangleBorder)
                                  .borderRadius
                              as BorderRadius)
                          .topLeft
                          .x
                    : 12.0,
              ),
              boxShadow:
                  theme.cardTheme.elevation != null &&
                      theme.cardTheme.elevation! > 0
                  ? [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
                        blurRadius: theme.cardTheme.elevation! * 2,
                        offset: Offset(0, theme.cardTheme.elevation!),
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                theme.cardTheme.shape is RoundedRectangleBorder
                    ? ((theme.cardTheme.shape as RoundedRectangleBorder)
                                  .borderRadius
                              as BorderRadius)
                          .topLeft
                          .x
                    : 12.0,
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.touch_app_outlined,
                    title: 'Access Method',
                    subtitle: _getHiddenAccessMethodDescription(
                      _selectedHiddenAccessMethod,
                    ),
                    onTap: _showHiddenAccessMethodSelectionDialog,
                  ),
                ],
              ),
            ),
          ),

          _buildSettingsSectionTitle(context, 'APPEARANCE'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.cardColor,
              borderRadius: BorderRadius.circular(
                theme.cardTheme.shape is RoundedRectangleBorder
                    ? ((theme.cardTheme.shape as RoundedRectangleBorder)
                                  .borderRadius
                              as BorderRadius)
                          .topLeft
                          .x
                    : 12.0,
              ),
              boxShadow:
                  theme.cardTheme.elevation != null &&
                      theme.cardTheme.elevation! > 0
                  ? [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
                        blurRadius: theme.cardTheme.elevation! * 2,
                        offset: Offset(0, theme.cardTheme.elevation!),
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                theme.cardTheme.shape is RoundedRectangleBorder
                    ? ((theme.cardTheme.shape as RoundedRectangleBorder)
                                  .borderRadius
                              as BorderRadius)
                          .topLeft
                          .x
                    : 12.0,
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.brightness_6_outlined,
                    title: 'Theme',
                    subtitle: themeProvider.getThemeModeString(
                      themeProvider.themeMode,
                    ),
                    onTap: () {
                      _showThemeSelectionDialog(
                        Provider.of<ThemeProvider>(context, listen: false),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildSettingsItem(
                    icon: Icons.style_outlined,
                    title: 'Category Tag Style',
                    // This will display the current style, e.g., "Glassmorphic"
                    subtitle: themeProvider.categoryTagStyle.name
                        .replaceFirstMapped(
                          themeProvider.categoryTagStyle.name[0],
                          (match) => themeProvider.categoryTagStyle.name[0]
                              .toUpperCase(),
                        ),
                    onTap: () {
                      _showCategoryTagStyleSelectionDialog(
                        Provider.of<ThemeProvider>(context, listen: false),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          _buildSettingsSectionTitle(context, 'ABOUT'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.cardColor,
              borderRadius: BorderRadius.circular(
                theme.cardTheme.shape is RoundedRectangleBorder
                    ? ((theme.cardTheme.shape as RoundedRectangleBorder)
                                  .borderRadius
                              as BorderRadius)
                          .topLeft
                          .x
                    : 12.0,
              ),
              boxShadow:
                  theme.cardTheme.elevation != null &&
                      theme.cardTheme.elevation! > 0
                  ? [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
                        blurRadius: theme.cardTheme.elevation! * 2,
                        offset: Offset(0, theme.cardTheme.elevation!),
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                theme.cardTheme.shape is RoundedRectangleBorder
                    ? ((theme.cardTheme.shape as RoundedRectangleBorder)
                                  .borderRadius
                              as BorderRadius)
                          .topLeft
                          .x
                    : 12.0,
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.info_outline,
                    title: 'App Version',
                    subtitle: '1.0.0', // Replace with dynamic version later
                    trailing: const SizedBox.shrink(),
                    onTap: null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
