import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/utils/url_util.dart';
import '../models/booru_site.dart';
import '../models/post.dart';
import '../models/tag.dart';

class ShimmieService {
  final Dio _dio = ApiClient().dio;

  Future<List<Post>> getPosts({
    required BooruSite site,
    required int page,
    required int limit,
    String query = '',
  }) async {
    var path = site.path?.trim() ?? '';
    if (path.startsWith('/')) path = path.substring(1);
    if (path.endsWith('/')) path = path.substring(0, path.length - 1);

    final basePath = path.isNotEmpty ? '/$path/api/danbooru/find_posts' : '/api/danbooru/find_posts';
    final url = '${site.baseUrl}$basePath';

    final queryParams = <String, dynamic>{
      'limit': limit,
      'page': page,
    };
    if (query.trim().isNotEmpty) {
      queryParams['tags'] = query.trim();
    }

    final response = await _dio.get(url, queryParameters: queryParams);
    final rawText = response.data.toString().trim();

    try {
      final doc = XmlDocument.parse(rawText);
      final elements = [
        ...doc.findAllElements('tag'),
        ...doc.findAllElements('post'),
      ];

      final posts = <Post>[];
      for (final el in elements) {
        final id = int.tryParse(el.getAttribute('id') ?? '') ?? 0;
        if (id <= 0) continue;

        final width = int.tryParse(el.getAttribute('width') ?? '') ?? 0;
        final height = int.tryParse(el.getAttribute('height') ?? '') ?? 0;
        final score = int.tryParse(el.getAttribute('score') ?? '') ?? 0;
        final rating = el.getAttribute('rating') ?? 's';

        var fileUrl = el.getAttribute('file_url') ?? '';
        var sampleUrl = el.getAttribute('sample_url') ?? fileUrl;
        var previewUrl = el.getAttribute('preview_url') ?? sampleUrl;

        fileUrl = UrlUtil.normalizeUrl(fileUrl, defaultScheme: site.scheme, host: site.host);
        sampleUrl = UrlUtil.normalizeUrl(sampleUrl, defaultScheme: site.scheme, host: site.host);
        previewUrl = UrlUtil.normalizeUrl(previewUrl, defaultScheme: site.scheme, host: site.host);

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
}
