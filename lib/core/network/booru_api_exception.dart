import 'package:dio/dio.dart';

enum BooruApiError {
  authentication,
  challenge,
  forbidden,
  timeout,
  connection,
  invalidResponse,
  query,
  rateLimit,
  server,
}

class BooruApiException implements Exception {
  final BooruApiError kind;
  final String host;
  final int? statusCode;

  const BooruApiException(this.kind, {this.host = '', this.statusCode});

  factory BooruApiException.from(Object error) {
    if (error is BooruApiException) return error;
    if (error is DioException) {
      final response = error.response;
      final status = response?.statusCode;
      final body = response?.data.toString().toLowerCase() ?? '';
      final challenge =
          response?.headers.value('cf-mitigated') == 'challenge' ||
          body.contains('cf-chl-') ||
          body.contains('/cdn-cgi/challenge-platform/');
      final kind = switch (status) {
        401 => BooruApiError.authentication,
        403 => challenge ? BooruApiError.challenge : BooruApiError.forbidden,
        422 => BooruApiError.query,
        429 => BooruApiError.rateLimit,
        _ => switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.sendTimeout => BooruApiError.timeout,
          DioExceptionType.connectionError ||
          DioExceptionType.badCertificate => BooruApiError.connection,
          _ => status == null ? BooruApiError.connection : BooruApiError.server,
        },
      };
      return BooruApiException(
        kind,
        host: error.requestOptions.uri.host,
        statusCode: status,
      );
    }
    return const BooruApiException(BooruApiError.invalidResponse);
  }

  String describe({bool chinese = true}) {
    return switch (kind) {
      BooruApiError.authentication =>
        chinese
            ? '接口需要认证，或凭据已失效。请编辑站点并填写有效的用户 ID / 用户名与 API Key；Sankaku 使用 Bearer Token。'
            : 'The API requires authentication or the credentials have expired. Edit the site and enter a valid user ID / username and API key; Sankaku uses a bearer token.',
      BooruApiError.challenge =>
        chinese
            ? '站点要求 Cloudflare 浏览器验证。请先恢复默认 User-Agent 并重试；若仍被拦截，请在浏览器检查站点访问和当前网络。'
            : 'The site requires a Cloudflare browser challenge. Restore the default User-Agent and retry; if blocked, check site access and your network in a browser.',
      BooruApiError.forbidden =>
        chinese
            ? '服务器拒绝访问（HTTP 403）。请检查站点地址、账号权限或网络限制。'
            : 'The server denied access (HTTP 403). Check the site address, account permissions and network restrictions.',
      BooruApiError.timeout =>
        chinese
            ? '连接或响应超时。请检查该站点能否在浏览器打开，以及代理、VPN、DNS 和网络路由，然后重试。'
            : 'Connection or response timed out. Check site access in a browser, proxy, VPN, DNS and network routing, then retry.',
      BooruApiError.connection =>
        chinese
            ? '无法连接站点，请检查网络、代理和证书。'
            : 'Cannot connect to the site. Check your network, proxy and certificate.',
      BooruApiError.invalidResponse =>
        chinese
            ? '接口返回了错误或无法识别的数据，并非没有作品。请检查 API 地址和认证配置。'
            : 'The API returned an error or unrecognized data, rather than an empty result. Check the API address and authentication.',
      BooruApiError.query =>
        chinese
            ? '搜索参数无效或超过站点标签数量限制（HTTP 422）。请减少标签后重试。'
            : 'Invalid search or too many tags (HTTP 422). Reduce the tags and retry.',
      BooruApiError.rateLimit =>
        chinese
            ? '请求过于频繁（HTTP 429），请稍后重试。'
            : 'Too many requests (HTTP 429). Retry later.',
      BooruApiError.server =>
        chinese
            ? '站点请求失败${statusCode == null ? '' : '（HTTP $statusCode）'}，请稍后重试。'
            : 'Site request failed${statusCode == null ? '' : ' (HTTP $statusCode)'}. Retry later.',
    };
  }

  @override
  String toString() => describe(chinese: false);
}
