import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post.dart';

class FavoritesProvider extends ChangeNotifier {
  static const String _keyFavorites = 'flexbooru_favorites';

  List<Post> _favorites = [];
  List<Post> get favorites => _favorites;

  FavoritesProvider() {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyFavorites);
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
    notifyListeners();
  }

  bool isFavorite(Object postId, String booruId) {
    return _favorites.any((p) => p.id == postId && p.booruId == booruId);
  }

  Future<void> toggleFavorite(Post post) async {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFavorites,
      jsonEncode(_favorites.map((p) => p.toJson()).toList()),
    );
    notifyListeners();
  }
}
