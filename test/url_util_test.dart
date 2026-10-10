import 'package:flutter_test/flutter_test.dart';
import 'package:flexbooru/core/utils/url_util.dart';
import 'package:flexbooru/models/booru_site.dart';

void main() {
  group('UrlUtil Tests', () {
    test('normalizes protocol-relative URLs (e.g. Yande.re bugfix)', () {
      expect(
        UrlUtil.normalizeUrl('//assets.yande.re/image.jpg'),
        equals('https://assets.yande.re/image.jpg'),
      );
    });

    test('normalizes relative URLs with host', () {
      expect(
        UrlUtil.normalizeUrl('/images/sample.jpg', host: 'gelbooru.com'),
        equals('https://gelbooru.com/images/sample.jpg'),
      );
    });

    test('detects video formats correctly', () {
      expect(UrlUtil.isVideo('https://danbooru.donmai.us/sample.mp4'), isTrue);
      expect(UrlUtil.isVideo('https://danbooru.donmai.us/sample.webm'), isTrue);
      expect(UrlUtil.isVideo('https://danbooru.donmai.us/sample.png'), isFalse);
    });
  });

  group('BooruSite & URI parsing tests', () {
    test('converts BooruSite to booru:// URI and parses back', () {
      final site = BooruSite(
        id: 'test_id',
        name: 'TestBooru',
        scheme: 'https',
        host: 'moe.fiepi.com',
        type: 1,
        hashSalt: 'my-salt',
      );

      final uriString = site.toBooruUri();
      expect(uriString.startsWith('booru://'), isTrue);

      final parsed = BooruSite.fromBooruUri(uriString);
      expect(parsed, isNotNull);
      expect(parsed!.name, equals('TestBooru'));
      expect(parsed.host, equals('moe.fiepi.com'));
      expect(parsed.type, equals(1));
      expect(parsed.hashSalt, equals('my-salt'));
    });
  });
}
