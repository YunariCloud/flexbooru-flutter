import 'package:flutter/material.dart';
import '../network/booru_api_exception.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('zh'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isZh => locale.languageCode == 'zh';

  // Common
  String get appName => 'Flexbooru';
  String get retry => isZh ? '重试' : 'Retry';
  String get refresh => isZh ? '刷新' : 'Refresh';
  String get loadMore => isZh ? '继续加载' : 'Load more';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get confirm => isZh ? '确定' : 'Confirm';
  String get save => isZh ? '保存' : 'Save';
  String get delete => isZh ? '删除' : 'Delete';
  String get clear => isZh ? '清除' : 'Clear';
  String get copied => isZh ? '已复制到剪贴板' : 'Copied to clipboard';
  String get failedToLoad => isZh ? '加载失败' : 'Failed to load';
  String get noPostsFound => isZh ? '未找到相关作品' : 'No posts found';
  String networkError(BooruApiException error) => error.describe(chinese: isZh);
  String get openSiteInBrowser => isZh ? '在浏览器检查站点' : 'Check site in browser';
  String get configureCredentials => isZh ? '配置站点认证' : 'Configure credentials';
  String get noSafePostsHint => isZh
      ? '安全模式已开启，当前查询可能没有符合安全分级的作品。'
      : 'Safe mode is on; this query may have no posts with a safe rating.';
  String get apiCredentialsHint => isZh
      ? 'Gelbooru / Rule34 API 可能要求认证：填写账户设置页的数字 User ID 和 API Key，而非登录密码。Sankaku 使用访问 Token。'
      : 'Gelbooru / Rule34 APIs may require authentication: enter the numeric user ID and API key from account settings, rather than your password. Sankaku uses an access token.';

  // Drawer & Nav
  String get postsFeed => isZh ? '作品流' : 'Posts Feed';
  String get popularPosts => isZh ? '热门作品' : 'Popular Posts';
  String get savedFavorites => isZh ? '本地收藏' : 'Saved Favorites';
  String get pools => isZh ? '图集' : 'Pools';
  String get manageBoorus => isZh ? '管理 Booru 网站' : 'Manage Boorus';
  String get tagBlacklist => isZh ? '标签黑名单' : 'Tag Blacklist';
  String get settings => isZh ? '设置' : 'Settings';
  String get about => isZh ? '关于' : 'About';
  String get selectBooru => isZh ? '选择站点' : 'Select Booru';
  String get sitesConfigured => isZh ? '个已配置站点' : 'sites configured';

  // Feed & Top Bar
  String get switchBooruSite => isZh ? '切换 Booru 网站' : 'Switch Booru Site';
  String get safeModeOn => isZh ? '安全模式：已开启' : 'Safe Mode: ON';
  String get safeModeOff => isZh ? '安全模式：已关闭' : 'Safe Mode: OFF';
  String get search => isZh ? '搜索' : 'Search';
  String get latestPosts => isZh ? '最新作品' : 'Latest Posts';
  String get popularToday => isZh ? '今日热门' : 'Popular (Today)';
  String get popularWeek => isZh ? '本周热门' : 'Popular (This Week)';
  String get popularMonth => isZh ? '本月热门' : 'Popular (This Month)';
  String get scrollToTop => isZh ? '回到顶部' : 'Scroll to top';

  // Search
  String searchHint(String siteName) =>
      isZh ? '在 $siteName 搜索标签...' : 'Search tags on $siteName...';
  String get searchHistory => isZh ? '搜索历史' : 'Search History';
  String get clearHistory => isZh ? '清空' : 'Clear';
  String get startTypingSearch =>
      isZh ? '输入标签名称开始搜索...' : 'Start typing to search tags...';
  String get danbooruLimitNotice => isZh
      ? 'Danbooru 限制说明：超过 2 个标签时将自动在客户端过滤，防止触发 HTTP 422 报错。'
      : 'Danbooru notice: Queries over 2 tags will use client-side filtering to prevent HTTP 422 error.';

  // Post Detail
  String postDetailsTitle(Object id) =>
      isZh ? '作品 #$id 详情' : 'Post #$id Details';
  String get dimensions => isZh ? '分辨率' : 'Dimensions';
  String get rating => isZh ? '分级' : 'Rating';
  String get score => isZh ? '评分' : 'Score';
  String get uploader => isZh ? '上传者' : 'Uploader';
  String get source => isZh ? '原始来源' : 'Source';
  String tagsCount(int count) => isZh ? '标签 ($count)' : 'Tags ($count)';
  String get copyAll => isZh ? '全部复制' : 'Copy All';
  String commentsCount(int count) => isZh ? '评论 ($count)' : 'Comments ($count)';
  String get noCommentsYet => isZh ? '暂无评论' : 'No comments yet.';
  String get download => isZh ? '下载原图' : 'Download';
  String get downloading => isZh ? '下载中' : 'Downloading';
  String savedTo(String path) => isZh ? '已保存至: $path' : 'Saved to: $path';
  String get downloadFailed => isZh ? '下载失败' : 'Download failed';
  String get share => isZh ? '分享' : 'Share';
  String get reverseSearch =>
      isZh ? '以图搜图 (SauceNAO)' : 'Reverse search (SauceNAO)';
  String get original => isZh ? '原图' : 'ORIGINAL';
  String get sample => isZh ? '大图' : 'SAMPLE';
  String get failedToLoadFullImage =>
      isZh ? '无法加载完整图片' : 'Failed to load full image';
  String get addFavorite => isZh ? '添加收藏' : 'Save Favorite';
  String get removeFavorite => isZh ? '取消收藏' : 'Remove Favorite';

  // Manage Booru
  String get addBooru => isZh ? '添加 Booru' : 'Add Booru';
  String get addFromPresets => isZh ? '从预设添加' : 'Add from Presets';
  String get addFromPresetsSub => isZh
      ? '快速添加 Danbooru、Gelbooru、Safebooru 等'
      : 'Choose from Danbooru, Gelbooru, Safebooru, etc.';
  String get addManually => isZh ? '手动添加' : 'Add Manually';
  String get addManuallySub => isZh
      ? '输入自定义站点域名、引擎类型及账号凭据'
      : 'Enter custom domain, engine type, credentials';
  String get importFromClipboard =>
      isZh ? '从剪贴板导入 (booru:// URI)' : 'Import from Clipboard (booru:// URI)';
  String get importFromClipboardSub =>
      isZh ? '粘贴 Flexbooru 格式分享链接或 JSON' : 'Paste Flexbooru URL or JSON';
  String get exportAllJson =>
      isZh ? '导出站点配置 (JSON)' : 'Export All Sites (JSON)';
  String get resetPresets => isZh ? '恢复默认预设' : 'Reset to Default Presets';
  String get resetPresetsConfirm => isZh
      ? '这将重置所有站点为默认预设列表。'
      : 'This will reset your Booru list to default presets.';
  String get copyBooruUri => isZh ? '复制 booru:// 分享链接' : 'Copy booru:// URI';
  String get edit => isZh ? '编辑' : 'Edit';
  String get activeSite => isZh ? '当前使用中' : 'Active';
  String get cannotDeleteLastSite =>
      isZh ? '无法删除最后一个站点' : 'Cannot delete the only remaining site';
  String get importSuccess =>
      isZh ? '成功导入 Booru 站点！' : 'Successfully imported Booru site!';
  String get importFailed => isZh
      ? '导入失败：格式非法 (需为 booru:// 或 JSON)'
      : 'Failed to import: Invalid format';

  // Booru Edit
  String get editBooruTitle => isZh ? '编辑 Booru 站点' : 'Edit Booru Site';
  String get addBooruTitle => isZh ? '添加自定义 Booru' : 'Add Custom Booru';
  String get booruName => isZh ? 'Booru 名称 *' : 'Booru Name *';
  String get hostDomain => isZh ? '域名 / 主机地址 *' : 'Host / Domain *';
  String get booruEngineType => isZh ? 'Booru 引擎类型' : 'Booru Engine Type';
  String get apiPathShimmie =>
      isZh ? 'API 相对路径 (Shimmie 可选)' : 'API Path (Optional for Shimmie)';
  String get hashSalt => isZh ? '密码 Hash Salt' : 'Password Hash Salt';
  String get authOptional =>
      isZh ? '用户账号认证 (可选)' : 'Authentication / User Account (Optional)';
  String get usernameOrId => isZh ? '用户名 / 用户 ID' : 'Username / User ID';
  String get tokenOrPassword =>
      isZh ? 'API Key / Token / 密码' : 'API Key / Token / Password Hash';
  String get saveChanges => isZh ? '保存修改' : 'Save Changes';
  String get credentialsGuide => isZh ? '站点登录与凭据指南' : 'Site Credentials Guide';
  String get viewCredentialsGuide => isZh ? '查看获取教程' : 'Credentials Guide';
  String get openWebsiteCredentialsPage =>
      isZh ? '前往官网获取' : 'Open Settings Page';
  String get copyUrl => isZh ? '复制网址' : 'Copy URL';
  String get close => isZh ? '关闭' : 'Close';
  String get authRequirement => isZh ? '认证要求' : 'Authentication Requirement';
  String get howToObtain => isZh ? '获取步骤' : 'Step-by-Step Instructions';
  String get importantTips => isZh ? '注意事项' : 'Important Tips';
  String get noAuthNeededBadge => isZh ? '无需登录即可使用' : 'No Auth Needed';
  String get recommendedBadge => isZh ? '建议配置' : 'Recommended';
  String get optionalBadge => isZh ? '按需配置 (可选)' : 'Optional';
  String get currentSiteGuide =>
      isZh ? '当前站点凭据指南' : 'Current Site Credentials Guide';
  String get selectSiteToViewGuide =>
      isZh ? '切换站点查看说明' : 'Switch site to view guide';

  // Blacklist
  String get addTagBlacklist => isZh ? '添加标签到黑名单' : 'Add tag to blacklist';
  String get add => isZh ? '添加' : 'Add';
  String get clearAllBlacklistConfirm =>
      isZh ? '确定要清空所有黑名单标签吗？' : 'All blacklisted tags will be removed.';
  String get blacklistExplanation => isZh
      ? '匹配此列表的所有作品将自动在所有站点的浏览瀑布流中隐藏。'
      : 'Posts matching these tags will be automatically filtered from feeds on all Boorus.';
  String get noBlacklistTags => isZh ? '暂无黑名单标签' : 'No blacklisted tags yet.';

  // Favorites
  String favoritesCount(int count) =>
      isZh ? '本地收藏 ($count)' : 'Favorites ($count)';
  String get noFavoritesYet => isZh ? '暂无收藏内容' : 'No saved favorites yet';

  // Pools
  String poolsTitle(String site) => isZh ? '图集 ($site)' : 'Pools ($site)';
  String get searchPoolHint => isZh ? '搜索图集名称...' : 'Search pool name...';
  String get noPoolsFound => isZh ? '未找到图集' : 'No pools found.';

  // Settings
  String get appearance => isZh ? '外观个性化' : 'Appearance';
  String get language => isZh ? '界面语言' : 'Language';
  String get followSystem => isZh ? '跟随系统' : 'System Default';
  String get chinese => isZh ? '简体中文' : '简体中文 (Chinese)';
  String get english => isZh ? 'English' : 'English';
  String get themeMode => isZh ? '主题模式' : 'Theme Mode';
  String get themeSystem => isZh ? '跟随系统' : 'System';
  String get themeLight => isZh ? '浅色' : 'Light';
  String get themeDark => isZh ? '深色' : 'Dark';
  String get amoledBlack => isZh ? 'AMOLED 纯黑' : 'AMOLED Pure Black';
  String get amoledBlackSub =>
      isZh ? '为 OLED 屏幕提供纯黑省电背景' : 'Pitch black background for OLED screens';
  String get accentColor => isZh ? '主题配色与渐变' : 'Theme Color & Gradient';
  String get chooseAccentColor => isZh ? '选择主题配色' : 'Choose Theme Color';
  String get chooseThemeColor => isZh ? '主题配色与渐变' : 'Theme Color & Gradient';
  String get gradientPresets => isZh ? '精选渐变' : 'Gradient Presets';
  String get solidPresets => isZh ? '经典纯色' : 'Solid Colors';
  String get customColors => isZh ? '自定义调色' : 'Custom';
  String get enableGradient => isZh ? '启用双色渐变' : 'Enable Two-Color Gradient';
  String get gradientEnabled => isZh ? '双色渐变' : 'Gradient';
  String get solidColor => isZh ? '经典纯色' : 'Solid Color';
  String get startColor => isZh ? '起始颜色' : 'Start Color';
  String get endColor => isZh ? '结束颜色' : 'End Color';
  String get hexCode => isZh ? '十六进制色值' : 'Hex Code';
  String get livePreview => isZh ? '效果预览' : 'Preview';
  String get applyColor => isZh ? '应用配色' : 'Apply Palette';
  String get invalidHexColor => isZh
      ? '请输入有效的十六进制色值 (如 #3F51B5)'
      : 'Please enter a valid hex color (e.g. #3F51B5)';
  String get layoutDisplay => isZh ? '布局与画质' : 'Layout & Display';
  String get gridColumns => isZh ? '瀑布流列数' : 'Grid Columns';
  String get gridAuto => isZh ? '自适应屏幕' : 'Auto';
  String gridCount(int count) => isZh ? '$count 列' : '$count Columns';
  String get defaultImageQuality => isZh ? '默认加载画质' : 'Default Image Quality';
  String get qualityPreview => isZh ? '缩略图 (最省流量)' : 'Preview (Lowest data)';
  String get qualitySample => isZh ? '高清样张 (平衡推荐)' : 'Sample (Balanced)';
  String get qualityOriginal => isZh ? '原始大图 (最高画质)' : 'Original (Highest)';
  String get contentSafety => isZh ? '内容安全' : 'Content Safety';
  String get defaultSafeMode => isZh ? '默认开启安全模式' : 'Default Safe Mode';
  String get defaultSafeModeSub => isZh
      ? '默认过滤可能含有非全年龄/可疑分级的作品'
      : 'Filter explicit & questionable posts by default';
  String get networkAntiWaf => isZh ? '网络与防拦截' : 'Network & Anti-WAF';
  String get customUserAgent =>
      isZh ? '自定义浏览器 User-Agent' : 'Custom User-Agent';
  String get userAgentHint => isZh
      ? 'API 默认使用 Flexbooru 标识；浏览器 UA 可能触发人机验证'
      : 'APIs use the Flexbooru identity by default; browser UAs may trigger challenges';
  String get resetDefault => isZh ? '恢复默认' : 'Reset Default';

  // About
  String get aboutAppSub => isZh
      ? '基于 Flutter 重构的跨平台 Booru 现代图版客户端，全引擎支持与全面 Bug 修复。'
      : 'A modern, multi-platform Booru client rewritten in Flutter with full engine compatibility and bug fixes.';
  String get bugFixesAndUpgrades =>
      isZh ? 'Bug 修复与现代升级' : 'Bug Fixes & Modern Upgrades';
  String get originalProject =>
      isZh ? '原版 Flexbooru 开源项目' : 'Original Flexbooru Project';
  String get currentProject =>
      isZh ? '本项目：Flexbooru Flutter' : 'This project: Flexbooru Flutter';
  String get license => isZh ? '开源授权' : 'License';

  // Update
  String get checkUpdates => isZh ? '检查更新' : 'Check for Updates';
  String get checkingUpdates => isZh ? '正在检查新版本...' : 'Checking for updates...';
  String get currentVersion => isZh ? '当前版本' : 'Current Version';
  String get latestVersion => isZh ? '最新版本' : 'Latest Version';
  String get alreadyLatestVersion =>
      isZh ? '当前已是最新版本' : 'Already running the latest version';
  String get newVersionAvailable => isZh ? '发现新版本' : 'New Version Available';
  String get viewUpdate => isZh ? '查看更新' : 'View Update';
  String get updateNotes => isZh ? '更新说明' : 'Release Notes';
  String get later => isZh ? '稍后再说' : 'Later';
  String get checkUpdateFailed => isZh
      ? '检查更新失败，请检查网络或稍后重试'
      : 'Failed to check for updates, please check network and try again';
  String get openReleasesPage => isZh ? '前往 Releases 页面' : 'Open Releases Page';
  String get autoCheckUpdates => isZh ? '启动时检查更新' : 'Check Updates on Startup';
  String get autoDownloadUpdates =>
      isZh ? '自动下载更新' : 'Download Updates Automatically';
  String get autoDownloadUpdatesSub => isZh
      ? '发现新版本后在应用内下载，安装时由你确认'
      : 'Download new releases in the app; you choose when to install';
  String get downloadUpdate => isZh ? '下载更新' : 'Download Update';
  String get downloadingUpdate => isZh ? '正在下载更新' : 'Downloading update';
  String get verifyingUpdate => isZh ? '正在校验更新包' : 'Verifying update';
  String get updateReady => isZh ? '更新包已下载' : 'Update downloaded';
  String get installUpdate => isZh ? '安装更新' : 'Install Update';
  String get openUpdatePackage => isZh ? '打开更新包' : 'Open Update Package';
  String get updateDownloadFailed => isZh
      ? '更新下载失败，请检查网络或剩余空间后重试。'
      : 'Download failed. Check your connection and free storage, then retry.';
  String get updateOpenFailed => isZh
      ? '无法打开更新包，请确认安装权限或重试。'
      : 'Unable to open the update package. Check install permissions or retry.';
  String get updateIntegrityFailed => isZh
      ? '更新包不完整或校验失败，请重新下载。'
      : 'Update is incomplete or failed verification. Download again.';
  String get noCompatibleUpdate => isZh
      ? '此版本尚无适合本设备的更新包，可前往发布页查看。'
      : 'No compatible package is available. Check the release page.';
  String get updateCancelled =>
      isZh ? '已取消下载，可随时重试。' : 'Download cancelled. Retry any time.';
  String get allowUpdateInstall => isZh
      ? '请允许 Flexbooru 安装应用，返回后再次点击“安装更新”。'
      : 'Allow Flexbooru to install apps, then return and tap Install Update again.';
  String get windowsUpdateInstructions => isZh
      ? '下载完成后打开压缩包，退出 Flexbooru，再将包内文件解压到原程序目录。'
      : 'Open the ZIP, close Flexbooru, then extract its contents to your existing app folder.';
  String get autoCheckUpdatesSub => isZh
      ? '应用启动时自动检测是否有可用新版本'
      : 'Automatically check for new versions on app startup';

  // Download Settings
  String get downloadSettings => isZh ? '下载设置' : 'Download Settings';
  String get downloadPath => isZh ? '图片下载路径' : 'Download Directory';
  String get downloadPathSub => isZh
      ? '保存已下载作品原图与大图的存储位置'
      : 'Location to store downloaded images and videos';
  String get defaultPath => isZh ? '默认' : 'Default';
  String get chooseDownloadPath => isZh ? '设置下载目录' : 'Set Download Directory';
  String get downloadPathHint =>
      isZh ? '请输入完整的文件夹路径...' : 'Enter full directory path...';
  String get pathPresets => isZh ? '常用目录预设' : 'Quick Presets';
  String get presetDownloads =>
      isZh ? '系统下载目录 (Downloads)' : 'Downloads Folder';
  String get presetPictures => isZh ? '系统图片目录 (Pictures)' : 'Pictures Folder';
  String get presetAppDir => isZh ? '应用专属目录 (App)' : 'App Documents Folder';
  String get openFolder => isZh ? '打开文件夹' : 'Open Folder';
  String get browseViaSystemDialog =>
      isZh ? '调用系统选择器浏览' : 'Browse via System Dialog';
  String get browseFolder => isZh ? '浏览文件夹' : 'Browse Folder';
  String get pickingFolder =>
      isZh ? '正在等待系统选择器...' : 'Waiting for system dialog...';
  String get pathNotWritable => isZh
      ? '该路径无法创建或无写入权限，请检查路径有效性'
      : 'Path cannot be created or is not writable, please verify';
  String get pathSaved => isZh ? '下载路径已更新' : 'Download path updated';

  // Tag Translation & Detail Layout
  String get tagLanguage => isZh ? 'Tag 显示语言' : 'Tag Display Language';
  String get tagLanguageDesc => isZh
      ? '设置标签显示中文翻译或英文原名（默认跟随应用语言）'
      : 'Choose to display tags in Chinese translation or English';
  String get tagLangZh => isZh ? '中文' : 'Chinese';
  String get tagLangEn => isZh ? '英文' : 'English';
  String get tagLangSystem =>
      isZh ? '跟随当前语言 (默认)' : 'Follow App Language (Default)';
  String get tagDatabase =>
      isZh ? 'Danbooru 标签汉化词库' : 'Danbooru Tag Translation Dictionary';
  String get tagDatabaseDesc => isZh
      ? '基于 ffdkj-Danbooru_Tag-Chinese-English 词库映射'
      : 'Powered by ffdkj/ffdkj-Danbooru_Tag-Chinese-English-Translation-Table';
  String get checkTagDbUpdate => isZh ? '检查词库更新' : 'Check Dictionary Update';
  String get downloadTagDb =>
      isZh ? '下载完整词库 (33万+ 标签)' : 'Download Full Dictionary (330k+ tags)';
  String get tagDbReady => isZh ? '完整词库已就绪' : 'Full dictionary ready';
  String get tagDbEmbedded => isZh
      ? '内置精选词库 (3,500+ 高频标签)'
      : 'Built-in popular dictionary (3,500+ tags)';
  String get tagDbUpToDate => isZh ? '词库已是最新版本' : 'Dictionary is up to date';
  String get tagDbUpdateFound =>
      isZh ? '发现新版标签词库' : 'New tag dictionary update available';
  String get tagDbDownloading =>
      isZh ? '正在下载标签词库...' : 'Downloading tag dictionary...';
  String get tagDbUpdatedSuccess =>
      isZh ? '标签词库已成功更新' : 'Tag dictionary updated successfully';
  String tagDbTotalTags(int count) =>
      isZh ? '已加载 $count 条标签' : '$count tags loaded';
  String get searchTag => isZh ? '在本站搜索此标签' : 'Search this tag on site';
  String get copyTag => isZh ? '复制标签名' : 'Copy tag name';
  String get copyTagZh => isZh ? '复制中文释义' : 'Copy Chinese translation';
  String get tagDetails => isZh ? '标签详情' : 'Tag Details';
  String get categoryArtist => isZh ? '画师' : 'Artist';
  String get categoryCharacter => isZh ? '角色' : 'Character';
  String get categoryCopyright => isZh ? '原作' : 'Copyright';
  String get categoryGeneral => isZh ? '普通' : 'General';
  String get categoryMeta => isZh ? '元标签' : 'Meta';
  String get categoryCircle => isZh ? '社团' : 'Circle';
  String get categoryFaults => isZh ? '缺陷' : 'Faults';
  String get openInBrowser => isZh ? '在浏览器中打开' : 'Open in Browser';
  String get copyPostUrl => isZh ? '复制帖子链接' : 'Copy Post Link';
  String get copiedPostUrl =>
      isZh ? '已复制帖子链接到剪贴板' : 'Post URL copied to clipboard';
  String copiedTag(String name) =>
      isZh ? '已复制标签 "$name"' : 'Copied tag "$name"';
  String get aspectRatio => isZh ? '长宽比' : 'Aspect Ratio';
  String get format => isZh ? '格式' : 'Format';
  String get toggleTagLang => isZh ? '中/英切换' : 'ZH/EN Toggle';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
