import 'dart:convert';
import 'dart:io';

/// Lossless storage compaction. Tombstones remain available to offline peers.
Map<String, dynamic> packSyncJournal(Map<String, dynamic> data) {
  final compact = Map<String, dynamic>.of(data);
  if (data['records'] case final List records) {
    compact['records'] = records
        .map(
          (r) => r['deleted'] == true ? [r['key'], r['clock'], r['device']] : r,
        )
        .toList();
  }
  return {
    'storageFormat': 2,
    'gzip': base64Encode(gzip.encode(utf8.encode(jsonEncode(compact)))),
  };
}

Map<String, dynamic> unpackSyncJournal(Map<String, dynamic> data) {
  if (data['storageFormat'] != 2) return data;
  final bytes = gzip.decode(base64Decode(data['gzip'] as String));
  if (bytes.length > 64 * 1024 * 1024) {
    throw const FormatException('Sync journal too large');
  }
  final result = (jsonDecode(utf8.decode(bytes)) as Map)
      .cast<String, dynamic>();
  if (result['records'] case final List records) {
    result['records'] = records
        .map(
          (item) => item is List
              ? {
                  'key': item[0],
                  'clock': item[1],
                  'device': item[2],
                  'value': null,
                  'deleted': true,
                }
              : item,
        )
        .toList();
  }
  return result;
}
