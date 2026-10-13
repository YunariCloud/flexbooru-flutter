import 'dart:convert';
import 'dart:isolate';
import 'package:cryptography/cryptography.dart';
import 'sync_crypto.dart';
import 'sync_record_codec.dart';

class DriveSyncCipher {
  DriveSyncCipher(this.password);
  final String password;
  final Map<String, SecretKey> _keys = {};
  Future<SecretKey> _key(String salt) async {
    final bytes = base64Url.decode(salt);
    if (bytes.length != 32) throw const FormatException('Invalid cloud salt');
    if (_keys[salt] != null) return _keys[salt]!;
    final secretPassword = password;
    final keyBytes = await Isolate.run(
      () async =>
          (await Pbkdf2(
                macAlgorithm: Hmac.sha256(),
                iterations: 210000,
                bits: 256,
              ).deriveKey(
                secretKey: SecretKey(utf8.encode(secretPassword)),
                nonce: bytes,
              ))
              .extractBytes(),
    );
    return _keys[salt] = SecretKey(keyBytes);
  }

  Future<String> seal(
    List<Map<String, dynamic>> records, {
    required String device,
    String? salt,
  }) async {
    salt ??= randomSyncKey();
    final packed = await Isolate.run(
      () => packSyncJournal({'device': device, 'records': records}),
    );
    final box = await sealSyncData(
      packed,
      await _key(salt),
      aad: 'flexbooru-drive-sync-v1/$salt',
    );
    return jsonEncode({'version': 1, 'salt': salt, ...box});
  }

  Future<Map<String, dynamic>> open(String data) async {
    final envelope = (jsonDecode(data) as Map).cast<String, dynamic>();
    if (envelope['version'] != 1) {
      throw const FormatException('Unsupported cloud format');
    }
    final salt = envelope['salt'] as String;
    return unpackSyncJournal(
      await openSyncData(
        envelope,
        await _key(salt),
        aad: 'flexbooru-drive-sync-v1/$salt',
      ),
    );
  }
}
