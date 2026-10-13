import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla si las funciones de IA estan habilitadas en toda la app.
/// La preferencia se guarda localmente, igual que el modo oscuro.
class AiProvider extends ChangeNotifier {
  static const _prefsKey = 'vivacol-ai-enabled';

  bool _enabled = false;

  bool get enabled => _enabled;

  AiProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsKey) ?? false;
    if (_enabled) notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
