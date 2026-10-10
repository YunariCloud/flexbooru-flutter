import 'package:flutter/foundation.dart';
import '../core/network/booru_api_exception.dart';
import '../models/booru_site.dart';
import '../models/post.dart';
import '../services/booru_service.dart';

class PostsProvider extends ChangeNotifier {
  final BooruService _booruService = BooruService();

  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  BooruApiException? _failure;
  String? _nextCursor;
  int _requestGeneration = 0;
  int _currentPage = 1;
  String _currentQuery = '';
  bool _safeMode = false;
  List<String> _blacklist = [];

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _failure?.describe();
  BooruApiException? get failure => _failure;
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

  int _popularPage = 1;
  String _currentPopularScale = '1d';

  Future<void> fetchPosts({
    required BooruSite site,
    String query = '',
    bool refresh = false,
  }) async {
    if (refresh) {
      _requestGeneration++;
      _nextCursor = null;
      _currentPage = 1;
      _hasMore = true;
      _failure = null;
      _isLoading = true;
      _isLoadingMore = false;
      _posts = [];
      _currentQuery = query;
      notifyListeners();
    } else {
      if (_isLoading || _isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
      _failure = null;
      notifyListeners();
    }

    final generation = _requestGeneration;

    try {
      final result = await _booruService.getPostPage(
        site: site,
        page: _currentPage,
        limit: 20,
        query: _currentQuery,
        safeMode: _safeMode,
        nextCursor: _nextCursor,
      );
      if (generation != _requestGeneration) return;
      final fetched = result.posts;

      // Filter against user's blacklist (client-side safeguard)
      final activeBlacklist = [
        ..._blacklist,
        ...site.blacklists,
      ].map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toSet();

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

      _hasMore = result.hasMore;
      _nextCursor = result.nextCursor;
      if (_hasMore) {
        _currentPage++;
      }
      _failure = null;

      // If initial fetch left too few items to fill viewport, auto-fetch more
      if (refresh && _posts.length < 12 && _hasMore) {
        _autoFetchMorePosts(site: site, generation: generation);
      }
    } catch (e) {
      if (generation != _requestGeneration) return;
      _failure = BooruApiException.from(e);
      if (refresh) {
        _posts = [];
      }
    } finally {
      if (generation == _requestGeneration) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> _autoFetchMorePosts({
    required BooruSite site,
    required int generation,
    int maxAttempts = 3,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (generation != _requestGeneration || !_hasMore || _posts.length >= 12) break;
      try {
        final result = await _booruService.getPostPage(
          site: site,
          page: _currentPage,
          limit: 20,
          query: _currentQuery,
          safeMode: _safeMode,
          nextCursor: _nextCursor,
        );
        if (generation != _requestGeneration) return;
        final fetched = result.posts;
        if (fetched.isEmpty) {
          _hasMore = false;
          notifyListeners();
          break;
        }

        final activeBlacklist = [
          ..._blacklist,
          ...site.blacklists,
        ].map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toSet();

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

        final existingIds = _posts.map((p) => p.id).toSet();
        for (final p in filtered) {
          if (!existingIds.contains(p.id)) {
            _posts.add(p);
            existingIds.add(p.id);
          }
        }

        _hasMore = result.hasMore;
        _nextCursor = result.nextCursor;
        if (_hasMore) {
          _currentPage++;
        }
        notifyListeners();
      } catch (_) {
        break;
      }
    }
  }

  Future<void> fetchPopular({
    required BooruSite site,
    String scale = '1d',
    bool refresh = false,
  }) async {
    if (refresh) {
      _requestGeneration++;
      _popularPage = 1;
      _currentPopularScale = scale;
      _hasMore = true;
      _failure = null;
      _isLoading = true;
      _isLoadingMore = false;
      _posts = [];
      notifyListeners();
    } else {
      if (_isLoading || _isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
      _failure = null;
      notifyListeners();
    }

    final generation = _requestGeneration;

    try {
      final fetched = await _booruService.getPopular(
        site: site,
        scale: _currentPopularScale,
        page: _popularPage,
        safeMode: _safeMode,
      );
      if (generation != _requestGeneration) return;

      final activeBlacklist = [
        ..._blacklist,
        ...site.blacklists,
      ].map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toSet();

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
        final existingIds = _posts.map((p) => p.id).toSet();
        for (final p in filtered) {
          if (!existingIds.contains(p.id)) {
            _posts.add(p);
            existingIds.add(p.id);
          }
        }
      }

      _hasMore = fetched.isNotEmpty;
      if (_hasMore) {
        _popularPage++;
      }
      _failure = null;
    } catch (e) {
      if (generation != _requestGeneration) return;
      _failure = BooruApiException.from(e);
      if (refresh) {
        _posts = [];
      }
    } finally {
      if (generation == _requestGeneration) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }
}
