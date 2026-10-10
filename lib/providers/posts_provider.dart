import 'package:flutter/foundation.dart';
import '../models/booru_site.dart';
import '../models/post.dart';
import '../services/booru_service.dart';

class PostsProvider extends ChangeNotifier {
  final BooruService _booruService = BooruService();

  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _currentPage = 1;
  String _currentQuery = '';
  bool _safeMode = false;
  List<String> _blacklist = [];

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  String get currentQuery => _currentQuery;
  bool get safeMode => _safeMode;

  void setSafeMode(bool val) {
    if (_safeMode != val) {
      _safeMode = val;
      notifyListeners();
    }
  }

  void setBlacklist(List<String> list) {
    _blacklist = list;
  }

  Future<void> fetchPosts({
    required BooruSite site,
    String query = '',
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _errorMessage = null;
      _isLoading = true;
      _posts = [];
      _currentQuery = query;
      notifyListeners();
    } else {
      if (_isLoading || _isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final fetched = await _booruService.getPosts(
        site: site,
        page: _currentPage,
        limit: 20,
        query: _currentQuery,
        safeMode: _safeMode,
      );

      // Filter against user's blacklist (client-side safeguard)
      final activeBlacklist = [..._blacklist, ...site.blacklists]
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toSet();

      final filtered = fetched.where((post) {
        if (_safeMode && !post.isSafe) return false;
        if (activeBlacklist.isNotEmpty) {
          final postTags = post.tags.map((t) => t.name.toLowerCase()).toSet();
          for (final b in activeBlacklist) {
            if (postTags.contains(b)) return false;
          }
        }
        return true;
      }).toList();

      if (refresh) {
        _posts = filtered;
      } else {
        // Prevent duplicate posts
        final existingIds = _posts.map((p) => p.id).toSet();
        for (final p in filtered) {
          if (!existingIds.contains(p.id)) {
            _posts.add(p);
            existingIds.add(p.id);
          }
        }
      }

      if (fetched.length < 10) {
        _hasMore = false;
      } else {
        _currentPage++;
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (refresh) {
        _posts = [];
      }
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchPopular({
    required BooruSite site,
    String scale = '1d',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _posts = [];
    _hasMore = false;
    notifyListeners();

    try {
      final fetched = await _booruService.getPopular(site: site, scale: scale);
      _posts = fetched;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
