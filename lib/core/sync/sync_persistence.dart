import 'dart:convert';
import 'dart:isolate';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_crypto.dart';
import 'sync_record_codec.dart';

abstract class SyncPersistence {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> data);
}

/// Only the encryption key enters platform secure storage. The journal and
/// paired-device credentials are authenticated ciphertext in app preferences.
class EncryptedSyncPersistence implements SyncPersistence {
  EncryptedSyncPersistence(
    this.preferences, {
    Future<String?> Function()? readKey,
    Future<void> Function(String)? writeKey,
  }) : _readKey = readKey ?? (() => _secure.read(key: _keyName)),
       _writeKey =
           writeKey ?? ((value) => _secure.write(key: _keyName, value: value));

  final SharedPreferences preferences;
  final Future<String?> Function() _readKey;
  final Future<void> Function(String) _writeKey;
  static const _keyName = 'flexbooru_sync_vault_key_v1';
  static const journalKey = 'flexbooru_sync_encrypted_v1';
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(migrateWithBackup: true),
  );
  SecretKey? _key;

  Future<SecretKey> _getKey() async {
    if (_key != null) return _key!;
    var key = await _readKey();
    if (key == null) {
      if (preferences.containsKey(journalKey)) {
        throw StateError('Sync encryption key unavailable');
      }
      key = randomSyncKey();
      await _writeKey(key);
    }
    return _key = SecretKey(base64Url.decode(key));
  }

  @override
  Future<Map<String, dynamic>?> load() async {
    final key = await _getKey();
    final stored = preferences.getString(journalKey);
    if (stored == null) return null;
    return unpackSyncJournal(
      await openSyncData(
        (jsonDecode(stored) as Map).cast<String, dynamic>(),
        key,
      ),
    );
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    final packed = await Isolate.run(() => packSyncJournal(data));
    final encrypted = await sealSyncData(packed, await _getKey());
    if (!await preferences.setString(journalKey, jsonEncode(encrypted))) {
      throw StateError('Unable to save sync journal');
    }
  }
}
