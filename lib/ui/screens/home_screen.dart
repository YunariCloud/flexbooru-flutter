import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/booru_api_exception.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/sync/sync_preferences.dart';
import '../../core/sync/sync_state.dart';
import '../../models/booru_site.dart';
import '../../models/browse_session.dart';
import '../../providers/blacklist_provider.dart';
import '../../providers/booru_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/update_service.dart';
import '../../services/app_update_manager.dart';
import '../widgets/post_grid_item.dart';
import '../widgets/update_dialog.dart';
import 'about_screen.dart';
import 'booru_manage_screen.dart';
import 'booru_edit_screen.dart';
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
  BlacklistProvider? _blacklistProvider;
  StreamSubscription<Set<String>>? _syncSubscription;
  UpdateDownloadState? _updateState;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    AppUpdateManager.instance.addListener(_onUpdateDownloadChanged);
    _syncSubscription = SyncPreferences.appliedChanges.stream.listen(_onSynced);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initLoad();
    });
  }

  @override
  void dispose() {
    _blacklistProvider?.removeListener(_syncBlacklist);
    _syncSubscription?.cancel();
    AppUpdateManager.instance.removeListener(_onUpdateDownloadChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      final booruProv = context.read<BooruProvider>();
      final postsProv = context.read<PostsProvider>();
      if (booruProv.activeSite != null &&
          !postsProv.isLoadingMore &&
          postsProv.hasMore) {
        if (_isPopular) {
          postsProv.fetchPopular(
            site: booruProv.activeSite!,
            scale: _popularScale,
            refresh: false,
          );
        } else {
          postsProv.fetchPosts(site: booruProv.activeSite!);
        }
      }
    }
  }

  Future<void> _initLoad() async {
    final booruProv = context.read<BooruProvider>();
    final postsProv = context.read<PostsProvider>();
    final settingsProv = context.read<SettingsProvider>();
    final blacklistProv = context.read<BlacklistProvider>();

    await Future.wait([
      booruProv.ready,
      settingsProv.ready,
      blacklistProv.ready,
    ]);
    if (!mounted) return;
    _blacklistProvider = blacklistProv;
    blacklistProv.addListener(_syncBlacklist);

    postsProv.setSafeMode(settingsProv.defaultSafeMode);
    postsProv.setBlacklist(blacklistProv.blacklist);

    if (booruProv.activeSite != null) {
      postsProv.fetchPosts(site: booruProv.activeSite!, refresh: true);
    }
    _checkUpdateQuietly();
  }

  void _syncBlacklist() {
    if (mounted) {
      context.read<PostsProvider>().setBlacklist(_blacklistProvider!.blacklist);
    }
  }

  void _onSynced(Set<String> keys) {
    if (!mounted) return;
    final posts = context.read<PostsProvider>();
    if (keys.contains('flex_safe_mode')) {
      posts.setSafeMode(context.read<SettingsProvider>().defaultSafeMode);
    }
    if (!keys.any(
      {
        sitesPreference,
        'flexbooru_active_site_id',
        'flex_safe_mode',
        'flex_user_agent',
      }.contains,
    )) {
      return;
    }
    final site = context.read<BooruProvider>().activeSite;
    if (site == null) {
      posts.clear();
    } else if (_isPopular) {
      posts.fetchPopular(site: site, scale: _popularScale, refresh: true);
    } else {
      posts.fetchPosts(site: site, query: posts.currentQuery, refresh: true);
    }
  }

  void _checkUpdateQuietly() async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final settingsProv = context.read<SettingsProvider>();
      if (!settingsProv.autoCheckUpdate) return;
      final info = await UpdateService().checkUpdate();
      if (!mounted) return;
      if (info.hasUpdate) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.newVersionAvailable}: v${info.latestVersion}',
            ),
            action: SnackBarAction(
              label: l10n.viewUpdate,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => UpdateDialog(updateInfo: info),
                );
              },
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (_) {
      // Quiet background check, errors are ignored
    }
  }

  void _onUpdateDownloadChanged() {
    final manager = AppUpdateManager.instance;
    if (!mounted || _updateState == manager.state || manager.info == null) {
      return;
    }
    _updateState = manager.state;
    final l10n = context.l10n;
    final message = switch (manager.state) {
      UpdateDownloadState.downloading => l10n.downloadingUpdate,
      UpdateDownloadState.ready => l10n.updateReady,
      UpdateDownloadState.failed => l10n.updateDownloadFailed,
      _ => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message: v${manager.info!.latestVersion}'),
        action: SnackBarAction(
          label: l10n.viewUpdate,
          onPressed: () => showDialog(
            context: context,
            builder: (_) => UpdateDialog(updateInfo: manager.info!),
          ),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _onRefresh() async {
    final booruProv = context.read<BooruProvider>();
    final postsProv = context.read<PostsProvider>();
    if (booruProv.activeSite == null) return;

    if (_isPopular) {
      await postsProv.fetchPopular(
        site: booruProv.activeSite!,
        scale: _popularScale,
        refresh: true,
      );
    } else {
      await postsProv.fetchPosts(site: booruProv.activeSite!, refresh: true);
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: settingsProv.useGradient
                        ? settingsProv.primaryGradient
                        : null,
                    color: settingsProv.useGradient
                        ? null
                        : theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: settingsProv.useGradient
                          ? Colors.white.withValues(alpha: 0.3)
                          : theme.colorScheme.primary.withValues(alpha: 0.25),
                    ),
                    boxShadow: settingsProv.useGradient
                        ? [
                            BoxShadow(
                              color: settingsProv.accentColor.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          activeSite.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: settingsProv.useGradient
                                ? Colors.white
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                        color: settingsProv.useGradient
                            ? Colors.white
                            : theme.colorScheme.primary,
                      ),
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
            onPressed: () async {
              if (activeSite != null) {
                await Navigator.of(context).push<void>(
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
              PopupMenuItem(value: '1d', child: Text(l10n.popularToday)),
              PopupMenuItem(value: '1w', child: Text(l10n.popularWeek)),
              PopupMenuItem(value: '1m', child: Text(l10n.popularMonth)),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(context, activeSite, l10n),
      body: activeSite == null
          ? Center(child: Text(l10n.selectBooru))
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: _buildBody(postsProv, activeSite, columns, l10n),
            ),
      floatingActionButton: Container(
        decoration: settingsProv.useGradient
            ? BoxDecoration(
                gradient: settingsProv.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: settingsProv.accentColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              )
            : null,
        child: FloatingActionButton.small(
          backgroundColor: settingsProv.useGradient ? Colors.transparent : null,
          elevation: settingsProv.useGradient ? 0 : null,
          heroTag: 'scroll_to_top',
          tooltip: l10n.scrollToTop,
          child: Icon(
            Icons.arrow_upward,
            color: settingsProv.useGradient ? Colors.white : null,
          ),
          onPressed: () {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    PostsProvider postsProv,
    BooruSite site,
    int columns,
    AppLocalizations l10n,
  ) {
    if ((postsProv.isLoading || postsProv.isLoadingMore) &&
        postsProv.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (postsProv.errorMessage != null && postsProv.posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.failedToLoad,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.networkError(postsProv.failure!),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
              if (postsProv.failure?.kind == BooruApiError.authentication)
                TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BooruEditScreen(existingSite: site),
                      ),
                    );
                    if (mounted) _onRefresh();
                  },
                  child: Text(l10n.configureCredentials),
                ),
              if (postsProv.failure?.kind == BooruApiError.challenge)
                TextButton(
                  onPressed: () async {
                    await context.read<SettingsProvider>().setUserAgent(
                      AppConstants.defaultUserAgent,
                    );
                    if (mounted) _onRefresh();
                  },
                  child: Text(l10n.resetDefault),
                ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(site.websiteUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(l10n.openSiteInBrowser),
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
            const Icon(
              Icons.image_not_supported_outlined,
              size: 56,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noPostsFound,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (postsProv.safeMode)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noSafePostsHint, textAlign: TextAlign.center),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: postsProv.hasMore
                  ? () => _isPopular
                        ? postsProv.fetchPopular(
                            site: site,
                            scale: _popularScale,
                          )
                        : postsProv.fetchPosts(site: site)
                  : _onRefresh,
              child: Text(postsProv.hasMore ? l10n.loadMore : l10n.refresh),
            ),
          ],
        ),
      );
    }

    final showLoadingMore = postsProv.isLoadingMore;
    final showLoadMoreError =
        postsProv.failure != null && postsProv.posts.isNotEmpty;
    final extraItemCount = showLoadingMore || showLoadMoreError ? 1 : 0;

    return MasonryGridView.count(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      crossAxisCount: columns,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      itemCount: postsProv.posts.length + extraItemCount,
      itemBuilder: (context, index) {
        if (index == postsProv.posts.length) {
          if (showLoadingMore) {
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
          if (showLoadMoreError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final booruProv = context.read<BooruProvider>();
                    if (booruProv.activeSite != null) {
                      if (_isPopular) {
                        postsProv.fetchPopular(
                          site: booruProv.activeSite!,
                          scale: _popularScale,
                          refresh: false,
                        );
                      } else {
                        postsProv.fetchPosts(site: booruProv.activeSite!);
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.retry),
                ),
              ),
            );
          }
        }
        final post = postsProv.posts[index];
        return PostGridItem(
          post: post,
          site: site,
          sourceBuilder: () {
            final popular = _isPopular;
            final scale = _popularScale;
            return BrowseSource.posts(
              postsProv,
              site,
              () => popular
                  ? postsProv.fetchPopular(site: site, scale: scale)
                  : postsProv.fetchPosts(site: site),
            );
          },
        );
      },
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    BooruSite? activeSite,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final booruProv = context.watch<BooruProvider>();
    final settingsProv = context.watch<SettingsProvider>();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: settingsProv.useGradient
                  ? settingsProv.primaryGradient
                  : null,
              color: settingsProv.useGradient
                  ? null
                  : theme.colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: settingsProv.useGradient
                        ? Colors.white
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  activeSite != null
                      ? '${activeSite.name} (${activeSite.typeName})'
                      : l10n.selectBooru,
                  style: TextStyle(
                    color: settingsProv.useGradient
                        ? Colors.white.withValues(alpha: 0.85)
                        : theme.colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.8,
                          ),
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
            onTap: () async {
              Navigator.pop(context);
              if (activeSite != null) {
                final selected = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => PoolsScreen(site: activeSite),
                  ),
                );
                if (selected == true && mounted) {
                  setState(() => _isPopular = false);
                }
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
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
            },
          ),
        ],
      ),
    );
  }

  void _showSitePicker(
    BuildContext context,
    BooruProvider booruProv,
    AppLocalizations l10n,
  ) {
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
                    Text(
                      l10n.switchBooruSite,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.settings, size: 18),
                      label: Text(l10n.manageBoorus),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BooruManageScreen(),
                          ),
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
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        site.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text('${site.host} (${site.typeName})'),
                      trailing: isSelected
                          ? Chip(
                              label: Text(
                                l10n.activeSite,
                                style: const TextStyle(fontSize: 11),
                              ),
                            )
                          : null,
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
