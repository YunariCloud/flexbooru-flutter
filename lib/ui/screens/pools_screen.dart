import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/booru_site.dart';
import '../../models/pool.dart';
import '../../providers/posts_provider.dart';
import '../../services/booru_service.dart';

class PoolsScreen extends StatefulWidget {
  final BooruSite site;

  const PoolsScreen({super.key, required this.site});

  @override
  State<PoolsScreen> createState() => _PoolsScreenState();
}

class _PoolsScreenState extends State<PoolsScreen> {
  final BooruService _booruService = BooruService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Pool> _pools = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchPools(refresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _fetchPools(query: _currentQuery, refresh: false);
      }
    }
  }

  void _fetchPools({String query = '', bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _pools = [];
        _currentQuery = query;
      });
    } else {
      if (_isLoading || _isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final list = await _booruService.getPools(
        site: widget.site,
        page: _page,
        query: _currentQuery,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _pools = list;
        } else {
          final existingIds = _pools.map((p) => p.id).toSet();
          for (final p in list) {
            if (!existingIds.contains(p.id)) {
              _pools.add(p);
            }
          }
        }
        _hasMore = list.isNotEmpty;
        if (_hasMore) {
          _page++;
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.poolsTitle(widget.site.name)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchPoolHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _fetchPools(refresh: true);
                        },
                      )
                    : null,
              ),
              onSubmitted: (val) => _fetchPools(query: val.trim(), refresh: true),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _pools.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text('${l10n.failedToLoad}: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _fetchPools(query: _currentQuery, refresh: true),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                )
              : _pools.isEmpty
                  ? Center(child: Text(l10n.noPoolsFound))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _pools.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _pools.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final pool = _pools[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${pool.postCount}'),
                          ),
                          title: Text(pool.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            pool.description.isNotEmpty
                                ? pool.description
                                : (pool.creatorName != null ? 'Created by ${pool.creatorName}' : 'Pool #${pool.id}'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // View posts in pool
                            final query = 'pool:${pool.id}';
                            context.read<PostsProvider>().fetchPosts(
                              site: widget.site,
                              query: query,
                              refresh: true,
                            );
                            Navigator.pop(context, true);
                          },
                        );
                      },
                    ),
    );
  }
}
