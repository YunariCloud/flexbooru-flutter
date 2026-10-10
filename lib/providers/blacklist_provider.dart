import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlacklistProvider extends ChangeNotifier {
  static const String _keyBlacklist = 'flexbooru_global_blacklist';

  List<String> _blacklist = [];
  List<String> get blacklist => _blacklist;

  BlacklistProvider() {
    loadBlacklist();
  }

  Future<void> loadBlacklist() async {
    final prefs = await SharedPreferences.getInstance();
    _blacklist = prefs.getStringList(_keyBlacklist) ?? [];
    notifyListeners();
  }

  Future<void> addTag(String tag) async {
    final cleaned = tag.trim().toLowerCase();
    if (cleaned.isNotEmpty && !_blacklist.contains(cleaned)) {
      _blacklist.add(cleaned);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyBlacklist, _blacklist);
      notifyListeners();
    }
  }

  Future<void> removeTag(String tag) async {
    final cleaned = tag.trim().toLowerCase();
    if (_blacklist.remove(cleaned)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyBlacklist, _blacklist);
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    _blacklist.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyBlacklist, _blacklist);
    notifyListeners();
  }
}
