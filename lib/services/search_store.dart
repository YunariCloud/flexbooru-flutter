import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/search_state.dart';
import '../core/sync/sync_preferences.dart';

class SearchStore extends ChangeNotifier {
  SearchStore() {
    ready = reload();
    _subscription = SyncPreferences.remoteChanges.stream.listen((keys) {
      if (keys.contains(searchPreference) ||
          keys.contains('flex_search_history')) {
        unawaited(reload());
      }
    });
  }
  late final Future<void> ready;
  StreamSubscription<Set<String>>? _subscription;
  List<SearchRecord> _records = [];
  List<String> legacyHistory = [];
  bool _disposed = false;
  // Shared queue also serializes different search pages in the same process.
  static Future<void>? _writes;
  Future<void> reload() async {
    final prefs = await SyncPreferences.getInstance();
    final records = SearchRecord.decode(prefs.getString(searchPreference));
    if (_disposed) return;
    _records = records;
    legacyHistory = prefs.getStringList('flex_search_history') ?? [];
    notifyListeners();
  }

  String draft(String site) =>
      _records
          .where((r) => r.kind == 'draft' && r.siteId == site)
          .firstOrNull
          ?.query ??
      '';
  List<SearchRecord> presets(String site) =>
      _records.where((r) => r.kind == 'preset' && r.siteId == site).toList();
  List<SearchRecord> history(String site) =>
      (_records.where((r) => r.kind == 'history' && r.siteId == site).toList()
            ..sort((a, b) => b.used.compareTo(a.used)))
          .take(20)
          .toList();
  bool get autoSearch =>
      _records.where((r) => r.kind == 'auto').firstOrNull?.enabled ?? false;
  List<String> get engineIds => List.of(
    _records.where((r) => r.kind == 'engines').firstOrNull?.engines ??
        reverseEngineIds,
  );
  List<String> get engineOrder => List.of(
    _records.where((r) => r.kind == 'engines').firstOrNull?.order ??
        [
          ...engineIds,
          ...reverseEngineIds.where((id) => !engineIds.contains(id)),
        ],
  );

  Future<void> _update(void Function(List<SearchRecord>) change) {
    final operation = (_writes ?? Future<void>.value()).then((_) async {
      final prefs = await SyncPreferences.getInstance();
      final previous = prefs.getString(searchPreference) ?? '[]';
      final records = SearchRecord.decode(previous);
      change(records);
      await prefs.setString(
        searchPreference,
        jsonEncode(records.map((r) => r.toJson()).toList()),
        previousValue: previous,
      );
      await reload();
    });
    late final Future<void> tail;
    void release() {
      if (identical(_writes, tail)) _writes = null;
    }

    tail = operation.then<void>(
      (_) => release(),
      onError: (Object e, StackTrace s) => release(),
    );
    _writes = tail;
    return operation;
  }

  Future<void> put(SearchRecord record) => _update((records) {
    SearchRecord.fromJson(record.toJson());
    records.removeWhere((r) => r.id == record.id);
    records.add(record);
  });
  Future<void> saveDraft(String site, String query) => put(
    SearchRecord(id: 'draft:$site', kind: 'draft', siteId: site, query: query),
  );
  Future<void> setAutoSearch(bool enabled) =>
      put(SearchRecord(id: 'auto', kind: 'auto', enabled: enabled));
  Future<void> setEngines(List<String> engines, {List<String>? order}) => put(
    SearchRecord(
      id: 'engines',
      kind: 'engines',
      engines: engines,
      order:
          order ??
          [...engines, ...engineOrder.where((id) => !engines.contains(id))],
    ),
  );
  Future<void> savePreset(
    String site,
    String name,
    String query, {
    String? id,
  }) => put(
    SearchRecord(
      id:
          id ??
          'preset:${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
      kind: 'preset',
      siteId: site,
      name: name.trim(),
      query: query,
    ),
  );
  Future<void> remove(String id) =>
      _update((records) => records.removeWhere((r) => r.id == id));
  Future<void> addHistory(String site, String query) => _update((records) {
    query = query.trim();
    if (query.isEmpty) return;
    final used = max(
      DateTime.now().millisecondsSinceEpoch,
      records.fold<int>(0, (n, r) => max(n, r.used)) + 1,
    );
    records.removeWhere(
      (r) => r.kind == 'history' && r.siteId == site && r.query == query,
    );
    records.add(
      SearchRecord(
        id: searchHistoryId(site, query),
        kind: 'history',
        siteId: site,
        query: query,
        used: used,
      ),
    );
    final history =
        records.where((r) => r.kind == 'history' && r.siteId == site).toList()
          ..sort((a, b) => b.used.compareTo(a.used));
    final removeIds = history.skip(20).map((r) => r.id).toSet();
    records.removeWhere((r) => removeIds.contains(r.id));
  });
  Future<void> clearHistory(String site) => _update(
    (records) =>
        records.removeWhere((r) => r.kind == 'history' && r.siteId == site),
  );
  Future<void> clearLegacy() async {
    final prefs = await SyncPreferences.getInstance();
    await prefs.remove('flex_search_history');
    await reload();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
