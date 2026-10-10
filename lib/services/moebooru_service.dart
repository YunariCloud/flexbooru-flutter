import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/utils/url_util.dart';
import '../models/booru_site.dart';
import '../models/comment.dart';
import '../models/pool.dart';
import '../models/post.dart';
import '../models/tag.dart';

class MoebooruService {
  final Dio _dio = ApiClient().dio;

  Future<List<Post>> getPosts({
    required BooruSite site,
    required int page,
    required int limit,
    String query = '',
    bool safeMode = false,
  }) async {
    final url = '${site.baseUrl}/post.json';

    final tagList = query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (safeMode && !tagList.any((t) => t.startsWith('rating:'))) {
      tagList.add('rating:s');
    }

    final queryParams = <String, dynamic>{
      'api_version': '2',
      'include_tags': '1',
      'include_votes': '1',
      'limit': limit,
      'page': page,
    };

    if (tagList.isNotEmpty) {
      queryParams['tags'] = tagList.join(' ');
    }

    if (site.hasAuth) {
      queryParams['login'] = site.username;
      queryParams['password_hash'] = site.token;
    }

    final response = await _dio.get(url, queryParameters: queryParams);
    final dynamic data = jsonDecode(response.data.toString());

    List<dynamic> postList = [];
    Map<String, dynamic> tagTypes = {};

    if (data is Map<String, dynamic>) {
      postList = data['posts'] as List<dynamic>? ?? [];
      tagTypes = data['tags'] as Map<String, dynamic>? ?? {};
    } else if (data is List) {
      postList = data;
    }

    return postList
        .whereType<Map<String, dynamic>>()
        .map((item) => _parseMoePost(item, site, tagTypes))
        .whereType<Post>()
        .toList();
  }

  Post? _parseMoePost(Map<String, dynamic> item, BooruSite site, Map<String, dynamic> tagTypes) {
    final id = item['id'] as int? ?? 0;
    if (id <= 0) return null;

    final width = item['width'] as int? ?? 0;
    final height = item['height'] as int? ?? 0;
    final fileSize = item['file_size'] as int? ?? 0;
    final score = item['score'] as int? ?? 0;
    final rating = item['rating']?.toString() ?? 's';

    var previewUrl = item['preview_url']?.toString() ?? '';
    var sampleUrl = item['sample_url']?.toString() ?? '';
    var originUrl = item['file_url']?.toString() ?? sampleUrl;

    // Fix protocol-relative URLs (e.g. //assets.yande.re/...)
    previewUrl = UrlUtil.normalizeUrl(previewUrl, defaultScheme: site.scheme, host: site.host);
    sampleUrl = UrlUtil.normalizeUrl(sampleUrl, defaultScheme: site.scheme, host: site.host);
    originUrl = UrlUtil.normalizeUrl(originUrl, defaultScheme: site.scheme, host: site.host);

    if (originUrl.isEmpty && sampleUrl.isNotEmpty) originUrl = sampleUrl;
    if (sampleUrl.isEmpty && originUrl.isNotEmpty) sampleUrl = originUrl;
    if (previewUrl.isEmpty && sampleUrl.isNotEmpty) previewUrl = sampleUrl;

    final tagString = item['tags']?.toString() ?? '';
    final tags = <Tag>[];
    for (final name in tagString.split(' ')) {
      if (name.isEmpty) continue;
      final typeStr = tagTypes[name]?.toString();
      int cat = TagCategory.general;
      if (typeStr == 'artist') {
        cat = TagCategory.artist;
      } else if (typeStr == 'copyright') {
        cat = TagCategory.copyright;
      } else if (typeStr == 'character') {
        cat = TagCategory.character;
      } else if (typeStr == 'circle' || typeStr == 'style') {
        cat = TagCategory.circle;
      } else if (typeStr == 'faults') {
        cat = TagCategory.faults;
      }
      tags.add(Tag(name: name, category: cat));
    }

    DateTime? createdAt;
    if (item['created_at'] != null) {
      if (item['created_at'] is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch((item['created_at'] as int) * 1000);
      } else {
        createdAt = DateTime.tryParse(item['created_at'].toString());
      }
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
      createdAt: createdAt,
      tags: tags,
      tagString: tagString,
      uploader: item['author']?.toString() ?? '',
      uploaderId: item['creator_id'] as int?,
      isFavored: item['is_favorited'] as bool? ?? false,
    );
  }

  Future<List<Tag>> getTagSuggestions({required BooruSite site, required String query}) async {
    final url = '${site.baseUrl}/tag.json';
    final response = await _dio.get(url, queryParameters: {
      'order': 'count',
      'limit': 15,
      'name': query,
    });
    final dynamic data = jsonDecode(response.data.toString());
    if (data is! List) return [];

    return data.map((item) {
      final name = item['name']?.toString() ?? '';
      final typeInt = item['type'] as int? ?? TagCategory.general;
      final count = item['count'] as int? ?? 0;
      return Tag(name: name, category: typeInt, count: count);
    }).toList();
  }

  Future<List<Comment>> getComments({required BooruSite site, required int postId}) async {
    final url = '${site.baseUrl}/comment.json';
    final response = await _dio.get(url, queryParameters: {
      'post_id': postId,
    });
    final dynamic data = jsonDecode(response.data.toString());
    if (data is! List) return [];
    return data.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Pool>> getPools({required BooruSite site, required int page, String query = ''}) async {
    final url = '${site.baseUrl}/pool.json';
    final queryParams = <String, dynamic>{
      'page': page,
    };
    if (query.isNotEmpty) {
      queryParams['query'] = query;
    }
    final response = await _dio.get(url, queryParameters: queryParams);
    final dynamic data = jsonDecode(response.data.toString());
    if (data is! List) return [];
    return data.map((e) => Pool.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Post>> getPopularPosts({
    required BooruSite site,
    String scale = '1d', // 1d, 1w, 1m, 1y
  }) async {
    String endpoint;
    switch (scale) {
      case '1w':
        endpoint = 'popular_by_week.json';
        break;
      case '1m':
        endpoint = 'popular_by_month.json';
        break;
      default:
        endpoint = 'popular_by_day.json';
        break;
    }
    final url = '${site.baseUrl}/post/$endpoint';
    final response = await _dio.get(url);
    final dynamic data = jsonDecode(response.data.toString());
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => _parseMoePost(e, site, {}))
        .whereType<Post>()
        .toList();
  }
}
