import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/sync/drive_sync_crypto.dart';
import '../core/sync/sync_state.dart';
import 'google_drive_auth.dart';
import 'google_drive_transport.dart';
import 'lan_sync_service.dart';

class GoogleDriveSyncService extends ChangeNotifier {
  GoogleDriveSyncService(
    this.local, {
    GoogleDriveAuth? auth,
    DriveSyncTransport? transport,
  }) : auth = auth ?? GoogleDriveAuth(),
       _transport = transport {
    _subscription = local.changes.stream.listen((_) => _schedule());
  }
  final LanSyncService local;
  final GoogleDriveAuth auth;
  DriveSyncTransport? _transport;
  StreamSubscription<void>? _subscription;
  Timer? _poll, _debounce;
  Future<void>? _running;
  DriveSyncCipher? _cipher;
  bool enabled = false, paused = false, _disposed = false, _pending = false;
  String status = 'off';
  String? error;
  DateTime? lastSync;
  int _generation = 0;
  String? _lastUploaded;
  bool get busy => _running != null || status == 'connecting';
  static const _passwordKey = 'flex_drive_sync_password_v1';
  static const _enabledKey = 'flex_drive_sync_enabled_v1';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> resumeSaved() async {
    try {
      await auth.load();
      final enabledRaw = await auth.storage.read(key: _enabledKey);
      final password = await auth.storage.read(key: _passwordKey);
      if (enabledRaw != 'true' || password == null) return;
      _cipher = DriveSyncCipher(password);
      enabled = true;
      _startPolling();
      await syncNow();
    } catch (_) {
      error = 'storage';
      status = 'error';
      _notify();
    }
  }

  Future<void> configure(DriveOAuthConfig config) async {
    await disconnect();
    await auth.configure(config);
    _notify();
  }

  Future<void> connect(String password) async {
    if (busy) throw StateError('Cloud sync is busy');
    if (password.length < 12) {
      throw ArgumentError('Use at least 12 characters for the sync password');
    }
    final generation = ++_generation;
    status = 'connecting';
    error = null;
    _notify();
    try {
      await auth.token(interactive: true);
      if (_disposed || generation != _generation) return;
      _cipher = DriveSyncCipher(password);
      _lastUploaded = null;
      enabled = true;
      await syncNow();
      if (_disposed || generation != _generation) return;
      if (error != null) {
        enabled = false;
        return;
      }
      await auth.storage.write(key: _passwordKey, value: password);
      await auth.storage.write(key: _enabledKey, value: 'true');
      if (_disposed || generation != _generation) {
        await auth.storage.delete(key: _passwordKey);
        await auth.storage.delete(key: _enabledKey);
        return;
      }
      _startPolling();
    } catch (_) {
      if (_disposed || generation != _generation) return;
      enabled = false;
      status = 'error';
      error = 'authorization';
    }
    _notify();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _schedule(immediate: true),
    );
  }

  void _schedule({bool immediate = false}) {
    if (!enabled || paused || _disposed) return;
    _pending = true;
    _debounce?.cancel();
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(seconds: 2),
      () => unawaited(syncNow()),
    );
  }

  Future<void> syncNow() {
    if (!enabled || paused || _disposed || _cipher == null) {
      return Future.value();
    }
    if (_running != null) return _running!;
    _pending = false;
    final operation = _cycle(_generation).whenComplete(() {
      _running = null;
      _notify();
      if (_pending) _schedule();
    });
    _running = operation;
    _notify();
    return operation;
  }

  bool _active(int generation) =>
      !_disposed && !paused && enabled && generation == _generation;
  Future<void> _cycle(int generation) async {
    status = 'syncing';
    error = null;
    try {
      await local.initialize();
      final transport = _transport ??= GoogleDriveTransport(
        () => auth.token(),
        auth.invalidate,
      );
      final files = await transport.list();
      final merged = SyncState(local.deviceId);
      // Validate/decrypt every remote snapshot before touching local data.
      String? salt;
      for (final file in files) {
        final raw = await transport.read(file.id);
        if (!_active(generation)) return;
        final data = await _cipher!.open(raw);
        merged.merge(data['records'] as List, snapshot: true);
        salt ??= (jsonDecode(raw) as Map)['salt'] as String;
      }
      if (!_active(generation)) return;
      await local.mergeCloudRecords(merged.records);
      if (!_active(generation)) return;
      final records = local.records;
      final fingerprint = crypto.sha256
          .convert(utf8.encode(jsonEncode(records)))
          .toString();
      final name = 'flexbooru-sync-v1-${local.deviceId}.json';
      final own = files.where((file) => file.name == name).firstOrNull;
      if (fingerprint != _lastUploaded || own == null) {
        final encrypted = await _cipher!.seal(
          records,
          device: local.deviceId,
          salt: salt,
        );
        if (!_active(generation)) return;
        await transport.write(name, encrypted, id: own?.id);
        if (!_active(generation)) return;
        _lastUploaded = fingerprint;
      }
      if (!_active(generation)) return;
      lastSync = DateTime.now();
      status = 'connected';
    } on SecretBoxAuthenticationError {
      if (!_active(generation)) return;
      error = 'password';
      status = 'error';
    } on DioException catch (exception) {
      if (!_active(generation)) return;
      error =
          exception.response?.statusCode == 401 ||
              exception.response?.statusCode == 403
          ? 'authorization'
          : 'network';
      status = 'error';
    } on FormatException {
      if (!_active(generation)) return;
      error = 'data';
      status = 'error';
    } catch (_) {
      if (!_active(generation)) return;
      error = 'authorization';
      status = 'error';
    }
    _notify();
  }

  void pause(bool value) {
    paused = value;
    if (value) {
      _generation++;
      _debounce?.cancel();
      _transport?.cancel();
    } else {
      _schedule(immediate: true);
    }
  }

  Future<void> disconnect() async {
    _generation++;
    _transport?.cancel();
    enabled = false;
    _poll?.cancel();
    _debounce?.cancel();
    _cipher = null;
    _lastUploaded = null;
    error = null;
    status = 'off';
    await auth.signOut();
    await auth.storage.delete(key: _passwordKey);
    await auth.storage.delete(key: _enabledKey);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _transport?.cancel();
    _generation++;
    _poll?.cancel();
    _debounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
