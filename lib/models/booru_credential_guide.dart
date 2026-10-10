import '../core/constants/app_constants.dart';
import 'booru_site.dart';

/// Information and instructions for configuring site authentication / API credentials
class BooruCredentialGuide {
  final String id;
  final String name;
  final String host;
  final int type;
  final String? directUrl;
  final String requirementZh;
  final String requirementEn;
  final String usernameLabelZh;
  final String usernameLabelEn;
  final String usernameHintZh;
  final String usernameHintEn;
  final String? usernameWarningZh;
  final String? usernameWarningEn;
  final String tokenLabelZh;
  final String tokenLabelEn;
  final String tokenHintZh;
  final String tokenHintEn;
  final String? tokenWarningZh;
  final String? tokenWarningEn;
  final List<String> stepsZh;
  final List<String> stepsEn;
  final String? tipZh;
  final String? tipEn;
  final bool isAuthRequired;
  final bool isNoAuthNeeded;

  const BooruCredentialGuide({
    required this.id,
    required this.name,
    required this.host,
    required this.type,
    this.directUrl,
    required this.requirementZh,
    required this.requirementEn,
    required this.usernameLabelZh,
    required this.usernameLabelEn,
    required this.usernameHintZh,
    required this.usernameHintEn,
    this.usernameWarningZh,
    this.usernameWarningEn,
    required this.tokenLabelZh,
    required this.tokenLabelEn,
    required this.tokenHintZh,
    required this.tokenHintEn,
    this.tokenWarningZh,
    this.tokenWarningEn,
    required this.stepsZh,
    required this.stepsEn,
    this.tipZh,
    this.tipEn,
    this.isAuthRequired = false,
    this.isNoAuthNeeded = false,
  });

  String getRequirement(bool isZh) => isZh ? requirementZh : requirementEn;
  String getUsernameLabel(bool isZh) => isZh ? usernameLabelZh : usernameLabelEn;
  String getUsernameHint(bool isZh) => isZh ? usernameHintZh : usernameHintEn;
  String? getUsernameWarning(bool isZh) => isZh ? usernameWarningZh : usernameWarningEn;
  String getTokenLabel(bool isZh) => isZh ? tokenLabelZh : tokenLabelEn;
  String getTokenHint(bool isZh) => isZh ? tokenHintZh : tokenHintEn;
  String? getTokenWarning(bool isZh) => isZh ? tokenWarningZh : tokenWarningEn;
  List<String> getSteps(bool isZh) => isZh ? stepsZh : stepsEn;
  String? getTip(bool isZh) => isZh ? tipZh : tipEn;

  /// Guides for all 9 preset sites
  static List<BooruCredentialGuide> get presetGuides => [
    const BooruCredentialGuide(
      id: 'danbooru',
      name: 'Danbooru',
      host: 'danbooru.donmai.us',
      type: BooruType.danbooru,
      directUrl: 'https://danbooru.donmai.us/profile',
      requirementZh: '非必须。匿名状态下搜索限制最多 2 个标签（超出报 422 错误）；登录账号可解锁多标签搜索与更高访问配额。',
      requirementEn: 'Optional. Anonymous searches are limited to max 2 tags (HTTP 422 error if exceeded); logging in unlocks multi-tag search and higher quotas.',
      usernameLabelZh: '用户名 (Login Name)',
      usernameLabelEn: 'Username (Login Name)',
      usernameHintZh: '你的 Danbooru 账号登录名',
      usernameHintEn: 'Your Danbooru login name',
      tokenLabelZh: 'API Key',
      tokenLabelEn: 'API Key',
      tokenHintZh: '在个人资料页生成的 API Key',
      tokenHintEn: 'API Key generated in your profile',
      tokenWarningZh: '⚠️ 严禁填写网页登录明文密码！Danbooru API 强制要求 API Key。',
      tokenWarningEn: '⚠️ Do NOT enter your web login password! Danbooru API strictly requires an API Key.',
      stepsZh: [
        '在浏览器打开 Danbooru (https://danbooru.donmai.us) 并登录账号。',
        '点击右上角个人用户名进入 Profile 页面（或点击下方按钮直接前往）。',
        '在资料页面找到 API Key 这一栏，点击 "View" 或 "Generate API Key" 查看/生成密钥。',
        '复制生成的 API Key，填入本 App 的 Token 输入框；用户名填你的登录账号名。',
      ],
      stepsEn: [
        'Open Danbooru (https://danbooru.donmai.us) in your browser and log in.',
        'Click your username in the top right to open Profile (or use the button below).',
        'Find the API Key section and click "View" or "Generate API Key".',
        'Copy the API Key into the Token field, and enter your login name in Username.',
      ],
      tipZh: '如仅进行单标签或双标签日常看图，无需配置登录信息，直接留空即可畅享浏览。',
      tipEn: 'If only browsing with 1 or 2 tags, credentials are not required and can be left empty.',
    ),

    const BooruCredentialGuide(
      id: 'gelbooru',
      name: 'Gelbooru',
      host: 'gelbooru.com',
      type: BooruType.gelbooru,
      directUrl: 'https://gelbooru.com/index.php?page=account&s=options',
      isAuthRequired: true,
      requirementZh: '强烈建议配置！Gelbooru 对未鉴权 API 限制极多且频繁报 401 拦截；配置后可稳定高速访问。',
      requirementEn: 'Highly recommended! Gelbooru enforces strict limits and authentication blocks on unauthenticated API calls; configuring credentials ensures stable access.',
      usernameLabelZh: '用户 ID (纯数字 User ID)',
      usernameLabelEn: 'Numeric User ID',
      usernameHintZh: '例如 123456（账户选项页面的纯数字 ID）',
      usernameHintEn: 'e.g. 123456 (numeric ID from Account Options)',
      usernameWarningZh: '⚠️ 务必填写纯数字 User ID！填入英文字符用户名会导致 API 鉴权失败。',
      usernameWarningEn: '⚠️ Must be a numeric User ID! Entering an alphanumeric username will fail authentication.',
      tokenLabelZh: 'API Key',
      tokenLabelEn: 'API Key',
      tokenHintZh: '在账户选项中生成的 64 位 API Key',
      tokenHintEn: '64-character API Key generated in Account Options',
      tokenWarningZh: '⚠️ 请勿填写网页登录密码，Gelbooru API 只接受 API Key。',
      tokenWarningEn: '⚠️ Do not enter your web login password; Gelbooru API only accepts the API Key.',
      stepsZh: [
        '在浏览器打开 Gelbooru (https://gelbooru.com) 并登录账号。',
        '点击顶部导航栏 Account -> Options（或点击下方按钮直达账户选项）。',
        '向页面下方滚动，找到 API Credentials 区域。',
        '复制页面显示的数字 User ID，填入本 App 的【用户名 / 用户 ID】框。',
        '点击 Generate 生成并复制 64 位 API Key，填入本 App 的【Token】框。',
      ],
      stepsEn: [
        'Open Gelbooru (https://gelbooru.com) in browser and log in.',
        'Click Account -> Options in the top navigation (or click the button below).',
        'Scroll down to the "API Credentials" section.',
        'Copy the numeric "User ID" into App\'s "Username / User ID" field.',
        'Click "Generate API Key" (if not done) and copy the 64-char key into "Token".',
      ],
      tipZh: 'Gelbooru 官方 API 接口强制要求以 user_id 与 api_key 传参，两项必须同时完整配置。',
      tipEn: 'Gelbooru API strictly expects user_id and api_key parameters together.',
    ),

    const BooruCredentialGuide(
      id: 'e621',
      name: 'e621',
      host: 'e621.net',
      type: BooruType.danbooru,
      directUrl: 'https://e621.net/api_keys',
      requirementZh: '非必须。匿名浏览直接可用；登录可同步账号收藏、黑名单并解除匿名搜索限制。',
      requirementEn: 'Optional. Public browsing works without login; logging in unlocks favorites, blacklist sync, and higher search limits.',
      usernameLabelZh: '用户名 (Username)',
      usernameLabelEn: 'Username',
      usernameHintZh: '你的 e621 用户名',
      usernameHintEn: 'Your e621 username',
      tokenLabelZh: 'API Key',
      tokenLabelEn: 'API Key',
      tokenHintZh: 'API Keys 页面生成的 API Key',
      tokenHintEn: 'API Key generated on the API Keys page',
      tokenWarningZh: '⚠️ e621 官方已禁用密码调用 API，强制要求使用 API Key。',
      tokenWarningEn: '⚠️ e621 API no longer accepts passwords. You must use an API Key.',
      stepsZh: [
        '在浏览器打开 e621.net 并登录你的账号。',
        '访问 API Keys 管理页面 (https://e621.net/api_keys) 或点击下方直达按钮。',
        '点击 "Generate API Key" 生成新的 API 访问密钥。',
        '复制生成的 API Key，填入本 App 的 Token 输入框；用户名填你的 e621 账号名。',
      ],
      stepsEn: [
        'Open e621.net in your browser and log in.',
        'Go to Manage API Keys (https://e621.net/api_keys) or click the button below.',
        'Click "Generate API Key" to generate a key.',
        'Copy the API Key into the Token field and enter your username in Username.',
      ],
    ),

    const BooruCredentialGuide(
      id: 'rule34',
      name: 'Rule34.xxx',
      host: 'api.rule34.xxx',
      type: BooruType.gelbooru,
      directUrl: 'https://rule34.xxx/index.php?page=account&s=home',
      requirementZh: '非必须。日常浏览可直接匿名使用；若遇限流或频繁访问，建议配置纯数字 User ID 与 API Key。',
      requirementEn: 'Optional. Public browsing works anonymously; configuring numeric User ID and API Key helps avoid rate limits.',
      usernameLabelZh: '用户 ID (纯数字 User ID)',
      usernameLabelEn: 'Numeric User ID',
      usernameHintZh: '例如 654321（个人主页显示的纯数字 ID）',
      usernameHintEn: 'e.g. 654321 (numeric ID from your account)',
      usernameWarningZh: '⚠️ 与 Gelbooru 一致，必须填纯数字 User ID，勿填用户名。',
      usernameWarningEn: '⚠️ Same as Gelbooru, must be numeric User ID, not username.',
      tokenLabelZh: 'API Key',
      tokenLabelEn: 'API Key',
      tokenHintZh: '账户设置页面的 API Key',
      tokenHintEn: 'API Key from account settings',
      stepsZh: [
        '在浏览器访问 Rule34.xxx 并登录你的账号。',
        '点击 Account -> Manage 账户管理页（或点击下方直达按钮）。',
        '在 API 区域生成并复制你的 API Key；同时确认自己的纯数字 User ID。',
        '分别填入 App 的 User ID 与 Token 输入框。',
      ],
      stepsEn: [
        'Open Rule34.xxx in browser and log in.',
        'Go to Account -> Manage (or click button below).',
        'Generate/view your API Key and note your numeric User ID.',
        'Enter the numeric User ID and API Key into the App fields.',
      ],
    ),

    const BooruCredentialGuide(
      id: 'sankaku',
      name: 'Sankaku Complex',
      host: 'sankakuapi.com',
      type: BooruType.sankaku,
      directUrl: 'https://sankaku.app',
      isAuthRequired: true,
      requirementZh: '建议配置。未登录时会有较严格的请求速率限制和深度翻页拦截；配置 Token 可解锁完整浏览。',
      requirementEn: 'Recommended. Unauthenticated access has strict rate limits and pagination caps; configuring a Token unlocks full browsing.',
      usernameLabelZh: '用户名 (可选，可留空)',
      usernameLabelEn: 'Username (Optional)',
      usernameHintZh: 'Sankaku 仅通过 Token 鉴权，用户名可留空',
      usernameHintEn: 'Sankaku only authenticates via Token, username can be left empty',
      tokenLabelZh: 'Access Token (Bearer 令牌)',
      tokenLabelEn: 'Access Token (Bearer Token)',
      tokenHintZh: '网页 LocalStorage 或请求头中的 access_token',
      tokenHintEn: 'access_token from browser LocalStorage or request headers',
      stepsZh: [
        '在电脑浏览器打开 sankaku.app（或点击下方按钮）并登录账号。',
        '按键盘 F12 打开开发者工具，切换到 Application（应用/存储）标签页。',
        '在左侧展开 Local Storage -> 选择 https://sankaku.app。',
        '在右侧找到名为 access_token 或 token 的键，复制其完整的长字符串值。',
        '粘贴到本 App 的 Token 输入框（用户名栏直接留空即可）。',
      ],
      stepsEn: [
        'Open sankaku.app in your browser and log in.',
        'Press F12 to open DevTools, then switch to Application (or Storage) tab.',
        'Expand Local Storage on the left and select https://sankaku.app.',
        'Find the key named access_token or token and copy the long string value.',
        'Paste it into App\'s Token field (Username can be left empty).',
      ],
      tipZh: 'Sankaku API 使用 HTTP Authorization: Bearer 头部鉴权，只需要有效的 Access Token 即可。',
      tipEn: 'Sankaku API uses HTTP Authorization: Bearer header. Only a valid Access Token is required.',
    ),

    const BooruCredentialGuide(
      id: 'yandere',
      name: 'Yande.re',
      host: 'yande.re',
      type: BooruType.moebooru,
      directUrl: 'https://yande.re',
      requirementZh: '非必须。匿名用户拥有完整的看图、多标签搜索与原图下载权限；登录主要用于同步投票和收藏。',
      requirementEn: 'Optional. Anonymous users have full browsing, multi-tag search, and download access; login is only for syncing favorites/votes.',
      usernameLabelZh: '用户名 (Username)',
      usernameLabelEn: 'Username',
      usernameHintZh: '你的 Yande.re 注册用户名',
      usernameHintEn: 'Your Yande.re username',
      tokenLabelZh: 'Password Hash (pass_hash Cookie)',
      tokenLabelEn: 'Password Hash (pass_hash Cookie)',
      tokenHintZh: '登录后浏览器 Cookie 中的 pass_hash',
      tokenHintEn: 'pass_hash from browser Cookies after login',
      tokenWarningZh: '⚠️ Moebooru API 要求密码哈希值（算法为 SHA1(choujin-steiner--密码--)），勿填明文密码。',
      tokenWarningEn: '⚠️ Moebooru API expects a password hash, not plaintext password.',
      stepsZh: [
        '在电脑浏览器打开 yande.re 并登录账号。',
        '按 F12 打开开发者工具，切换到 Application -> Cookies -> https://yande.re。',
        '找到名为 pass_hash 的 Cookie 项，复制其 Value 值。',
        '填入本 App 的 Token 输入框；用户名填你的登录用户名。',
      ],
      stepsEn: [
        'Open yande.re in browser and log in.',
        'Press F12 -> Application -> Cookies -> https://yande.re.',
        'Locate the Cookie named pass_hash and copy its value.',
        'Paste it into the Token field, and enter your username in Username.',
      ],
    ),

    const BooruCredentialGuide(
      id: 'konachan',
      name: 'Konachan (Safe)',
      host: 'konachan.net',
      type: BooruType.moebooru,
      directUrl: 'https://konachan.net',
      requirementZh: '非必须。同 Yande.re（Moebooru 架构），匿名可直接全量浏览与搜索，无需配置登录。',
      requirementEn: 'Optional. Same as Yande.re (Moebooru), public browsing works out of the box without login.',
      usernameLabelZh: '用户名 (Username)',
      usernameLabelEn: 'Username',
      usernameHintZh: '你的 Konachan 注册用户名',
      usernameHintEn: 'Your Konachan username',
      tokenLabelZh: 'Password Hash (pass_hash Cookie)',
      tokenLabelEn: 'Password Hash (pass_hash Cookie)',
      tokenHintZh: '登录后浏览器 Cookie 中的 pass_hash',
      tokenHintEn: 'pass_hash from browser Cookies after login',
      stepsZh: [
        '在浏览器打开 konachan.net 并登录。',
        '按 F12 打开开发者工具 -> Application -> Cookies -> https://konachan.net。',
        '复制 pass_hash Cookie 的值填入 Token 输入框。',
      ],
      stepsEn: [
        'Open konachan.net in browser and log in.',
        'Press F12 -> Application -> Cookies -> https://konachan.net.',
        'Copy the pass_hash Cookie value into the Token field.',
      ],
    ),

    const BooruCredentialGuide(
      id: 'safebooru',
      name: 'Safebooru',
      host: 'safebooru.org',
      type: BooruType.gelbooru,
      directUrl: 'https://safebooru.org',
      isNoAuthNeeded: true,
      requirementZh: '无需登录！Safebooru 是开放的安全级 Booru，公共 API 完全开放且无鉴权要求，直接留空即可。',
      requirementEn: 'No login needed! Safebooru is fully open and its public API requires no authentication. Leave fields empty.',
      usernameLabelZh: '用户名 / 用户 ID (留空即可)',
      usernameLabelEn: 'Username (Leave empty)',
      usernameHintZh: '无需填写',
      usernameHintEn: 'Not needed',
      tokenLabelZh: 'Token / 密码 (留空即可)',
      tokenLabelEn: 'Token (Leave empty)',
      tokenHintZh: '无需填写',
      tokenHintEn: 'Not needed',
      stepsZh: [
        '此站点无需配置账号凭据，所有功能（浏览、搜索、原图下载、标签）均直接可用。',
        '用户名和 Token 输入框保持为空即可。',
      ],
      stepsEn: [
        'This site does not require credentials. All features work out of the box.',
        'Leave both Username and Token fields empty.',
      ],
    ),

    const BooruCredentialGuide(
      id: 'paheal',
      name: 'Rule34 Paheal',
      host: 'rule34.paheal.net',
      type: BooruType.shimmie,
      directUrl: 'https://rule34.paheal.net',
      isNoAuthNeeded: true,
      requirementZh: '无需登录！Paheal 基于 Shimmie 架构，公开搜索接口完全开放，不支持 API Token 认证，留空即可。',
      requirementEn: 'No login needed! Paheal uses Shimmie Danbooru-compatible public API without token auth. Leave fields empty.',
      usernameLabelZh: '用户名 (留空即可)',
      usernameLabelEn: 'Username (Leave empty)',
      usernameHintZh: '无需填写',
      usernameHintEn: 'Not needed',
      tokenLabelZh: 'Token (留空即可)',
      tokenLabelEn: 'Token (Leave empty)',
      tokenHintZh: '无需填写',
      tokenHintEn: 'Not needed',
      stepsZh: [
        'Paheal 使用公开的 Shimmie 接口提供搜索与浏览服务。',
        '无需账号认证，用户名和 Token 直接保持为空。',
      ],
      stepsEn: [
        'Paheal uses public Shimmie endpoints for browsing and search.',
        'No authentication required. Keep fields empty.',
      ],
    ),
  ];

  /// Find matching guide by BooruSite
  static BooruCredentialGuide forSite(BooruSite site) {
    return forHostOrType(site.host, site.type);
  }

  /// Find matching guide by Host string and Engine Type
  static BooruCredentialGuide forHostOrType(String host, int type) {
    final cleanHost = host.toLowerCase().trim();

    // Check exact or partial host matches in preset list
    for (final preset in presetGuides) {
      final pHost = preset.host.toLowerCase();
      if (cleanHost.isNotEmpty && (cleanHost == pHost || cleanHost.contains(pHost) || pHost.contains(cleanHost))) {
        return preset;
      }
    }

    // Specific domain keywords
    if (cleanHost.contains('danbooru')) return presetGuides.firstWhere((g) => g.id == 'danbooru');
    if (cleanHost.contains('e621')) return presetGuides.firstWhere((g) => g.id == 'e621');
    if (cleanHost.contains('gelbooru')) return presetGuides.firstWhere((g) => g.id == 'gelbooru');
    if (cleanHost.contains('rule34.xxx')) return presetGuides.firstWhere((g) => g.id == 'rule34');
    if (cleanHost.contains('safebooru')) return presetGuides.firstWhere((g) => g.id == 'safebooru');
    if (cleanHost.contains('yande.re')) return presetGuides.firstWhere((g) => g.id == 'yandere');
    if (cleanHost.contains('konachan')) return presetGuides.firstWhere((g) => g.id == 'konachan');
    if (cleanHost.contains('sankaku')) return presetGuides.firstWhere((g) => g.id == 'sankaku');
    if (cleanHost.contains('paheal')) return presetGuides.firstWhere((g) => g.id == 'paheal');

    // Generic fallback based on engine type
    return _genericForType(type, host);
  }

  static BooruCredentialGuide _genericForType(int type, String host) {
    switch (type) {
      case BooruType.danbooru:
        return BooruCredentialGuide(
          id: 'custom_danbooru',
          name: host.isNotEmpty ? host : 'Danbooru 站点',
          host: host,
          type: BooruType.danbooru,
          requirementZh: 'Danbooru 2.x 架构 API：通常使用登录用户名与个人资料页生成的 API Key 进行鉴权。',
          requirementEn: 'Danbooru 2.x API: Authenticates via login username and API Key generated in your profile.',
          usernameLabelZh: '用户名 (Login Name)',
          usernameLabelEn: 'Username (Login Name)',
          usernameHintZh: '你的账号登录名',
          usernameHintEn: 'Your account login name',
          tokenLabelZh: 'API Key',
          tokenLabelEn: 'API Key',
          tokenHintZh: '个人资料页生成的 API Key',
          tokenHintEn: 'API Key from user profile',
          tokenWarningZh: '⚠️ 请使用 API Key，多数 Danbooru 站点已禁止明文密码访问 API。',
          tokenWarningEn: '⚠️ Please use an API Key; passwords are often blocked on modern Danbooru sites.',
          stepsZh: [
            '登录该站点并在个人中心 (Profile) 找到 API Key 设置。',
            '生成或查看 API Key，复制填入 Token 栏；用户名填登录名。',
          ],
          stepsEn: [
            'Log into the site and navigate to your Profile to find the API Key section.',
            'Generate/copy the API Key into Token; enter your login name in Username.',
          ],
        );

      case BooruType.gelbooru:
      case BooruType.gelbooruLegacy:
        return BooruCredentialGuide(
          id: 'custom_gelbooru',
          name: host.isNotEmpty ? host : 'Gelbooru 站点',
          host: host,
          type: BooruType.gelbooru,
          requirementZh: 'Gelbooru 架构 API：通常要求纯数字 User ID 和 API Key。',
          requirementEn: 'Gelbooru API: Usually requires numeric User ID and API Key.',
          usernameLabelZh: '用户 ID (纯数字 User ID)',
          usernameLabelEn: 'Numeric User ID',
          usernameHintZh: '例如 123456（账户设置中的纯数字 ID）',
          usernameHintEn: 'e.g. 123456 (numeric ID from account settings)',
          usernameWarningZh: '⚠️ 必须填入纯数字 User ID，而非用户名。',
          usernameWarningEn: '⚠️ Must be a numeric User ID, not a username.',
          tokenLabelZh: 'API Key',
          tokenLabelEn: 'API Key',
          tokenHintZh: '账户选项中生成的 API Key',
          tokenHintEn: 'API Key generated in account options',
          stepsZh: [
            '登录站点并进入 Account -> Options。',
            '在 API Credentials 区域复制纯数字 User ID 与 API Key。',
          ],
          stepsEn: [
            'Log in and navigate to Account -> Options.',
            'Copy the numeric User ID and API Key from API Credentials.',
          ],
        );

      case BooruType.moebooru:
        return BooruCredentialGuide(
          id: 'custom_moebooru',
          name: host.isNotEmpty ? host : 'Moebooru 站点',
          host: host,
          type: BooruType.moebooru,
          requirementZh: 'Moebooru 架构 API：通常使用用户名与密码 SHA1 哈希 (pass_hash)。',
          requirementEn: 'Moebooru API: Usually uses username and SHA1 password hash (pass_hash).',
          usernameLabelZh: '用户名 (Username)',
          usernameLabelEn: 'Username',
          usernameHintZh: '注册用户名',
          usernameHintEn: 'Account username',
          tokenLabelZh: 'Password Hash (pass_hash Cookie)',
          tokenLabelEn: 'Password Hash (pass_hash Cookie)',
          tokenHintZh: '登录后 Cookie 中的 pass_hash',
          tokenHintEn: 'pass_hash from browser cookies',
          stepsZh: [
            '登录站点后，在浏览器开发者工具 (F12) 的 Cookies 中找到 pass_hash 的值复制填入。',
          ],
          stepsEn: [
            'After logging in, copy the value of pass_hash from browser Cookies (F12).',
          ],
        );

      case BooruType.sankaku:
        return BooruCredentialGuide(
          id: 'custom_sankaku',
          name: host.isNotEmpty ? host : 'Sankaku 站点',
          host: host,
          type: BooruType.sankaku,
          requirementZh: 'Sankaku 架构 API：使用 Bearer Access Token 鉴权。',
          requirementEn: 'Sankaku API: Uses Bearer Access Token for authentication.',
          usernameLabelZh: '用户名 (可选，可留空)',
          usernameLabelEn: 'Username (Optional)',
          usernameHintZh: '可留空',
          usernameHintEn: 'Can be left empty',
          tokenLabelZh: 'Access Token',
          tokenLabelEn: 'Access Token',
          tokenHintZh: '登录后的 Access Token',
          tokenHintEn: 'Access Token after login',
          stepsZh: [
            '登录站点后在 LocalStorage 或请求头中提取 access_token 填入。',
          ],
          stepsEn: [
            'Extract access_token from LocalStorage or network headers and paste into Token.',
          ],
        );

      case BooruType.shimmie:
      default:
        return BooruCredentialGuide(
          id: 'custom_shimmie',
          name: host.isNotEmpty ? host : 'Shimmie / 公开站点',
          host: host,
          type: BooruType.shimmie,
          isNoAuthNeeded: true,
          requirementZh: '此站点通常公开开放，直接留空即可正常浏览。',
          requirementEn: 'This site is typically publicly accessible. Leave fields empty.',
          usernameLabelZh: '用户名 (留空即可)',
          usernameLabelEn: 'Username (Leave empty)',
          usernameHintZh: '无需填写',
          usernameHintEn: 'Not needed',
          tokenLabelZh: 'Token (留空即可)',
          tokenLabelEn: 'Token (Leave empty)',
          tokenHintZh: '无需填写',
          tokenHintEn: 'Not needed',
          stepsZh: [
            '无需填写账号凭据，留空直接保存即可。',
          ],
          stepsEn: [
            'No credentials needed, leave empty and save.',
          ],
        );
    }
  }
}
