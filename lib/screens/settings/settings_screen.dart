import 'package:echolog/services/api_key_service.dart';
import 'package:echolog/services/data_exporter_service.dart';
import 'package:echolog/services/security_service.dart';
import 'package:echolog/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String PREF_HIDDEN_ACCESS_METHOD = 'selectedHiddenAccessTriggerMethod';

enum HiddenAccessTriggerMethod {
  longPressAppBar,
  tripleTapAppBar,
  pinchInScreen,
  pinchOutScreen,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  HiddenAccessTriggerMethod _selectedHiddenAccessMethod =
      HiddenAccessTriggerMethod.longPressAppBar;
  bool _isExporting = false;
  bool _isImporting = false;
  bool _canUseBiometrics = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadHiddenAccessPreference();
    _checkBiometrics();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        HiddenAccessTriggerMethod.longPressAppBar;
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
        return "Long-press App Bar";
      case HiddenAccessTriggerMethod.tripleTapAppBar:
        return "Triple-tap App Bar";
      case HiddenAccessTriggerMethod.pinchInScreen:
        return "Pinch In Screen";
      case HiddenAccessTriggerMethod.pinchOutScreen:
        return "Pinch Out Screen";
    }
  }

  void _showHiddenAccessMethodSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Access Method',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Choose how to access your secret vault',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Options
                ...HiddenAccessTriggerMethod.values.map((method) {
                  final isSelected = method == _selectedHiddenAccessMethod;
                  return InkWell(
                    onTap: () {
                      _saveHiddenAccessPreference(method);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1)
                            : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.4),
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _getHiddenAccessMethodDescription(method),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showSetPasscodeDialog() async {
    final controller = TextEditingController();
    String? passcode;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Set App Lock Passcode'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Enter a 4-6 digit passcode',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length >= 4 && controller.text.length <= 6) {
                passcode = controller.text;
                Navigator.of(context).pop();
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    return passcode;
  }

  Future<bool?> _showVerifyPasscodeDialog(
    SecurityService securityService,
  ) async {
    final controller = TextEditingController();
    bool? verified = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify Passcode'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Enter your passcode'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (securityService.checkPasscode(controller.text)) {
                verified = true;
                Navigator.of(context).pop();
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    return verified;
  }

  String _getSecurityMethodDescription(AuthMethod method) {
    switch (method) {
      case AuthMethod.None:
        return 'App is not secured';
      case AuthMethod.Passcode:
        return 'Secured with PIN';
      case AuthMethod.Biometrics:
        return 'Secured with biometrics';
    }
  }

  void _showThemeSelectionDialog(ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Theme',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Choose your preferred appearance',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...ThemeMode.values.map((mode) {
                  final isSelected = mode == themeProvider.themeMode;
                  return InkWell(
                    onTap: () {
                      themeProvider.setThemeMode(mode);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1)
                            : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.4),
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            themeProvider.getThemeModeString(mode),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCategoryTagStyleSelectionDialog(ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Category Tag Style',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Customize how category tags appear',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...CategoryTagStyle.values.map((style) {
                  final isSelected = style == themeProvider.categoryTagStyle;
                  String styleName = style.name.replaceFirstMapped(
                    style.name[0],
                    (match) => style.name[0].toUpperCase(),
                  );
                  return InkWell(
                    onTap: () {
                      themeProvider.setCategoryTagStyle(style);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1)
                            : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.4),
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            styleName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleExportData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 20),
            Text("Exporting data...", style: GoogleFonts.inter(fontSize: 16)),
          ],
        ),
      ),
    );

    final exporter = DataExporter();
    String message = 'Export process initiated.';
    bool success = false;
    bool cancelled = false;

    try {
      await exporter.exportData();
      message = 'Data exported successfully';
      success = true;
    } catch (e) {
      final eString = e.toString();
      if (eString.contains('Export cancelled by user')) {
        message = 'Export cancelled';
        cancelled = true;
      } else {
        message = 'Export failed: ${eString.replaceFirst("Exception: ", "")}';
      }
      success = false;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        if (!cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message, style: GoogleFonts.inter()),
              backgroundColor: success ? Colors.green : Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleImportData() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 20),
            Text("Importing data...", style: GoogleFonts.inter(fontSize: 16)),
          ],
        ),
      ),
    );

    final exporter = DataExporter();
    String message = 'Import process initiated.';
    bool success = false;

    try {
      message = await exporter.importData();
      success = !message.startsWith('Import cancelled');
    } catch (e) {
      message =
          'Import failed: ${e.toString().replaceFirst("Exception: ", "")}';
      success = false;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: GoogleFonts.inter()),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: Duration(seconds: message.length > 100 ? 6 : 4),
          ),
        );
      }
    }
  }

  Widget _buildSettingsGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isLoading = false,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: !isLast
              ? Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.1),
                    width: 0.5,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(
                      icon,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null && !isLoading) ...[
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final securityService = Provider.of<SecurityService>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // Gemini API Key Section
            _buildSettingsGroup(
              title: 'GEMINI API',
              children: [
                _buildSettingsItem(
                  icon: Icons.vpn_key_outlined,
                  title: 'Clear Gemini API Key',
                  subtitle:
                      'Remove the stored Gemini API key from secure storage',
                  onTap: () async {
                    try {
                      await ApiKeyService.removeApiKey();
                      setState(() {}); // Force UI to refresh and re-fetch key
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Gemini API key cleared.',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to clear API key: $e',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  isFirst: true,
                  isLast: true,
                ),
              ],
            ),
            // Secret Vault Section
            _buildSettingsGroup(
              title: 'SECRET VAULT',
              children: [
                _buildSettingsItem(
                  icon: Icons.lock_outline,
                  title: 'Access Method',
                  subtitle: _getHiddenAccessMethodDescription(
                    _selectedHiddenAccessMethod,
                  ),
                  onTap: _showHiddenAccessMethodSelectionDialog,
                  isFirst: true,
                  isLast: true,
                ),
              ],
            ),

            // Security Section
            _buildSettingsGroup(
              title: 'SECURITY',
              children: [
                Consumer<SecurityService>(
                  builder: (context, securityService, _) => _buildSettingsItem(
                    icon: Icons.shield_outlined,
                    title: 'App Lock',
                    subtitle: _getSecurityMethodDescription(
                      securityService.authMethod,
                    ),
                    trailing: Switch.adaptive(
                      value: securityService.authMethod != AuthMethod.None,
                      onChanged: (bool value) async {
                        if (value) {
                          final passcode = await _showSetPasscodeDialog();
                          if (passcode != null) {
                            final method = _canUseBiometrics
                                ? AuthMethod.Biometrics
                                : AuthMethod.Passcode;
                            await securityService.setAuthMethod(
                              method,
                              passcode: passcode,
                            );
                          }
                        } else {
                          final didVerify = await _showVerifyPasscodeDialog(
                            securityService,
                          );
                          if (didVerify == true) {
                            await securityService.setAuthMethod(
                              AuthMethod.None,
                            );
                          }
                        }
                      },
                      activeColor: theme.colorScheme.primary,
                    ),
                    onTap: () async {
                      if (securityService.authMethod == AuthMethod.None) {
                        final passcode = await _showSetPasscodeDialog();
                        if (passcode != null) {
                          final method = _canUseBiometrics
                              ? AuthMethod.Biometrics
                              : AuthMethod.Passcode;
                          await securityService.setAuthMethod(
                            method,
                            passcode: passcode,
                          );
                        }
                      } else {
                        final didVerify = await _showVerifyPasscodeDialog(
                          securityService,
                        );
                        if (didVerify == true) {
                          await securityService.setAuthMethod(AuthMethod.None);
                        }
                      }
                    },
                    isFirst: true,
                    isLast: true,
                  ),
                ),
              ],
            ),

            // Appearance Section
            _buildSettingsGroup(
              title: 'APPEARANCE',
              children: [
                _buildSettingsItem(
                  icon: Icons.palette_outlined,
                  title: 'Theme',
                  subtitle: themeProvider.getThemeModeString(
                    themeProvider.themeMode,
                  ),
                  onTap: () => _showThemeSelectionDialog(themeProvider),
                  isFirst: true,
                  isLast: false,
                ),
                _buildSettingsItem(
                  icon: Icons.style_outlined,
                  title: 'Category Tag Style',
                  subtitle: themeProvider.categoryTagStyle.name
                      .replaceFirstMapped(
                        themeProvider.categoryTagStyle.name[0],
                        (match) => themeProvider.categoryTagStyle.name[0]
                            .toUpperCase(),
                      ),
                  onTap: () =>
                      _showCategoryTagStyleSelectionDialog(themeProvider),
                  isFirst: false,
                  isLast: true,
                ),
              ],
            ),

            // Data Management Section
            _buildSettingsGroup(
              title: 'DATA MANAGEMENT',
              children: [
                _buildSettingsItem(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Export Data',
                  subtitle: 'Backup your recordings and settings',
                  onTap: _handleExportData,
                  isLoading: _isExporting,
                  isFirst: true,
                  isLast: false,
                ),
                _buildSettingsItem(
                  icon: Icons.cloud_download_outlined,
                  title: 'Import Data',
                  subtitle: 'Restore data from a backup file',
                  onTap: _handleImportData,
                  isLoading: _isImporting,
                  isFirst: false,
                  isLast: true,
                ),
              ],
            ),

            // About Section
            _buildSettingsGroup(
              title: 'ABOUT',
              children: [
                _buildSettingsItem(
                  icon: Icons.info_outline,
                  title: 'App Version',
                  subtitle: '2.4.8',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Latest',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  onTap: null,
                  isFirst: true,
                  isLast: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
