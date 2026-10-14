class BooruType {
  static const int danbooru = 0;
  static const int moebooru = 1;
  static const int danbooru1 = 2;
  static const int gelbooru = 3;
  static const int sankaku = 4;
  static const int shimmie = 5;
  static const int gelbooruLegacy = 6;
  static const int unknown = -1;

  static String getTypeName(int type) {
    switch (type) {
      case danbooru:
        return 'Danbooru';
      case moebooru:
        return 'Moebooru';
      case danbooru1:
        return 'Danbooru 1.x';
      case gelbooru:
        return 'Gelbooru';
      case sankaku:
        return 'Sankaku';
      case shimmie:
        return 'Shimmie';
      case gelbooruLegacy:
        return 'Gelbooru (Legacy XML)';
      default:
        return 'Unknown';
    }
  }
}

class TagCategory {
  static const int all = -1;
  static const int general = 0;
  static const int artist = 1;
  static const int studio = 2;
  static const int copyright = 3;
  static const int character = 4;
  static const int meta = 5;
  static const int faults = 6;
  static const int circle = 7;
  static const int medium = 8;
  static const int legacyMeta = 9;

  static String getCategoryName(int category) {
    switch (category) {
      case artist:
        return 'Artist';
      case copyright:
        return 'Copyright';
      case character:
        return 'Character';
      case studio:
        return 'Studio';
      case meta:
      case legacyMeta:
        return 'Meta';
      case circle:
        return 'Circle';
      case faults:
        return 'Faults';
      case general:
      default:
        return 'General';
    }
  }

  static String getCategoryNameZh(int category) {
    switch (category) {
      case artist:
        return '画师';
      case copyright:
        return '原作';
      case character:
        return '角色';
      case studio:
      case circle:
        return '社团';
      case meta:
      case legacyMeta:
        return '元标签';
      case faults:
        return '缺陷';
      case general:
      default:
        return '普通';
    }
  }
}

class AppConstants {
  static const String appName = 'Flexbooru';
  static const String rawVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.4.1',
  );
  static const String appVersion = '$rawVersion (Flutter Edition)';
  static const String githubRepo = 'YunariCloud/flexbooru-flutter';
  static const String githubReleasesUrl =
      'https://github.com/$githubRepo/releases';
  static const String githubLatestReleaseApi =
      'https://api.github.com/repos/$githubRepo/releases/latest';
  static const String githubLatestReleasePage =
      'https://github.com/$githubRepo/releases/latest';

  static const String defaultUserAgent =
      'Flexbooru/2.0 (Flutter; Booru client)';
  static const String defaultBrowserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
  static const String legacyUserAgent = defaultBrowserUserAgent;
  static const String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  static const String sankakuOrigin = 'https://sankaku.app';
  static const String sankakuReferer = 'https://sankaku.app/';
}
