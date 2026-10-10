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

  List<Pool> _pools = [];
  bool _isLoading = true;
  String? _error;
  final int _page = 1;

  @override
  void initState() {
    super.initState();
    _fetchPools();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchPools({String query = ''}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _booruService.getPools(site: widget.site, page: _page, query: query);
      setState(() {
        _pools = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
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
                          _fetchPools();
                        },
                      )
                    : null,
              ),
              onSubmitted: (val) => _fetchPools(query: val.trim()),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text('${l10n.failedToLoad}: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _fetchPools, child: Text(l10n.retry)),
                    ],
                  ),
                )
              : _pools.isEmpty
                  ? Center(child: Text(l10n.noPoolsFound))
                  : ListView.builder(
                      itemCount: _pools.length,
                      itemBuilder: (context, index) {
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
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
    );
  }
}
