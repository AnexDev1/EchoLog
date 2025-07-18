import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import 'gemini_helper.dart';

class ApiKeyService extends ChangeNotifier {
  static const String _hiveBox = 'settings';
  static const String _apiKeyKey = 'gemini_api_key';
  static const String _secureApiKeyKey = 'secure_gemini_api_key';
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static final ApiKeyService instance = ApiKeyService._internal();
  ApiKeyService._internal();
  factory ApiKeyService() => instance;

  /// Save API key securely
  static Future<void> saveApiKey(String apiKey) async {
    await _secureStorage.write(key: _secureApiKeyKey, value: apiKey);
    final box = await Hive.openBox(_hiveBox);
    await box.put(_apiKeyKey, apiKey);
    instance.notifyListeners();
  }

  /// Get API key (secure storage first, fallback to Hive)
  static Future<String?> getApiKey() async {
    String? apiKey = await _secureStorage.read(key: _secureApiKeyKey);
    if (apiKey != null && apiKey.isNotEmpty) return apiKey;
    final box = await Hive.openBox(_hiveBox);
    apiKey = box.get(_apiKeyKey);
    return apiKey;
  }

  /// Replace API key (prompt user for new key, then save it)
  static Future<void> replaceApiKey(String newApiKey) async {
    await _secureStorage.write(key: _secureApiKeyKey, value: newApiKey);
    final box = await Hive.openBox(_hiveBox);
    await box.put(_apiKeyKey, newApiKey);
    GeminiHelper.initWithKey(newApiKey);
    instance.notifyListeners();
  }

  //create removeapikey
  static Future<void> removeApiKey() async {
    await _secureStorage.delete(key: _secureApiKeyKey);
    final box = await Hive.openBox(_hiveBox);
    await box.delete(_apiKeyKey);
    GeminiHelper.clearInstance();
    instance.notifyListeners();
  }
}
