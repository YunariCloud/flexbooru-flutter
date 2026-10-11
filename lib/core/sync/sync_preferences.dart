import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared write boundary for app data. Download paths and caches bypass sync.
class SyncPreferences {
  SyncPreferences(this.raw);
  final SharedPreferences raw;
  static Future<bool> Function(String, Object?, Object?)? writeHook;
  static String? Function()? secureSitesReader;
  static final remoteChanges = StreamController<Set<String>>.broadcast();
  // Emitted by app bindings after provider objects have reloaded.
  static final appliedChanges = StreamController<Set<String>>.broadcast();

  static Future<SyncPreferences> getInstance() async =>
      SyncPreferences(await SharedPreferences.getInstance());

  String? getString(String key) =>
      key == 'flexbooru_sites' && secureSitesReader != null
      ? secureSitesReader!()
      : raw.getString(key);
  bool? getBool(String key) => raw.getBool(key);
  int? getInt(String key) => raw.getInt(key);
  List<String>? getStringList(String key) => raw.getStringList(key);

  Future<bool> _write(
    String key,
    Object? value, {
    Object? previousValue,
  }) async {
    if (await writeHook?.call(key, value, previousValue) == true) return true;
    return writeRaw(raw, key, value);
  }

  Future<bool> setString(String key, String value, {String? previousValue}) =>
      _write(key, value, previousValue: previousValue);
  Future<bool> setBool(String key, bool value) => _write(key, value);
  Future<bool> setInt(String key, int value) => _write(key, value);
  Future<bool> setStringList(
    String key,
    List<String> value, {
    List<String>? previousValue,
  }) => _write(
    key,
    List<String>.of(value),
    previousValue: previousValue == null
        ? null
        : List<String>.of(previousValue),
  );
  Future<bool> remove(String key) => _write(key, null);

  static Future<bool> writeRaw(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) {
    return switch (value) {
      null => prefs.remove(key),
      String v => prefs.setString(key, v),
      bool v => prefs.setBool(key, v),
      int v => prefs.setInt(key, v),
      List<String> v => prefs.setStringList(key, v),
      _ => throw ArgumentError('Unsupported preference type'),
    };
  }
}
