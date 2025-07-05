import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert'; // For base64 encoding

enum AuthMethod { None, Passcode, Biometrics }

class SecurityService with ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const _keyStorageKey = 'com.example.echolog.encryptionKey';

  AuthMethod _authMethod = AuthMethod.None;
  String? _savedPasscode;

  // Use ValueNotifier for clean, efficient UI updates.
  // The app should always start in an unlocked state.
  final ValueNotifier<bool> isLocked = ValueNotifier(false);

  // For grace period logic
  DateTime? _pausedTime;
  static const int _gracePeriodSeconds = 2; // 2-second grace period

  // The key is now loaded asynchronously and stored in a Future.
  late final Future<encrypt.Key> _keyFuture;

  AuthMethod get authMethod => _authMethod;

  SecurityService() {
    _loadSettings();
    _keyFuture = _getOrCreateEncryptionKey();
  }

  Future<encrypt.Key> _getOrCreateEncryptionKey() async {
    // Try to read the key from secure storage
    String? base64Key = await _secureStorage.read(key: _keyStorageKey);

    if (base64Key == null) {
      // If no key exists, generate a new one
      final newKey = encrypt.Key.fromSecureRandom(32);
      // Store it securely as a base64 string
      await _secureStorage.write(
        key: _keyStorageKey,
        value: base64.encode(newKey.bytes),
      );
      debugPrint('Generated and stored a new encryption key.');
      return newKey;
    } else {
      // If a key exists, decode it from base64
      debugPrint('Loaded existing encryption key.');
      return encrypt.Key(base64.decode(base64Key));
    }
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

  /// Encrypts a file and writes the encrypted data to [outputPath].
  /// The file format will be: [16-byte IV][encrypted data]
  Future<void> encryptFile(String inputPath, String outputPath) async {
    final key = await _keyFuture;
    final plainBytes = await File(inputPath).readAsBytes();
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    // Create a new, random IV for each encryption for security
    final iv = encrypt.IV.fromSecureRandom(16);

    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    // Prepend the IV to the encrypted data. The decryptor will need it.
    final encryptedBytesWithIv = iv.bytes + encrypted.bytes;

    await File(outputPath).writeAsBytes(encryptedBytesWithIv);
  }

  /// Decrypts a file and writes the decrypted data to [outputPath].
  /// Assumes the file format is: [16-byte IV][encrypted data]
  Future<void> decryptFile(String inputPath, String outputPath) async {
    final decryptedBytes = await decryptFileToBytes(inputPath);
    await File(outputPath).writeAsBytes(decryptedBytes);
  }

  /// Decrypts a file and returns the raw bytes (for in-memory playback, etc.)
  /// Assumes the file format is: [16-byte IV][encrypted data]
  Future<Uint8List> decryptFileToBytes(String inputPath) async {
    final key = await _keyFuture;
    final encryptedBytesWithIv = await File(inputPath).readAsBytes();

    // 1. Extract the IV from the first 16 bytes.
    final iv = encrypt.IV(encryptedBytesWithIv.sublist(0, 16));

    // 2. Extract the actual encrypted data.
    final encryptedBytes = encryptedBytesWithIv.sublist(16);

    // 3. Decrypt
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(encryptedBytes),
      iv: iv,
    );
    return Uint8List.fromList(decrypted);
  }
}
