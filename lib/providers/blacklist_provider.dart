import 'package:flutter/foundation.dart';
import '../core/sync/sync_preferences.dart';

class BlacklistProvider extends ChangeNotifier {
  static const String _keyBlacklist = 'flexbooru_global_blacklist';

  List<String> _blacklist = [];
  List<String> _persistedBlacklist = [];
  List<String> get blacklist => _blacklist;

  BlacklistProvider() {
    ready = loadBlacklist();
  }

  late final Future<void> ready;

  Future<void> loadBlacklist() async {
    final prefs = await SyncPreferences.getInstance();
    _blacklist = prefs.getStringList(_keyBlacklist) ?? [];
    _persistedBlacklist = List.of(_blacklist);
    notifyListeners();
  }

  Future<void> addTag(String tag) async {
    await ready;
    final cleaned = tag.trim().toLowerCase();
    if (cleaned.isNotEmpty && !_blacklist.contains(cleaned)) {
      _blacklist.add(cleaned);
      await _save();
      notifyListeners();
    }
  }

  Future<void> removeTag(String tag) async {
    await ready;
    final cleaned = tag.trim().toLowerCase();
    if (_blacklist.remove(cleaned)) {
      await _save();
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    await ready;
    _blacklist.clear();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SyncPreferences.getInstance();
    final value = List<String>.of(_blacklist);
    await prefs.setStringList(
      _keyBlacklist,
      value,
      previousValue: _persistedBlacklist,
    );
    _persistedBlacklist = value;
  }
}
