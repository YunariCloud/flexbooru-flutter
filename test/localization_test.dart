import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexbooru/core/i18n/app_localizations.dart';

void main() {
  group('AppLocalizations Tests', () {
    test('provides correct Chinese strings', () {
      final l10nZh = AppLocalizations(const Locale('zh'));
      expect(l10nZh.isZh, isTrue);
      expect(l10nZh.settings, equals('设置'));
      expect(l10nZh.manageBoorus, equals('管理 Booru 网站'));
      expect(l10nZh.postsFeed, equals('作品流'));
      expect(l10nZh.popularPosts, equals('热门作品'));
      expect(l10nZh.tagBlacklist, equals('标签黑名单'));
      expect(l10nZh.download, equals('下载原图'));
    });

    test('provides correct English strings', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      expect(l10nEn.isZh, isFalse);
      expect(l10nEn.settings, equals('Settings'));
      expect(l10nEn.manageBoorus, equals('Manage Boorus'));
      expect(l10nEn.postsFeed, equals('Posts Feed'));
      expect(l10nEn.popularPosts, equals('Popular Posts'));
      expect(l10nEn.tagBlacklist, equals('Tag Blacklist'));
      expect(l10nEn.download, equals('Download'));
    });
  });
}
