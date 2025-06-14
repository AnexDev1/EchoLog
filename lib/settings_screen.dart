import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String PREF_HIDDEN_ACCESS_METHOD = 'selectedHiddenAccessTriggerMethod';

enum HiddenAccessTriggerMethod {
  longPressAppBar, // "Hold" on AppBar
  tripleTapAppBar,
  pinchInScreen,
  pinchOutScreen,
  // If "Hold" is meant for the general screen, we might add another:
  // longPressScreen,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  HiddenAccessTriggerMethod _selectedMethod =
      HiddenAccessTriggerMethod.longPressAppBar;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final methodName = prefs.getString(PREF_HIDDEN_ACCESS_METHOD);
    if (methodName != null) {
      try {
        _selectedMethod = HiddenAccessTriggerMethod.values.firstWhere(
          (e) => e.toString() == methodName,
          orElse: () => HiddenAccessTriggerMethod.longPressAppBar,
        );
      } catch (e) {
        _selectedMethod = HiddenAccessTriggerMethod.longPressAppBar;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _savePreference(HiddenAccessTriggerMethod method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PREF_HIDDEN_ACCESS_METHOD, method.toString());
    if (mounted) {
      setState(() {
        _selectedMethod = method;
      });
    }
  }

  String _getMethodDescription(HiddenAccessTriggerMethod method) {
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

  void _showAccessMethodSelectionDialog() {
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
                _getMethodDescription(method),
                style: GoogleFonts.poppins(),
              ),
              value: method,
              groupValue: _selectedMethod,
              onChanged: (HiddenAccessTriggerMethod? value) {
                if (value != null) {
                  Navigator.pop(context, value); // Pop with the selected value
                }
              },
              activeColor: Theme.of(context).colorScheme.primary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            );
          }).toList(),
        );
      },
    ).then((selectedValue) {
      if (selectedValue != null) {
        _savePreference(selectedValue);
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
    return Material(
      // To get inkwell effect if onTap is provided
      color: Theme.of(
        context,
      ).cardColor, // Or transparent if you want list background
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        title: Text(title, style: GoogleFonts.poppins(fontSize: 16)),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 4.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background, // Clean background
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor:
            theme.colorScheme.surface, // Use surface color for a flatter AppBar
        elevation: 0, // Minimalist AppBar
        foregroundColor:
            theme.colorScheme.onSurface, // Ensure text/icon contrast
        leading: IconButton(
          // Custom back button for consistency if needed
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: <Widget>[
          _buildSettingsSectionTitle(context, 'SECRET VAULT'),
          Container(
            color: theme.cardColor, // Group items with a card background
            child: Column(
              children: [
                _buildSettingsItem(
                  icon: Icons.touch_app_outlined,
                  title: 'Access Method',
                  subtitle: _getMethodDescription(_selectedMethod),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                  onTap: _showAccessMethodSelectionDialog,
                ),
                // Add other "Secret Vault" related settings here using _buildSettingsItem
                // Example:
                // _buildSettingsItem(
                //   icon: Icons.lock_outline,
                //   title: 'Change PIN',
                //   onTap: () { /* Navigate to change PIN screen */ },
                // ),
              ],
            ),
          ),

          _buildSettingsSectionTitle(context, 'APPEARANCE'),
          Container(
            color: theme.cardColor,
            child: Column(
              children: [
                _buildSettingsItem(
                  icon: Icons.brightness_6_outlined,
                  title: 'Theme',
                  subtitle: 'System default', // This would be dynamic
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                  onTap: () {
                    // Show theme selection dialog (Light, Dark, System)
                    print('Theme setting tapped');
                  },
                ),
              ],
            ),
          ),

          _buildSettingsSectionTitle(context, 'ABOUT'),
          Container(
            color: theme.cardColor,
            child: Column(
              children: [
                _buildSettingsItem(
                  icon: Icons.info_outline,
                  title: 'App Version',
                  subtitle:
                      '1.0.0', // This would be dynamic (e.g., from package_info_plus)
                ),
                // _buildSettingsItem(
                //   icon: Icons.policy_outlined,
                //   title: 'Privacy Policy',
                //   onTap: () { /* Open privacy policy URL */ },
                // ),
              ],
            ),
          ),
          const SizedBox(height: 30), // Bottom padding
        ],
      ),
    );
  }
}
