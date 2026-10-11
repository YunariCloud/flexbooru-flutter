import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'update_service.dart';

enum UpdateDownloadState {
  idle,
  downloading,
  verifying,
  ready,
  cancelled,
  failed,
}

class AppUpdateManager extends ChangeNotifier {
  AppUpdateManager({
    Dio? dio,
    Future<Directory> Function()? directory,
    Future<String> Function(String)? openPackage,
    String? platform,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 30),
               receiveTimeout: const Duration(minutes: 2),
             ),
           ),
       _directory = directory ?? getApplicationSupportDirectory,
       _openPackage = openPackage ?? _openNative,
       platform = platform ?? (kIsWeb ? 'web' : Platform.operatingSystem);

  static final instance = AppUpdateManager();
  static const _channel = MethodChannel('com.flexbooru.app/updates');
  final Dio _dio;
  final Future<Directory> Function() _directory;
  final Future<String> Function(String) _openPackage;
  final String platform;
  UpdateInfo? info;
  UpdateDownloadState state = UpdateDownloadState.idle;
  String? filePath;
  String? error;
  int received = 0;
  int total = 0;
  CancelToken? _cancel;
  Future<void>? _download;
  String? _verifiedSha256;
  bool _disposed = false;
  bool get busy =>
      state == UpdateDownloadState.downloading ||
      state == UpdateDownloadState.verifying;
  double? get progress => total > 0 ? (received / total).clamp(0, 1) : null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> download(UpdateInfo update) {
    if (_disposed) return Future.error(StateError('Updater disposed'));
    // One stream across the startup check, settings page and about page.
    if (_download != null) return _download!;
    final operation = Completer<void>();
    _download = operation.future;
    unawaited(() async {
      try {
        await _performDownload(update);
        operation.complete();
      } catch (exception, stack) {
        operation.completeError(exception, stack);
      } finally {
        _download = null;
      }
    }());
    return operation.future;
  }

  Future<void> _performDownload(UpdateInfo update) async {
    info = update;
    filePath = null;
    _verifiedSha256 = null;
    error = null;
    received = 0;
    total = update.assetSize ?? 0;
    state = UpdateDownloadState.downloading;
    final cancel = _cancel = CancelToken();
    _notify();
    File? partial;
    try {
      final url = update.downloadUrl;
      final name = update.assetName;
      if (url == null ||
          name == null ||
          !UpdateService.isTrustedAssetUrl(url) ||
          UpdateService.assetScore(name, platform) == 0 ||
          !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._+-]*$').hasMatch(name)) {
        throw const FormatException('No compatible update asset');
      }
      final root = Directory(
        '${(await _directory()).path}${Platform.pathSeparator}updates',
      );
      await root.create(recursive: true);
      final identity = sha256
          .convert(
            utf8.encode('$url|${update.assetSha256}|${update.assetSize}'),
          )
          .toString()
          .substring(0, 16);
      final file = File('${root.path}${Platform.pathSeparator}$identity-$name');
      if (await file.exists()) {
        state = UpdateDownloadState.verifying;
        _notify();
        try {
          _verifiedSha256 = await _validate(file, update, cancel);
          if (cancel.isCancelled) throw const _UpdateCancelled();
          filePath = file.path;
          state = UpdateDownloadState.ready;
          received = await file.length();
          total = received;
          return;
        } on _UpdateCancelled {
          rethrow;
        } on FormatException {
          await file.delete();
        }
      }
      partial = File('${file.path}.part');
      state = UpdateDownloadState.downloading;
      _notify();
      await _dio.download(
        url,
        partial.path,
        cancelToken: cancel,
        options: Options(
          headers: {
            'User-Agent': 'Flexbooru-Flutter-App',
            'Accept': 'application/octet-stream',
          },
          receiveTimeout: const Duration(minutes: 2),
          validateStatus: (status) => status == 200,
        ),
        onReceiveProgress: (count, length) {
          received = count;
          total = length > 0 ? length : update.assetSize ?? 0;
          _notify();
        },
      );
      state = UpdateDownloadState.verifying;
      _notify();
      _verifiedSha256 = await _validate(partial, update, cancel);
      if (cancel.isCancelled) throw const _UpdateCancelled();
      await partial.rename(file.path);
      filePath = file.path;
      state = UpdateDownloadState.ready;
      received = await file.length();
      total = received;
    } catch (exception) {
      final cancelled =
          cancel.isCancelled ||
          exception is _UpdateCancelled ||
          (exception is DioException && CancelToken.isCancel(exception));
      state = cancelled
          ? UpdateDownloadState.cancelled
          : UpdateDownloadState.failed;
      error = cancelled
          ? null
          : exception is FormatException
          ? 'integrity'
          : 'download';
    } finally {
      try {
        if (partial != null && await partial.exists()) await partial.delete();
      } catch (_) {
        // A locked partial is never offered as an installable package.
      }
      _cancel = null;
      _notify();
    }
  }

  Future<String> _validate(
    File file,
    UpdateInfo update,
    CancelToken cancel, {
    String? verifiedSha256,
  }) async {
    final size = await file.length();
    if (size < 4 ||
        (update.assetSize != null &&
            update.assetSize! > 0 &&
            size != update.assetSize)) {
      throw const FormatException('Update size mismatch');
    }
    // APKs and portable Windows bundles are ZIP containers, never HTML pages.
    final reader = await file.open();
    try {
      final bytes = await reader.read(4);
      if (bytes.length != 4 ||
          bytes[0] != 0x50 ||
          bytes[1] != 0x4b ||
          bytes[2] != 3 ||
          bytes[3] != 4) {
        throw const FormatException('Update is not an APK or ZIP');
      }
    } finally {
      await reader.close();
    }
    var expected = verifiedSha256 ?? update.assetSha256;
    if (expected == null && update.checksumUrl != null) {
      if (!UpdateService.isTrustedAssetUrl(update.checksumUrl!)) {
        throw const FormatException('Invalid checksum URL');
      }
      final response = await _dio.get<String>(
        update.checksumUrl!,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'User-Agent': 'Flexbooru-Flutter-App'},
        ),
      );
      for (final line in (response.data ?? '').split('\n')) {
        final match = RegExp(
          r'^([0-9a-fA-F]{64})\s+\*?(.+)$',
        ).firstMatch(line.replaceFirst('\uFEFF', '').trim());
        final name = match?[2]?.replaceFirst(RegExp(r'^\./'), '');
        if (match != null && name == update.assetName) {
          expected = match[1]!.toLowerCase();
        }
      }
      if (expected == null) {
        throw const FormatException('Missing asset checksum');
      }
    }
    final actual = (await sha256.bind(file.openRead()).first).toString();
    if (expected != null && actual != expected.toLowerCase()) {
      throw const FormatException('Update checksum mismatch');
    }
    if (cancel.isCancelled) throw const _UpdateCancelled();
    return actual;
  }

  void cancel() => _cancel?.cancel('User cancelled update');

  Future<String> openDownloadedPackage() async {
    final path = filePath;
    final update = info;
    if (state != UpdateDownloadState.ready || path == null || update == null) {
      throw StateError('Update not ready');
    }
    // Recheck before handing a cached installer to the operating system.
    try {
      await _validate(
        File(path),
        update,
        CancelToken(),
        verifiedSha256: _verifiedSha256,
      );
    } catch (_) {
      state = UpdateDownloadState.failed;
      error = 'integrity';
      filePath = null;
      _notify();
      rethrow;
    }
    return _openPackage(path);
  }

  static Future<String> _openNative(String path) async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod<String>('installApk', {
            'path': path,
          }) ??
          'opened';
    }
    if (Platform.isWindows) {
      if (!await launchUrl(
        Uri.file(path),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Cannot open update package');
      }
      return 'opened';
    }
    throw UnsupportedError('Automatic updates unavailable');
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}

class _UpdateCancelled implements Exception {
  const _UpdateCancelled();
}
