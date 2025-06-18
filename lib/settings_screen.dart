import 'package:echolog/services/data_exporter_service.dart';
import 'package:echolog/services/security_service.dart'; // Ensure correct path
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
  bool _isExporting = false;
  bool _isImporting = false;
  bool _canUseBiometrics = false; // For security settings

  @override
  void initState() {
    super.initState();
    _loadHiddenAccessPreference();
    _checkBiometrics(); // Check for biometrics support
  }

  Future<void> _checkBiometrics() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final securityService = Provider.of<SecurityService>(
        context,
        listen: false,
      );
      final canUse = await securityService.canUseBiometrics();
      if (mounted) {
        setState(() {
          _canUseBiometrics = canUse;
        });
      }
    });
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

  // --- Security Methods ---
  Future<String?> _showSetPasscodeDialog() async {
    final passcodeController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Set a 4-Digit PIN',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: passcodeController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (passcodeController.text.length == 4) {
                Navigator.pop(context, passcodeController.text);
              }
            },
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showVerifyPasscodeDialog(
    SecurityService securityService,
  ) async {
    final passcodeController = TextEditingController();
    String? errorText;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Enter PIN to Disable',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: TextField(
                controller: passcodeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter current PIN',
                  counterText: '',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (passcodeController.text.length == 4) {
                      final isCorrect = securityService.checkPasscode(
                        passcodeController.text,
                      );
                      if (isCorrect) {
                        Navigator.pop(context, true);
                      } else {
                        setState(() {
                          errorText = 'Incorrect PIN. Please try again.';
                        });
                        passcodeController.clear();
                      }
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getSecurityMethodDescription(AuthMethod method) {
    switch (method) {
      case AuthMethod.None:
        return 'Disabled. The app will not be locked.';
      case AuthMethod.Passcode:
        return 'Enabled using Passcode.';
      case AuthMethod.Biometrics:
        return 'Enabled using Biometrics & Passcode.';
    }
  }
  // --- End Security Methods ---

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
          children: CategoryTagStyle.values.map((style) {
            String styleName = style.name.replaceFirstMapped(
              style.name[0],
              (match) => style.name[0].toUpperCase(),
            );
            return RadioListTile<CategoryTagStyle>(
              title: Text(styleName, style: GoogleFonts.poppins()),
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

  Future<void> _handleExportData() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text("Exporting data...", style: GoogleFonts.poppins()),
            ],
          ),
        );
      },
    );

    final exporter = DataExporter();
    String message = 'Export process initiated.';
    bool success = false;
    bool cancelled = false;

    try {
      await exporter.exportData();
      message = 'Data export completed. Check your selected save location.';
      success = true;
    } catch (e) {
      final eString = e.toString();
      if (eString.contains('Export cancelled by user')) {
        message = 'Export cancelled by user.';
        cancelled = true;
      } else {
        message = 'Export failed: ${eString.replaceFirst("Exception: ", "")}';
      }
      success = false;
    } finally {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Dismiss loading dialog
        setState(() {
          _isExporting = false;
        });
        if (!cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message, style: GoogleFonts.poppins()),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleImportData() async {
    if (_isImporting) return;

    setState(() {
      _isImporting = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text("Importing data...", style: GoogleFonts.poppins()),
            ],
          ),
        );
      },
    );

    final exporter = DataExporter();
    String message = 'Import process initiated.';
    bool success = false; // Success here means the process completed,
    // message will contain details.

    try {
      message = await exporter.importData();
      if (message.startsWith('Import cancelled')) {
        success = false;
      } else {
        success = true;
      }
    } catch (e) {
      message =
          'Import failed: ${e.toString().replaceFirst("Exception: ", "")}';
      success = false;
    } finally {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Dismiss loading dialog
        setState(() {
          _isImporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: GoogleFonts.poppins()),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: Duration(seconds: message.length > 100 ? 6 : 4),
          ),
        );
      }
    }
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
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color ?? theme.cardColor,
      child: ListTile(
        leading: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.secondary,
                  ),
                ),
              )
            : Icon(icon, color: theme.colorScheme.secondary),
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
        trailing: isLoading
            ? null
            : trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: theme.hintColor.withOpacity(0.7),
                  ),
        onTap: isLoading ? null : onTap,
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
    final securityService = Provider.of<SecurityService>(
      context,
    ); // Get SecurityService

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
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: _buildSettingsItem(
                icon: Icons.touch_app_outlined,
                title: 'Access Method',
                subtitle: _getHiddenAccessMethodDescription(
                  _selectedHiddenAccessMethod,
                ),
                onTap: _showHiddenAccessMethodSelectionDialog,
              ),
            ),
          ),

          _buildSettingsSectionTitle(context, 'SECURITY'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.cardColor,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: _buildSettingsItem(
                icon: Icons.lock_outline,
                title: 'App Lock',
                subtitle: _getSecurityMethodDescription(
                  securityService.authMethod,
                ),
                trailing: Switch(
                  value: securityService.authMethod != AuthMethod.None,
                  onChanged: (bool value) async {
                    if (value) {
                      // Turning ON
                      final passcode = await _showSetPasscodeDialog();
                      if (passcode != null) {
                        final method = _canUseBiometrics
                            ? AuthMethod.Biometrics
                            : AuthMethod.Passcode;
                        securityService.setAuthMethod(
                          method,
                          passcode: passcode,
                        );
                      }
                    } else {
                      // Turning OFF
                      final didVerify = await _showVerifyPasscodeDialog(
                        securityService,
                      );
                      if (didVerify == true) {
                        securityService.setAuthMethod(AuthMethod.None);
                      }
                    }
                  },
                ),
              ),
            ),
          ),

          _buildSettingsSectionTitle(context, 'APPEARANCE'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.cardColor,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
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

          _buildSettingsSectionTitle(context, 'DATA MANAGEMENT'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.cardColor,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.backup_outlined,
                    title: 'Export Data',
                    subtitle: 'Backup your recordings and settings',
                    onTap: _handleExportData,
                    isLoading: _isExporting,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildSettingsItem(
                    icon: Icons.cloud_download_outlined,
                    title: 'Import Data',
                    subtitle: 'Restore data from a backup file',
                    onTap: _handleImportData,
                    isLoading: _isImporting,
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
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: _buildSettingsItem(
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: '1.0.0', // Replace with dynamic version later
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
