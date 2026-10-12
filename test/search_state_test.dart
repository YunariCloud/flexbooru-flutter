import 'dart:convert';
import 'package:flexbooru/core/sync/sync_state.dart';
import 'package:flexbooru/models/search_state.dart';
import 'package:flexbooru/models/post.dart';
import 'package:flexbooru/services/reverse_image_search.dart';
import 'package:flexbooru/services/search_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all six engines encode arbitrary image URLs without adding credentials',
    () {
      const image = 'https://images.example/a.jpg?x=1&name=中文#fragment';
      expect(reverseImageEngines.length, 6);
      for (final engine in reverseImageEngines) {
        final url = engine.searchUrl(image);
        expect(url.scheme, 'https');
        expect(url.queryParameters[engine.parameter], image);
        expect(
          url.queryParameters.keys,
          unorderedEquals([engine.parameter, ...engine.extra.keys]),
        );
      }
    },
  );
  test('video search uses a static preview, rejecting non-web URLs', () {
    final post = Post(
      id: 1,
      booruId: 'a',
      width: 10,
      height: 10,
      rating: 'g',
      previewUrl: 'https://example/a.jpg',
      sampleUrl: 'https://example/a.mp4',
      originUrl: 'https://example/a.mp4',
      tags: [],
      tagString: '',
    );
    expect(reverseImageUrl(post), 'https://example/a.jpg');
    expect(reverseImageUrl(post.copyWith(previewUrl: 'blob:abc')), isNull);
  });
  test(
    'filter groups replace duplicates and aliases without changing quoted or excluded tags',
    () {
      final rating = searchFilters.firstWhere(
        (f) => f.token == 'rating:general',
      );
      final order = searchFilters.firstWhere((f) => f.token == 'order:score');
      expect(
        toggleSearchFilter(
          'solo -cat source:"two words" order:rank order:random',
          order,
        ),
        'solo -cat source:"two words" order:score',
      );
      expect(filterSelected('solo rating:G', rating), true);
      expect(toggleSearchFilter('solo rating:g', rating), 'solo');
      expect(
        toggleSearchFilter(
          '-cat -rating:e source:"a \\"quoted\\" word"',
          rating,
        ),
        '-cat source:"a \\"quoted\\" word" rating:general',
      );
      expect(searchFilters.where((f) => f.group == 'order').length, 8);
      expect(searchFilters.where((f) => f.group == 'rating').length, 4);
      expect(searchFilters.where((f) => f.group == 'age').length, 4);
    },
  );
  test(
    'drafts, presets, history and engine preferences survive store recreation',
    () async {
      SharedPreferences.setMockInitialValues({
        'flex_search_history': ['legacy'],
      });
      final a = SearchStore();
      await a.ready;
      await a.saveDraft('siteA', 'solo order:score');
      await a.saveDraft('siteB', 'cat');
      await a.savePreset(
        'siteA',
        'My preset',
        'solo age:<1w',
        id: 'preset:one',
      );
      await a.setAutoSearch(true);
      await a.setEngines(['iqdb', 'saucenao']);
      for (var i = 0; i < 23; i++) {
        await a.addHistory('siteA', 'query_$i');
      }
      await a.addHistory('siteA', 'query_5');
      await a.addHistory('siteB', 'other');
      a.dispose();
      final b = SearchStore();
      await b.ready;
      expect(b.draft('siteA'), 'solo order:score');
      expect(b.draft('siteB'), 'cat');
      expect(b.presets('siteA').single.name, 'My preset');
      expect(b.engineIds, ['iqdb', 'saucenao']);
      expect(b.autoSearch, true);
      expect(b.history('siteA').length, 20);
      expect(b.history('siteA').first.query, 'query_5');
      expect(b.history('siteB').single.query, 'other');
      expect(b.legacyHistory, ['legacy']);
      await b.remove('preset:one');
      await b.clearHistory('siteA');
      expect(b.presets('siteA'), isEmpty);
      expect(b.history('siteA'), isEmpty);
      expect(b.history('siteB').length, 1);
      b.dispose();
    },
  );
  test(
    'search collection merges independent edits and deletion does not erase remote additions',
    () {
      String records(List<SearchRecord> r) =>
          jsonEncode(r.map((e) => e.toJson()).toList());
      const draft = SearchRecord(
        id: 'draft:site',
        kind: 'draft',
        siteId: 'site',
        query: 'old',
      );
      const one = SearchRecord(
        id: 'preset:one',
        kind: 'preset',
        siteId: 'site',
        query: 'cat',
        name: 'One',
      );
      const two = SearchRecord(
        id: 'preset:two',
        kind: 'preset',
        siteId: 'site',
        query: 'dog',
        name: 'Two',
      );
      final initial = records([draft, one]);
      final a = SyncState('a')..capture(searchPreference, initial);
      final b = SyncState('b')..merge(a.records);
      b.capture(
        searchPreference,
        records([draft, one, two]),
        previousValue: initial,
      );
      a.merge(b.records);
      a.capture(
        searchPreference,
        records([
          const SearchRecord(
            id: 'draft:site',
            kind: 'draft',
            siteId: 'site',
            query: 'new',
          ),
        ]),
        previousValue: initial,
      );
      b.merge(a.records);
      final result = SearchRecord.decode(
        b.readPreference(searchPreference) as String,
      );
      expect(
        result.map((r) => r.id),
        unorderedEquals(['draft:site', 'preset:two']),
      );
      expect(result.firstWhere((r) => r.kind == 'draft').query, 'new');
      expect(
        () => SyncEntry.fromJson({
          'key': 'search/${syncId('engines')}',
          'value': {'id': 'engines', 'kind': 'engines', 'engines': []},
          'clock': 1,
          'device': 'a',
          'deleted': false,
        }),
        throwsFormatException,
      );
    },
  );
}
