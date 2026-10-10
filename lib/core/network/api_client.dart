import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'User-Agent': AppConstants.defaultUserAgent,
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7',
        },
        responseType: ResponseType.plain, // plain allows parsing both JSON and XML cleanly
        validateStatus: (status) => status != null && status >= 200 && status < 400,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final uri = options.uri;
          // Apply host-specific headers
          if (uri.host.contains('sankaku')) {
            options.headers['Origin'] = AppConstants.sankakuOrigin;
            options.headers['Referer'] = AppConstants.sankakuReferer;
          } else if (uri.host.contains('danbooru')) {
            options.headers['Referer'] = 'https://${uri.host}/';
          } else if (uri.host.contains('yande.re') || uri.host.contains('konachan')) {
            options.headers['Referer'] = 'https://${uri.host}/';
          } else if (uri.host.contains('gelbooru') || uri.host.contains('rule34')) {
            options.headers['Referer'] = 'https://${uri.host}/';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Provide friendly message on Cloudflare or 422 Danbooru limit
          if (e.response?.statusCode == 422) {
            // Danbooru 2-tag limit or invalid param
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: 'Tag search limit exceeded or invalid query (Danbooru 422).',
              ),
            );
          } else if (e.response?.statusCode == 403) {
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: 'Access blocked by Cloudflare / WAF (403 Forbidden). Try updating User-Agent.',
              ),
            );
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// Get image headers for CachedNetworkImage
  static Map<String, String> getImageHeaders({String? host}) {
    final headers = <String, String>{
      'User-Agent': AppConstants.defaultUserAgent,
    };
    if (host != null && host.isNotEmpty) {
      if (host.contains('sankaku')) {
        headers['Origin'] = AppConstants.sankakuOrigin;
        headers['Referer'] = AppConstants.sankakuReferer;
      } else {
        headers['Referer'] = 'https://$host/';
      }
    }
    return headers;
  }
}
