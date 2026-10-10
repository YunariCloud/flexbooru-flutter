import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'flex_theme_mode';
  static const String _keyAmoled = 'flex_amoled';
  static const String _keyColor = 'flex_accent_color';
  static const String _keyColumns = 'flex_columns';
  static const String _keySafeMode = 'flex_safe_mode';
  static const String _keyUserAgent = 'flex_user_agent';
  static const String _keyQuality = 'flex_image_quality';
  static const String _keyLanguage = 'flex_language';

  ThemeMode _themeMode = ThemeMode.system;
  bool _amoled = false;
  Color _accentColor = const Color(0xFF3F51B5); // Classic Flexbooru Indigo/Blue
  int _gridColumns = 0; // 0 for auto responsive
  bool _defaultSafeMode = true;
  String _userAgent = AppConstants.defaultUserAgent;
  String _imageQuality = 'sample'; // preview, sample, original
  String _languageCode = 'system'; // 'system', 'zh', 'en'

  ThemeMode get themeMode => _themeMode;
  bool get amoled => _amoled;
  Color get accentColor => _accentColor;
  int get gridColumns => _gridColumns;
  bool get defaultSafeMode => _defaultSafeMode;
  String get userAgent => _userAgent;
  String get imageQuality => _imageQuality;
  String get languageCode => _languageCode;

  Locale? get locale {
    if (_languageCode == 'zh') return const Locale('zh');
    if (_languageCode == 'en') return const Locale('en');
    return null; // System default
  }

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final tm = prefs.getString(_keyThemeMode);
    if (tm == 'light') {
      _themeMode = ThemeMode.light;
    } else if (tm == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    _amoled = prefs.getBool(_keyAmoled) ?? false;
    final colorValue = prefs.getInt(_keyColor);
    if (colorValue != null) {
      _accentColor = Color(colorValue);
    }
    _gridColumns = prefs.getInt(_keyColumns) ?? 0;
    _defaultSafeMode = prefs.getBool(_keySafeMode) ?? true;
    _userAgent = prefs.getString(_keyUserAgent) ?? AppConstants.defaultUserAgent;
    _imageQuality = prefs.getString(_keyQuality) ?? 'sample';
    _languageCode = prefs.getString(_keyLanguage) ?? 'system';

    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.name);
    notifyListeners();
  }

  Future<void> setAmoled(bool val) async {
    _amoled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAmoled, val);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setGridColumns(int cols) async {
    _gridColumns = cols;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyColumns, cols);
    notifyListeners();
  }

  Future<void> setDefaultSafeMode(bool val) async {
    _defaultSafeMode = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySafeMode, val);
    notifyListeners();
  }

  Future<void> setUserAgent(String ua) async {
    _userAgent = ua;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserAgent, ua);
    notifyListeners();
  }

  Future<void> setImageQuality(String q) async {
    _imageQuality = q;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQuality, q);
    notifyListeners();
  }
}
