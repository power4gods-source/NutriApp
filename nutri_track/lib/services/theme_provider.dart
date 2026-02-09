import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _darkModeKey = 'dark_mode';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }
}
