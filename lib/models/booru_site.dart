import 'dart:convert';
import '../core/constants/app_constants.dart';

class BooruSite {
  final String id;
  String name;
  String scheme;
  String host;
  int type;
  String hashSalt;
  String? path;
  String? username;
  String? token; // password hash or API key
  List<String> blacklists;

  BooruSite({
    required this.id,
    required this.name,
    this.scheme = 'https',
    required this.host,
    required this.type,
    this.hashSalt = '',
    this.path,
    this.username,
    this.token,
    List<String>? blacklists,
  }) : blacklists = blacklists ?? [];

  String get baseUrl => '$scheme://$host';

  // Resolve known API hosts at request time so saved sites also get the fix.
  String get apiBaseUrl {
    final domain = host.toLowerCase();
    if ((type == BooruType.gelbooru || type == BooruType.gelbooruLegacy) &&
        (domain == 'rule34.xxx' || domain == 'www.rule34.xxx')) {
      return 'https://api.rule34.xxx';
    }
    if (type == BooruType.sankaku &&
        (domain == 'capi-v2.sankakucomplex.com' ||
            domain == 'chan.sankakucomplex.com')) {
      return 'https://sankakuapi.com';
    }
    return baseUrl;
  }

  String get websiteUrl {
    if (host == 'api.rule34.xxx') return 'https://rule34.xxx';
    if (type == BooruType.sankaku) return 'https://sankaku.app';
    return baseUrl;
  }

  bool get hasApiCredentials =>
      (username?.trim().isNotEmpty ?? false) &&
      (token?.trim().isNotEmpty ?? false);

  String get typeName => BooruType.getTypeName(type);

  bool get isRetiredPreset {
    final domain = host.trim().toLowerCase();
    return domain == 'lolibooru.moe' || domain == 'www.lolibooru.moe';
  }

  bool get hasAuth =>
      (username != null && username!.isNotEmpty) ||
      (token != null && token!.isNotEmpty);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'scheme': scheme,
      'host': host,
      'type': type,
      'hashSalt': hashSalt,
      'path': path,
      'username': username,
      'token': token,
      'blacklists': blacklists,
    };
  }

  factory BooruSite.fromJson(Map<String, dynamic> json) {
    return BooruSite(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? '',
      scheme: json['scheme'] ?? 'https',
      host: json['host'] ?? '',
      type: json['type'] as int? ?? BooruType.danbooru,
      hashSalt: json['hashSalt'] ?? json['hash_salt'] ?? '',
      path: json['path'],
      username: json['username'] ?? json['user']?['name'],
      token: json['token'] ?? json['user']?['token'],
      blacklists:
          (json['blacklists'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// Converts to original Flexbooru URI scheme: `booru://<base64>`
  /// Format inside base64: `name@@@scheme@@@host@@@type@@@hashSalt[@@@path]`
  String toBooruUri() {
    final raw = path != null && path!.isNotEmpty
        ? '$name@@@$scheme@@@$host@@@$type@@@$hashSalt@@@$path'
        : '$name@@@$scheme@@@$host@@@$type@@@$hashSalt';
    final encoded = base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
    return 'booru://$encoded';
  }

  /// Parses original Flexbooru URI scheme
  static BooruSite? fromBooruUri(String uriString) {
    try {
      if (!uriString.startsWith('booru://')) return null;
      var rawPayload = uriString.substring('booru://'.length);
      if (rawPayload.startsWith('/')) rawPayload = rawPayload.substring(1);
      final queryIdx = rawPayload.indexOf('?');
      if (queryIdx != -1) rawPayload = rawPayload.substring(0, queryIdx);

      // Pad base64 string if needed
      var padded = rawPayload;
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      List<int> bytes;
      try {
        bytes = base64Url.decode(padded);
      } catch (_) {
        bytes = base64.decode(padded);
      }
      final decoded = utf8.decode(bytes);
      final parts = decoded.split('@@@');
      if (parts.length >= 5) {
        return BooruSite(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: parts[0],
          scheme: parts[1],
          host: parts[2],
          type: int.tryParse(parts[3]) ?? BooruType.moebooru,
          hashSalt: parts[4],
          path: parts.length > 5 && parts[5].isNotEmpty ? parts[5] : null,
        );
      }
    } catch (_) {}
    return null;
  }

  BooruSite copyWith({
    String? id,
    String? name,
    String? scheme,
    String? host,
    int? type,
    String? hashSalt,
    String? path,
    String? username,
    String? token,
    List<String>? blacklists,
  }) {
    return BooruSite(
      id: id ?? this.id,
      name: name ?? this.name,
      scheme: scheme ?? this.scheme,
      host: host ?? this.host,
      type: type ?? this.type,
      hashSalt: hashSalt ?? this.hashSalt,
      path: path ?? this.path,
      username: username ?? this.username,
      token: token ?? this.token,
      blacklists: blacklists ?? List.from(this.blacklists),
    );
  }

  /// Standard preset Booru sites
  static List<BooruSite> get defaultPresets => [
    BooruSite(
      id: 'yandere',
      name: 'Yande.re',
      scheme: 'https',
      host: 'yande.re',
      type: BooruType.moebooru,
    ),
    BooruSite(
      id: 'konachan',
      name: 'Konachan (Safe)',
      scheme: 'https',
      host: 'konachan.net',
      type: BooruType.moebooru,
    ),
    BooruSite(
      id: 'danbooru',
      name: 'Danbooru',
      scheme: 'https',
      host: 'danbooru.donmai.us',
      type: BooruType.danbooru,
    ),
    BooruSite(
      id: 'safebooru',
      name: 'Safebooru',
      scheme: 'https',
      host: 'safebooru.org',
      type: BooruType.gelbooru,
    ),
    BooruSite(
      id: 'gelbooru',
      name: 'Gelbooru',
      scheme: 'https',
      host: 'gelbooru.com',
      type: BooruType.gelbooru,
    ),
    BooruSite(
      id: 'rule34',
      name: 'Rule34.xxx',
      scheme: 'https',
      host: 'api.rule34.xxx',
      type: BooruType.gelbooru,
    ),
    BooruSite(
      id: 'paheal',
      name: 'Rule34 Paheal',
      scheme: 'https',
      host: 'rule34.paheal.net',
      type: BooruType.shimmie,
    ),
    BooruSite(
      id: 'e621',
      name: 'e621',
      scheme: 'https',
      host: 'e621.net',
      type: BooruType.danbooru,
    ),
    BooruSite(
      id: 'sankaku',
      name: 'Sankaku Complex',
      scheme: 'https',
      host: 'sankakuapi.com',
      type: BooruType.sankaku,
    ),
  ];
}
