import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/booru_site.dart';
import '../../providers/blacklist_provider.dart';
import '../../providers/booru_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/post_grid_item.dart';
import 'about_screen.dart';
import 'booru_manage_screen.dart';
import 'favorites_screen.dart';
import 'pools_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'tag_blacklist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isPopular = false;
  String _popularScale = '1d';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLoad();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isPopular) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      final booruProv = context.read<BooruProvider>();
      final postsProv = context.read<PostsProvider>();
      if (booruProv.activeSite != null && !postsProv.isLoadingMore && postsProv.hasMore) {
        postsProv.fetchPosts(site: booruProv.activeSite!);
      }
    }
  }

  void _initLoad() {
    final booruProv = context.read<BooruProvider>();
    final postsProv = context.read<PostsProvider>();
    final settingsProv = context.read<SettingsProvider>();
    final blacklistProv = context.read<BlacklistProvider>();

    postsProv.setSafeMode(settingsProv.defaultSafeMode);
    postsProv.setBlacklist(blacklistProv.blacklist);

    if (booruProv.activeSite != null) {
      postsProv.fetchPosts(site: booruProv.activeSite!, refresh: true);
    }
  }

  void _onRefresh() {
    final booruProv = context.read<BooruProvider>();
    final postsProv = context.read<PostsProvider>();
    if (booruProv.activeSite == null) return;

    if (_isPopular) {
      postsProv.fetchPopular(site: booruProv.activeSite!, scale: _popularScale);
    } else {
      postsProv.fetchPosts(site: booruProv.activeSite!, refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final booruProv = context.watch<BooruProvider>();
    final postsProv = context.watch<PostsProvider>();
    final settingsProv = context.watch<SettingsProvider>();
    final activeSite = booruProv.activeSite;

    // Determine grid columns
    final screenWidth = MediaQuery.of(context).size.width;
    int columns = settingsProv.gridColumns;
    if (columns <= 0) {
      if (screenWidth > 1200) {
        columns = 5;
      } else if (screenWidth > 800) {
        columns = 4;
      } else if (screenWidth > 500) {
        columns = 3;
      } else {
        columns = 2;
      }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: activeSite == null
            ? Text(l10n.appName)
            : InkWell(
                onTap: () => _showSitePicker(context, booruProv, l10n),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          activeSite.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 22),
                    ],
                  ),
                ),
              ),
        actions: [
          // Safe mode toggle
          IconButton(
            tooltip: postsProv.safeMode ? l10n.safeModeOn : l10n.safeModeOff,
            icon: Icon(
              postsProv.safeMode ? Icons.shield : Icons.shield_outlined,
              color: postsProv.safeMode ? Colors.green : Colors.grey,
            ),
            onPressed: () {
              postsProv.setSafeMode(!postsProv.safeMode);
              _onRefresh();
            },
          ),

          // Search button
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search),
            onPressed: () {
              if (activeSite != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SearchScreen(site: activeSite),
                  ),
                );
              }
            },
          ),

          // Popular popup menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.trending_up,
              color: _isPopular ? theme.colorScheme.primary : null,
            ),
            tooltip: l10n.popularPosts,
            onSelected: (val) {
              if (val == 'posts') {
                setState(() => _isPopular = false);
                _onRefresh();
              } else {
                setState(() {
                  _isPopular = true;
                  _popularScale = val;
                });
                _onRefresh();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'posts',
                child: Row(
                  children: [
                    const Icon(Icons.feed_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.latestPosts),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: '1d',
                child: Text(l10n.popularToday),
              ),
              PopupMenuItem(
                value: '1w',
                child: Text(l10n.popularWeek),
              ),
              PopupMenuItem(
                value: '1m',
                child: Text(l10n.popularMonth),
              ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(context, activeSite, l10n),
      body: activeSite == null
          ? Center(child: Text(l10n.selectBooru))
          : RefreshIndicator(
              onRefresh: () async => _onRefresh(),
              child: _buildBody(postsProv, activeSite, columns, l10n),
            ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'scroll_to_top',
        tooltip: l10n.scrollToTop,
        child: const Icon(Icons.arrow_upward),
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        },
      ),
    );
  }

  Widget _buildBody(PostsProvider postsProv, BooruSite site, int columns, AppLocalizations l10n) {
    if (postsProv.isLoading && postsProv.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (postsProv.errorMessage != null && postsProv.posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                l10n.failedToLoad,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                postsProv.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (postsProv.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(l10n.noPostsFound, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _onRefresh, child: Text(l10n.refresh)),
          ],
        ),
      );
    }

    return MasonryGridView.count(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      crossAxisCount: columns,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      itemCount: postsProv.posts.length + (postsProv.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == postsProv.posts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        final post = postsProv.posts[index];
        return PostGridItem(post: post, site: site);
      },
    );
  }

  Widget _buildDrawer(BuildContext context, BooruSite? activeSite, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final booruProv = context.watch<BooruProvider>();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.photo_library_outlined, size: 38),
                const SizedBox(height: 8),
                Text(
                  l10n.appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  activeSite != null ? '${activeSite.name} (${activeSite.typeName})' : l10n.selectBooru,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.feed),
            title: Text(l10n.postsFeed),
            selected: !_isPopular,
            onTap: () {
              Navigator.pop(context);
              if (_isPopular) {
                setState(() => _isPopular = false);
                _onRefresh();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.whatshot),
            title: Text(l10n.popularPosts),
            selected: _isPopular,
            onTap: () {
              Navigator.pop(context);
              if (!_isPopular) {
                setState(() => _isPopular = true);
                _onRefresh();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: Text(l10n.savedFavorites),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.collections_bookmark_outlined),
            title: Text(l10n.pools),
            onTap: () {
              Navigator.pop(context);
              if (activeSite != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PoolsScreen(site: activeSite)),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(l10n.manageBoorus),
            subtitle: Text('${booruProv.sites.length} ${l10n.sitesConfigured}'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BooruManageScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: Text(l10n.tagBlacklist),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagBlacklistScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.settings),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSitePicker(BuildContext context, BooruProvider booruProv, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.switchBooruSite, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      icon: const Icon(Icons.settings, size: 18),
                      label: Text(l10n.manageBoorus),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BooruManageScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: booruProv.sites.length,
                  itemBuilder: (context, index) {
                    final site = booruProv.sites[index];
                    final isSelected = site.id == booruProv.activeSite?.id;
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                      ),
                      title: Text(site.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text('${site.host} (${site.typeName})'),
                      trailing: isSelected ? Chip(label: Text(l10n.activeSite, style: const TextStyle(fontSize: 11))) : null,
                      onTap: () {
                        booruProv.setActiveSite(site);
                        Navigator.pop(ctx);
                        _onRefresh();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
