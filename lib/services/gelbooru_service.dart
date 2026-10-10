import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/utils/url_util.dart';
import '../models/booru_site.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/tag.dart';

class GelbooruService {
  final Dio _dio = ApiClient().dio;

  Future<List<Post>> getPosts({
    required BooruSite site,
    required int page,
    required int limit,
    String query = '',
    bool safeMode = false,
  }) async {
    final url = '${site.baseUrl}/index.php';

    final tagList = query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (safeMode && !tagList.any((t) => t.startsWith('rating:'))) {
      tagList.add('rating:general');
    }

    final pid = page > 0 ? page - 1 : 0; // Gelbooru pid is 0-indexed page

    final queryParams = <String, dynamic>{
      'page': 'dapi',
      's': 'post',
      'q': 'index',
      'json': '1',
      'limit': limit,
      'pid': pid,
    };

    if (tagList.isNotEmpty) {
      queryParams['tags'] = tagList.join(' ');
    }

    if (site.hasAuth) {
      queryParams['user_id'] = site.username;
      queryParams['api_key'] = site.token;
    }

    final response = await _dio.get(url, queryParameters: queryParams);
    final rawText = response.data.toString().trim();

    // Check if returned XML instead of JSON
    if (rawText.startsWith('<?xml') || rawText.startsWith('<posts')) {
      return _parseGelbooruXml(rawText, site);
    }

    try {
      final dynamic data = jsonDecode(rawText);
      List<dynamic> postList = [];

      if (data is List) {
        postList = data;
      } else if (data is Map<String, dynamic>) {
        final dynamic p = data['post'];
        if (p is List) {
          postList = p;
        } else if (p is Map<String, dynamic>) {
          postList = [p];
        }
      }

      return postList
          .whereType<Map<String, dynamic>>()
          .map((item) => _parseGelbooruJsonPost(item, site))
          .whereType<Post>()
          .toList();
    } catch (_) {
      // Fallback to XML parser if JSON parsing failed
      return _parseGelbooruXml(rawText, site);
    }
  }

  Post? _parseGelbooruJsonPost(Map<String, dynamic> item, BooruSite site) {
    final id = item['id'] as int? ?? int.tryParse(item['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return null;

    final width = item['width'] as int? ?? int.tryParse(item['width']?.toString() ?? '') ?? 0;
    final height = item['height'] as int? ?? int.tryParse(item['height']?.toString() ?? '') ?? 0;
    final score = item['score'] as int? ?? int.tryParse(item['score']?.toString() ?? '') ?? 0;
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

    fileUrl = UrlUtil.normalizeUrl(fileUrl, defaultScheme: site.scheme, host: site.host);
    sampleUrl = UrlUtil.normalizeUrl(sampleUrl, defaultScheme: site.scheme, host: site.host);
    previewUrl = UrlUtil.normalizeUrl(previewUrl, defaultScheme: site.scheme, host: site.host);

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
      uploaderId: item['creator_id'] as int?,
    );
  }

  List<Post> _parseGelbooruXml(String xmlString, BooruSite site) {
    try {
      final doc = XmlDocument.parse(xmlString);
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

        fileUrl = UrlUtil.normalizeUrl(fileUrl, defaultScheme: site.scheme, host: site.host);
        sampleUrl = UrlUtil.normalizeUrl(sampleUrl, defaultScheme: site.scheme, host: site.host);
        previewUrl = UrlUtil.normalizeUrl(previewUrl, defaultScheme: site.scheme, host: site.host);

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
      return posts;
    } catch (_) {
      return [];
    }
  }

  Future<List<Tag>> getTagSuggestions({required BooruSite site, required String query}) async {
    try {
      final url = '${site.baseUrl}/index.php';
      final response = await _dio.get(url, queryParameters: {
        'page': 'dapi',
        's': 'tag',
        'q': 'index',
        'json': '1',
        'name_pattern': '%$query%',
        'limit': 15,
      });

      final raw = response.data.toString().trim();
      if (raw.startsWith('<?xml') || raw.startsWith('<tags')) {
        final doc = XmlDocument.parse(raw);
        return doc.findAllElements('tag').map((el) {
          final name = el.getAttribute('name') ?? '';
          final typeInt = int.tryParse(el.getAttribute('type') ?? '') ?? TagCategory.general;
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

  Future<List<Comment>> getComments({required BooruSite site, required int postId}) async {
    try {
      final url = '${site.baseUrl}/index.php';
      final response = await _dio.get(url, queryParameters: {
        'page': 'dapi',
        's': 'comment',
        'q': 'index',
        'post_id': postId,
      });
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
