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
      expect(l10nZh.checkUpdates, equals('检查更新'));
      expect(l10nZh.autoCheckUpdates, equals('启动时检查更新'));
      expect(l10nZh.downloadSettings, equals('下载设置'));
      expect(l10nZh.downloadPath, equals('图片下载路径'));
      expect(l10nZh.browseViaSystemDialog, equals('调用系统选择器浏览'));
      expect(l10nZh.browseFolder, equals('浏览文件夹'));
      expect(l10nZh.pickingFolder, equals('正在等待系统选择器...'));
      expect(l10nZh.chooseThemeColor, equals('主题配色与渐变'));
      expect(l10nZh.gradientPresets, equals('精选渐变'));
      expect(l10nZh.solidPresets, equals('经典纯色'));
      expect(l10nZh.customColors, equals('自定义调色'));
      expect(l10nZh.enableGradient, equals('启用双色渐变'));
      expect(l10nZh.tagLanguage, equals('Tag 显示语言'));
      expect(l10nZh.tagDatabase, equals('Danbooru 标签汉化词库'));
      expect(l10nZh.checkTagDbUpdate, equals('检查词库更新'));
      expect(l10nZh.downloadTagDb, equals('下载完整词库 (33万+ 标签)'));
      expect(l10nZh.searchTag, equals('在本站搜索此标签'));
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
      expect(l10nEn.checkUpdates, equals('Check for Updates'));
      expect(l10nEn.autoCheckUpdates, equals('Check Updates on Startup'));
      expect(l10nEn.downloadSettings, equals('Download Settings'));
      expect(l10nEn.downloadPath, equals('Download Directory'));
      expect(l10nEn.browseViaSystemDialog, equals('Browse via System Dialog'));
      expect(l10nEn.browseFolder, equals('Browse Folder'));
      expect(l10nEn.pickingFolder, equals('Waiting for system dialog...'));
      expect(l10nEn.chooseThemeColor, equals('Theme Color & Gradient'));
      expect(l10nEn.gradientPresets, equals('Gradient Presets'));
      expect(l10nEn.solidPresets, equals('Solid Colors'));
      expect(l10nEn.customColors, equals('Custom'));
      expect(l10nEn.enableGradient, equals('Enable Two-Color Gradient'));
      expect(l10nEn.tagLanguage, equals('Tag Display Language'));
      expect(l10nEn.tagDatabase, equals('Danbooru Tag Translation Dictionary'));
      expect(l10nEn.checkTagDbUpdate, equals('Check Dictionary Update'));
      expect(l10nEn.downloadTagDb, equals('Download Full Dictionary (330k+ tags)'));
      expect(l10nEn.searchTag, equals('Search this tag on site'));
    });
  });
}
