import 'dart:convert';
import 'dart:math';
import '../../models/booru_site.dart';
import '../../models/post.dart';
import '../../models/search_state.dart';

const sitesPreference = 'flexbooru_sites';
const favoritesPreference = 'flexbooru_favorites';
const blacklistPreference = 'flexbooru_global_blacklist';
const historyPreference = 'flex_search_history';
const syncedSettings = {
  'flex_theme_mode',
  'flex_amoled',
  'flex_accent_color',
  'flex_gradient_end_color',
  'flex_use_gradient',
  'flex_columns',
  'flex_safe_mode',
  'flex_user_agent',
  'flex_image_quality',
  'flex_language',
  'flex_tag_language',
  'flex_auto_check_update',
  'flex_auto_download_update',
  'flexbooru_active_site_id',
};
const siteFields = {
  'name',
  'scheme',
  'host',
  'type',
  'hashSalt',
  'path',
  'credentials',
  'blacklists',
};
bool isSyncedPreference(String key) =>
    syncedSettings.contains(key) ||
    {
      sitesPreference,
      favoritesPreference,
      blacklistPreference,
      historyPreference,
      searchPreference,
    }.contains(key);

String syncId(String value) => base64UrlEncode(utf8.encode(value));
String decodeSyncId(String value) => utf8.decode(base64Url.decode(value));

class SyncEntry {
  const SyncEntry(
    this.key,
    this.value,
    this.clock,
    this.device, {
    this.deleted = false,
  });
  final String key;
  final Object? value;
  final int clock;
  final String device;
  final bool deleted;
  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'clock': clock,
    'device': device,
    'deleted': deleted,
  };
  factory SyncEntry.fromJson(Map<String, dynamic> json) {
    final entry = SyncEntry(
      json['key'] as String,
      json['value'],
      json['clock'] as int,
      json['device'] as String,
      deleted: json['deleted'] as bool,
    );
    if (entry.clock < 0 ||
        entry.clock > 9007199254740991 ||
        entry.device.length > 128 ||
        entry.device.isEmpty) {
      throw const FormatException('Invalid sync version');
    }
    validateSyncValue(entry.key, entry.value, deleted: entry.deleted);
    return entry;
  }
  bool newerThan(SyncEntry other) =>
      clock > other.clock ||
      (clock == other.clock && device.compareTo(other.device) > 0);
}

/// Per-field registers and per-item tombstones preserve independent offline edits.
class SyncState {
  SyncState(this.device);
  final String device;
  final Map<String, SyncEntry> entries = {};
  int clock = 0;
  SyncState copy() => SyncState(device)
    ..entries.addAll(entries)
    ..clock = clock;
  List<Map<String, dynamic>> get records =>
      entries.values.map((entry) => entry.toJson()).toList();

  Set<String> merge(List<dynamic> records, {bool snapshot = false}) {
    if (records.length > (snapshot ? 500000 : 50000)) {
      throw const FormatException('Too many sync records');
    }
    // Validate the entire message before changing local state.
    final parsed = records
        .map(
          (value) => SyncEntry.fromJson((value as Map).cast<String, dynamic>()),
        )
        .toList();
    final changed = <String>{};
    for (final entry in parsed) {
      clock = max(clock, entry.clock);
      final current = entries[entry.key];
      if (current == null || entry.newerThan(current)) {
        entries[entry.key] = entry;
        changed.add(preferenceForRecord(entry.key));
      }
    }
    return changed;
  }

  bool capture(
    String preference,
    Object? value, {
    bool seed = false,
    Object? previousValue,
  }) {
    if (!isSyncedPreference(preference)) return false;
    final next = _flatten(preference, value);
    final baseline = previousValue == null
        ? null
        : _flatten(preference, previousValue);
    for (final item in next.entries) {
      validateSyncValue(item.key, item.value);
    }
    final previousFirst = preference == historyPreference
        ? (readPreference(preference) as List).firstOrNull
        : null;
    final old = entries.values.where(
      (e) => preferenceForRecord(e.key) == preference && !e.deleted,
    );
    final removed = (baseline?.keys ?? old.map((e) => e.key))
        .where((key) => !next.containsKey(key))
        .toList();
    var changed = false;
    for (final key in removed) {
      // Site fields remain available, while the membership marker records deletion.
      if (preference == sitesPreference && !key.endsWith('/present')) continue;
      changed = _put(key, null, deleted: true, seed: seed) || changed;
    }
    var rank = 0;
    for (final item in next.entries.toList().reversed) {
      // Emit only the user's edits to their displayed snapshot. A remote item
      // arriving before the UI reloads must not be removed or overwritten.
      if (baseline != null &&
          baseline.containsKey(item.key) &&
          jsonEncode(baseline[item.key]) == jsonEncode(item.value)) {
        continue;
      }
      final ordered =
          item.key.startsWith('favorite/') ||
          item.key.startsWith('history/') ||
          item.key.endsWith('/present');
      changed =
          _put(
            item.key,
            item.value,
            seed: seed,
            seedClock: ordered ? ++rank : 0,
          ) ||
          changed;
    }
    // Searching for an existing query again moves it to the front.
    if (!seed &&
        preference == historyPreference &&
        value is List &&
        value.isNotEmpty) {
      final key = 'history/${syncId(value.first as String)}';
      if (previousFirst != value.first) {
        changed = _put(key, value.first, force: true) || changed;
      }
    }
    return changed;
  }

  bool _put(
    String key,
    Object? value, {
    bool deleted = false,
    bool seed = false,
    int seedClock = 0,
    bool force = false,
  }) {
    validateSyncValue(key, value, deleted: deleted);
    final current = entries[key];
    if (!force &&
        current != null &&
        current.deleted == deleted &&
        jsonEncode(current.value) == jsonEncode(value)) {
      return false;
    }
    clock = seed
        ? max(clock, seedClock)
        : max(clock + 1, DateTime.now().millisecondsSinceEpoch);
    entries[key] = SyncEntry(
      key,
      value,
      seed ? seedClock : clock,
      device,
      deleted: deleted,
    );
    return true;
  }

  Map<String, Object?> _flatten(String preference, Object? value) {
    if (syncedSettings.contains(preference)) {
      return value == null ? {} : {'setting/$preference': value};
    }
    final values = value is String
        ? jsonDecode(value) as List
        : (value as List? ?? []);
    final result = <String, Object?>{};
    for (final item in values) {
      if (preference == sitesPreference) {
        final site = (item as Map).cast<String, dynamic>();
        final id = syncId(site['id'] as String);
        result['site/$id/present'] = true;
        for (final field in siteFields) {
          if (field == 'credentials') {
            if (site['username'] != null ||
                site['token'] != null ||
                entries.containsKey('site/$id/credentials')) {
              result['site/$id/credentials'] = {
                'username': site['username'],
                'token': site['token'],
              };
            }
            continue;
          }
          // Missing credentials on a fresh device must not overwrite saved logins.
          if (site[field] != null || entries.containsKey('site/$id/$field')) {
            result['site/$id/$field'] = site[field];
          }
        }
      } else if (preference == searchPreference) {
        final record = SearchRecord.fromJson(
          (item as Map).cast<String, dynamic>(),
        );
        result['search/${syncId(record.id)}'] = record.toJson();
      } else if (preference == favoritesPreference) {
        final post = Post.fromJson(
          (item as Map).cast<String, dynamic>(),
        ).toJson();
        final id = syncId(jsonEncode([post['booruId'], post['id'].toString()]));
        result['favorite/$id'] = post;
      } else {
        final text = item as String;
        final prefix = preference == blacklistPreference
            ? 'blacklist'
            : 'history';
        result['$prefix/${syncId(text)}'] = text;
      }
    }
    return result;
  }

  Object? readPreference(String preference) {
    if (syncedSettings.contains(preference)) {
      final entry = entries['setting/$preference'];
      return entry?.deleted == false ? entry!.value : null;
    }
    final active =
        entries.values
            .where(
              (e) => !e.deleted && preferenceForRecord(e.key) == preference,
            )
            .toList()
          ..sort((a, b) {
            final order = b.clock.compareTo(a.clock);
            return order == 0 ? a.key.compareTo(b.key) : order;
          });
    if (preference == sitesPreference) {
      final sites = <Map<String, dynamic>>[];
      for (final marker in active.where((e) => e.key.endsWith('/present'))) {
        final prefix = marker.key.substring(
          0,
          marker.key.length - 'present'.length,
        );
        final site = <String, dynamic>{
          'id': decodeSyncId(marker.key.split('/')[1]),
        };
        for (final field in siteFields) {
          final value = entries['$prefix$field']?.value;
          if (field == 'credentials') {
            if (value is Map) site.addAll(value.cast<String, dynamic>());
          } else {
            site[field] = value;
          }
        }
        if (site['host'] == null ||
            site['type'] == null ||
            site['name'] == null) {
          continue;
        }
        site['scheme'] ??= 'https';
        site['hashSalt'] ??= '';
        site['blacklists'] ??= <String>[];
        sites.add(BooruSite.fromJson(site).toJson());
      }
      return jsonEncode(sites);
    }
    if (preference == searchPreference) {
      return jsonEncode(active.map((e) => e.value).toList());
    }
    if (preference == favoritesPreference) {
      return jsonEncode(active.map((e) => e.value).toList());
    }
    final strings = active.map((e) => e.value as String);
    return (preference == historyPreference ? strings.take(20) : strings)
        .toList();
  }
}

String preferenceForRecord(String key) => switch (key.split('/').first) {
  'setting' => key.substring('setting/'.length),
  'site' => sitesPreference,
  'favorite' => favoritesPreference,
  'blacklist' => blacklistPreference,
  'history' => historyPreference,
  'search' => searchPreference,
  _ => throw const FormatException('Unknown sync record'),
};

void validateSyncValue(String key, Object? value, {bool deleted = false}) {
  if (key.length > 2048) throw const FormatException('Sync key too long');
  final parts = key.split('/');
  final preference = preferenceForRecord(key);
  if (!isSyncedPreference(preference)) {
    throw const FormatException('Preference cannot be synced');
  }
  if (parts.first == 'site') {
    if (parts.length != 3 ||
        (!siteFields.contains(parts.last) && parts.last != 'present')) {
      throw const FormatException('Invalid site field');
    }
    if (decodeSyncId(parts[1]).isEmpty) {
      throw const FormatException('Invalid site ID');
    }
  } else if (parts.length != 2) {
    throw const FormatException('Invalid sync key');
  }
  if (deleted) return;
  if (parts.first != 'setting') decodeSyncId(parts[1]);
  if (jsonEncode(value).length > 1024 * 1024) {
    throw const FormatException('Sync value too large');
  }
  bool valid = false;
  if (parts.first == 'site') {
    valid = switch (parts.last) {
      'present' => value == true,
      'type' => value is int && value >= -1 && value <= 6,
      'blacklists' => value is List && value.every((v) => v is String),
      'credentials' =>
        value is Map &&
            value.length == 2 &&
            value.containsKey('username') &&
            value.containsKey('token') &&
            value.values.every((v) => v == null || v is String),
      'scheme' => value == 'https' || value == 'http',
      _ => value == null || value is String,
    };
  } else if (parts.first == 'search') {
    if (value is Map) {
      final record = SearchRecord.fromJson(value.cast<String, dynamic>());
      valid = syncId(record.id) == parts[1];
    }
  } else if (parts.first == 'favorite') {
    if (value is Map) {
      final json = value.cast<String, dynamic>();
      final fields = Post.fromJson(json).toJson().keys;
      valid =
          json.keys.every(fields.contains) &&
          (json['id'] is int || json['id'] is String) &&
          json['booruId'] is String &&
          syncId(jsonEncode([json['booruId'], json['id'].toString()])) ==
              parts[1];
    }
  } else if (parts.first == 'blacklist' || parts.first == 'history') {
    valid = value is String && syncId(value) == parts[1];
  } else {
    valid = switch (preference) {
      'flex_theme_mode' => {'system', 'light', 'dark'}.contains(value),
      'flex_language' ||
      'flex_tag_language' => {'system', 'zh', 'en'}.contains(value),
      'flex_image_quality' => {'preview', 'sample', 'original'}.contains(value),
      'flex_columns' => value is int && value >= 0 && value <= 12,
      'flex_accent_color' || 'flex_gradient_end_color' =>
        value is int && value >= 0 && value <= 0xffffffff,
      'flex_user_agent' || 'flexbooru_active_site_id' => value is String,
      _ => value is bool,
    };
  }
  if (!valid) throw const FormatException('Invalid sync value');
}
