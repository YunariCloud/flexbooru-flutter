import 'dart:convert';
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
  final int? remoteSize;
  final String? currentSha;
  final String? currentDate;
  final int localTagCount;

  const TagDbUpdateInfo({
    required this.hasUpdate,
    required this.isDownloaded,
    this.remoteSha,
    this.remoteDate,
    this.remoteSize,
    this.currentSha,
    this.currentDate,
    this.localTagCount = 0,
  });
}

class TagTranslationService {
  static final TagTranslationService _instance = TagTranslationService._internal();
  factory TagTranslationService() => _instance;
  TagTranslationService._internal();

  static const String keyTagDbSha = 'tag_db_sha';
  static const String keyTagDbDate = 'tag_db_date';
  static const String keyTagDbEtag = 'tag_db_etag';

  static const String repoOwner = 'ffdkj';
  static const String repoName = 'ffdkj-Danbooru_Tag-Chinese-English-Translation-Table';

  static const List<String> downloadMirrors = [
    'https://raw.githubusercontent.com/$repoOwner/$repoName/main/tag.sqlite',
    'https://raw.gitmirror.com/$repoOwner/$repoName/main/tag.sqlite',
    'https://ghproxy.net/https://raw.githubusercontent.com/$repoOwner/$repoName/main/tag.sqlite',
  ];

  static const String githubCommitsApi =
      'https://api.github.com/repos/$repoOwner/$repoName/commits?path=tag.sqlite&page=1&per_page=1';

  Database? _db;
  final Map<String, ({String cn, int cat})> _embeddedTags = {};
  bool _initialized = false;
  String? _customDbPath;

  bool get isDatabaseReady => _db != null;
  int get embeddedTagCount => _embeddedTags.length;

  /// Used for testing to inject mock / local SQLite path
  void setCustomDbPath(String? path) {
    _customDbPath = path;
    _db?.close();
    _db = null;
    _initialized = false;
  }

  Future<String> getDatabasePath() async {
    if (_customDbPath != null) return _customDbPath!;
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/tag_translation.sqlite';
  }

  Future<void> init() async {
    if (_initialized) return;

    // 1. Load embedded fallback dictionary
    if (_embeddedTags.isEmpty) {
      try {
        final jsonStr = await rootBundle.loadString('assets/tags/common_tags.json');
        final Map<String, dynamic> raw = json.decode(jsonStr) as Map<String, dynamic>;
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
      if (await file.exists() && await file.length() > 0) {
        _db?.close();
        _db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      }
    } catch (_) {
      _db?.close();
      _db = null;
    }

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

  TagTranslation? getTranslation(String tagName) {
    final cleanName = tagName.trim().toLowerCase().replaceAll(' ', '_');

    // Query SQLite if available
    if (_db != null) {
      try {
        final stmt = _db!.prepare(
          'SELECT name, category, cn_name, post_count FROM tags WHERE name = ? LIMIT 1',
        );
        final rows = stmt.select([cleanName]);
        stmt.close();
        if (rows.isNotEmpty) {
          final r = rows.first;
          final cn = r['cn_name'] as String?;
          final cat = (r['category'] as num?)?.toInt() ?? TagCategory.general;
          final count = (r['post_count'] as num?)?.toInt() ?? 0;
          return TagTranslation(
            name: tagName,
            cnName: (cn != null && cn.isNotEmpty) ? cn : null,
            category: _mapDanbooruCategory(cat),
            postCount: count,
          );
        }
      } catch (_) {}
    }

    // Fallback to embedded common tags
    final embedded = _embeddedTags[cleanName];
    if (embedded != null) {
      return TagTranslation(
        name: tagName,
        cnName: embedded.cn.isNotEmpty ? embedded.cn : null,
        category: _mapDanbooruCategory(embedded.cat),
      );
    }

    return null;
  }

  Map<String, TagTranslation> getTranslationsBatch(List<String> tagNames) {
    final result = <String, TagTranslation>{};
    if (tagNames.isEmpty) return result;

    final cleanMap = <String, String>{};
    for (final name in tagNames) {
      cleanMap[name.trim().toLowerCase().replaceAll(' ', '_')] = name;
    }

    if (_db != null && cleanMap.isNotEmpty) {
      try {
        final keys = cleanMap.keys.toList();
        final placeholders = List.filled(keys.length, '?').join(',');
        final stmt = _db!.prepare(
          'SELECT name, category, cn_name, post_count FROM tags WHERE name IN ($placeholders)',
        );
        final rows = stmt.select(keys);
        stmt.close();

        for (final r in rows) {
          final clean = (r['name'] as String?) ?? '';
          final original = cleanMap[clean] ?? clean;
          final cn = r['cn_name'] as String?;
          final cat = (r['category'] as num?)?.toInt() ?? TagCategory.general;
          final count = (r['post_count'] as num?)?.toInt() ?? 0;
          result[original] = TagTranslation(
            name: original,
            cnName: (cn != null && cn.isNotEmpty) ? cn : null,
            category: _mapDanbooruCategory(cat),
            postCount: count,
          );
        }
      } catch (_) {}
    }

    // Fill remaining with embedded tags if not found
    for (final entry in cleanMap.entries) {
      if (!result.containsKey(entry.value)) {
        final emb = _embeddedTags[entry.key];
        if (emb != null) {
          result[entry.value] = TagTranslation(
            name: entry.value,
            cnName: emb.cn.isNotEmpty ? emb.cn : null,
            category: _mapDanbooruCategory(emb.cat),
          );
        }
      }
    }

    return result;
  }

  Tag enrichTag(Tag tag) {
    final trans = getTranslation(tag.name);
    if (trans == null) return tag;

    // If tag has general category (default) and translation has specific category, use translation's category
    final effectiveCategory = (tag.category == TagCategory.general && trans.category != TagCategory.general)
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

      final effectiveCategory = (tag.category == TagCategory.general && trans.category != TagCategory.general)
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
    final dio = client ?? Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': 'Flexbooru-App'},
    ));

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
      if (res.statusCode == 200 && res.data is List && (res.data as List).isNotEmpty) {
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
    if (remoteSha == null) {
      for (final mirror in downloadMirrors) {
        try {
          final headRes = await dio.head(mirror);
          if (headRes.statusCode == 200) {
            remoteEtag = headRes.headers.value('etag')?.replaceAll('"', '').trim();
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
    } else if (remoteDate != null && currentDate != null) {
      hasUpdate = remoteDate != currentDate;
    } else if (remoteSha != null || remoteEtag != null) {
      // Remote exists but local has no record
      hasUpdate = true;
    }

    return TagDbUpdateInfo(
      hasUpdate: hasUpdate,
      isDownloaded: isDownloaded,
      remoteSha: remoteSha ?? remoteEtag,
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
  }) async {
    final dio = client ?? Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
      headers: {'User-Agent': 'Flexbooru-App'},
    ));

    final dbPath = await getDatabasePath();
    final tmpPath = '$dbPath.tmp';
    final tmpFile = File(tmpPath);
    if (await tmpFile.exists()) {
      await tmpFile.delete();
    }

    Exception? lastError;
    bool success = false;
    String? matchedEtag;

    for (final url in downloadMirrors) {
      try {
        final res = await dio.download(
          url,
          tmpPath,
          onReceiveProgress: onProgress,
        );
        if (res.statusCode == 200 && await tmpFile.exists() && await tmpFile.length() > 0) {
          matchedEtag = res.headers.value('etag')?.replaceAll('"', '').trim();
          success = true;
          break;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }

    if (!success) {
      throw lastError ?? Exception('Failed to download tag dictionary from all mirrors');
    }

    // Close existing DB handle
    _db?.close();
    _db = null;

    // Atomically replace database file
    final targetFile = File(dbPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tmpFile.rename(dbPath);

    // Reopen SQLite DB
    _db = sqlite3.open(dbPath, mode: OpenMode.readOnly);

    // Save metadata
    final prefs = await SharedPreferences.getInstance();
    if (matchedEtag != null) {
      await prefs.setString(keyTagDbEtag, matchedEtag);
    }
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(keyTagDbDate, nowStr);
  }

  void close() {
    _db?.close();
    _db = null;
    _initialized = false;
  }
}
