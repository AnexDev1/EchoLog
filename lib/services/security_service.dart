import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthMethod { None, Passcode, Biometrics }

class SecurityService with ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();
  AuthMethod _authMethod = AuthMethod.None;
  String? _savedPasscode;

  // Use ValueNotifier for clean, efficient UI updates.
  // The app should always start in an unlocked state.
  final ValueNotifier<bool> isLocked = ValueNotifier(false);

  // For grace period logic
  DateTime? _pausedTime;
  static const int _gracePeriodSeconds = 2; // 2-second grace period

  AuthMethod get authMethod => _authMethod;

  SecurityService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final methodIndex = prefs.getInt('authMethod') ?? AuthMethod.None.index;
    _authMethod = AuthMethod.values[methodIndex];
    _savedPasscode = prefs.getString('passcode');

    // We no longer need to set the lock state here; it defaults to false.
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

    // When changing settings, ensure the app is unlocked.
    isLocked.value = false;
    notifyListeners();
  }

  // --- Lifecycle Methods (to be called from main.dart) ---
  void didPause() {
    // Record the time when the app is paused, if locking is enabled.
    if (authMethod != AuthMethod.None) {
      _pausedTime = DateTime.now();
    }
  }

  void didResume() {
    // On resume, check if the grace period has passed.
    if (authMethod != AuthMethod.None && _pausedTime != null) {
      final elapsed = DateTime.now().difference(_pausedTime!).inSeconds;
      if (elapsed > _gracePeriodSeconds) {
        lockApp();
      }
      _pausedTime = null; // Reset the timer
    }
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint("Error checking biometrics support: $e");
      return false;
    }
  }

  Future<bool> authenticate() async {
    if (_authMethod != AuthMethod.Biometrics || !await canUseBiometrics()) {
      return false;
    }
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your recordings',
        options: const AuthenticationOptions(
          stickyAuth: true,
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
    if (authMethod != AuthMethod.None && !isLocked.value) {
      isLocked.value = true;
    }
  }

  void unlockApp() {
    if (isLocked.value) {
      isLocked.value = false;
    }
  }
}
