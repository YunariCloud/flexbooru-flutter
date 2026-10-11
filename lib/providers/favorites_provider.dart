import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/sync/sync_preferences.dart';
import '../models/post.dart';

class FavoritesProvider extends ChangeNotifier {
  static const String _keyFavorites = 'flexbooru_favorites';

  List<Post> _favorites = [];
  String _persistedFavorites = '[]';
  List<Post> get favorites => _favorites;

  FavoritesProvider() {
    ready = loadFavorites();
  }

  late final Future<void> ready;

  Future<void> loadFavorites() async {
    final prefs = await SyncPreferences.getInstance();
    final jsonStr = prefs.getString(_keyFavorites);
    _favorites = [];
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        _favorites = list
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _favorites = [];
      }
    }
    _persistedFavorites = jsonEncode(
      _favorites.map((post) => post.toJson()).toList(),
    );
    notifyListeners();
  }

  bool isFavorite(Object postId, String booruId) {
    return _favorites.any((p) => p.id == postId && p.booruId == booruId);
  }

  Future<void> toggleFavorite(Post post) async {
    await ready;
    final index = _favorites.indexWhere(
      (p) => p.id == post.id && p.booruId == post.booruId,
    );
    if (index != -1) {
      _favorites.removeAt(index);
      post.isFavored = false;
    } else {
      post.isFavored = true;
      _favorites.insert(0, post);
    }
    final prefs = await SyncPreferences.getInstance();
    final json = jsonEncode(_favorites.map((p) => p.toJson()).toList());
    await prefs.setString(
      _keyFavorites,
      json,
      previousValue: _persistedFavorites,
    );
    _persistedFavorites = json;
    notifyListeners();
  }
}
