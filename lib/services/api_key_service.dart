import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'gemini_helper.dart';

class ApiKeyService {
  static const String _hiveBox = 'settings';
  static const String _apiKeyKey = 'gemini_api_key';
  static const String _secureApiKeyKey = 'secure_gemini_api_key';
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Save API key securely
  static Future<void> saveApiKey(String apiKey) async {
    await _secureStorage.write(key: _secureApiKeyKey, value: apiKey);
    final box = await Hive.openBox(_hiveBox);
    await box.put(_apiKeyKey, apiKey);
  }

  /// Get API key (secure storage first, fallback to Hive)
  static Future<String?> getApiKey() async {
    String? apiKey = await _secureStorage.read(key: _secureApiKeyKey);
    if (apiKey != null && apiKey.isNotEmpty) return apiKey;
    final box = await Hive.openBox(_hiveBox);
    apiKey = box.get(_apiKeyKey);
    return apiKey;
  }

  /// Remove API key
  static Future<void> removeApiKey() async {
    await _secureStorage.delete(key: _secureApiKeyKey);
    final box = await Hive.openBox(_hiveBox);
    await box.delete(_apiKeyKey);
    // Also clear Gemini instance in memory
    GeminiHelper.clearInstance();
  }
}
