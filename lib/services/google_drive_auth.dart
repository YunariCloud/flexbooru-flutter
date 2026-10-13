import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/sync/sync_crypto.dart';

const driveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';

class DriveOAuthConfig {
  const DriveOAuthConfig({
    this.androidServerId = '',
    this.windowsClientId = '',
    this.windowsSecret = '',
  });
  final String androidServerId, windowsClientId, windowsSecret;
  Map<String, dynamic> toJson() => {
    'android': androidServerId,
    'windows': windowsClientId,
    'secret': windowsSecret,
  };
  factory DriveOAuthConfig.fromJson(Map<String, dynamic> json) =>
      DriveOAuthConfig(
        androidServerId: json['android'] as String? ?? '',
        windowsClientId: json['windows'] as String? ?? '',
        windowsSecret: json['secret'] as String? ?? '',
      );
}

class GoogleDriveAuth {
  GoogleDriveAuth({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage storage;
  DriveOAuthConfig config = const DriveOAuthConfig();
  GoogleSignInAccount? _account;
  auth.AccessCredentials? _credentials;
  String? _initializedAndroidId;
  HttpServer? _oauthServer;
  String? email;
  int _epoch = 0;
  static const _configKey = 'flex_drive_oauth_config_v1';
  static const _tokenKey = 'flex_drive_oauth_token_v1';

  Future<void> load() async {
    final raw = await storage.read(key: _configKey);
    if (raw != null) {
      config = DriveOAuthConfig.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    }
    final token = await storage.read(key: _tokenKey);
    if (token != null) {
      _credentials = auth.AccessCredentials.fromJson(
        (jsonDecode(token) as Map).cast<String, dynamic>(),
      );
      _readEmail();
    }
  }

  Future<void> configure(DriveOAuthConfig value) async {
    if (_initializedAndroidId != null &&
        value.androidServerId != _initializedAndroidId) {
      throw StateError(
        'Restart the app before changing the Android OAuth client',
      );
    }
    await signOut();
    config = value;
    await storage.write(key: _configKey, value: jsonEncode(value.toJson()));
  }

  void _readEmail() {
    final jwt = _credentials?.idToken;
    if (jwt == null) return;
    try {
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(jwt.split('.')[1])),
                ),
              )
              as Map;
      email = claims['email'] as String?;
    } catch (_) {
      /* A display label is optional; Drive authorizes the token. */
    }
  }

  Future<String> token({bool interactive = false}) async {
    final epoch = _epoch;
    if (Platform.isAndroid) {
      if (!config.androidServerId.endsWith('.apps.googleusercontent.com')) {
        throw StateError('Android OAuth client is not configured');
      }
      if (_initializedAndroidId == null) {
        await GoogleSignIn.instance.initialize(
          serverClientId: config.androidServerId,
        );
        _initializedAndroidId = config.androidServerId;
      }
      _account ??= await GoogleSignIn.instance
          .attemptLightweightAuthentication();
      if (_account == null && interactive) {
        _account = await GoogleSignIn.instance.authenticate();
      }
      if (_account == null) throw StateError('Sign in to Google first');
      email = _account!.email;
      final client = _account!.authorizationClient;
      var permission = await client.authorizationForScopes([driveAppDataScope]);
      if (permission == null && interactive) {
        permission = await client.authorizeScopes([driveAppDataScope]);
      }
      if (permission == null) {
        throw StateError('Google Drive authorization is required');
      }
      if (epoch != _epoch) {
        _account = null;
        throw StateError('Sign-in cancelled');
      }
      return permission.accessToken;
    }
    if (!Platform.isWindows) {
      throw UnsupportedError('Google Drive sync supports Android and Windows');
    }
    if (!config.windowsClientId.endsWith('.apps.googleusercontent.com')) {
      throw StateError('Windows OAuth client is not configured');
    }
    final clientId = auth.ClientId(
      config.windowsClientId,
      config.windowsSecret,
    );
    final client = http.Client();
    try {
      if (_credentials == null) {
        if (!interactive) throw StateError('Sign in to Google first');
        final credentials = await _windowsSignIn(client, clientId, epoch);
        if (epoch != _epoch) throw StateError('Sign-in cancelled');
        _credentials = credentials;
      } else if (_credentials!.accessToken.expiry.isBefore(
        DateTime.now().toUtc().add(const Duration(seconds: 30)),
      )) {
        final credentials = await auth
            .refreshCredentials(clientId, _credentials!, client)
            .timeout(const Duration(seconds: 30));
        if (epoch != _epoch) throw StateError('Sign-in cancelled');
        _credentials = credentials;
      }
      if (epoch != _epoch) throw StateError('Sign-in cancelled');
      await storage.write(
        key: _tokenKey,
        value: jsonEncode(_credentials!.toJson()),
      );
      if (epoch != _epoch) {
        await storage.delete(key: _tokenKey);
        throw StateError('Sign-in cancelled');
      }
      _readEmail();
      return _credentials!.accessToken.data;
    } finally {
      client.close();
    }
  }

  Future<auth.AccessCredentials> _windowsSignIn(
    http.Client client,
    auth.ClientId clientId,
    int epoch,
  ) async {
    final server = _oauthServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final redirect = 'http://127.0.0.1:${server.port}';
    final state = randomSyncKey();
    final verifier = randomSyncKey().replaceAll('=', '');
    final challenge = base64UrlEncode(
      crypto.sha256.convert(utf8.encode(verifier)).bytes,
    ).replaceAll('=', '');
    try {
      if (epoch != _epoch) throw StateError('Sign-in cancelled');
      final uri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': config.windowsClientId,
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope': '$driveAppDataScope openid email',
        'state': state,
        'access_type': 'offline',
        'prompt': 'consent select_account',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open Google sign-in');
      }
      final request = await server.first.timeout(const Duration(minutes: 3));
      final params = request.uri.queryParameters;
      final valid =
          request.method == 'GET' &&
          constantTimeEqual(params['state'] ?? '', state) &&
          params['code'] != null;
      request.response.headers.contentType = ContentType.text;
      request.response.write(
        valid
            ? 'Google sign-in received. You may close this page.'
            : 'Google sign-in was cancelled or invalid.',
      );
      await request.response.close();
      if (!valid) throw StateError('Google sign-in was cancelled or invalid');
      return await auth
          .obtainAccessCredentialsViaCodeExchange(
            client,
            clientId,
            params['code']!,
            redirectUrl: redirect,
            codeVerifier: verifier,
          )
          .timeout(const Duration(seconds: 30));
    } finally {
      await server.close(force: true);
      if (identical(_oauthServer, server)) _oauthServer = null;
    }
  }

  Future<void> invalidate(String token) async {
    if (Platform.isAndroid && _account != null) {
      await _account!.authorizationClient.clearAuthorizationToken(
        accessToken: token,
      );
    } else if (_credentials != null) {
      _credentials = auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          token,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
        _credentials!.refreshToken,
        _credentials!.scopes,
        idToken: _credentials!.idToken,
      );
    }
  }

  Future<void> signOut() async {
    _epoch++;
    await _oauthServer?.close(force: true);
    if (Platform.isAndroid && _initializedAndroidId != null) {
      await GoogleSignIn.instance.signOut();
    }
    _account = null;
    _credentials = null;
    email = null;
    await storage.delete(key: _tokenKey);
  }
}
