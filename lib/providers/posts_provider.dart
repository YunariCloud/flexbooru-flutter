import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../core/network/booru_api_exception.dart';
import '../models/booru_site.dart';
import '../models/post.dart';
import '../services/booru_service.dart';

class PostsProvider extends ChangeNotifier {
  final BooruService _booruService = BooruService();
  final List<Post> _loadedPosts = [];
  final Set<Object> _loadedIds = {};
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _disposed = false;
  BooruApiException? _failure;
  BooruSite? _site;
  String? _nextCursor;
  int _requestGeneration = 0;
  int _currentPage = 1;
  String _currentQuery = '';
  bool _safeMode = false;
  Set<String> _blacklist = {};
  String _currentPopularScale = '1d';

  List<Post> get posts => UnmodifiableListView(_posts);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _failure?.describe();
  BooruApiException? get failure => _failure;
  int get sessionGeneration => _requestGeneration;
  int get currentPage => _currentPage;
  String get currentQuery => _currentQuery;
  bool get safeMode => _safeMode;

  void clear() {
    _requestGeneration++;
    _site = null;
    _loadedPosts.clear();
    _loadedIds.clear();
    _posts = [];
    _failure = null;
    _isLoading = false;
    _isLoadingMore = false;
    _hasMore = false;
    notifyListeners();
  }

  void setSafeMode(bool value) {
    if (_safeMode == value) return;
    _safeMode = value;
    _filterPosts();
    notifyListeners();
  }

  void setBlacklist(List<String> list) {
    final normalized = _normalizeBlacklist(list);
    if (setEquals(_blacklist, normalized)) return;
    _blacklist = normalized;
    _filterPosts();
    notifyListeners();
  }

  Set<String> _normalizeBlacklist(Iterable<String> tags) => tags
      .map((tag) => tag.trim().toLowerCase())
      .where((tag) => tag.isNotEmpty)
      .toSet();

  void _filterPosts() {
    final blacklist = {
      ..._blacklist,
      ..._normalizeBlacklist(_site?.blacklists ?? []),
    };
    _posts = _loadedPosts.where((post) {
      if (_safeMode && !post.isSafe) return false;
      return !post.tags.any(
        (tag) => blacklist.contains(tag.name.toLowerCase()),
      );
    }).toList();
  }

  Future<void> fetchPosts({
    required BooruSite site,
    String query = '',
    bool refresh = false,
  }) => _fetch(site: site, query: query, refresh: refresh);

  Future<void> fetchPopular({
    required BooruSite site,
    String scale = '1d',
    bool refresh = false,
  }) => _fetch(site: site, scale: scale, popular: true, refresh: refresh);

  Future<void> _fetch({
    required BooruSite site,
    String query = '',
    String scale = '1d',
    bool popular = false,
    bool refresh = false,
  }) async {
    if (_disposed) return;
    if (refresh) {
      _requestGeneration++;
      _site = site;
      _nextCursor = null;
      _currentPage = 1;
      _currentQuery = query;
      _currentPopularScale = scale;
      _hasMore = true;
      _loadedPosts.clear();
      _loadedIds.clear();
      _posts = [];
      _isLoading = true;
      _isLoadingMore = false;
    } else {
      if (_isLoading || _isLoadingMore || !_hasMore) return;
      _site = site;
      _isLoadingMore = true;
    }
    _failure = null;
    final generation = _requestGeneration;
    final initialVisibleCount = _posts.length;
    notifyListeners();

    try {
      // All page requests, including viewport filling, share the loading lock.
      // Bound filtered-page scanning so a long blacklist cannot loop forever.
      for (var attempt = 0; attempt < 4; attempt++) {
        if (_disposed || generation != _requestGeneration) return;
        final requestedPage = _currentPage;
        final result = popular
            ? await _booruService.getPopularPage(
                site: site,
                scale: _currentPopularScale,
                page: requestedPage,
                safeMode: _safeMode,
                nextCursor: _nextCursor,
              )
            : await _booruService.getPostPage(
                site: site,
                page: requestedPage,
                limit: 20,
                query: _currentQuery,
                safeMode: _safeMode,
                nextCursor: _nextCursor,
              );
        if (_disposed || generation != _requestGeneration) return;

        for (final post in result.posts) {
          if (_loadedIds.add(post.id)) _loadedPosts.add(post);
        }
        _hasMore = result.hasMore;
        _nextCursor = result.nextCursor;
        _currentPage = requestedPage + 1;
        _filterPosts();
        // Render accepted results while retaining the lock for the next page.
        _isLoading = false;
        _isLoadingMore = true;
        notifyListeners();
        if (!_hasMore ||
            (_posts.length >= 12 && _posts.length > initialVisibleCount)) {
          break;
        }
      }
    } catch (error) {
      if (_disposed || generation != _requestGeneration) return;
      _failure = BooruApiException.from(error);
    } finally {
      if (!_disposed && generation == _requestGeneration) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    super.dispose();
  }
}
