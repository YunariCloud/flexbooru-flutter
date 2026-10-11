import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/booru_api_exception.dart';
import '../core/utils/url_util.dart';
import '../models/booru_site.dart';
import '../models/comment.dart';
import '../models/pool.dart';
import '../models/post.dart';
import '../models/post_page.dart';
import '../models/tag.dart';

class DanbooruService {
  final Dio _dio;

  DanbooruService({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<List<Post>> getPosts({
    required BooruSite site,
    required int page,
    required int limit,
    String query = '',
    bool safeMode = false,
  }) async => (await getPostPage(
    site: site,
    page: page,
    limit: limit,
    query: query,
    safeMode: safeMode,
  )).posts;

  Future<PostPage> getPostPage({
    required BooruSite site,
    required int page,
    required int limit,
    String query = '',
    bool safeMode = false,
  }) async {
    final isE621 = site.host.contains('e621');
    final url = '${site.baseUrl}/posts.json';

    // Build tags parameter carefully to avoid Danbooru 422 limit!
    final tagList = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    // Map unindexed timeout-causing order tags on Danbooru to indexed order:rank
    if (!isE621) {
      for (int i = 0; i < tagList.length; i++) {
        if (tagList[i] == 'order:score' ||
            tagList[i] == 'order:favcount' ||
            tagList[i] == 'order:upvotes') {
          tagList[i] = 'order:rank';
        }
      }
    }

    // Check if we should append rating:g server-side
    // Danbooru anonymous allows max 2 tags.
    bool clientSideSafeFilter = false;
    if (safeMode && !tagList.any((t) => t.startsWith('rating:'))) {
      if (site.hasAuth || tagList.length < 2) {
        tagList.add('rating:g');
      } else {
        // Tag count would exceed 2, filter client-side instead of crashing with 422
        clientSideSafeFilter = true;
      }
    }

    final queryParams = <String, dynamic>{'page': page, 'limit': limit};

    if (tagList.isNotEmpty) {
      queryParams['tags'] = tagList.join(' ');
    }

    if (site.hasAuth) {
      if (site.username?.trim().isNotEmpty ?? false) {
        queryParams['login'] = site.username!.trim();
      }
      if (site.token?.trim().isNotEmpty ?? false) {
        queryParams['api_key'] = site.token!.trim();
      }
    }

    final response = await _dio.get(url, queryParameters: queryParams);
    final dynamic data = jsonDecode(response.data.toString());

    List<dynamic> list;
    if (data is Map<String, dynamic>) {
      if (isE621) {
        list = data['posts'] as List<dynamic>? ?? [];
      } else {
        if (data.containsKey('error') ||
            data['success'] == false ||
            data['success'] == 'false' ||
            data.containsKey('message')) {
          final msg = (data['error'] ?? data['message'] ?? '').toString();
          final isAuth =
              msg.toLowerCase().contains('api key') ||
              msg.toLowerCase().contains('access denied') ||
              msg.toLowerCase().contains('authentication');
          throw BooruApiException(
            isAuth
                ? BooruApiError.authentication
                : BooruApiError.invalidResponse,
            host: site.host,
            customMessageZh: msg,
            customMessageEn: msg,
          );
        }
        list = [];
      }
    } else if (data is List) {
      list = data;
    } else {
      list = [];
    }

    final posts = <Post>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final post = _parseDanbooruPost(item, site, isE621: isE621);
      if (post != null) {
        if (clientSideSafeFilter && !post.isSafe) {
          continue;
        }
        posts.add(post);
      }
    }
    return PostPage(posts: posts, hasMore: list.isNotEmpty);
  }

  Post? _parseDanbooruPost(
    Map<String, dynamic> item,
    BooruSite site, {
    bool isE621 = false,
  }) {
    final id = item['id'] as int? ?? 0;
    if (id <= 0) return null;

    final width =
        item['image_width'] as int? ?? item['file']?['width'] as int? ?? 0;
    final height =
        item['image_height'] as int? ?? item['file']?['height'] as int? ?? 0;
    final fileSize =
        item['file_size'] as int? ?? item['file']?['size'] as int? ?? 0;
    final score = item['score'] is Map
        ? (item['score']['total'] as int? ?? 0)
        : (item['score'] as int? ?? 0);
    final rating = item['rating']?.toString() ?? 's';

    String previewUrl = '';
    String sampleUrl = '';
    String originUrl = '';

    if (isE621) {
      previewUrl = item['preview']?['url']?.toString() ?? '';
      sampleUrl = item['sample']?['url']?.toString() ?? '';
      originUrl = item['file']?['url']?.toString() ?? sampleUrl;
    } else {
      previewUrl = item['preview_file_url']?.toString() ?? '';
      sampleUrl = item['large_file_url']?.toString() ?? '';
      originUrl = item['file_url']?.toString() ?? sampleUrl;
    }

    // Normalization & fallback
    previewUrl = UrlUtil.normalizeUrl(
      previewUrl,
      defaultScheme: site.scheme,
      host: site.host,
    );
    sampleUrl = UrlUtil.normalizeUrl(
      sampleUrl,
      defaultScheme: site.scheme,
      host: site.host,
    );
    originUrl = UrlUtil.normalizeUrl(
      originUrl,
      defaultScheme: site.scheme,
      host: site.host,
    );

    if (originUrl.isEmpty && sampleUrl.isNotEmpty) originUrl = sampleUrl;
    if (sampleUrl.isEmpty && originUrl.isNotEmpty) sampleUrl = originUrl;
    if (previewUrl.isEmpty && sampleUrl.isNotEmpty) previewUrl = sampleUrl;

    // Tags
    final tags = <Tag>[];
    final tagString = isE621
        ? (item['tags'] is Map
              ? (item['tags'] as Map).values
                    .expand((e) => (e as List))
                    .join(' ')
              : '')
        : (item['tag_string']?.toString() ?? '');

    if (isE621 && item['tags'] is Map) {
      final tagsMap = item['tags'] as Map;
      tagsMap.forEach((categoryName, tagNames) {
        int cat = TagCategory.general;
        if (categoryName == 'artist') cat = TagCategory.artist;
        if (categoryName == 'copyright') cat = TagCategory.copyright;
        if (categoryName == 'character') cat = TagCategory.character;
        if (categoryName == 'meta') cat = TagCategory.meta;
        if (tagNames is List) {
          for (final t in tagNames) {
            tags.add(Tag(name: t.toString(), category: cat));
          }
        }
      });
    } else {
      // Categorized tags in Danbooru
      void addCategorized(String? field, int cat) {
        if (field != null && field.isNotEmpty) {
          for (final name in field.split(' ')) {
            if (name.isNotEmpty) tags.add(Tag(name: name, category: cat));
          }
        }
      }

      addCategorized(item['tag_string_artist']?.toString(), TagCategory.artist);
      addCategorized(
        item['tag_string_copyright']?.toString(),
        TagCategory.copyright,
      );
      addCategorized(
        item['tag_string_character']?.toString(),
        TagCategory.character,
      );
      addCategorized(
        item['tag_string_general']?.toString(),
        TagCategory.general,
      );
      addCategorized(item['tag_string_meta']?.toString(), TagCategory.meta);
    }

    DateTime? createdAt;
    if (item['created_at'] != null) {
      createdAt = DateTime.tryParse(item['created_at'].toString());
    }

    return Post(
      id: id,
      booruId: site.id,
      width: width,
      height: height,
      fileSize: fileSize,
      score: score,
      rating: rating,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      originUrl: originUrl,
      source: item['source']?.toString(),
      pixivId: item['pixiv_id'] as int?,
      createdAt: createdAt,
      tags: tags,
      tagString: tagString,
      uploader: item['uploader_name']?.toString() ?? '',
      uploaderId: item['uploader_id'] as int?,
      isFavored: item['is_favorited'] as bool? ?? false,
    );
  }

  Future<List<Tag>> getTagSuggestions({
    required BooruSite site,
    required String query,
  }) async {
    final url = '${site.baseUrl}/autocomplete.json';
    final response = await _dio.get(
      url,
      queryParameters: {
        'search[query]': query,
        'search[type]': 'tag_query',
        'limit': 15,
      },
    );
    final dynamic data = jsonDecode(response.data.toString());
    if (data is! List) return [];

    return data.map((item) {
      final name = item['value']?.toString() ?? item['name']?.toString() ?? '';
      final category = item['category'] as int? ?? TagCategory.general;
      final count = item['post_count'] as int? ?? 0;
      return Tag(name: name, category: category, count: count);
    }).toList();
  }

  Future<List<Comment>> getComments({
    required BooruSite site,
    required int postId,
  }) async {
    final url = '${site.baseUrl}/comments.json';
    final response = await _dio.get(
      url,
      queryParameters: {'group_by': 'comment', 'search[post_id]': postId},
    );
    final dynamic data = jsonDecode(response.data.toString());
    if (data is! List) return [];
    return data
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Pool>> getPools({
    required BooruSite site,
    required int page,
    String query = '',
  }) async {
    final url = '${site.baseUrl}/pools.json';
    final queryParams = <String, dynamic>{'page': page, 'limit': 20};
    if (query.isNotEmpty) {
      queryParams['search[name_matches]'] = '*$query*';
    }
    final response = await _dio.get(url, queryParameters: queryParams);
    final dynamic data = jsonDecode(response.data.toString());
    if (data is! List) return [];
    return data.map((e) => Pool.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Artist>> getArtists({
    required BooruSite site,
    required int page,
    String query = '',
  }) async {
    final url = '${site.baseUrl}/artists.json';
    final queryParams = <String, dynamic>{'page': page, 'limit': 20};
    if (query.isNotEmpty) {
      queryParams['search[name]'] = '*$query*';
    }
    final response = await _dio.get(url, queryParameters: queryParams);
    final dynamic data = jsonDecode(response.data.toString());
    if (data is! List) return [];
    return data.map((e) => Artist.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Post>> getPopularPosts({
    required BooruSite site,
    String scale = '1d',
    int page = 1,
    bool safeMode = false,
  }) async => (await getPopularPage(
    site: site,
    scale: scale,
    page: page,
    safeMode: safeMode,
  )).posts;

  Future<PostPage> getPopularPage({
    required BooruSite site,
    String scale = '1d',
    int page = 1,
    bool safeMode = false,
  }) async {
    final isE621 = site.host.contains('e621');
    final danScale = switch (scale) {
      '1w' => 'week',
      '1m' => 'month',
      _ => 'day',
    };

    final url = isE621
        ? '${site.baseUrl}/popular.json'
        : '${site.baseUrl}/explore/posts/popular.json';

    final queryParams = <String, dynamic>{'scale': danScale, 'page': page};

    if (site.hasAuth) {
      if (site.username?.trim().isNotEmpty ?? false) {
        queryParams['login'] = site.username!.trim();
      }
      if (site.token?.trim().isNotEmpty ?? false) {
        queryParams['api_key'] = site.token!.trim();
      }
    }

    final response = await _dio.get(url, queryParameters: queryParams);
    final dynamic data = jsonDecode(response.data.toString());

    List<dynamic> list;
    if (isE621 && data is Map<String, dynamic>) {
      list = data['posts'] as List<dynamic>? ?? [];
    } else if (data is List) {
      list = data;
    } else {
      list = [];
    }

    final posts = <Post>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final post = _parseDanbooruPost(item, site, isE621: isE621);
      if (post != null) {
        if (safeMode && !post.isSafe) {
          continue;
        }
        posts.add(post);
      }
    }
    return PostPage(posts: posts, hasMore: list.isNotEmpty);
  }
}
