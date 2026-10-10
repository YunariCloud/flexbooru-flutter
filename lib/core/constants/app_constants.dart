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
  static const int circle = 5;
  static const int faults = 6;
  static const int medium = 8;
  static const int meta = 9;

  static String getCategoryName(int category) {
    switch (category) {
      case artist:
        return 'Artist';
      case copyright:
        return 'Copyright';
      case character:
        return 'Character';
      case circle:
      case studio:
        return 'Circle / Studio';
      case meta:
        return 'Meta';
      case faults:
        return 'Faults';
      case general:
      default:
        return 'General';
    }
  }
}

class AppConstants {
  static const String appName = 'Flexbooru';
  static const String appVersion =
      '${String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0')} (Flutter Edition)';

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
