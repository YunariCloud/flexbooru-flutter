import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/sync/sync_crypto.dart';
import '../core/sync/sync_persistence.dart';
import '../core/sync/sync_preferences.dart';
import '../core/sync/sync_state.dart';
import '../models/booru_site.dart';
import '../models/search_state.dart';

class SyncPairRequest {
  SyncPairRequest._(this.deviceId, this.name, this._link, this._invite);
  final String deviceId;
  final String name;
  final _SyncLink _link;
  final String _invite;
}

class LanSyncService extends ChangeNotifier {
  LanSyncService({
    SyncPersistence? persistence,
    SharedPreferences? preferences,
    this.attachToApp = true,
    this.supportsSearchState = true,
  }) : _persistence = persistence,
       _preferences = preferences;
  final bool attachToApp;
  final bool supportsSearchState;
  SyncPersistence? _persistence;
  SharedPreferences? _preferences;
  Future<void>? _initialization;
  Future<void> _tail = Future.value();
  SyncState? _state;
  String deviceName = kIsWeb
      ? 'Device'
      : Platform.isWindows
      ? 'Windows'
      : 'Android';
  String? error;
  String status = 'off';
  String mode = 'off';
  int port = 45873;
  DateTime? lastSync;
  HttpServer? _server;
  final Set<_SyncLink> _links = {};
  final Map<String, Map<String, dynamic>> _trusted = {};
  final List<SyncPairRequest> pending = [];
  Map<String, dynamic>? _target;
  String? _invitation;
  DateTime? invitationExpires;
  Timer? _inviteTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _paused = false;
  int _generation = 0;
  int _retrySeconds = 2;
  Future<bool> Function(String, Object?, Object?)? _appHook;

  String get deviceId => _state?.device ?? '';
  bool get isHosting => _server != null;
  bool get isConnected => _links.any((link) => link.authorized);
  List<String> get connectedDevices =>
      _links.where((l) => l.authorized).map((l) => l.name).toList();
  Map<String, String> get trustedDevices =>
      _trusted.map((key, value) => MapEntry(key, value['name'] as String));
  String? get hostAddress => _target?['host'] as String?;
  List<Map<String, dynamic>> get records => _state?.records ?? [];

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace stack) {});
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initialization ??= _initialize().catchError((
    Object exception,
    StackTrace stack,
  ) {
    _initialization = null;
    status = 'error';
    error = 'vault';
    _notify();
    Error.throwWithStackTrace(exception, stack);
  });
  Future<void> _initialize() async {
    if (attachToApp) {
      // Block writes until encrypted storage is ready, including after a failure.
      _appHook = (key, value, previous) =>
          updatePreference(key, value, previousValue: previous);
      SyncPreferences.writeHook = _appHook;
    }
    _preferences ??= await SharedPreferences.getInstance();
    _persistence ??= EncryptedSyncPersistence(_preferences!);
    final saved = await _persistence!.load();
    _state = SyncState(saved?['device'] as String? ?? randomSyncKey());
    if (saved != null) {
      _state!.merge(saved['records'] as List, snapshot: true);
      deviceName = saved['name'] as String;
      mode = saved['mode'] as String;
      port = saved['port'] as int;
      _target = (saved['target'] as Map?)?.cast<String, dynamic>();
      for (final entry in (saved['trusted'] as Map).entries) {
        _trusted[entry.key as String] = (entry.value as Map)
            .cast<String, dynamic>();
      }
    }
    // Providers are created only after initialization in production. The
    // journal is authoritative after migration, even if a mirror write failed.
    final preferences = _preferences!;
    if (saved == null) {
      for (final key in preferences.getKeys().where(isSyncedPreference)) {
        var value = preferences.get(key);
        if (key == searchPreference && value is String) {
          var invalid = 0;
          final recovered = SearchRecord.decode(
            value,
            tolerant: true,
            onInvalid: () => invalid++,
          );
          if (invalid > 0) {
            if (!preferences.containsKey(
              '${searchPreference}_recovery_backup',
            )) {
              await preferences.setString(
                '${searchPreference}_recovery_backup',
                value,
              );
            }
            value = jsonEncode(recovered.map((r) => r.toJson()).toList());
            await preferences.setString(searchPreference, value);
          }
        }
        _state!.capture(key, value, seed: true);
      }
      if (!preferences.containsKey(sitesPreference)) {
        _state!.capture(
          sitesPreference,
          jsonEncode(BooruSite.defaultPresets.map((s) => s.toJson()).toList()),
          seed: true,
        );
      }
    }
    if (!_state!.entries.keys.any((key) => key.startsWith('search/')) &&
        preferences.containsKey(searchPreference)) {
      _state!.capture(
        searchPreference,
        jsonEncode(
          SearchRecord.decode(
            preferences.getString(searchPreference),
            tolerant: true,
          ).map((r) => r.toJson()).toList(),
        ),
        seed: true,
      );
    }
    await _save(_state!);
    await _mirror({
      sitesPreference,
      favoritesPreference,
      blacklistPreference,
      historyPreference,
      searchPreference,
      ...syncedSettings,
    });
    if (attachToApp) {
      SyncPreferences.secureSitesReader = () =>
          _state!.readPreference(sitesPreference) as String;
      SyncPreferences.remoteChanges.add({
        sitesPreference,
        favoritesPreference,
        blacklistPreference,
        historyPreference,
        searchPreference,
        ...syncedSettings,
      });
    }
    status = 'off';
    _notify();
  }

  /// Called only after app providers have loaded. Does not open ports on first use.
  Future<void> resumeSavedMode() async {
    await initialize();
    if (mode == 'host') {
      await startHost();
    } else if (mode == 'client' && _target != null) {
      await _connect();
    }
  }

  Future<void> _save(SyncState state) => _persistence!.save({
    'version': 1,
    'device': state.device,
    'name': deviceName,
    'mode': mode,
    'port': port,
    'target': _target,
    'trusted': _trusted,
    'records': state.records,
  });

  Future<void> _mirror(Set<String> keys) async {
    for (final key in keys) {
      Object? value = _state!.readPreference(key);
      if (key == sitesPreference) {
        final sites = (jsonDecode(value as String) as List).map((v) {
          final site = (v as Map).cast<String, dynamic>();
          site.remove('username');
          site.remove('token');
          return site;
        }).toList();
        value = jsonEncode(sites);
      }
      if (!await SyncPreferences.writeRaw(_preferences!, key, value)) {
        throw StateError('Unable to save local preferences');
      }
    }
  }

  Future<bool> updatePreference(
    String key,
    Object? value, {
    Object? previousValue,
  }) async {
    if (!isSyncedPreference(key)) return false;
    await initialize();
    return _serial(() async {
      final next = _state!.copy();
      if (!next.capture(key, value, previousValue: previousValue)) return true;
      final delta = next.entries.values
          .where((entry) => !identical(_state!.entries[entry.key], entry))
          .map((entry) => entry.toJson())
          .toList();
      await _save(next);
      _state = next;
      await _mirror({key});
      if (attachToApp &&
          previousValue != null &&
          jsonEncode(next.readPreference(key)) != jsonEncode(value)) {
        SyncPreferences.remoteChanges.add({key});
      }
      await _broadcast(delta);
      return true;
    });
  }

  Future<void> _merge(List<dynamic> records, {bool snapshot = false}) =>
      _serial(() async {
        final next = _state!.copy();
        final changed = next.merge(records, snapshot: snapshot);
        if (changed.isEmpty) return;
        final accepted = records.where((record) {
          final current = _state!.entries[record['key']];
          return current == null ||
              next.entries[record['key']]!.newerThan(current);
        }).toList();
        await _save(next);
        _state = next;
        await _mirror(changed);
        lastSync = DateTime.now();
        if (attachToApp) SyncPreferences.remoteChanges.add(changed);
        _notify();
        await _broadcast(accepted);
      });

  Future<void> _broadcast(List<dynamic> records) async {
    for (final link in _links.toList().where((link) => link.authorized)) {
      try {
        await _sendRecords(link, records);
      } catch (_) {
        link.close();
      }
    }
  }

  Future<void> _sendRecords(_SyncLink link, List<dynamic> records) async {
    var batch = <dynamic>[];
    var bytes = 0;
    for (final record in records) {
      if ((record['key'] as String).startsWith('search/') &&
          (!supportsSearchState || !link.searchSupported)) {
        continue;
      }
      final size = utf8.encode(jsonEncode(record)).length;
      if (batch.isNotEmpty &&
          (batch.length >= 100 || bytes + size > 3 * 1024 * 1024)) {
        await link.send({
          'type': 'records',
          'records': batch,
          if (supportsSearchState) 'capabilities': ['search_v2'],
        });
        batch = [];
        bytes = 0;
      }
      batch.add(record);
      bytes += size;
    }
    if (batch.isNotEmpty || records.isEmpty || !link.capabilitiesSent) {
      link.capabilitiesSent = true;
      await link.send({
        'type': 'records',
        'records': batch,
        if (supportsSearchState) 'capabilities': ['search_v2'],
      });
    }
  }

  Future<void> setDeviceName(String name) async {
    await initialize();
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 80) {
      throw const FormatException('Invalid device name');
    }
    await _serial(() async {
      deviceName = clean;
      await _save(_state!);
    });
    _notify();
  }

  Future<void> startHost({int? listenPort, InternetAddress? address}) async {
    await initialize();
    if (isHosting) return;
    await _closeConnections();
    try {
      _server = await HttpServer.bind(
        address ?? InternetAddress.anyIPv4,
        listenPort ?? port,
      );
      port = _server!.port;
      mode = 'host';
      status = 'hosting';
      error = null;
      await _serial(() => _save(_state!));
      _server!.listen(
        _accept,
        onError: (Object _) {
          error = 'host';
          _notify();
        },
      );
      newInvitation();
      _notify();
    } catch (_) {
      await _server?.close(force: true);
      _server = null;
      status = 'error';
      error = 'host';
      _notify();
      rethrow;
    }
  }

  void newInvitation() {
    if (!isHosting) return;
    for (final request in pending.toList()) {
      request._link.close();
    }
    pending.clear();
    _invitation = randomSyncKey();
    invitationExpires = DateTime.now().add(const Duration(minutes: 5));
    _inviteTimer?.cancel();
    _inviteTimer = Timer(const Duration(minutes: 5), () {
      _invitation = null;
      invitationExpires = null;
      for (final request in pending.toList()) {
        request._link.close();
      }
      pending.clear();
      _notify();
    });
    _notify();
  }

  String pairingLink(String address) {
    if (_invitation == null) return '';
    return Uri(
      scheme: 'flexbooru-sync',
      host: 'pair',
      queryParameters: {
        'host': address,
        'port': '$port',
        'id': deviceId,
        'key': _invitation!,
      },
    ).toString();
  }

  static Map<String, dynamic> parsePairingLink(String value) {
    final uri = Uri.parse(value.trim());
    final parameters = uri.queryParameters;
    final host = InternetAddress.tryParse(parameters['host'] ?? '');
    final port = int.tryParse(parameters['port'] ?? '');
    final key = parameters['key'] ?? '';
    final id = parameters['id'] ?? '';
    if (uri.scheme != 'flexbooru-sync' ||
        uri.host != 'pair' ||
        host == null ||
        !isLanAddress(host) ||
        port == null ||
        port < 1024 ||
        port > 65535 ||
        base64Url.decode(key).length != 32 ||
        id.isEmpty ||
        id.length > 128) {
      throw const FormatException('Invalid LAN pairing link');
    }
    return {
      'host': host.address,
      'port': port,
      'hostId': id,
      'key': key,
      'pairing': true,
    };
  }

  Future<void> pair(String pairingLink) async {
    final target = parsePairingLink(pairingLink);
    await initialize();
    await _closeConnections();
    await _server?.close(force: true);
    _server = null;
    _inviteTimer?.cancel();
    _invitation = null;
    invitationExpires = null;
    _target = target;
    mode = 'client';
    await _serial(() => _save(_state!));
    await _connect();
  }

  Future<void> updateHostAddress(String address) async {
    final parsed = InternetAddress.tryParse(address.trim());
    if (_target == null || parsed == null || !isLanAddress(parsed)) {
      throw const FormatException('Invalid LAN address');
    }
    await _closeConnections();
    _target!['host'] = parsed.address;
    await _serial(() => _save(_state!));
    await _connect();
  }

  Future<void> _accept(HttpRequest request) async {
    try {
      final remote = request.connectionInfo?.remoteAddress;
      if (remote == null ||
          !isLanAddress(remote) ||
          request.uri.path != '/sync' ||
          !WebSocketTransformer.isUpgradeRequest(request) ||
          _links.length >= 8) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(
        request,
        compression: CompressionOptions.compressionOff,
      );
      _listen(_SyncLink(socket, server: true));
    } catch (_) {
      request.response.close();
    }
  }

  void _listen(_SyncLink link) {
    _links.add(link);
    link.socket.pingInterval = const Duration(seconds: 20);
    link.timeout = Timer(const Duration(seconds: 20), link.close);
    link.subscription = link.socket
        .asyncMap((frame) async {
          try {
            if (frame is! String || frame.length > 12 * 1024 * 1024) {
              throw const FormatException('Invalid sync frame');
            }
            await _message(link, frame);
          } catch (_) {
            if (!link.server) {
              error = link.authorized ? 'data' : 'auth';
              _notify();
            }
            link.close();
          }
        })
        .listen(
          (_) {},
          onError: (Object _) => link.close(),
          onDone: () {
            link.timeout?.cancel();
            _links.remove(link);
            pending.removeWhere((request) => identical(request._link, link));
            if (!link.server && mode == 'client' && !_disposed) {
              status = 'waiting';
              _scheduleReconnect();
            }
            _notify();
          },
        );
  }

  Future<void> _message(_SyncLink link, String frame) async {
    if (link.cipher != null) {
      final message = await link.cipher!.decode(frame);
      switch (message['type']) {
        case 'pending':
          if (link.server || link.authorized) {
            throw const FormatException('Unexpected approval request');
          }
          status = 'approval';
          link.timeout?.cancel();
          link.timeout = Timer(const Duration(minutes: 2), link.close);
          _notify();
        case 'welcome':
          if (link.server ||
              link.authorized ||
              message['hostId'] != _target?['hostId']) {
            throw const FormatException('Unexpected welcome');
          }
          final peerKey = message['key'] as String;
          if (base64Url.decode(peerKey).length != 32) {
            throw const FormatException('Invalid peer key');
          }
          await _serial(() async {
            _target!['key'] = peerKey;
            _target!['pairing'] = false;
            await _save(_state!);
          });
          link.searchSupported =
              supportsSearchState &&
              (message['capabilities'] as List? ?? []).contains('search_v2');
          link.authorized = true;
          link.timeout?.cancel();
          status = 'connected';
          error = null;
          _retrySeconds = 2;
          _notify();
          await _sendRecords(link, _state!.records);
        case 'records':
          if (!link.authorized) {
            throw const FormatException('Sync peer not approved');
          }
          final gainedSearch =
              supportsSearchState &&
              !link.searchSupported &&
              (message['capabilities'] as List? ?? []).contains('search_v2');
          if (gainedSearch) link.searchSupported = true;
          final incoming = message['records'] as List;
          if (!supportsSearchState &&
              incoming.any((r) => (r['key'] as String).startsWith('search/'))) {
            throw const FormatException('Unsupported search records');
          }
          await _merge(incoming);
          if (gainedSearch) await _sendRecords(link, _state!.records);
          lastSync = DateTime.now();
          _notify();
        case 'rejected':
          if (link.server) throw const FormatException('Unexpected rejection');
          error = 'rejected';
          mode = 'off';
          status = 'off';
          _target = null;
          await _serial(() => _save(_state!));
          link.close();
          _notify();
        default:
          throw const FormatException('Unknown sync message');
      }
      return;
    }
    if (frame.length > 4096) throw const FormatException('Handshake too large');
    final message = (jsonDecode(frame) as Map).cast<String, dynamic>();
    if (link.server && message['type'] == 'hello' && link.context == null) {
      link.deviceId = message['device'] as String;
      link.name = message['name'] as String;
      if (link.deviceId.isEmpty ||
          link.deviceId.length > 128 ||
          link.name.isEmpty ||
          link.name.length > 80) {
        throw const FormatException('Invalid peer');
      }
      final pairing = message['pairing'] == true;
      link.masterKey = pairing
          ? _invitation
          : _trusted[link.deviceId]?['key'] as String?;
      if (link.masterKey == null ||
          (pairing && (invitationExpires?.isAfter(DateTime.now()) != true))) {
        throw const FormatException('Unknown peer');
      }
      final clientNonce = message['nonce'] as String;
      if (base64Url.decode(clientNonce).length != 32) {
        throw const FormatException('Invalid nonce');
      }
      final serverNonce = randomSyncKey();
      link.context = jsonEncode([
        1,
        deviceId,
        link.deviceId,
        clientNonce,
        serverNonce,
      ]);
      link.socket.add(
        jsonEncode({
          'type': 'challenge',
          'nonce': serverNonce,
          'hostId': deviceId,
        }),
      );
    } else if (link.server &&
        message['type'] == 'auth' &&
        link.context != null) {
      if (!constantTimeEqual(
        message['proof'] as String,
        await syncProof(link.masterKey!, link.context!),
      )) {
        throw const FormatException('Invalid proof');
      }
      link.cipher = await SyncCipher.create(
        link.masterKey!,
        link.context!,
        server: true,
      );
      if (_trusted[link.deviceId]?['key'] == link.masterKey) {
        await _authorize(link, link.masterKey!);
      } else {
        if (link.masterKey != _invitation ||
            invitationExpires?.isAfter(DateTime.now()) != true) {
          throw const FormatException('Invitation expired or peer revoked');
        }
        if (pending.length >= 4 ||
            pending.any((request) => request.deviceId == link.deviceId)) {
          throw const FormatException('Duplicate pairing request');
        }
        pending.add(
          SyncPairRequest._(link.deviceId, link.name, link, link.masterKey!),
        );
        link.timeout?.cancel();
        link.timeout = Timer(const Duration(minutes: 2), link.close);
        await link.send({'type': 'pending'});
        _notify();
      }
    } else if (!link.server &&
        message['type'] == 'challenge' &&
        link.context == null) {
      if (message['hostId'] != _target?['hostId']) {
        throw const FormatException('Host identity mismatch');
      }
      final nonce = message['nonce'] as String;
      if (base64Url.decode(nonce).length != 32) {
        throw const FormatException('Invalid nonce');
      }
      link.context = jsonEncode([
        1,
        message['hostId'],
        deviceId,
        link.clientNonce,
        nonce,
      ]);
      link.socket.add(
        jsonEncode({
          'type': 'auth',
          'proof': await syncProof(link.masterKey!, link.context!),
        }),
      );
      link.cipher = await SyncCipher.create(
        link.masterKey!,
        link.context!,
        server: false,
      );
    } else {
      throw const FormatException('Unexpected handshake');
    }
  }

  Future<void> approve(SyncPairRequest request) async {
    if (!pending.contains(request) ||
        request._invite != _invitation ||
        invitationExpires?.isAfter(DateTime.now()) != true ||
        !_links.contains(request._link)) {
      return;
    }
    // An independent key keeps other holders of the invitation from deriving
    // this device's long-term credential after approval.
    final key = randomSyncKey();
    await _serial(() async {
      _trusted[request.deviceId] = {'name': request.name, 'key': key};
      await _save(_state!);
    });
    pending.remove(request);
    await _authorize(request._link, key);
    newInvitation();
    _notify();
  }

  Future<void> reject(SyncPairRequest request) async {
    pending.remove(request);
    try {
      await request._link.send({'type': 'rejected'});
    } finally {
      request._link.close();
      _notify();
    }
  }

  Future<void> _authorize(_SyncLink link, String key) async {
    for (final other in _links.toList()) {
      if (!identical(link, other) && other.deviceId == link.deviceId) {
        other.close();
      }
    }
    link.authorized = true;
    link.timeout?.cancel();
    await link.send({
      'type': 'welcome',
      'key': key,
      'hostId': deviceId,
      if (supportsSearchState) 'capabilities': ['search_v2'],
    });
    await _sendRecords(link, _state!.records);
    _notify();
  }

  Future<void> revoke(String id) async {
    await _serial(() async {
      _trusted.remove(id);
      await _save(_state!);
    });
    for (final link in _links.toList().where((link) => link.deviceId == id)) {
      if (link.authorized) {
        try {
          await link.send({'type': 'rejected'});
        } catch (_) {
          /* Already disconnected. */
        }
      }
      link.close();
    }
    _notify();
  }

  Future<void> _connect() async {
    if (_disposed || _paused || _target == null || mode != 'client') return;
    final generation = ++_generation;
    status = 'connecting';
    error = null;
    _notify();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    var abandoned = false;
    try {
      final connecting = WebSocket.connect(
        Uri(
          scheme: 'ws',
          host: _target!['host'] as String,
          port: _target!['port'] as int,
          path: '/sync',
        ).toString(),
        compression: CompressionOptions.compressionOff,
        customClient: client,
      );
      unawaited(
        connecting.then((socket) async {
          if (abandoned || _disposed || generation != _generation) {
            await socket.close();
          }
        }, onError: (Object _) {}),
      );
      final socket = await connecting.timeout(const Duration(seconds: 10));
      if (_disposed || generation != _generation) {
        await socket.close();
        return;
      }
      final link = _SyncLink(socket, server: false)
        ..masterKey = _target!['key'] as String
        ..deviceId = _target!['hostId'] as String
        ..name = 'Windows';
      link.clientNonce = randomSyncKey();
      _listen(link);
      socket.add(
        jsonEncode({
          'type': 'hello',
          'device': deviceId,
          'name': deviceName,
          'nonce': link.clientNonce,
          'pairing': _target!['pairing'] == true,
        }),
      );
    } catch (_) {
      abandoned = true;
      if (_disposed || generation != _generation) return;
      status = 'waiting';
      error = 'connection';
      _notify();
      _scheduleReconnect();
    } finally {
      client.close(force: true);
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _paused || mode != 'client' || _target == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _retrySeconds), _connect);
    _retrySeconds = (_retrySeconds * 2).clamp(2, 30);
  }

  Future<void> reconnect() async {
    await _closeConnections();
    if (mode == 'client') await _connect();
  }

  Future<void> pauseClient(bool paused) async {
    if (_paused == paused) return;
    _paused = paused;
    if (mode != 'client') return;
    if (paused) {
      await _closeConnections();
      status = 'waiting';
      _notify();
    } else {
      await _connect();
    }
  }

  Future<void> stop() async {
    await initialize();
    mode = 'off';
    status = 'off';
    await _closeConnections();
    await _server?.close(force: true);
    _server = null;
    _inviteTimer?.cancel();
    _invitation = null;
    invitationExpires = null;
    pending.clear();
    await _serial(() => _save(_state!));
    _notify();
  }

  Future<void> forgetHost() async {
    _target = null;
    await stop();
  }

  Future<void> _closeConnections() async {
    _generation++;
    _reconnectTimer?.cancel();
    final links = _links.toList();
    _links.clear();
    for (final link in links) {
      link.timeout?.cancel();
      await link.subscription?.cancel();
      await link.socket.close();
    }
    pending.clear();
  }

  static bool isLanAddress(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) return false;
    final bytes = address.rawAddress;
    return bytes[0] == 127 ||
        bytes[0] == 10 ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 169 && bytes[1] == 254);
  }

  static Future<List<String>> lanAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    return interfaces
        .expand((i) => i.addresses)
        .where((a) => isLanAddress(a) && !a.isLoopback)
        .map((a) => a.address)
        .toSet()
        .toList();
  }

  Future<void> shutdown() async {
    _disposed = true;
    _inviteTimer?.cancel();
    _reconnectTimer?.cancel();
    if (identical(SyncPreferences.writeHook, _appHook)) {
      SyncPreferences.writeHook = null;
      SyncPreferences.secureSitesReader = null;
    }
    await _closeConnections();
    await _server?.close(force: true);
    _server = null;
    await _tail;
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}

class _SyncLink {
  _SyncLink(this.socket, {required this.server});
  final WebSocket socket;
  final bool server;
  String deviceId = '';
  String name = '';
  String? clientNonce;
  String? context;
  String? masterKey;
  SyncCipher? cipher;
  bool authorized = false;
  bool searchSupported = false;
  bool capabilitiesSent = false;
  Timer? timeout;
  StreamSubscription<dynamic>? subscription;
  Future<void> _sendTail = Future.value();

  Future<void> send(Object message) {
    final sent = _sendTail.then((_) async {
      if (socket.readyState != WebSocket.open) {
        throw StateError('Sync socket closed');
      }
      socket.add(await cipher!.encode(message));
    });
    _sendTail = sent.then<void>(
      (_) {},
      onError: (Object _, StackTrace stack) {},
    );
    return sent;
  }

  void close() {
    timeout?.cancel();
    unawaited(socket.close(WebSocketStatus.policyViolation));
  }
}
