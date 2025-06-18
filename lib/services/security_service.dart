import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthMethod { None, Passcode, Biometrics }

class SecurityService with ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();
  AuthMethod _authMethod = AuthMethod.None;
  bool _isLocked = true;
  String? _savedPasscode;

  AuthMethod get authMethod => _authMethod;
  bool get isLocked => _isLocked;

  SecurityService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final methodIndex = prefs.getInt('authMethod') ?? 0;
    _authMethod = AuthMethod.values[methodIndex];
    _savedPasscode = prefs.getString('passcode');

    // If no security is set, the app is unlocked by default.
    if (_authMethod == AuthMethod.None) {
      _isLocked = false;
    }
    notifyListeners();
  }

  Future<void> setAuthMethod(AuthMethod method, {String? passcode}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('authMethod', method.index);
    _authMethod = method;

    if (method == AuthMethod.Passcode ||
        (method == AuthMethod.Biometrics && passcode != null)) {
      await prefs.setString('passcode', passcode!);
      _savedPasscode = passcode;
    } else if (method == AuthMethod.None) {
      await prefs.remove('passcode');
      _savedPasscode = null;
    }

    // When changing settings, unlock the app to prevent being locked out.
    unlockApp();
    notifyListeners();
  }

  Future<bool> canUseBiometrics() async {
    return await _localAuth.canCheckBiometrics &&
        await _localAuth.isDeviceSupported();
  }

  Future<bool> authenticate() async {
    if (_authMethod == AuthMethod.Biometrics) {
      return await _authenticateWithBiometrics();
    }
    // Passcode authentication will be handled by a dedicated screen.
    return false;
  }

  Future<bool> _authenticateWithBiometrics() async {
    if (!await canUseBiometrics()) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your recordings',
        options: const AuthenticationOptions(
          stickyAuth: true, // Keep auth prompt open on app switch
          biometricOnly: true,
        ),
      );
    } catch (e) {
      debugPrint("Error during biometric authentication: $e");
      return false;
    }
  }

  bool checkPasscode(String passcode) {
    return passcode == _savedPasscode;
  }

  void lockApp() {
    if (_authMethod != AuthMethod.None && !_isLocked) {
      _isLocked = true;
      notifyListeners();
    }
  }

  void unlockApp() {
    if (_isLocked) {
      _isLocked = false;
      notifyListeners();
    }
  }
}
