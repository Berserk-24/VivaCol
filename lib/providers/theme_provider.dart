import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el modo de tema (claro/oscuro) y lo persiste localmente,
/// equivalente a guardar la preferencia en localStorage en web.
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'vivacol-theme';

  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKey);
    if (value == 'dark') {
      _mode = ThemeMode.dark;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, isDark ? 'dark' : 'light');
  }
}
