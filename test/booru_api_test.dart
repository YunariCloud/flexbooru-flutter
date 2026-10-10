import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/core/network/api_client.dart';
import 'package:flexbooru/core/network/booru_api_exception.dart';
import 'package:flexbooru/models/booru_site.dart';
import 'package:flexbooru/models/post.dart';
import 'package:flexbooru/providers/settings_provider.dart';
import 'package:flexbooru/services/danbooru_service.dart';
import 'package:flexbooru/services/gelbooru_service.dart';
import 'package:flexbooru/services/sankaku_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) respond;
  _Adapter(this.respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

Dio _dio(ResponseBody Function(RequestOptions) respond) =>
    Dio(BaseOptions(responseType: ResponseType.plain))
      ..httpClientAdapter = _Adapter(respond);

ResponseBody _json(Object data) => ResponseBody.fromString(
  jsonEncode(data),
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

BooruSite _site(String host, int type) =>
    BooruSite(id: 'test', name: 'Test', host: host, type: type);

final _authError = isA<BooruApiException>().having(
  (e) => e.kind,
  'kind',
  BooruApiError.authentication,
);
final _responseError = isA<BooruApiException>().having(
  (e) => e.kind,
  'kind',
  BooruApiError.invalidResponse,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => ApiClient().setUserAgent(AppConstants.defaultUserAgent));

  test(
    'old saved API hosts resolve without changing custom hosts or credentials',
    () {
      final old = BooruSite.fromJson({
        'id': 'saved',
        'name': 'Sankaku',
        'host': 'capi-v2.sankakucomplex.com',
        'type': BooruType.sankaku,
        'token': 'secret',
      });
      expect(old.apiBaseUrl, 'https://sankakuapi.com');
      expect(old.token, 'secret');
      expect(
        _site('rule34.xxx', BooruType.gelbooru).apiBaseUrl,
        'https://api.rule34.xxx',
      );
      expect(
        _site('custom.example', BooruType.sankaku).apiBaseUrl,
        'https://custom.example',
      );
    },
  );

  test(
    'settings update API and image User-Agent, and migrate the old default',
    () async {
      SharedPreferences.setMockInitialValues({
        'flex_user_agent': AppConstants.legacyUserAgent,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();
      expect(settings.userAgent, AppConstants.defaultUserAgent);
      await settings.setUserAgent('TestClient/1.0');
      expect(ApiClient().dio.options.headers['User-Agent'], 'TestClient/1.0');
      expect(
        ApiClient.getImageHeaders(host: 'danbooru.donmai.us')['User-Agent'],
        'TestClient/1.0',
      );
      await settings.setUserAgent('  ');
      expect(
        ApiClient().dio.options.headers['User-Agent'],
        AppConstants.defaultUserAgent,
      );
      settings.dispose();
    },
  );

  test(
    'Rule34 uses the API host, 0-based paging and legacy safe rating',
    () async {
      final site = _site('rule34.xxx', BooruType.gelbooru)
        ..username = '123'
        ..token = 'key';
      final service = GelbooruService(
        dio: _dio((options) {
          expect(options.uri.host, 'api.rule34.xxx');
          expect(options.queryParameters['pid'], 1);
          expect(options.queryParameters['tags'], 'landscape rating:safe');
          expect(options.queryParameters['user_id'], '123');
          expect(options.queryParameters['api_key'], 'key');
          return _json([
            {
              'id': '12',
              'width': '640',
              'height': '480',
              'score': '3',
              'creator_id': '7',
              'rating': 's',
              'tags': 'landscape',
              'file_url': 'https://images.example/12.jpg',
            },
          ]);
        }),
      );
      final posts = await service.getPosts(
        site: site,
        page: 2,
        limit: 20,
        query: 'landscape',
        safeMode: true,
      );
      expect(posts.single.id, 12);
      expect(posts.single.width, 640);
      expect(posts.single.uploaderId, 7);
      expect(posts.single.isSafe, true);
    },
  );

  test(
    'authentication is sent for Gelbooru tag and comment requests',
    () async {
      final site = _site('gelbooru.com', BooruType.gelbooru)
        ..username = '123'
        ..token = 'key';
      var requests = 0;
      final service = GelbooruService(
        dio: _dio((options) {
          requests++;
          expect(options.queryParameters['user_id'], '123');
          expect(options.queryParameters['api_key'], 'key');
          return options.queryParameters['s'] == 'tag'
              ? _json([])
              : ResponseBody.fromString('<comments/>', 200);
        }),
      );
      await service.getTagSuggestions(site: site, query: 'sky');
      await service.getComments(site: site, postId: 1);
      expect(requests, 2);
    },
  );

  test('Gelbooru modern safe rating and single post envelope', () async {
    final service = GelbooruService(
      dio: _dio((options) {
        expect(options.queryParameters['tags'], 'rating:general');
        return _json({
          'post': {'id': 1, 'rating': 'general'},
        });
      }),
    );
    expect(
      (await service.getPosts(
        site: _site('gelbooru.com', BooruType.gelbooru),
        page: 1,
        limit: 20,
        safeMode: true,
      )).single.id,
      1,
    );
  });

  for (final data in <Object>[
    'Missing authentication. Go to api.rule34.xxx for more information',
    {'success': false, 'message': 'Invalid API key'},
  ]) {
    test(
      'HTTP 200 authentication error is not an empty search: $data',
      () async {
        final service = GelbooruService(dio: _dio((_) => _json(data)));
        await expectLater(
          service.getPosts(
            site: _site('rule34.xxx', BooruType.gelbooru),
            page: 1,
            limit: 20,
          ),
          throwsA(_authError),
        );
      },
    );
  }

  for (final raw in [
    '<html><body>Error</body></html>',
    '{broken',
    '{"success":false,"message":"search down"}',
    '<posts success="false" reason="search down"/>',
    '[{"unexpected":"data"}]',
    '<posts><post unexpected="data"/></posts>',
  ]) {
    test('invalid responses are reported instead of swallowed: $raw', () async {
      final service = GelbooruService(
        dio: _dio((_) => ResponseBody.fromString(raw, 200)),
      );
      await expectLater(
        service.getPosts(
          site: _site('rule34.xxx', BooruType.gelbooru),
          page: 1,
          limit: 20,
        ),
        throwsA(_responseError),
      );
    });
  }

  for (final raw in [
    '[]',
    '<posts count="0"/>',
    '{"@attributes":{"count":0}}',
  ]) {
    test('legitimate empty results remain empty: $raw', () async {
      final service = GelbooruService(
        dio: _dio((_) => ResponseBody.fromString(raw, 200)),
      );
      expect(
        await service.getPosts(
          site: _site('safebooru.org', BooruType.gelbooru),
          page: 1,
          limit: 20,
        ),
        isEmpty,
      );
    });
  }

  test('partial credentials are rejected before making a request', () async {
    final service = GelbooruService(
      dio: _dio((_) => throw StateError('must not request')),
    );
    final site = _site('gelbooru.com', BooruType.gelbooru)..username = '123';
    await expectLater(
      service.getPosts(site: site, page: 1, limit: 20),
      throwsA(_authError),
    );
  });

  test(
    'Sankaku preserves opaque IDs and uses next cursors with bearer auth',
    () async {
      final site = _site('capi-v2.sankakucomplex.com', BooruType.sankaku)
        ..token = 'access';
      var requests = 0;
      final service = SankakuService(
        dio: _dio((options) {
          requests++;
          expect(options.uri.host, 'sankakuapi.com');
          expect(options.headers['Authorization'], 'Bearer access');
          expect(options.headers.containsKey('User-Agent'), false);
          expect(options.queryParameters.containsKey('page'), false);
          if (requests == 2) {
            expect(options.queryParameters['next'], 'cursor-2');
          }
          return _json({
            'meta': {'next': requests == 1 ? 'cursor-2' : null},
            'data': [
              {
                'id': '09az5j07GMk',
                'width': 640,
                'height': 480,
                'rating': 's',
                'tags': [],
                'author': {'id': 'author-opaque', 'name': 'Example'},
                'created_at': {'s': 1700000000, 'n': 0},
              },
            ],
          });
        }),
      );
      final first = await service.getPostPage(site: site, page: 1, limit: 20);
      expect(first.posts.single.id, '09az5j07GMk');
      expect(first.posts.single.uploaderId, 'author-opaque');
      expect(
        first.posts.single.createdAt?.millisecondsSinceEpoch,
        1700000000000,
      );
      expect(first.hasMore, true);
      expect(
        Post.fromJson(first.posts.single.toJson()).id,
        first.posts.single.id,
      );
      final next = await service.getPostPage(
        site: site,
        page: 2,
        limit: 20,
        nextKey: first.nextCursor,
      );
      expect(next.hasMore, false);
    },
  );

  test('only actual Cloudflare challenges are labelled as challenges', () {
    DioException error({int status = 403, bool challenge = false}) {
      final request = RequestOptions(path: 'https://example.com/api');
      return DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: request,
          statusCode: status,
          data: '<html>Forbidden</html>',
          headers: Headers.fromMap(
            challenge
                ? {
                    'cf-mitigated': ['challenge'],
                  }
                : {},
          ),
        ),
      );
    }

    expect(BooruApiException.from(error()).kind, BooruApiError.forbidden);
    expect(
      BooruApiException.from(error(challenge: true)).kind,
      BooruApiError.challenge,
    );
    expect(
      BooruApiException.from(error(status: 401)).kind,
      BooruApiError.authentication,
    );
    expect(
      BooruApiException.from(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionTimeout,
        ),
      ).kind,
      BooruApiError.timeout,
    );
  });

  test('Danbooru database timeout 500 produces user-friendly error message', () {
    final dioError = DioException(
      requestOptions: RequestOptions(
        path: 'https://danbooru.donmai.us/posts.json',
      ),
      response: Response(
        requestOptions: RequestOptions(
          path: 'https://danbooru.donmai.us/posts.json',
        ),
        statusCode: 500,
        data:
            '{"success":false,"error":"ActiveRecord::QueryCanceled","message":"The database timed out running your query."}',
      ),
    );
    final exception = BooruApiException.from(dioError);
    expect(exception.kind, equals(BooruApiError.server));
    expect(exception.statusCode, equals(500));
    expect(exception.describe(chinese: true), contains('Danbooru 数据库查询超时'));
    expect(
      exception.describe(chinese: false),
      contains('Danbooru database query timed out'),
    );
  });

  test('DanbooruService maps timeout order tags to order:rank', () async {
    String? requestedTags;
    final service = DanbooruService(
      dio: _dio((options) {
        requestedTags = options.queryParameters['tags']?.toString();
        return _json([
          {
            'id': 1,
            'image_width': 100,
            'image_height': 100,
            'file_url': 'https://cdn.donmai.us/1.jpg',
            'tag_string': 'solo',
          }
        ]);
      }),
    );

    final site = _site('danbooru.donmai.us', BooruType.danbooru);
    await service.getPosts(site: site, page: 1, limit: 10, query: 'cat order:score');
    expect(requestedTags, equals('cat order:rank'));

    await service.getPosts(site: site, page: 1, limit: 10, query: 'order:favcount');
    expect(requestedTags, equals('order:rank'));
  });

  test('DanbooruService getPopularPosts calls explore endpoint', () async {
    String? requestedPath;
    String? requestedScale;
    final service = DanbooruService(
      dio: _dio((options) {
        requestedPath = options.path;
        requestedScale = options.queryParameters['scale']?.toString();
        return _json([
          {
            'id': 10,
            'image_width': 100,
            'image_height': 100,
            'file_url': 'https://cdn.donmai.us/10.jpg',
            'tag_string': 'solo',
          }
        ]);
      }),
    );

    final site = _site('danbooru.donmai.us', BooruType.danbooru);
    final posts = await service.getPopularPosts(site: site, scale: '1w');
    expect(posts.length, equals(1));
    expect(
      requestedPath,
      equals('https://danbooru.donmai.us/explore/posts/popular.json'),
    );
    expect(requestedScale, equals('week'));
  });

  test('DanbooruService getPopularPosts forwards page parameter', () async {
    int? requestedPage;
    final service = DanbooruService(
      dio: _dio((options) {
        requestedPage = options.queryParameters['page'] as int?;
        return _json([]);
      }),
    );

    final site = _site('danbooru.donmai.us', BooruType.danbooru);
    await service.getPopularPosts(site: site, scale: '1d', page: 3);
    expect(requestedPage, equals(3));
  });

  test('DanbooruService getPosts reports error JSON maps as BooruApiException', () async {
    final service = DanbooruService(
      dio: _dio((_) => _json({
        'success': false,
        'message': 'You cannot search for more than 2 tags.',
      })),
    );

    final site = _site('danbooru.donmai.us', BooruType.danbooru);
    expect(
      () => service.getPosts(site: site, page: 1, limit: 20),
      throwsA(isA<BooruApiException>()),
    );
  });

  test('SankakuService gracefully returns empty page when page > 1 without nextKey', () async {
    final service = SankakuService(
      dio: _dio((_) => throw StateError('must not call network')),
    );

    final site = _site('sankakuapi.com', BooruType.sankaku);
    final page = await service.getPostPage(site: site, page: 2, limit: 20, nextKey: null);
    expect(page.posts, isEmpty);
    expect(page.hasMore, false);
  });
}

