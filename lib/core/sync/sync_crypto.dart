import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

String randomSyncKey() {
  final random = Random.secure();
  return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
}

Future<SecretKey> deriveSyncKey(String key, String context) =>
    Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(base64Url.decode(key)),
      nonce: utf8.encode('flexbooru-lan-sync-v1'),
      info: utf8.encode(context),
    );

Future<String> syncProof(String key, String context) async => base64UrlEncode(
  (await Hmac.sha256().calculateMac(
    utf8.encode(context),
    secretKey: SecretKey(base64Url.decode(key)),
  )).bytes,
);

bool constantTimeEqual(String a, String b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}

Future<Map<String, dynamic>> sealSyncData(
  Object data,
  SecretKey key, {
  String aad = 'vault-v1',
}) async {
  final algorithm = AesGcm.with256bits();
  final box = await algorithm.encrypt(
    utf8.encode(jsonEncode(data)),
    secretKey: key,
    nonce: algorithm.newNonce(),
    aad: utf8.encode(aad),
  );
  return {
    'nonce': base64UrlEncode(box.nonce),
    'data': base64UrlEncode(box.cipherText),
    'mac': base64UrlEncode(box.mac.bytes),
  };
}

Future<Map<String, dynamic>> openSyncData(
  Map<String, dynamic> envelope,
  SecretKey key, {
  String aad = 'vault-v1',
}) async {
  final bytes = await AesGcm.with256bits().decrypt(
    SecretBox(
      base64Url.decode(envelope['data'] as String),
      nonce: base64Url.decode(envelope['nonce'] as String),
      mac: Mac(base64Url.decode(envelope['mac'] as String)),
    ),
    secretKey: key,
    aad: utf8.encode(aad),
  );
  return (jsonDecode(utf8.decode(bytes)) as Map).cast<String, dynamic>();
}

/// Fresh directional keys and ordered counters reject replayed frames.
class SyncCipher {
  SyncCipher(this.sendKey, this.receiveKey);
  final SecretKey sendKey;
  final SecretKey receiveKey;
  int _sent = 0;
  int _received = 0;

  static Future<SyncCipher> create(
    String key,
    String context, {
    required bool server,
  }) async {
    final clientKey = await deriveSyncKey(key, '$context/client');
    final serverKey = await deriveSyncKey(key, '$context/server');
    return server
        ? SyncCipher(serverKey, clientKey)
        : SyncCipher(clientKey, serverKey);
  }

  Future<String> encode(Object data) async {
    final sequence = ++_sent;
    final envelope = await sealSyncData(
      data,
      sendKey,
      aad: 'frame-v1/$sequence',
    );
    return jsonEncode({'seq': sequence, ...envelope});
  }

  Future<Map<String, dynamic>> decode(String frame) async {
    if (frame.length > 12 * 1024 * 1024) {
      throw const FormatException('Sync frame too large');
    }
    final envelope = (jsonDecode(frame) as Map).cast<String, dynamic>();
    final sequence = envelope['seq'];
    if (sequence != _received + 1) {
      throw const FormatException('Unexpected sync sequence');
    }
    final data = await openSyncData(
      envelope,
      receiveKey,
      aad: 'frame-v1/$sequence',
    );
    _received = sequence as int;
    return data;
  }
}
