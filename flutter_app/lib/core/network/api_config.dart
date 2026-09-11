import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolves the FastAPI base URL for the platform the app is actually
/// running on.
///
/// This exists because a single hard-coded host cannot work everywhere:
///  - Android emulator reaches the host machine's loopback via 10.0.2.2
///  - Chrome / desktop / iOS simulator reach it via localhost
///
/// Previously `.env` hard-coded the Android alias (10.0.2.2), which is not
/// routable from Chrome — every request failed with a connection error that
/// the UI surfaced as "Could not reach the server."
///
/// Precedence:
///   1. `--dart-define=API_BASE_URL=...`   (explicit override, wins always)
///   2. `API_BASE_URL_ANDROID` from .env   (Android only)
///   3. `API_BASE_URL` from .env           (everything else)
class ApiConfig {
  ApiConfig._();

  static const String _dartDefineBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_dartDefineBaseUrl.isNotEmpty) return _dartDefineBaseUrl;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final android = dotenv.maybeGet('API_BASE_URL_ANDROID');
      if (android != null && android.isNotEmpty) return android;
    }

    return dotenv.get('API_BASE_URL');
  }
}
