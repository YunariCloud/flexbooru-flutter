import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/booru_api_exception.dart';
import '../core/utils/url_util.dart';
import '../models/booru_site.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/tag.dart';

class GelbooruService {
  final Dio _dio;

  GelbooruService({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Map<String, dynamic> _credentials(BooruSite site) {
    if (!site.hasAuth) return {};
    if (!site.hasApiCredentials) {
      throw BooruApiException(BooruApiError.authentication, host: site.host);
    }
    return {'user_id': site.username!.trim(), 'api_key': site.token!.trim()};
  }

  Never _responseError(dynamic data, BooruSite site) {
    final text = data.toString().toLowerCase();
    final auth =
        text.contains('auth') ||
        text.contains('api key') ||
        text.contains('api_key') ||
        text.contains('access denied');
    throw BooruApiException(
      auth ? BooruApiError.authentication : BooruApiError.invalidResponse,
      host: site.host,
    );
  }

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  Future<List<Post>> getPosts({
    required BooruSite site,
    required int page,
    required int limit,
    String query = '',
    bool safeMode = false,
  }) async {
    final url = '${site.apiBaseUrl}/index.php';

    final tagList = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (safeMode && !tagList.any((t) => t.startsWith('rating:'))) {
      final host = Uri.parse(site.apiBaseUrl).host;
      tagList.add(host == 'gelbooru.com' ? 'rating:general' : 'rating:safe');
    }

    final pid = page > 0 ? page - 1 : 0; // Gelbooru pid is 0-indexed page

    final queryParams = <String, dynamic>{
      'page': 'dapi',
      's': 'post',
      'q': 'index',
      'json': '1',
      'limit': limit,
      'pid': pid,
      ..._credentials(site),
    };

    if (tagList.isNotEmpty) {
      queryParams['tags'] = tagList.join(' ');
    }

    final response = await _dio.get(url, queryParameters: queryParams);
    final rawText = response.data.toString().trim();

    // Check if returned XML instead of JSON
    if (rawText.startsWith('<?xml') || rawText.startsWith('<posts')) {
      return _parseGelbooruXml(rawText, site);
    }

    dynamic data;
    try {
      data = jsonDecode(rawText);
    } on FormatException {
      _responseError(rawText, site);
    }
    List<dynamic> postList = [];

    if (data is List) {
      postList = data;
    } else if (data is Map<String, dynamic>) {
      if (data['success'] == false ||
          data['success'] == 'false' ||
          data.containsKey('error')) {
        _responseError(data, site);
      }
      final dynamic p = data['post'];
      if (p is List) {
        postList = p;
      } else if (p is Map<String, dynamic>) {
        postList = [p];
      } else {
        final attributes = data['@attributes'];
        if (attributes is! Map || attributes['count']?.toString() != '0') {
          _responseError(data, site);
        }
      }
    } else {
      _responseError(data, site);
    }

    final posts = postList
        .whereType<Map<String, dynamic>>()
        .map((item) => _parseGelbooruJsonPost(item, site))
        .whereType<Post>()
        .toList();
    if (postList.isNotEmpty && posts.isEmpty) {
      _responseError(data, site);
    }
    return posts;
  }

  Post? _parseGelbooruJsonPost(Map<String, dynamic> item, BooruSite site) {
    final id = _int(item['id']);
    if (id <= 0) return null;

    final width = _int(item['width']);
    final height = _int(item['height']);
    final score = _int(item['score']);
    final rating = item['rating']?.toString() ?? 's';

    var fileUrl = item['file_url']?.toString() ?? '';
    var sampleUrl = item['sample_url']?.toString() ?? '';
    var previewUrl = item['preview_url']?.toString() ?? '';

    // Handle relative paths in Gelbooru
    final dir = item['directory']?.toString() ?? '';
    final image = item['image']?.toString() ?? '';
    if (fileUrl.isEmpty && image.isNotEmpty) {
      fileUrl = '${site.baseUrl}/images/$dir/$image';
    }
    if (sampleUrl.isEmpty && item['sample'] == true && image.isNotEmpty) {
      sampleUrl = '${site.baseUrl}/samples/$dir/sample_$image';
    }
    if (previewUrl.isEmpty && image.isNotEmpty) {
      previewUrl = '${site.baseUrl}/thumbnails/$dir/thumbnail_$image';
    }

    fileUrl = UrlUtil.normalizeUrl(
      fileUrl,
      defaultScheme: site.scheme,
      host: site.host,
    );
    sampleUrl = UrlUtil.normalizeUrl(
      sampleUrl,
      defaultScheme: site.scheme,
      host: site.host,
    );
    previewUrl = UrlUtil.normalizeUrl(
      previewUrl,
      defaultScheme: site.scheme,
      host: site.host,
    );

    if (fileUrl.isEmpty && sampleUrl.isNotEmpty) fileUrl = sampleUrl;
    if (sampleUrl.isEmpty && fileUrl.isNotEmpty) sampleUrl = fileUrl;
    if (previewUrl.isEmpty && sampleUrl.isNotEmpty) previewUrl = sampleUrl;

    final tagString = item['tags']?.toString() ?? '';
    final tags = tagString
        .split(' ')
        .where((t) => t.isNotEmpty)
        .map((t) => Tag(name: t, category: TagCategory.general))
        .toList();

    DateTime? createdAt;
    if (item['created_at'] != null) {
      createdAt = DateTime.tryParse(item['created_at'].toString());
    }

    return Post(
      id: id,
      booruId: site.id,
      width: width,
      height: height,
      score: score,
      rating: rating,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      originUrl: fileUrl,
      source: item['source']?.toString(),
      createdAt: createdAt,
      tags: tags,
      tagString: tagString,
      uploaderId: item['creator_id'] == null ? null : _int(item['creator_id']),
    );
  }

  List<Post> _parseGelbooruXml(String xmlString, BooruSite site) {
    try {
      final doc = XmlDocument.parse(xmlString);
      if (doc.rootElement.name.local != 'posts' ||
          doc.rootElement.getAttribute('success') == 'false') {
        _responseError(xmlString, site);
      }
      final postElements = doc.findAllElements('post');
      final posts = <Post>[];

      for (final el in postElements) {
        final id = int.tryParse(el.getAttribute('id') ?? '') ?? 0;
        if (id <= 0) continue;

        final width = int.tryParse(el.getAttribute('width') ?? '') ?? 0;
        final height = int.tryParse(el.getAttribute('height') ?? '') ?? 0;
        final score = int.tryParse(el.getAttribute('score') ?? '') ?? 0;
        final rating = el.getAttribute('rating') ?? 's';

        var fileUrl = el.getAttribute('file_url') ?? '';
        var sampleUrl = el.getAttribute('sample_url') ?? '';
        var previewUrl = el.getAttribute('preview_url') ?? '';

        fileUrl = UrlUtil.normalizeUrl(
          fileUrl,
          defaultScheme: site.scheme,
          host: site.host,
        );
        sampleUrl = UrlUtil.normalizeUrl(
          sampleUrl,
          defaultScheme: site.scheme,
          host: site.host,
        );
        previewUrl = UrlUtil.normalizeUrl(
          previewUrl,
          defaultScheme: site.scheme,
          host: site.host,
        );

        if (fileUrl.isEmpty && sampleUrl.isNotEmpty) fileUrl = sampleUrl;
        if (sampleUrl.isEmpty && fileUrl.isNotEmpty) sampleUrl = fileUrl;
        if (previewUrl.isEmpty && sampleUrl.isNotEmpty) previewUrl = sampleUrl;

        final tagString = el.getAttribute('tags') ?? '';
        final tags = tagString
            .split(' ')
            .where((t) => t.isNotEmpty)
            .map((t) => Tag(name: t, category: TagCategory.general))
            .toList();

        posts.add(
          Post(
            id: id,
            booruId: site.id,
            width: width,
            height: height,
            score: score,
            rating: rating,
            previewUrl: previewUrl,
            sampleUrl: sampleUrl,
            originUrl: fileUrl,
            source: el.getAttribute('source'),
            tags: tags,
            tagString: tagString,
          ),
        );
      }
      if (postElements.isNotEmpty && posts.isEmpty) {
        _responseError(xmlString, site);
      }
      return posts;
    } on XmlParserException {
      _responseError(xmlString, site);
    }
  }

  Future<List<Tag>> getTagSuggestions({
    required BooruSite site,
    required String query,
  }) async {
    try {
      final url = '${site.apiBaseUrl}/index.php';
      final response = await _dio.get(
        url,
        queryParameters: {
          'page': 'dapi',
          's': 'tag',
          'q': 'index',
          'json': '1',
          'name_pattern': '%$query%',
          'limit': 15,
          ..._credentials(site),
        },
      );

      final raw = response.data.toString().trim();
      if (raw.startsWith('<?xml') || raw.startsWith('<tags')) {
        final doc = XmlDocument.parse(raw);
        return doc.findAllElements('tag').map((el) {
          final name = el.getAttribute('name') ?? '';
          final typeInt =
              int.tryParse(el.getAttribute('type') ?? '') ??
              TagCategory.general;
          final count = int.tryParse(el.getAttribute('count') ?? '') ?? 0;
          return Tag(name: name, category: typeInt, count: count);
        }).toList();
      }

      final dynamic data = jsonDecode(raw);
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data['tag'] is List) {
        list = data['tag'];
      }

      return list.map((item) {
        final name = item['name']?.toString() ?? '';
        final typeInt = item['type'] as int? ?? TagCategory.general;
        final count = item['count'] as int? ?? 0;
        return Tag(name: name, category: typeInt, count: count);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Comment>> getComments({
    required BooruSite site,
    required int postId,
  }) async {
    try {
      final url = '${site.apiBaseUrl}/index.php';
      final response = await _dio.get(
        url,
        queryParameters: {
          'page': 'dapi',
          's': 'comment',
          'q': 'index',
          'post_id': postId,
          ..._credentials(site),
        },
      );
      final raw = response.data.toString().trim();
      final doc = XmlDocument.parse(raw);
      return doc.findAllElements('comment').map((el) {
        return Comment(
          id: int.tryParse(el.getAttribute('id') ?? '') ?? 0,
          postId: int.tryParse(el.getAttribute('post_id') ?? '') ?? postId,
          author: el.getAttribute('creator') ?? 'Anonymous',
          body: el.getAttribute('body') ?? '',
          createdAt: el.getAttribute('created_at') != null
              ? DateTime.tryParse(el.getAttribute('created_at')!)
              : null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
