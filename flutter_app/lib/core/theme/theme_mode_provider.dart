import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _themeModeStorageKey = 'ske_theme_mode';

/// Persists the user's Light/Dark/System choice using the same secure
/// storage already declared as a dependency for the app — no new package
/// added. Falls back to [ThemeMode.light] (the app's default) on first
/// launch or if reading storage fails for any reason.
class ThemeModeController extends Notifier<ThemeMode> {
  final _storage = const FlutterSecureStorage();

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.light;
  }

  Future<void> _restore() async {
    try {
      final saved = await _storage.read(key: _themeModeStorageKey);
      if (saved != null) {
        state = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.light);
      }
    } catch (_) {
      // Storage unavailable (e.g. some web contexts) — silently keep default.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      await _storage.write(key: _themeModeStorageKey, value: mode.name);
    } catch (_) {
      // Non-fatal — the in-memory preference for this session still applies.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
