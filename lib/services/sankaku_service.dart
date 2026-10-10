import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/utils/url_util.dart';
import '../models/booru_site.dart';
import '../models/post.dart';
import '../models/tag.dart';

class SankakuService {
  final Dio _dio = ApiClient().dio;

  Future<List<Post>> getPosts({
    required BooruSite site,
    required int page,
    required int limit,
    String query = '',
    bool safeMode = false,
    String? nextKey,
  }) async {
    final url = '${site.baseUrl}/posts/keyset';

    final tagList = query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (safeMode && !tagList.any((t) => t.startsWith('rating:'))) {
      tagList.add('rating:safe');
    }

    final queryParams = <String, dynamic>{
      'lang': 'en',
      'default_threshold': '1',
      'hide_posts_in_books': 'in-larger-tags',
      'limit': limit,
    };

    if (tagList.isNotEmpty) {
      queryParams['tags'] = tagList.join(' ');
    }

    if (nextKey != null && nextKey.isNotEmpty) {
      queryParams['next'] = nextKey;
    } else if (page > 1) {
      queryParams['page'] = page;
    }

    final headers = <String, dynamic>{
      'Origin': AppConstants.sankakuOrigin,
      'Referer': AppConstants.sankakuReferer,
      'User-Agent': AppConstants.defaultUserAgent,
    };

    if (site.hasAuth && site.token != null) {
      headers['Authorization'] = 'Bearer ${site.token}';
    }

    final response = await _dio.get(
      url,
      queryParameters: queryParams,
      options: Options(headers: headers),
    );

    final dynamic data = jsonDecode(response.data.toString());
    List<dynamic> list = [];
    if (data is Map<String, dynamic>) {
      list = data['data'] as List<dynamic>? ?? data['posts'] as List<dynamic>? ?? [];
    } else if (data is List) {
      list = data;
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((item) => _parseSankakuPost(item, site))
        .whereType<Post>()
        .toList();
  }

  Post? _parseSankakuPost(Map<String, dynamic> item, BooruSite site) {
    final id = item['id'] as int? ?? 0;
    if (id <= 0) return null;

    final width = item['width'] as int? ?? 0;
    final height = item['height'] as int? ?? 0;
    final fileSize = item['file_size'] as int? ?? 0;
    final score = item['total_score'] as int? ?? item['score'] as int? ?? 0;
    final rating = item['rating']?.toString() ?? 's';

    var previewUrl = item['preview_url']?.toString() ?? '';
    var sampleUrl = item['sample_url']?.toString() ?? '';
    var originUrl = item['file_url']?.toString() ?? sampleUrl;

    previewUrl = UrlUtil.normalizeUrl(previewUrl, defaultScheme: site.scheme, host: site.host);
    sampleUrl = UrlUtil.normalizeUrl(sampleUrl, defaultScheme: site.scheme, host: site.host);
    originUrl = UrlUtil.normalizeUrl(originUrl, defaultScheme: site.scheme, host: site.host);

    if (originUrl.isEmpty && sampleUrl.isNotEmpty) originUrl = sampleUrl;
    if (sampleUrl.isEmpty && originUrl.isNotEmpty) sampleUrl = originUrl;
    if (previewUrl.isEmpty && sampleUrl.isNotEmpty) previewUrl = sampleUrl;

    final tags = <Tag>[];
    final tagsData = item['tags'];
    if (tagsData is List) {
      for (final t in tagsData) {
        if (t is Map<String, dynamic>) {
          final tagName = t['name']?.toString() ?? '';
          final tagType = t['type'] as int? ?? TagCategory.general;
          final tagCount = t['count'] as int? ?? 0;
          tags.add(Tag(name: tagName, category: tagType, count: tagCount));
        } else if (t is String) {
          tags.add(Tag(name: t, category: TagCategory.general));
        }
      }
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
      createdAt: createdAt,
      tags: tags,
      tagString: tags.map((t) => t.name).join(' '),
      uploader: item['author']?['name']?.toString() ?? '',
      uploaderId: item['author']?['id'] as int?,
      isFavored: item['is_favorited'] as bool? ?? false,
    );
  }
}
