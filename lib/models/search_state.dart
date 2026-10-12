import 'dart:convert';
import 'package:crypto/crypto.dart';

String searchHistoryId(String site, String query) =>
    'history:$site:${sha256.convert(utf8.encode(query))}';

const searchPreference = 'flex_search_state_v2';
const reverseEngineIds = [
  'google',
  'bing',
  'yandex',
  'tineye',
  'saucenao',
  'iqdb',
];

class SearchRecord {
  const SearchRecord({
    required this.id,
    required this.kind,
    this.siteId = '',
    this.query = '',
    this.name = '',
    this.used = 0,
    this.enabled,
    this.engines,
    this.order,
  });
  final String id, kind, siteId, query, name;
  final int used;
  final bool? enabled;
  final List<String>? engines, order;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'siteId': siteId,
    'query': query,
    'name': name,
    'used': used,
    if (enabled != null) 'enabled': enabled,
    if (engines != null) 'engines': engines,
    if (order != null) 'order': order,
  };
  factory SearchRecord.fromJson(Map<String, dynamic> json) {
    final record = SearchRecord(
      id: json['id'] as String,
      kind: json['kind'] as String,
      siteId: json['siteId'] as String? ?? '',
      query: json['query'] as String? ?? '',
      name: json['name'] as String? ?? '',
      used: json['used'] as int? ?? 0,
      enabled: json['enabled'] as bool?,
      engines: (json['engines'] as List?)?.cast<String>(),
      order: (json['order'] as List?)?.cast<String>(),
    );
    if (!{
          'draft',
          'history',
          'preset',
          'auto',
          'engines',
        }.contains(record.kind) ||
        record.id.isEmpty ||
        record.id.length > 1024 ||
        record.siteId.length > 128 ||
        record.query.length > 8192 ||
        record.name.length > 100 ||
        record.used < 0 ||
        (record.kind == 'draft' && record.id != 'draft:${record.siteId}') ||
        (record.kind == 'history' &&
            record.id != searchHistoryId(record.siteId, record.query)) ||
        (record.kind == 'preset' &&
            (!record.id.startsWith('preset:') || record.name.trim().isEmpty)) ||
        ({'draft', 'history', 'preset'}.contains(record.kind) &&
            record.siteId.isEmpty) ||
        (record.kind == 'auto' &&
            (record.id != 'auto' || record.enabled == null)) ||
        (record.kind == 'engines' &&
            (record.id != 'engines' ||
                record.engines == null ||
                record.engines!.isEmpty ||
                record.engines!.toSet().length != record.engines!.length ||
                !record.engines!.every(reverseEngineIds.contains)))) {
      throw const FormatException('Invalid search record');
    }
    if (record.order != null &&
        (record.kind != 'engines' ||
            record.order!.length != reverseEngineIds.length ||
            record.order!.toSet().length != reverseEngineIds.length ||
            !record.order!.every(reverseEngineIds.contains))) {
      throw const FormatException('Invalid engine order');
    }
    if (json.keys.any((k) => !record.toJson().containsKey(k))) {
      throw const FormatException('Unexpected search field');
    }
    return record;
  }
  static List<SearchRecord> decode(String? value) => value == null
      ? []
      : (jsonDecode(value) as List)
            .map(
              (v) => SearchRecord.fromJson((v as Map).cast<String, dynamic>()),
            )
            .toList();
}

class SearchFilter {
  const SearchFilter(this.group, this.value, this.zh, this.en);
  final String group, value, zh, en;
  String get token => '$group:$value';
}

const searchFilters = [
  SearchFilter('order', 'favcount', '收藏', 'Favorites'),
  SearchFilter('order', 'score', '评分', 'Score'),
  SearchFilter('order', 'rank', '热门', 'Popular'),
  SearchFilter('order', 'id_desc', '最新', 'Newest'),
  SearchFilter('order', 'id_asc', '最早', 'Oldest'),
  SearchFilter('order', 'random', '随机', 'Random'),
  SearchFilter('order', 'comment_bumped', '评论', 'Comments'),
  SearchFilter('order', 'mpixels', '高清', 'Resolution'),
  SearchFilter('rating', 'general', '全年龄', 'General'),
  SearchFilter('rating', 'sensitive', '敏感', 'Sensitive'),
  SearchFilter('rating', 'questionable', '存疑', 'Questionable'),
  SearchFilter('rating', 'explicit', '限制级', 'Explicit'),
  SearchFilter('age', '<1d', '1天内', '1 day'),
  SearchFilter('age', '<1w', '1周内', '1 week'),
  SearchFilter('age', '<1m', '1月内', '1 month'),
  SearchFilter('age', '<1y', '1年内', '1 year'),
];

/// Preserve quoted expressions and escaped quotes instead of splitting on spaces.
List<String> queryTokens(String query) {
  final tokens = <String>[];
  var start = -1;
  String? quote;
  var escaped = false;
  for (var i = 0; i < query.length; i++) {
    final char = query[i];
    if (start < 0 && char.trim().isEmpty) continue;
    if (start < 0) start = i;
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == r'\') {
      escaped = true;
      continue;
    }
    if (quote != null) {
      if (char == quote) quote = null;
      continue;
    }
    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }
    if (char.trim().isEmpty) {
      tokens.add(query.substring(start, i));
      start = -1;
    }
  }
  if (start >= 0) tokens.add(query.substring(start));
  return tokens;
}

String _canonical(String token) {
  final lower = token.toLowerCase();
  return switch (lower) {
    'rating:g' => 'rating:general',
    'rating:s' => 'rating:sensitive',
    'rating:q' => 'rating:questionable',
    'rating:e' => 'rating:explicit',
    _ => lower,
  };
}

bool filterSelected(String query, SearchFilter filter) =>
    queryTokens(query).any((token) => _canonical(token) == filter.token);
String toggleSearchFilter(String query, SearchFilter filter) {
  final tokens = queryTokens(query);
  final selected = filterSelected(query, filter);
  final pattern = RegExp('^-?${filter.group}:', caseSensitive: false);
  final next = tokens.where((token) => !pattern.hasMatch(token)).toList();
  if (!selected) next.add(filter.token);
  return next.join(' ');
}
