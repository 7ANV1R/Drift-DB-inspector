import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Call once from [main] before [runApp] so the first frame uses saved mode.
  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    state = _themeModeFromPrefs(prefs.getString(_kThemeModeKey));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
  }
}

ThemeMode _themeModeFromPrefs(String? raw) {
  if (raw == null) return ThemeMode.system;
  for (final v in ThemeMode.values) {
    if (v.name == raw) return v;
  }
  return ThemeMode.system;
}
