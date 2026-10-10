import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'flex_theme_mode';
  static const String _keyAmoled = 'flex_amoled';
  static const String _keyColor = 'flex_accent_color';
  static const String _keyGradientEndColor = 'flex_gradient_end_color';
  static const String _keyUseGradient = 'flex_use_gradient';
  static const String _keyColumns = 'flex_columns';
  static const String _keySafeMode = 'flex_safe_mode';
  static const String _keyUserAgent = 'flex_user_agent';
  static const String _keyQuality = 'flex_image_quality';
  static const String _keyLanguage = 'flex_language';
  static const String _keyAutoCheckUpdate = 'flex_auto_check_update';
  static const String _keyDownloadPath = 'flex_download_path';
  static const String _keyTagLanguage = 'flex_tag_language';

  ThemeMode _themeMode = ThemeMode.system;
  bool _amoled = false;
  Color _accentColor = const Color(0xFF3F51B5); // Classic Flexbooru Indigo/Blue
  Color? _gradientEndColor;
  bool _useGradient = false;
  int _gridColumns = 0; // 0 for auto responsive
  bool _defaultSafeMode = true;
  String _userAgent = AppConstants.defaultUserAgent;
  String _imageQuality = 'sample'; // preview, sample, original
  String _languageCode = 'system'; // 'system', 'zh', 'en'
  String _tagLanguage = 'system'; // 'system', 'zh', 'en'
  bool _autoCheckUpdate = true;
  String _downloadPath = '';

  ThemeMode get themeMode => _themeMode;
  bool get amoled => _amoled;
  Color get accentColor => _accentColor;
  Color? get gradientEndColor => _gradientEndColor;
  bool get useGradient => _useGradient && _gradientEndColor != null;
  LinearGradient get primaryGradient => LinearGradient(
        colors: useGradient
            ? [_accentColor, _gradientEndColor!]
            : [_accentColor, _accentColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  int get gridColumns => _gridColumns;
  bool get defaultSafeMode => _defaultSafeMode;
  String get userAgent => _userAgent;
  String get imageQuality => _imageQuality;
  String get languageCode => _languageCode;
  String get tagLanguage => _tagLanguage;
  String get effectiveTagLanguage {
    if (_tagLanguage == 'zh') return 'zh';
    if (_tagLanguage == 'en') return 'en';
    if (_languageCode == 'zh') return 'zh';
    if (_languageCode == 'en') return 'en';
    final sys = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return sys.startsWith('zh') ? 'zh' : 'en';
  }
  bool get autoCheckUpdate => _autoCheckUpdate;
  String get downloadPath => _downloadPath;

  Locale? get locale {
    if (_languageCode == 'zh') return const Locale('zh');
    if (_languageCode == 'en') return const Locale('en');
    return null; // System default
  }

  Future<void>? _loadingFuture;

  SettingsProvider() {
    _loadingFuture = loadSettings();
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
    final endColorValue = prefs.getInt(_keyGradientEndColor);
    if (endColorValue != null) {
      _gradientEndColor = Color(endColorValue);
    } else {
      _gradientEndColor = _accentColor;
    }
    _useGradient = prefs.getBool(_keyUseGradient) ?? false;
    _gridColumns = prefs.getInt(_keyColumns) ?? 0;
    _defaultSafeMode = prefs.getBool(_keySafeMode) ?? true;
    _userAgent =
        prefs.getString(_keyUserAgent) ?? AppConstants.defaultUserAgent;
    if (_userAgent.trim().isEmpty ||
        _userAgent == AppConstants.legacyUserAgent) {
      _userAgent = AppConstants.defaultUserAgent;
      await prefs.setString(_keyUserAgent, _userAgent);
    }
    ApiClient().setUserAgent(_userAgent);
    _imageQuality = prefs.getString(_keyQuality) ?? 'sample';
    _languageCode = prefs.getString(_keyLanguage) ?? 'system';
    _tagLanguage = prefs.getString(_keyTagLanguage) ?? 'system';
    _autoCheckUpdate = prefs.getBool(_keyAutoCheckUpdate) ?? true;
    _downloadPath = prefs.getString(_keyDownloadPath) ?? '';

    notifyListeners();
  }

  Future<void> setTagLanguage(String lang) async {
    if (_loadingFuture != null) await _loadingFuture;
    _tagLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTagLanguage, lang);
    notifyListeners();
  }

  Future<void> setDownloadPath(String path) async {
    if (_loadingFuture != null) await _loadingFuture;
    _downloadPath = path.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDownloadPath, _downloadPath);
    notifyListeners();
  }

  Future<void> setAutoCheckUpdate(bool val) async {
    if (_loadingFuture != null) await _loadingFuture;
    _autoCheckUpdate = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoCheckUpdate, val);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (_loadingFuture != null) await _loadingFuture;
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_loadingFuture != null) await _loadingFuture;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.name);
    notifyListeners();
  }

  Future<void> setAmoled(bool val) async {
    if (_loadingFuture != null) await _loadingFuture;
    _amoled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAmoled, val);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    if (_loadingFuture != null) await _loadingFuture;
    _accentColor = color;
    _useGradient = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyColor, color.toARGB32());
    await prefs.setBool(_keyUseGradient, false);
    notifyListeners();
  }

  Future<void> setGradientColor(Color startColor, Color endColor) async {
    if (_loadingFuture != null) await _loadingFuture;
    _accentColor = startColor;
    _gradientEndColor = endColor;
    _useGradient = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyColor, startColor.toARGB32());
    await prefs.setInt(_keyGradientEndColor, endColor.toARGB32());
    await prefs.setBool(_keyUseGradient, true);
    notifyListeners();
  }

  Future<void> setGridColumns(int cols) async {
    if (_loadingFuture != null) await _loadingFuture;
    _gridColumns = cols;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyColumns, cols);
    notifyListeners();
  }

  Future<void> setDefaultSafeMode(bool val) async {
    if (_loadingFuture != null) await _loadingFuture;
    _defaultSafeMode = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySafeMode, val);
    notifyListeners();
  }

  Future<void> setUserAgent(String ua) async {
    if (_loadingFuture != null) await _loadingFuture;
    _userAgent = ua.trim().isEmpty ? AppConstants.defaultUserAgent : ua.trim();
    ApiClient().setUserAgent(_userAgent);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserAgent, _userAgent);
    notifyListeners();
  }

  Future<void> setImageQuality(String q) async {
    if (_loadingFuture != null) await _loadingFuture;
    _imageQuality = q;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQuality, q);
    notifyListeners();
  }
}
