import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flexbooru/services/app_update_manager.dart';
import 'package:flexbooru/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mock_http_adapter.dart';

const assetRoot =
    'https://github.com/YunariCloud/flexbooru-flutter/releases/download/v2.0.0';
const assetName = 'flexbooru-windows-x64.zip';
final packageBytes = [0x50, 0x4b, 3, 4, ...List.generate(128, (i) => i)];

UpdateInfo updateInfo({
  String name = assetName,
  String? url,
  String? hash,
  int? size,
  String? checksumUrl,
  bool publishedDigest = true,
}) => UpdateInfo(
  currentVersion: '1.0.0',
  latestVersion: '2.0.0',
  tagName: 'v2.0.0',
  title: 'Release',
  releaseNotes: '',
  releaseUrl: '$assetRoot/../tag/v2.0.0',
  downloadUrl: url ?? '$assetRoot/$name',
  assetName: name,
  assetSize: size ?? packageBytes.length,
  assetSha256: publishedDigest
      ? hash ?? sha256.convert(packageBytes).toString()
      : null,
  checksumUrl: checksumUrl,
  hasUpdate: true,
);

ResponseBody packageResponse([List<int>? bytes]) => ResponseBody.fromBytes(
  bytes ?? packageBytes,
  200,
  headers: {
    Headers.contentLengthHeader: ['${(bytes ?? packageBytes).length}'],
  },
);

void main() {
  late Directory directory;
  late Dio dio;
  late AppUpdateManager manager;
  late int requests;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flexbooru-update-test-');
    requests = 0;
    dio = Dio()
      ..httpClientAdapter = MockHttpAdapter((request) {
        requests++;
        return packageResponse();
      });
    manager = AppUpdateManager(
      dio: dio,
      directory: () async => directory,
      platform: 'windows',
      openPackage: (_) async => 'opened',
    );
  });
  tearDown(() async {
    manager.dispose();
    dio.close(force: true);
    final path = directory.absolute.path;
    final root = Directory.systemTemp.absolute.path;
    expect(
      path.startsWith('$root${Platform.pathSeparator}flexbooru-update-test-'),
      isTrue,
    );
    await directory.delete(recursive: true);
  });

  test(
    'downloads, reports progress, reuses verified package after restart',
    () async {
      final states = <UpdateDownloadState>[];
      manager.addListener(() => states.add(manager.state));
      await manager.download(updateInfo());
      expect(manager.state, UpdateDownloadState.ready);
      expect(manager.progress, 1);
      expect(
        states,
        containsAll([
          UpdateDownloadState.downloading,
          UpdateDownloadState.verifying,
          UpdateDownloadState.ready,
        ]),
      );
      final path = manager.filePath!;
      expect(await File(path).readAsBytes(), packageBytes);
      expect(await manager.openDownloadedPackage(), 'opened');
      manager.dispose();
      manager = AppUpdateManager(
        dio: dio,
        directory: () async => directory,
        platform: 'windows',
      );
      await manager.download(updateInfo());
      expect(manager.filePath, path);
      expect(requests, 1);
      expect(await Directory('${directory.path}/updates').list().length, 1);
    },
  );

  test(
    'simultaneous callers and listener reentry share one download',
    () async {
      Future<void>? reentered;
      manager.addListener(() {
        reentered ??= manager.download(updateInfo());
      });
      final first = manager.download(updateInfo());
      final second = manager.download(updateInfo());
      expect(identical(first, second), isTrue);
      expect(identical(first, reentered), isTrue);
      await first;
      expect(requests, 1);
    },
  );

  for (final failure in ['hash', 'size', 'html']) {
    test('rejects $failure mismatch and removes incomplete download', () async {
      if (failure == 'html') {
        dio.httpClientAdapter = MockHttpAdapter(
          (_) => packageResponse(List.filled(packageBytes.length, 60)),
        );
      }
      await manager.download(
        updateInfo(
          hash: failure == 'hash' ? '0' * 64 : null,
          size: failure == 'size' ? packageBytes.length + 1 : null,
        ),
      );
      expect(manager.state, UpdateDownloadState.failed);
      expect(manager.error, 'integrity');
      expect(manager.filePath, isNull);
      expect(await Directory('${directory.path}/updates').list().length, 0);
      await expectLater(manager.openDownloadedPackage(), throwsStateError);
    });
  }

  test(
    'cancel then retry completes without exposing a partial package',
    () async {
      final started = Completer<void>();
      final response = Completer<ResponseBody>();
      dio.httpClientAdapter = MockHttpAdapter((_) {
        started.complete();
        return response.future;
      });
      final operation = manager.download(updateInfo());
      await started.future;
      manager.cancel();
      await operation;
      response.complete(packageResponse());
      expect(manager.state, UpdateDownloadState.cancelled);
      expect(manager.filePath, isNull);
      expect(await Directory('${directory.path}/updates').list().length, 0);
      dio.httpClientAdapter = MockHttpAdapter((_) => packageResponse());
      await manager.download(updateInfo());
      expect(manager.state, UpdateDownloadState.ready);
    },
  );

  test('network failure is retryable and never marks package ready', () async {
    dio.httpClientAdapter = MockHttpAdapter(
      (_) => ResponseBody.fromString('Unavailable', 503),
    );
    await manager.download(updateInfo());
    expect(manager.state, UpdateDownloadState.failed);
    expect(manager.error, 'download');
    dio.httpClientAdapter = MockHttpAdapter((_) => packageResponse());
    await manager.download(updateInfo());
    expect(manager.state, UpdateDownloadState.ready);
  });

  test(
    'rejects path traversal, foreign URL and incompatible bundles before IO',
    () async {
      for (final info in [
        updateInfo(name: '../flexbooru-windows-x64.zip'),
        updateInfo(url: 'https://example.com/$assetName'),
        updateInfo(name: 'flexbooru-android.aab'),
        updateInfo(name: 'flexbooru-linux-x64.zip'),
      ]) {
        await manager.download(info);
        expect(manager.state, UpdateDownloadState.failed);
      }
      expect(requests, 0);
      expect(await directory.list().length, 0);
    },
  );

  test(
    'uses published SHA256SUMS when GitHub asset digest is absent',
    () async {
      final checksumUrl = '$assetRoot/windows-SHA256SUMS.txt';
      final hash = sha256.convert(packageBytes).toString();
      dio.httpClientAdapter = MockHttpAdapter(
        (request) => request.uri.toString() == checksumUrl
          ? ResponseBody.fromString('\uFEFF$hash  ./$assetName\n', 200)
            : packageResponse(),
      );
      await manager.download(
        updateInfo(publishedDigest: false, checksumUrl: checksumUrl),
      );
      expect(manager.state, UpdateDownloadState.ready);
      // Ready packages can be opened offline without fetching checksums again.
      dio.httpClientAdapter = MockHttpAdapter(
        (_) => throw StateError('Offline'),
      );
      expect(await manager.openDownloadedPackage(), 'opened');
    },
  );

  test('fails closed when checksum list has no matching asset', () async {
    dio.httpClientAdapter = MockHttpAdapter(
      (request) => request.uri.path.endsWith('.txt')
          ? ResponseBody.fromString('${'0' * 64}  other.zip\n', 200)
          : packageResponse(),
    );
    await manager.download(
      updateInfo(
        publishedDigest: false,
        checksumUrl: '$assetRoot/windows-SHA256SUMS.txt',
      ),
    );
    expect(manager.state, UpdateDownloadState.failed);
    expect(manager.error, 'integrity');
  });

  test(
    'revalidates before install and repairs a corrupted cached download',
    () async {
      await manager.download(updateInfo());
      final file = File(manager.filePath!);
      await file.writeAsBytes([0x50, 0x4b, 3, 4, ...List.filled(128, 0)]);
      await expectLater(manager.openDownloadedPackage(), throwsFormatException);
      expect(manager.state, UpdateDownloadState.failed);
      expect(manager.filePath, isNull);
      await manager.download(updateInfo());
      expect(manager.state, UpdateDownloadState.ready);
      expect(requests, 2);
      expect(await file.readAsBytes(), packageBytes);
    },
  );
}
