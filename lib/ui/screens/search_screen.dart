import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/booru_site.dart';
import '../../models/browse_session.dart';
import '../../models/search_state.dart';
import '../../models/tag.dart';
import '../../providers/blacklist_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/booru_service.dart';
import '../../services/search_store.dart';
import '../widgets/post_grid_item.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.site,
    this.initialQuery,
    this.executeInitially = false,
    this.safeMode,
  });
  final BooruSite site;
  final String? initialQuery;
  final bool executeInitially;
  final bool? safeMode;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _booruService = BooruService();
  final _store = SearchStore();
  final _posts = PostsProvider();
  final _scroll = ScrollController();
  Timer? _debounce, _draftTimer, _autoTimer;
  int _suggestionGeneration = 0;
  List<Tag> _suggestions = [];
  bool _isLoadingSuggestions = false, _ready = false, _restoring = false;
  bool _showResults = false, _expanded = true, _dirty = false;
  String _executedQuery = '';
  String _observedText = '';
  BlacklistProvider? _blacklist;
  String t(String zh, String en) => context.l10n.isZh ? zh : en;

  @override
  void initState() {
    super.initState();
    try {
      _posts.setSafeMode(
        widget.safeMode ?? context.read<PostsProvider>().safeMode,
      );
    } on ProviderNotFoundException {
      _posts.setSafeMode(widget.safeMode ?? true);
    }
    try {
      _blacklist = context.read<BlacklistProvider>();
      _posts.setBlacklist(_blacklist!.blacklist);
      _blacklist!.addListener(_syncBlacklist);
    } on ProviderNotFoundException {
      /* Standalone search. */
    }
    _controller.addListener(_onTextChanged);
    _store.addListener(_storeChanged);
    _posts.addListener(_postsChanged);
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 500) _loadMore();
    });
    _restore();
  }

  Future<void> _restore() async {
    await _store.ready;
    if (!mounted) return;
    _restoring = true;
    _controller.text = widget.initialQuery ?? _store.draft(widget.site.id);
    _observedText = _controller.text;
    _restoring = false;
    setState(() => _ready = true);
    if (widget.executeInitially) _executeSearch(_controller.text);
  }

  void _storeChanged() {
    if (mounted) setState(() {});
  }

  void _postsChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _showResults &&
          _posts.failure == null &&
          _scroll.hasClients &&
          _scroll.position.maxScrollExtent == 0) {
        _loadMore();
      }
    });
  }

  void _syncBlacklist() => _posts.setBlacklist(_blacklist!.blacklist);
  @override
  void dispose() {
    _debounce?.cancel();
    _draftTimer?.cancel();
    _autoTimer?.cancel();
    if (_ready && _dirty) {
      unawaited(_saveDraft(_controller.text));
    }
    _suggestionGeneration++;
    _blacklist?.removeListener(_syncBlacklist);
    _store.removeListener(_storeChanged);
    _posts.removeListener(_postsChanged);
    _store.dispose();
    _posts.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _saveDraft(String query) async {
    try {
      await _store.saveDraft(widget.site.id, query);
      if (mounted && _controller.text == query) _dirty = false;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t('保存搜索条件失败', 'Could not save search conditions')}: $error',
            ),
          ),
        );
      }
    }
  }

  void _onTextChanged() {
    if (_restoring || _controller.text == _observedText) return;
    _observedText = _controller.text;
    _debounce?.cancel();
    _draftTimer?.cancel();
    _autoTimer?.cancel();
    final generation = ++_suggestionGeneration;
    final tokens = queryTokens(_controller.text);
    final token = tokens.lastOrNull ?? '';
    final suggest =
        token.isNotEmpty &&
        !token.contains(':') &&
        !_controller.text.endsWith(' ');
    _dirty = true;
    setState(() {
      _suggestions = [];
      _isLoadingSuggestions = suggest;
    });
    if (_ready) {
      final query = _controller.text;
      _draftTimer = Timer(
        const Duration(milliseconds: 600),
        () => unawaited(_saveDraft(query)),
      );
    }
    if (!suggest) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final list = await _booruService.getTagSuggestions(
          site: widget.site,
          query: token.startsWith('-') ? token.substring(1) : token,
        );
        if (mounted && generation == _suggestionGeneration) {
          setState(() {
            _suggestions = list;
            _isLoadingSuggestions = false;
          });
        }
      } catch (_) {
        if (mounted && generation == _suggestionGeneration) {
          setState(() => _isLoadingSuggestions = false);
        }
      }
    });
  }

  void _addTag(String name) {
    final tokens = queryTokens(_controller.text);
    final exclude =
        tokens.isNotEmpty &&
        tokens.last.startsWith('-') &&
        !_controller.text.endsWith(' ');
    if (tokens.isNotEmpty &&
        !tokens.last.contains(':') &&
        !_controller.text.endsWith(' ')) {
      tokens.removeLast();
    }
    final selected = exclude ? '-$name' : name;
    if (!tokens.contains(selected)) tokens.add(selected);
    _controller.text = '${tokens.join(' ')} ';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  void _fill(String query, {bool quick = false}) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    if (quick && _store.autoSearch) {
      _autoTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) _executeSearch(_controller.text);
      });
    }
  }

  void _executeSearch(String query) {
    if (!_ready) return;
    query = query.trim();
    _restoring = true;
    _controller.text = query;
    _observedText = query;
    _restoring = false;
    _dirty = true;
    _autoTimer?.cancel();
    _debounce?.cancel();
    _draftTimer?.cancel();
    _suggestionGeneration++;
    FocusScope.of(context).unfocus();
    setState(() {
      _executedQuery = query;
      _showResults = true;
      _expanded = false;
      _suggestions = [];
      _isLoadingSuggestions = false;
    });
    unawaited(_saveExecuted(query));
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(
      _posts.fetchPosts(site: widget.site, query: query, refresh: true),
    );
  }

  Future<void> _loadMore() async {
    if (_showResults &&
        !_posts.isLoading &&
        !_posts.isLoadingMore &&
        _posts.hasMore) {
      await _posts.fetchPosts(site: widget.site);
    }
  }

  Future<void> _saveExecuted(String query) async {
    try {
      await _store.recordSearch(widget.site.id, query);
      if (mounted && _controller.text == query) _dirty = false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                '搜索记录保存失败，请重试。',
                'Could not save search records. Please retry.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _editPreset({
    SearchRecord? preset,
    bool replaceQuery = false,
  }) async {
    final name = TextEditingController(text: preset?.name ?? '');
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            t(
              preset == null ? '保存预设' : '修改预设',
              preset == null ? 'Save preset' : 'Edit preset',
            ),
          ),
          content: TextField(
            controller: name,
            maxLength: 100,
            autofocus: true,
            decoration: InputDecoration(labelText: t('预设名称', 'Preset name')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, name.text.trim());
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      );
      if (result != null) {
        await _store.savePreset(
          widget.site.id,
          result,
          preset != null && !replaceQuery
              ? preset.query
              : _controller.text.trim(),
          id: preset?.id,
        );
      }
    } finally {
      name.dispose();
    }
  }

  bool get _advanced =>
      widget.site.type == BooruType.danbooru &&
      !RegExp(
        r'(^|\.)(e621|e926)\.net$',
        caseSensitive: false,
      ).hasMatch(widget.site.host);
  Widget _panel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_advanced) ...[
        for (final group in ['order', 'rating', 'age'])
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, right: 4),
                  child: Text(switch (group) {
                    'order' => t('排序', 'Order'),
                    'rating' => t('分级', 'Rating'),
                    _ => t('时间', 'Time'),
                  }),
                ),
                ...searchFilters
                    .where((f) => f.group == group)
                    .map(
                      (filter) => FilterChip(
                        label: Text(context.l10n.isZh ? filter.zh : filter.en),
                        selected: filterSelected(_controller.text, filter),
                        onSelected: (_) => _fill(
                          toggleSearchFilter(_controller.text, filter),
                          quick: true,
                        ),
                      ),
                    ),
              ],
            ),
          ),
      ],
      SwitchListTile(
        dense: true,
        title: Text(t('快捷条件自动搜索', 'Auto-search quick filters')),
        value: _store.autoSearch,
        onChanged: (value) {
          _autoTimer?.cancel();
          unawaited(_store.setAutoSearch(value));
        },
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: () => _editPreset(),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(t('保存当前预设', 'Save current preset')),
            ),
            TextButton(
              onPressed: () => _fill(''),
              child: Text(t('清空条件', 'Clear conditions')),
            ),
          ],
        ),
      ),
      ..._store
          .presets(widget.site.id)
          .map(
            (preset) => ListTile(
              dense: true,
              leading: const Icon(Icons.bookmark_outline),
              title: Text(
                preset.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                preset.query,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _fill(preset.query, quick: true),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _editPreset(preset: preset);
                    case 'update':
                      _editPreset(preset: preset, replaceQuery: true);
                    case 'delete':
                      unawaited(_store.remove(preset.id));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(t('重命名', 'Rename')),
                  ),
                  PopupMenuItem(
                    value: 'update',
                    child: Text(t('更新为当前条件', 'Replace with current query')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(context.l10n.delete),
                  ),
                ],
              ),
            ),
          ),
      if (_isLoadingSuggestions) const LinearProgressIndicator(),
      ..._suggestions.map(
        (tag) => ListTile(
          dense: true,
          title: Text(tag.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${tag.categoryName} · ${tag.count}'),
          onTap: () => _addTag(tag.name),
          trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addTag(tag.name),
          ),
        ),
      ),
    ],
  );
  Widget _history() {
    final history = _store.history(widget.site.id);
    return Column(
      children: [
        ListTile(
          title: Text(
            '${context.l10n.searchHistory} · ${widget.site.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton(
            onPressed: () => _store.clearHistory(widget.site.id),
            child: Text(context.l10n.clearHistory),
          ),
        ),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.startTypingSearch),
          ),
        ...history.map(
          (entry) => ListTile(
            leading: const Icon(Icons.history),
            title: Text(
              entry.query,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _executeSearch(entry.query),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: t('回填编辑', 'Edit query'),
                  icon: const Icon(Icons.north_west),
                  onPressed: () => _fill(entry.query),
                ),
                IconButton(
                  tooltip: context.l10n.delete,
                  icon: const Icon(Icons.close),
                  onPressed: () => _store.remove(entry.id),
                ),
              ],
            ),
          ),
        ),
        if (_store.legacyHistory.isNotEmpty) ...[
          ListTile(
            title: Text(
              t('旧版历史（未分类）', 'Legacy history (unclassified)'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: TextButton(
              onPressed: _store.clearLegacy,
              child: Text(context.l10n.clearHistory),
            ),
          ),
          ..._store.legacyHistory.map(
            (query) => ListTile(
              title: Text(query, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => _executeSearch(query),
              trailing: IconButton(
                icon: const Icon(Icons.north_west),
                onPressed: () => _fill(query),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _results() {
    if (_posts.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _posts.failure?.describe(chinese: context.l10n.isZh) ??
                    context.l10n.noPostsFound,
                textAlign: TextAlign.center,
              ),
              if (_posts.safeMode)
                Text(context.l10n.noSafePostsHint, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _executeSearch(_executedQuery),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }
    int columns = 0;
    try {
      columns = context.watch<SettingsProvider>().gridColumns;
    } on ProviderNotFoundException {
      /* Adaptive grid. */
    }
    if (columns <= 0) {
      columns = MediaQuery.sizeOf(context).width > 800
          ? 5
          : MediaQuery.sizeOf(context).width > 500
          ? 3
          : 2;
    }
    return RefreshIndicator(
      onRefresh: () => _posts.fetchPosts(
        site: widget.site,
        query: _executedQuery,
        refresh: true,
      ),
      child: MasonryGridView.count(
        controller: _scroll,
        padding: const EdgeInsets.all(4),
        crossAxisCount: columns,
        itemCount: _posts.posts.length + 1,
        itemBuilder: (context, index) {
          if (index == _posts.posts.length) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: _posts.isLoadingMore
                    ? const CircularProgressIndicator()
                    : _posts.hasMore
                    ? OutlinedButton(
                        onPressed: _loadMore,
                        child: Text(
                          _posts.failure == null
                              ? context.l10n.loadMore
                              : context.l10n.retry,
                        ),
                      )
                    : Text(t('没有更多作品', 'No more posts')),
              ),
            );
          }
          return PostGridItem(
            post: _posts.posts[index],
            site: widget.site,
            sourceBuilder: () =>
                BrowseSource.posts(_posts, widget.site, _loadMore),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 0,
      title: TextField(
        controller: _controller,
        maxLength: 8192,
        autofocus: !widget.executeInitially,
        decoration: InputDecoration(
          hintText: context.l10n.searchHint(widget.site.name),
          border: InputBorder.none,
          counterText: '',
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _fill(''),
                ),
        ),
        onTap: () => setState(() => _expanded = true),
        onSubmitted: _executeSearch,
      ),
      actions: [
        IconButton(
          tooltip: context.l10n.search,
          icon: const Icon(Icons.search),
          onPressed: _ready ? () => _executeSearch(_controller.text) : null,
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, bodyBounds) => Column(
        children: [
          ListTile(
            dense: true,
            title: Text(
              _showResults
                  ? '${t('当前结果', 'Results')}: ${_executedQuery.isEmpty ? t('全部作品', 'All posts') : _executedQuery}'
                  : widget.site.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: _showResults && _controller.text.trim() != _executedQuery
                ? Text(t('条件已修改，尚未执行', 'Conditions edited, not submitted'))
                : null,
            trailing: IconButton(
              tooltip: t('搜索条件与历史', 'Conditions and history'),
              icon: Icon(_expanded ? Icons.expand_less : Icons.tune),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math
                    .min(
                      bodyBounds.maxHeight * (_showResults ? 0.4 : 0.65),
                      math.max(
                        0,
                        bodyBounds.maxHeight -
                            MediaQuery.textScalerOf(context).scale(104),
                      ),
                    )
                    .toDouble(),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_store.invalidRecords > 0)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          t(
                            '部分搜索记录异常，已备份原始内容并恢复有效记录。',
                            'Damaged search data was backed up. Valid records were recovered.',
                          ),
                        ),
                      ),
                    _panel(),
                    if (_store.invalidRecords > 0)
                      TextButton(
                        onPressed: _store.dismissRecoveryWarning,
                        child: Text(t('关闭恢复提示', 'Dismiss recovery notice')),
                      ),
                    _history(),
                  ],
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: !_ready
                ? const Center(child: CircularProgressIndicator())
                : _showResults
                ? _results()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}
