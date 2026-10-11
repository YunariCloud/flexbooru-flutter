import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import '../core/constants/app_constants.dart';
import '../models/tag.dart';

class TagTranslation {
  final String name;
  final String? cnName;
  final int category;
  final int postCount;

  const TagTranslation({
    required this.name,
    this.cnName,
    this.category = TagCategory.general,
    this.postCount = 0,
  });
}

class TagDbUpdateInfo {
  final bool hasUpdate;
  final bool isDownloaded;
  final String? remoteSha;
  final String? remoteDate;
  final String? remoteEtag;
  final int? remoteSize;
  final String? currentSha;
  final String? currentDate;
  final int localTagCount;

  const TagDbUpdateInfo({
    required this.hasUpdate,
    required this.isDownloaded,
    this.remoteSha,
    this.remoteDate,
    this.remoteEtag,
    this.remoteSize,
    this.currentSha,
    this.currentDate,
    this.localTagCount = 0,
  });
}

class TagTranslationService {
  static final TagTranslationService _instance =
      TagTranslationService._internal();
  factory TagTranslationService() => _instance;
  TagTranslationService._internal();

  static const String keyTagDbSha = 'tag_db_sha';
  static const String keyTagDbDate = 'tag_db_date';
  static const String keyTagDbEtag = 'tag_db_etag';

  static const String repoOwner = 'ffdkj';
  static const String repoName =
      'ffdkj-Danbooru_Tag-Chinese-English-Translation-Table';

  static const List<String> downloadMirrors = [
    'https://raw.githubusercontent.com/$repoOwner/$repoName/main/tag.sqlite',
    'https://raw.gitmirror.com/$repoOwner/$repoName/main/tag.sqlite',
    'https://ghproxy.net/https://raw.githubusercontent.com/$repoOwner/$repoName/main/tag.sqlite',
  ];

  static const String githubCommitsApi =
      'https://api.github.com/repos/$repoOwner/$repoName/commits?path=tag.sqlite&page=1&per_page=1';

  Database? _db;
  Future<void>? _initializing;
  Future<void>? _downloading;
  final Map<String, TagTranslation?> _translationCache = {};
  static const _cacheLimit = 2048;
  final Map<String, ({String cn, int cat})> _embeddedTags = {};
  bool _initialized = false;
  String? _customDbPath;

  bool get isDatabaseReady => _db != null;
  int get embeddedTagCount => _embeddedTags.length;

  /// Used for testing to inject mock / local SQLite path
  void setCustomDbPath(String? path) {
    _customDbPath = path;
    _translationCache.clear();
    _db?.close();
    _db = null;
    _initialized = false;
  }

  Future<String> getDatabasePath() async {
    if (_customDbPath != null) return _customDbPath!;
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/tag_translation.sqlite';
  }

  Future<void> init() {
    if (_initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    // 1. Load embedded fallback dictionary
    if (_embeddedTags.isEmpty) {
      try {
        final jsonStr = await rootBundle.loadString(
          'assets/tags/common_tags.json',
        );
        final Map<String, dynamic> raw =
            json.decode(jsonStr) as Map<String, dynamic>;
        for (final entry in raw.entries) {
          final val = entry.value as Map<String, dynamic>;
          _embeddedTags[entry.key] = (
            cn: val['cn']?.toString() ?? '',
            cat: (val['cat'] as num?)?.toInt() ?? 0,
          );
        }
      } catch (_) {
        // Fallback silently if asset not loaded yet
      }
    }

    // 2. Open SQLite database if present
    try {
      final dbPath = await getDatabasePath();
      final file = File(dbPath);
      final backup = File('$dbPath.bak');
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(dbPath);
      }
      if (await file.exists() && await file.length() > 0) {
        _db?.close();
        _db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
        _db!.select(
          'SELECT name, category, cn_name, post_count FROM tags LIMIT 1',
        );
        _translationCache.clear();
      }
    } catch (_) {
      _db?.close();
      _db = null;
    }

    _translationCache.clear();
    _initialized = true;
  }

  int getLoadedTagCount() {
    if (_db != null) {
      try {
        final res = _db!.select('SELECT COUNT(*) as cnt FROM tags');
        if (res.isNotEmpty) {
          return (res.first['cnt'] as num).toInt();
        }
      } catch (_) {}
    }
    return _embeddedTags.length;
  }

  String _normalizeName(String name) =>
      name.trim().toLowerCase().replaceAll(' ', '_');

  TagTranslation? getTranslation(String tagName) =>
      getTranslationsBatch([tagName])[tagName];

  Map<String, TagTranslation> getTranslationsBatch(List<String> tagNames) {
    final result = <String, TagTranslation>{};
    final keys = tagNames.map(_normalizeName).toSet();
    final missing = keys
        .where((key) => !_translationCache.containsKey(key))
        .toList();
    final fetched = <String, TagTranslation>{};
    if (_db != null) {
      // Stay below SQLite's parameter limit, including for unusually large posts.
      for (var offset = 0; offset < missing.length; offset += 900) {
        final chunk = missing.skip(offset).take(900).toList();
        final placeholders = List.filled(chunk.length, '?').join(',');
        try {
          final rows = _db!.select(
            'SELECT name, category, cn_name, post_count FROM tags WHERE name IN ($placeholders)',
            chunk,
          );
          for (final row in rows) {
            final name = row['name'] as String;
            final cn = row['cn_name'] as String?;
            fetched[name] = TagTranslation(
              name: name,
              cnName: cn?.isNotEmpty == true ? cn : null,
              category: _mapDanbooruCategory(
                (row['category'] as num?)?.toInt() ?? 0,
              ),
              postCount: (row['post_count'] as num?)?.toInt() ?? 0,
            );
          }
        } catch (_) {
          // The embedded dictionary remains available when a local query fails.
        }
      }
    }
    for (final key in missing) {
      final embedded = _embeddedTags[key];
      _translationCache[key] =
          fetched[key] ??
          (embedded == null
              ? null
              : TagTranslation(
                  name: key,
                  cnName: embedded.cn.isEmpty ? null : embedded.cn,
                  category: _mapDanbooruCategory(embedded.cat),
                ));
    }
    for (final name in tagNames) {
      final key = _normalizeName(name);
      final translation = _translationCache.remove(key);
      _translationCache[key] = translation;
      if (translation != null) {
        result[name] = TagTranslation(
          name: name,
          cnName: translation.cnName,
          category: translation.category,
          postCount: translation.postCount,
        );
      }
    }
    while (_translationCache.length > _cacheLimit) {
      _translationCache.remove(_translationCache.keys.first);
    }
    return result;
  }

  Tag enrichTag(Tag tag) {
    final trans = getTranslation(tag.name);
    if (trans == null) return tag;

    // If tag has general category (default) and translation has specific category, use translation's category
    final effectiveCategory =
        (tag.category == TagCategory.general &&
            trans.category != TagCategory.general)
        ? trans.category
        : tag.category;

    return tag.copyWith(
      translatedName: trans.cnName,
      category: effectiveCategory,
      count: tag.count > 0 ? tag.count : trans.postCount,
    );
  }

  List<Tag> enrichTags(List<Tag> tags) {
    if (tags.isEmpty) return tags;
    final batch = getTranslationsBatch(tags.map((t) => t.name).toList());

    return tags.map((tag) {
      final trans = batch[tag.name];
      if (trans == null) return tag;

      final effectiveCategory =
          (tag.category == TagCategory.general &&
              trans.category != TagCategory.general)
          ? trans.category
          : tag.category;

      return tag.copyWith(
        translatedName: trans.cnName,
        category: effectiveCategory,
        count: tag.count > 0 ? tag.count : trans.postCount,
      );
    }).toList();
  }

  int _mapDanbooruCategory(int rawCat) {
    // Danbooru mapping:
    // 0: General, 1: Artist, 3: Copyright, 4: Character, 5: Meta
    switch (rawCat) {
      case 1:
        return TagCategory.artist;
      case 3:
        return TagCategory.copyright;
      case 4:
        return TagCategory.character;
      case 5:
        return TagCategory.meta;
      case 0:
      default:
        return TagCategory.general;
    }
  }

  /// Check for tag dictionary update on GitHub repository
  Future<TagDbUpdateInfo> checkForUpdate({Dio? client}) async {
    final dio =
        client ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'User-Agent': 'Flexbooru-App'},
          ),
        );

    final prefs = await SharedPreferences.getInstance();
    final currentSha = prefs.getString(keyTagDbSha);
    final currentDate = prefs.getString(keyTagDbDate);
    final currentEtag = prefs.getString(keyTagDbEtag);

    final dbPath = await getDatabasePath();
    final dbFile = File(dbPath);
    final isDownloaded = await dbFile.exists() && await dbFile.length() > 0;
    final localCount = getLoadedTagCount();

    String? remoteSha;
    String? remoteDate;
    String? remoteEtag;
    int? remoteSize;

    // 1. Try GitHub Commits API
    try {
      final res = await dio.get(githubCommitsApi);
      if (res.statusCode == 200 &&
          res.data is List &&
          (res.data as List).isNotEmpty) {
        final first = (res.data as List).first as Map<String, dynamic>;
        remoteSha = first['sha']?.toString();
        final commit = first['commit'] as Map<String, dynamic>?;
        final committer = commit?['committer'] as Map<String, dynamic>?;
        remoteDate = committer?['date']?.toString();
      }
    } catch (_) {
      // API may fail due to rate limiting
    }

    // 2. Fallback to HEAD request on raw.githubusercontent.com
    if (remoteSha == null || currentSha == null) {
      for (final mirror in downloadMirrors) {
        try {
          final headRes = await dio.head(mirror);
          if (headRes.statusCode == 200) {
            remoteEtag = headRes.headers
                .value('etag')
                ?.replaceAll('"', '')
                .trim();
            final len = headRes.headers.value('content-length');
            if (len != null) {
              remoteSize = int.tryParse(len);
            }
            remoteDate = headRes.headers.value('last-modified');
            break;
          }
        } catch (_) {}
      }
    }

    bool hasUpdate = false;
    if (!isDownloaded) {
      hasUpdate = true; // Not downloaded at all, needs initial download
    } else if (remoteSha != null && currentSha != null) {
      hasUpdate = remoteSha != currentSha;
    } else if (remoteEtag != null && currentEtag != null) {
      hasUpdate = remoteEtag != currentEtag;
    } else if (remoteSha != null || remoteEtag != null) {
      // Remote exists but local has no record
      hasUpdate = true;
    }

    return TagDbUpdateInfo(
      hasUpdate: hasUpdate,
      isDownloaded: isDownloaded,
      remoteSha: remoteSha,
      remoteEtag: remoteEtag,
      remoteDate: remoteDate,
      remoteSize: remoteSize ?? 24547328, // approx 23.4 MB
      currentSha: currentSha ?? currentEtag,
      currentDate: currentDate,
      localTagCount: localCount,
    );
  }

  /// Download or update tag.sqlite from GitHub repository
  Future<void> downloadDatabase({
    void Function(int received, int total)? onProgress,
    Dio? client,
  }) => _downloading ??= _downloadDatabase(
    onProgress: onProgress,
    client: client,
  ).whenComplete(() => _downloading = null);

  Future<void> _downloadDatabase({
    void Function(int received, int total)? onProgress,
    Dio? client,
  }) async {
    await init();
    final dio =
        client ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 120),
            headers: {'User-Agent': 'Flexbooru-App'},
          ),
        );
    // Pin the download to the exact revision whose metadata we save.
    String? sha;
    String? remoteDate;
    try {
      final response = await dio.get(githubCommitsApi);
      if (response.data is List && (response.data as List).isNotEmpty) {
        final commit = (response.data as List).first as Map;
        sha = commit['sha']?.toString();
        remoteDate = commit['commit']?['committer']?['date']?.toString();
      }
    } catch (_) {
      // Mirrors still work when the GitHub API is unavailable.
    }
    final dbPath = await getDatabasePath();
    final target = File(dbPath);
    final temporary = File('$dbPath.tmp');
    final backup = File('$dbPath.bak');
    await target.parent.create(recursive: true);
    Exception? lastError;
    String? etag;
    var downloaded = false;
    try {
      for (final mirror in downloadMirrors) {
        final url = sha == null
            ? mirror
            : mirror.replaceFirst('/main/tag.sqlite', '/$sha/tag.sqlite');
        try {
          final response = await dio.download(
            url,
            temporary.path,
            onReceiveProgress: onProgress,
          );
          if (response.statusCode != 200 ||
              !await temporary.exists() ||
              await temporary.length() == 0) {
            throw const FormatException('Empty tag dictionary response');
          }
          // Integrity checking runs off the UI isolate before touching the old DB.
          final validationPath = temporary.path;
          await Isolate.run(() => _validateTagDatabase(validationPath));
          etag = response.headers.value('etag')?.replaceAll('"', '').trim();
          remoteDate ??= response.headers.value('last-modified');
          downloaded = true;
          break;
        } catch (error) {
          lastError = error is Exception ? error : Exception(error.toString());
        }
      }
      if (!downloaded) {
        throw lastError ??
            Exception('Failed to download tag dictionary from all mirrors');
      }

      _db?.close();
      _db = null;
      var backedUp = false;
      var installed = false;
      try {
        if (await target.exists()) {
          if (await backup.exists()) await backup.delete();
          await target.rename(backup.path);
          backedUp = true;
        }
        await temporary.rename(dbPath);
        installed = true;
        _db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
        _db!.select(
          'SELECT name, category, cn_name, post_count FROM tags LIMIT 1',
        );
      } catch (_) {
        _db?.close();
        _db = null;
        if (installed && await target.exists()) await target.delete();
        if (backedUp) await backup.rename(dbPath);
        if (await target.exists()) {
          _db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
        }
        rethrow;
      }
      _translationCache.clear();
      final prefs = await SharedPreferences.getInstance();
      if (sha != null) {
        await prefs.setString(keyTagDbSha, sha);
      } else {
        await prefs.remove(keyTagDbSha);
      }
      if (etag != null) {
        await prefs.setString(keyTagDbEtag, etag);
      } else {
        await prefs.remove(keyTagDbEtag);
      }
      if (remoteDate != null) {
        await prefs.setString(keyTagDbDate, remoteDate);
      } else {
        await prefs.remove(keyTagDbDate);
      }
      if (await backup.exists()) await backup.delete();
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  void close() {
    _translationCache.clear();
    _db?.close();
    _db = null;
    _initialized = false;
  }
}

void _validateTagDatabase(String path) {
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final check = database.select('PRAGMA quick_check');
    if (check.length != 1 || check.first.values.single != 'ok') {
      throw const FormatException('Invalid tag dictionary database');
    }
    database.select(
      'SELECT name, category, cn_name, post_count FROM tags LIMIT 1',
    );
  } finally {
    database.close();
  }
}
