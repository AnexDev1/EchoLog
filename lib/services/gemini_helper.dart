import 'package:flutter_gemini/flutter_gemini.dart';

class GeminiHelper {
  static void clearInstance() {
    // This is a workaround: re-init with empty key to clear the singleton
    Gemini.init(apiKey: '');
  }
}
