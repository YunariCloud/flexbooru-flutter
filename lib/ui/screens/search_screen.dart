import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/booru_site.dart';
import '../../models/tag.dart';
import '../../providers/posts_provider.dart';
import '../../services/booru_service.dart';

class SearchScreen extends StatefulWidget {
  final BooruSite site;

  const SearchScreen({super.key, required this.site});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final BooruService _booruService = BooruService();
  Timer? _debounce;

  final List<String> _selectedTags = [];
  List<Tag> _suggestions = [];
  List<String> _history = [];
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('flex_search_history') ?? [];
    });
  }

  void _saveHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _history.remove(trimmed);
    _history.insert(0, trimmed);
    if (_history.length > 20) {
      _history = _history.sublist(0, 20);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('flex_search_history', _history);
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoadingSuggestions = true);
      try {
        final list = await _booruService.getTagSuggestions(site: widget.site, query: text);
        if (mounted) {
          setState(() {
            _suggestions = list;
            _isLoadingSuggestions = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isLoadingSuggestions = false);
        }
      }
    });
  }

  void _addTag(String tagName) {
    if (!_selectedTags.contains(tagName)) {
      setState(() {
        _selectedTags.add(tagName);
        _controller.clear();
        _suggestions = [];
      });
    }
  }

  void _executeSearch(String query) {
    _saveHistory(query);
    final postsProv = context.read<PostsProvider>();
    postsProv.fetchPosts(site: widget.site, query: query, refresh: true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDanbooru = widget.site.type == BooruType.danbooru;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint(widget.site.name),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _controller.clear(),
                  )
                : null,
          ),
          onSubmitted: (val) {
            final allQuery = [..._selectedTags, if (val.trim().isNotEmpty) val.trim()].join(' ');
            if (allQuery.isNotEmpty) {
              _executeSearch(allQuery);
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search),
            onPressed: () {
              final allQuery = [..._selectedTags, if (_controller.text.trim().isNotEmpty) _controller.text.trim()].join(' ');
              if (allQuery.isNotEmpty) {
                _executeSearch(allQuery);
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected tags row
          if (_selectedTags.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _selectedTags.map((t) {
                  return InputChip(
                    label: Text(t),
                    onDeleted: () {
                      setState(() => _selectedTags.remove(t));
                    },
                  );
                }).toList(),
              ),
            ),

          // Danbooru 2-tag limit warning hint (Bug fix explanation)
          if (isDanbooru && _selectedTags.length > 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.amber.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.danbooruLimitNotice,
                      style: const TextStyle(fontSize: 11, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),

          // Quick filter helper chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _buildQuickFilterChip('rating:general'),
                _buildQuickFilterChip('rating:questionable'),
                _buildQuickFilterChip('rating:explicit'),
                _buildQuickFilterChip('order:score'),
                _buildQuickFilterChip('order:favcount'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Suggestions or History list
          Expanded(
            child: _isLoadingSuggestions
                ? const Center(child: CircularProgressIndicator())
                : _suggestions.isNotEmpty
                    ? ListView.builder(
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final tag = _suggestions[index];
                          return ListTile(
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: tag.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(tag.name, style: TextStyle(color: tag.color, fontWeight: FontWeight.bold)),
                            subtitle: Text('${tag.categoryName} • ${tag.count}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: () => _addTag(tag.name),
                            ),
                            onTap: () {
                              final allQuery = [..._selectedTags, tag.name].join(' ');
                              _executeSearch(allQuery);
                            },
                          );
                        },
                      )
                    : _buildHistorySection(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: () => _addTag(label),
      ),
    );
  }

  Widget _buildHistorySection(AppLocalizations l10n) {
    if (_history.isEmpty) {
      return Center(
        child: Text(
          l10n.startTypingSearch,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.searchHistory, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              TextButton(
                onPressed: () async {
                  setState(() => _history.clear());
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('flex_search_history');
                },
                child: Text(l10n.clearHistory, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        ..._history.map(
          (h) => ListTile(
            leading: const Icon(Icons.history, size: 20),
            title: Text(h),
            trailing: IconButton(
              icon: const Icon(Icons.north_west, size: 16),
              onPressed: () {
                _controller.text = h;
              },
            ),
            onTap: () => _executeSearch(h),
          ),
        ),
      ],
    );
  }
}
