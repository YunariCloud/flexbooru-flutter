import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'booru_site.dart';
import 'post.dart';
import '../providers/posts_provider.dart';

class GalleryEntry {
  const GalleryEntry(this.post, this.site);
  final Post post;
  final BooruSite? site;
  String get identity => '${post.booruId}:${post.id}';
}

class BrowseSource extends ChangeNotifier {
  BrowseSource.fixed(List<GalleryEntry> entries) : _entries = List.of(entries);
  BrowseSource.posts(
    PostsProvider provider,
    BooruSite site,
    Future<void> Function() loadMore,
  ) : _entries = provider.posts.map((p) => GalleryEntry(p, site)).toList(),
      _provider = provider,
      _site = site,
      _loadMore = loadMore,
      _generation = provider.sessionGeneration {
    provider.addListener(_changed);
  }
  final List<GalleryEntry> _entries;
  PostsProvider? _provider;
  BooruSite? _site;
  Future<void> Function()? _loadMore;
  int? _generation;
  List<GalleryEntry> get entries => UnmodifiableListView(_entries);
  bool? get safeMode => _provider?.safeMode;
  bool get active =>
      _provider != null && _provider!.sessionGeneration == _generation;
  bool get hasMore => active && _provider!.hasMore;
  bool get loading =>
      active && (_provider!.isLoadingMore || _provider!.isLoading);
  String? get error => active ? _provider!.errorMessage : null;
  void _changed() {
    if (active) {
      // Keep opened pictures stable, appending only new pages.
      final known = _entries.map((e) => e.identity).toSet();
      for (final post in _provider!.posts) {
        final entry = GalleryEntry(post, _site);
        if (known.add(entry.identity)) _entries.add(entry);
      }
    }
    notifyListeners();
  }

  Future<void> loadNext() async {
    if (hasMore && !loading) await _loadMore!();
  }

  @override
  void dispose() {
    _provider?.removeListener(_changed);
    super.dispose();
  }
}
