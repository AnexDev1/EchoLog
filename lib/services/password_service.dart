import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasswordService {
  final _storage = const FlutterSecureStorage();
  static const _passwordKey = 'hidden_screen_password';

  Future<void> setPassword(String password) async {
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<String?> getPassword() async {
    return await _storage.read(key: _passwordKey);
  }

  Future<bool> hasPassword() async {
    final password = await _storage.read(key: _passwordKey);
    return password != null && password.isNotEmpty;
  }

  Future<bool> verifyPassword(String inputPassword) async {
    final storedPassword = await getPassword();
    return storedPassword == inputPassword;
  }

  Future<void> deletePassword() async {
    await _storage.delete(key: _passwordKey);
  }
}
