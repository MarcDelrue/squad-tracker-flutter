import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleProvider() {
    _loadSavedLocale();
  }

  static const String _prefsKey = 'app_locale_code';
  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> setLocale(Locale? newLocale) async {
    _locale = newLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (newLocale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, newLocale.languageCode);
    }
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == null || code.isEmpty) return;
    if (code == 'en' || code == 'fr') {
      _locale = Locale(code);
      notifyListeners();
    }
  }
}
