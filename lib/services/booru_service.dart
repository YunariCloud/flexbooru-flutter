import '../core/constants/app_constants.dart';
import '../models/booru_site.dart';
import '../models/comment.dart';
import '../models/pool.dart';
import '../models/post.dart';
import '../models/post_page.dart';
import '../models/tag.dart';
import 'danbooru_service.dart';
import 'gelbooru_service.dart';
import 'moebooru_service.dart';
import 'sankaku_service.dart';
import 'shimmie_service.dart';

class BooruService {
  static final BooruService _instance = BooruService._internal();
  factory BooruService() => _instance;
  BooruService._internal();

  final _danbooru = DanbooruService();
  final _moebooru = MoebooruService();
  final _gelbooru = GelbooruService();
  final _sankaku = SankakuService();
  final _shimmie = ShimmieService();

  Future<PostPage> getPostPage({
    required BooruSite site,
    required int page,
    required int limit,
    String query = '',
    bool safeMode = false,
    String? nextCursor,
  }) async {
    if (site.type == BooruType.sankaku) {
      return _sankaku.getPostPage(
        site: site,
        page: page,
        limit: limit,
        query: query,
        safeMode: safeMode,
        nextKey: nextCursor,
      );
    }
    final posts = await getPosts(
      site: site,
      page: page,
      limit: limit,
      query: query,
      safeMode: safeMode,
    );
    return PostPage(posts: posts, hasMore: posts.isNotEmpty);
  }

  Future<List<Post>> getPosts({
    required BooruSite site,
    required int page,
    required int limit,
    String query = '',
    bool safeMode = false,
  }) async {
    switch (site.type) {
      case BooruType.danbooru:
      case BooruType.danbooru1:
        return _danbooru.getPosts(
          site: site,
          page: page,
          limit: limit,
          query: query,
          safeMode: safeMode,
        );
      case BooruType.moebooru:
        return _moebooru.getPosts(
          site: site,
          page: page,
          limit: limit,
          query: query,
          safeMode: safeMode,
        );
      case BooruType.gelbooru:
      case BooruType.gelbooruLegacy:
        return _gelbooru.getPosts(
          site: site,
          page: page,
          limit: limit,
          query: query,
          safeMode: safeMode,
        );
      case BooruType.sankaku:
        return _sankaku.getPosts(
          site: site,
          page: page,
          limit: limit,
          query: query,
          safeMode: safeMode,
        );
      case BooruType.shimmie:
        return _shimmie.getPosts(
          site: site,
          page: page,
          limit: limit,
          query: query,
        );
      default:
        return _moebooru.getPosts(
          site: site,
          page: page,
          limit: limit,
          query: query,
          safeMode: safeMode,
        );
    }
  }

  Future<List<Tag>> getTagSuggestions({
    required BooruSite site,
    required String query,
  }) async {
    switch (site.type) {
      case BooruType.danbooru:
      case BooruType.danbooru1:
        return _danbooru.getTagSuggestions(site: site, query: query);
      case BooruType.moebooru:
        return _moebooru.getTagSuggestions(site: site, query: query);
      case BooruType.gelbooru:
      case BooruType.gelbooruLegacy:
        return _gelbooru.getTagSuggestions(site: site, query: query);
      default:
        return _moebooru.getTagSuggestions(site: site, query: query);
    }
  }

  Future<List<Comment>> getComments({
    required BooruSite site,
    required Object postId,
  }) async {
    final numericId = int.tryParse(postId.toString());
    if (numericId == null) return [];
    switch (site.type) {
      case BooruType.danbooru:
      case BooruType.danbooru1:
        return _danbooru.getComments(site: site, postId: numericId);
      case BooruType.moebooru:
        return _moebooru.getComments(site: site, postId: numericId);
      case BooruType.gelbooru:
      case BooruType.gelbooruLegacy:
        return _gelbooru.getComments(site: site, postId: numericId);
      default:
        return [];
    }
  }

  Future<List<Pool>> getPools({
    required BooruSite site,
    required int page,
    String query = '',
  }) async {
    switch (site.type) {
      case BooruType.danbooru:
        return _danbooru.getPools(site: site, page: page, query: query);
      case BooruType.moebooru:
        return _moebooru.getPools(site: site, page: page, query: query);
      default:
        return [];
    }
  }

  Future<List<Post>> getPopular({
    required BooruSite site,
    String scale = '1d',
    int page = 1,
    bool safeMode = false,
  }) async {
    if (site.type == BooruType.moebooru) {
      return _moebooru.getPopularPosts(site: site, scale: scale, page: page);
    }
    if (site.type == BooruType.danbooru) {
      return _danbooru.getPopularPosts(
        site: site,
        scale: scale,
        page: page,
        safeMode: safeMode,
      );
    }
    if (site.type == BooruType.gelbooru || site.type == BooruType.gelbooruLegacy) {
      return _gelbooru.getPosts(
        site: site,
        page: page,
        limit: 20,
        safeMode: safeMode,
        query: 'sort:score:desc',
      );
    }
    // Default to search with order:score or popular tags
    return getPosts(
      site: site,
      page: page,
      limit: 20,
      safeMode: safeMode,
      query: 'order:score',
    );
  }
}
