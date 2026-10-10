import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'User-Agent': AppConstants.defaultUserAgent,
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7',
        },
        responseType: ResponseType
            .plain, // plain allows parsing both JSON and XML cleanly
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final uri = options.uri;
          // Apply host-specific headers
          if (uri.host.contains('sankaku')) {
            // Sankaku closes API connections for non-browser default UAs.
            // Keep explicitly configured user agents intact.
            if (options.headers['User-Agent'] ==
                AppConstants.defaultUserAgent) {
              options.headers['User-Agent'] =
                  AppConstants.defaultBrowserUserAgent;
            }
            options.headers['Origin'] = AppConstants.sankakuOrigin;
            options.headers['Referer'] = AppConstants.sankakuReferer;
          } else if (uri.host.contains('danbooru')) {
            options.headers['Referer'] = 'https://${uri.host}/';
          } else if (uri.host.contains('yande.re') ||
              uri.host.contains('konachan')) {
            options.headers['Referer'] = 'https://${uri.host}/';
          } else if (uri.host.contains('gelbooru') ||
              uri.host.contains('rule34')) {
            options.headers['Referer'] = uri.host == 'api.rule34.xxx'
                ? 'https://rule34.xxx/'
                : '${uri.origin}/';
          }
          return handler.next(options);
        },
      ),
    );
  }

  void setUserAgent(String value) {
    dio.options.headers['User-Agent'] = value.trim().isEmpty
        ? AppConstants.defaultUserAgent
        : value.trim();
  }

  /// Get image headers for CachedNetworkImage
  static Map<String, String> getImageHeaders({String? host}) {
    final headers = <String, String>{
      'User-Agent': _instance.dio.options.headers['User-Agent'].toString(),
    };
    if (host != null && host.isNotEmpty) {
      if (host.contains('sankaku')) {
        if (headers['User-Agent'] == AppConstants.defaultUserAgent) {
          headers['User-Agent'] = AppConstants.defaultBrowserUserAgent;
        }
        headers['Origin'] = AppConstants.sankakuOrigin;
        headers['Referer'] = AppConstants.sankakuReferer;
      } else {
        headers['Referer'] = host == 'api.rule34.xxx'
            ? 'https://rule34.xxx/'
            : 'https://$host/';
      }
    }
    return headers;
  }
}
