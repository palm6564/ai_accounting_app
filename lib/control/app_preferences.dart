import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences._(this._storage)
    : _themeMode = _themeFromName(_storage.getString('themeMode')),
      _locale = Locale(_localeFromName(_storage.getString('locale'))),
      _useBuddhistYear = _storage.getBool('useBuddhistYear') ?? true;

  final SharedPreferences _storage;
  ThemeMode _themeMode;
  Locale _locale;
  bool _useBuddhistYear;

  static Future<AppPreferences> load() async =>
      AppPreferences._(await SharedPreferences.getInstance());

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get useBuddhistYear => _useBuddhistYear;

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    await _storage.setString('themeMode', value.name);
  }

  Future<void> setLocale(Locale value) async {
    if (_locale == value) return;
    _locale = value;
    notifyListeners();
    await _storage.setString('locale', value.languageCode);
  }

  Future<void> setUseBuddhistYear(bool value) async {
    if (_useBuddhistYear == value) return;
    _useBuddhistYear = value;
    notifyListeners();
    await _storage.setBool('useBuddhistYear', value);
  }

  static ThemeMode _themeFromName(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.light,
  };

  static String _localeFromName(String? value) => value == 'en' ? 'en' : 'th';
}
