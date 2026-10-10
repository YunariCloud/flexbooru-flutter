# Flexbooru Flutter

[简体中文](#flexbooru-flutter-中文) | [English](#flexbooru-flutter-english)

---

<a id="flexbooru-flutter-中文"></a>
## Flexbooru Flutter (中文)

[![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10%2B-0175C2.svg)](https://dart.dev)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-orange.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux-green.svg)]()
[![Build and Release](https://github.com/YunariCloud/flexbooru-flutter/actions/workflows/build-release.yml/badge.svg)](https://github.com/YunariCloud/flexbooru-flutter/actions/workflows/build-release.yml)

基于原生 Android Kotlin 项目 [flexbooru/flexbooru](https://github.com/flexbooru/flexbooru) 重写的 Flutter Booru 客户端，由 YunariCloud 在独立仓库维护。

- **本项目**：[YunariCloud/flexbooru-flutter](https://github.com/YunariCloud/flexbooru-flutter)。使用不同仓库名，便于区分原项目与 Flutter 版本。
- **原项目地址**：[https://github.com/flexbooru/flexbooru](https://github.com/flexbooru/flexbooru)。原仓库已于 2024 年 6 月 16 日归档。
- **项目关系**：本仓库是独立维护的 Flutter 重写与接口适配版本，不是原作者的官方发布；原项目及贡献者的工作在此致谢。
- **许可证**：沿用 GPL-3.0，完整许可证见 [LICENSE](LICENSE)，从原项目保留。

### Flutter 版本的实现与扩展

使用 Flutter/Dart 实现统一的 Material 3 界面，包含 Android、Windows、iOS、macOS 和 Linux 平台工程；新增桌面端适配、响应式瀑布流列数、中文/英文界面、AMOLED 主题、全局主题强调色拓展、调用系统文件选择器自定义下载路径、在线检查更新服务、本地收藏与可配置网络请求头。

---

### 🌟 功能特性 (Features)

- **多引擎支持**:
  - **Danbooru** (Danbooru 2.x API 及 e621)
  - **Moebooru** (Yande.re, Konachan 等)
  - **Gelbooru** (Gelbooru 0.2.x 现代 JSON API 及 Legacy XML，Safebooru, Rule34.xxx)
  - **Sankaku Complex** (`sankakuapi.com` API、字符串 ID、Keyset 分页及认证)
  - **Shimmie 2** (Rule34 Paheal 等 XML API)
- **瀑布流浏览**:
  - 高性能 Masonry Staggered Grid 瀑布流布局
  - 自动适配屏幕宽度 (手机 2 列、平板 3-4 列、桌面端 5 列或自定义列数)
  - 缩略图按原图比例呈现，支持评分等级标识 (G / S / Q / E) 与视频/动图徽标
- **高清大图查看器**:
  - 基于 PhotoView 的多手势无缝缩放、双击放大与平移
  - 原图 (Original) 与样本图 (Sample) 灵活切换
  - 详情面板：尺寸、体积、评分、热度、上传者、原始来源链接跳转
  - 分类标签体系：按绘师 (Artist)、作品 (Copyright)、角色 (Character)、社团 (Circle)、常规 (General) 色彩区分，支持一键复制
  - 评论面板：查看各帖子评论列表
  - 以图搜图：一键跳转 SauceNAO
- **本地与跨端能力**:
  - 高清大图/视频本地下载与进度展示 (适配 Android 13/14+ 分区存储与桌面端下载路径)
  - **调用系统文件选择器**：桌面端一键唤起原生文件夹选择弹窗，支持路径可写性校验与快捷预设
  - **在线检查更新**：内置 GitHub Releases 自动与手动检查更新，包含更新日志与下载跳转
  - 收藏夹：本地收藏作品离线持久化存储
  - 标签黑名单：全局与单个站点黑名单标签过滤
  - 搜索建议：实时标签联想与补全，搜索历史记录
- **外观与定制**:
  - Material 3 风格设计与全界面主题强调色渗透
  - 明暗主题与专为 OLED 屏幕设计的 **AMOLED 纯黑模式**
  - 多种强调色切换（Indigo, Blue, Teal, Green, Orange, Pink, Purple, Blue Grey）
  - 自定义 User-Agent（同时用于 API 与图片）与站点 Referer 请求头

---

### 本次修复与新增内容

| 范围 | 问题 | 修复或新增行为 |
| --- | --- | --- |
| Danbooru | 默认浏览器 UA 触发 Cloudflare；自定义 UA 仅保存、未用于请求 | 使用客户端默认标识，迁移旧默认 UA；设置同时用于 API、图片和下载请求 |
| Gelbooru | 401 认证错误显示 Dio 长串异常；标签和评论未发送凭据 | 校验完整 User ID/API Key，作品、标签、评论请求均携带认证；增加认证提示和编辑入口 |
| Rule34.xxx | 网页域名与 API 域名混用；错误安全分级参数；HTTP 200 的认证错误被吞成空结果 | 使用 `api.rule34.xxx`、`rating:safe`，识别认证错误、非法 JSON/XML 和异常响应结构；兼容旧保存域名 |
| Sankaku | 旧域名返回 nginx 403；新接口 ID 为字符串；分页未使用真实游标 | 使用 `sankakuapi.com`、匹配站点的默认 UA、Bearer Token；支持作品及上传者字符串 ID、收藏序列化和 `meta.next` 分页 |
| 错误处理 | 所有 403 都被误判为 Cloudflare，接口错误与没有作品混淆 | 分别处理认证、普通 403、Cloudflare challenge、422、429、超时与连接失败，提供中文/英文说明及浏览器检查入口 |
| 作品加载 | 切换站点或刷新时旧请求可能覆盖新结果；安全模式空结果原因不明确 | 忽略过期请求结果，增加安全模式空结果说明，热门结果也执行安全分级过滤 |
| Lolibooru | 持续连接超时 | 移除默认预设与专用超时配置；升级时清理已保存的 Lolibooru 站点，自动切换到可用预设 |
| 主题强调色 | 主题色仅作用于部分按钮，界面其余部分不够明显 | 全局注入 M3 配色，AppBar、ListTile 图标、高亮背景、设置分组、药丸等全面渗透用户选择的主题色 |
| 下载路径 | 手动输入路径繁琐，桌面端缺乏原生目录选择器 | 支持原生系统文件夹选择器（Windows STA/macOS/Linux），集成快速预设与写入权限校验 |
| 检查更新 | 缺少版本发现机制 | 新增 GitHub Release API 检查与重定向回退机制，支持启动自动检测与关于页手动检查 |
| 验证与来源 | 缺少针对上述接口变化的回归覆盖与清晰来源说明 | 新增请求/解析/迁移/下载/更新回归测试，README 与应用关于页同时标明本项目、原项目和修复内容，补齐原项目 GPL-3.0 许可证 |

---

### 站点连接与认证

- **Danbooru**：API 默认发送 `Flexbooru/2.0 (Flutter; Booru client)`。旧的默认 Chrome UA 会自动迁移；自定义 UA 会真正用于请求。部分网络仍可能被站点要求完成浏览器验证，修改 UA 不保证通过所有防护规则。
- **Gelbooru**：站点可能要求 API 认证。请在「管理 Booru 网站 → 编辑」填写账户设置页的数字 `user_id` 和 `api_key`，而非登录密码。作品、标签、评论请求均发送这组凭据。参见 [官方 API 文档](https://gelbooru.com/index.php?page=wiki&s=view&id=18780)。
- **Rule34.xxx**：请求自动使用 `api.rule34.xxx`，旧保存配置无需重置。请填写账户设置页的 User ID 和 API Key。安全查询使用 `rating:safe`；HTTP 200 返回的认证错误也会作为加载错误提示。参见 [官方 API 文档](https://api.rule34.xxx/)。
- **Sankaku**：默认及已保存的旧 API 域名均使用新接口；需要登录权限时填写有效 Bearer Token。客户端不会自动登录或刷新失效 Token。

401、普通 403、Cloudflare challenge、超时和接口数据错误分别显示中文/英文说明。只有合法空列表或空 XML 才显示「未找到相关作品」；安全模式导致的空结果也会给出提示。

---

### 🚀 运行与构建 (Build & Run)

#### 前置环境
- Flutter SDK >= 3.38（本地验证使用 3.38.5）
- Dart SDK >= 3.10.4（以 `pubspec.yaml` 为准）
- 相应平台构建工具链（Windows 需 C++ CMake 编译环境，Android 需 JDK 17 及 Android SDK）

#### 依赖安装
```bash
flutter pub get
```

#### 运行单元测试与分析
```bash
flutter analyze
flutter test
```

#### 本地调试运行
```bash
# Windows
flutter run -d windows

# Android
flutter run -d android
```

#### 生产版本构建
```bash
# 构建 Android APK
flutter build apk --release

# 构建 Windows 可执行程序
flutter build windows --release
```
编译产物位于 `build/windows/x64/runner/Release/` 或 `build/app/outputs/flutter-apk/app-release.apk`。

---

### GitHub Actions 自动打包与发布

工作流：[Build and Release](https://github.com/YunariCloud/flexbooru-flutter/actions/workflows/build-release.yml)，配置见 [.github/workflows/build-release.yml](.github/workflows/build-release.yml)。固定使用 Flutter 3.38.5 / Java 17，先运行静态检查和测试，随后构建 Android 与 Windows。

| 触发方式 | 行为 |
| --- | --- |
| 推送到 `master` / `main` 或提交 PR | 自动检查、打包 APK、AAB 和 Windows ZIP；产物保存在该次 Actions 的 Artifacts 中，保留 14 天；不创建 Release |
| 推送 `v1.0.1` 等 `v*` 标签 | 两个平台构建成功后，自动创建或更新同名 GitHub Release 并上传产物及 SHA-256 校验文件 |
| Actions → Build and Release → Run workflow | 默认仅构建；勾选 `publish` 并填写 `tag` 可以发布。已有标签必须对应当前选择的提交 |

发布产物包括：
- `flexbooru-flutter-<版本>-android-universal.apk`：可直接安装的 Android 通用 APK。
- `flexbooru-flutter-<版本>-android.aab`：Android App Bundle。
- `flexbooru-flutter-<版本>-windows-x64.zip`：包含 EXE、全部 DLL、`data` 目录、README 和许可证。解压后运行 `flexbooru.exe`；系统需要 Microsoft Visual C++ 2015–2022 x64 运行库。
- `android-SHA256SUMS.txt` / `windows-SHA256SUMS.txt` 和 GPL-3.0 许可证。

#### Android 发布签名 Secrets
在仓库 Settings → Secrets and variables → Actions 配置：
- `ANDROID_KEYSTORE_BASE64`：JKS 文件的 Base64 编码
- `ANDROID_KEYSTORE_PASSWORD`：Keystore 密码
- `ANDROID_KEY_PASSWORD`：签名密钥密码
- `ANDROID_KEY_ALIAS`：密钥别名

---

<a id="flexbooru-flutter-english"></a>
## Flexbooru Flutter (English)

[![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10%2B-0175C2.svg)](https://dart.dev)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-orange.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux-green.svg)]()
[![Build and Release](https://github.com/YunariCloud/flexbooru-flutter/actions/workflows/build-release.yml/badge.svg)](https://github.com/YunariCloud/flexbooru-flutter/actions/workflows/build-release.yml)

A multi-platform Booru client rewritten in Flutter and Dart based on the original Android Kotlin project [flexbooru/flexbooru](https://github.com/flexbooru/flexbooru), maintained independently by YunariCloud.

- **This Project**: [YunariCloud/flexbooru-flutter](https://github.com/YunariCloud/flexbooru-flutter). Uses a distinct repository name to avoid confusion with the original Kotlin repository.
- **Original Project**: [https://github.com/flexbooru/flexbooru](https://github.com/flexbooru/flexbooru). Archived on June 16, 2024.
- **Relationship**: This repository is an independent Flutter rewrite and modern API adaptation, not an official release from the original authors. Grateful acknowledgment is given to the original creators and contributors.
- **License**: Released under GNU General Public License v3.0 ([LICENSE](LICENSE)), preserved from the upstream project.

---

### Implementation & Enhancements

Flexbooru Flutter provides a unified Material 3 interface across Android, Windows, iOS, macOS, and Linux platforms. Enhancements over the original project include desktop layout adaptation, responsive masonry waterfall grid columns, bilingual interface (English / Chinese), AMOLED pure black theme, pervasive accent color customisation, native OS folder picker integration for download locations, in-app update checking with version comparison, offline favorites persistence, and configurable anti-WAF request headers.

---

### 🌟 Key Features

- **Multi-Engine Compatibility**:
  - **Danbooru** (Danbooru 2.x API and e621)
  - **Moebooru** (Yande.re, Konachan, etc.)
  - **Gelbooru** (Gelbooru 0.2.x modern JSON API and Legacy XML, Safebooru, Rule34.xxx)
  - **Sankaku Complex** (`sankakuapi.com` API, string IDs, keyset pagination, and bearer authentication)
  - **Shimmie 2** (Rule34 Paheal and other XML APIs)
- **Waterfall Masonry Browsing**:
  - High-performance Masonry Staggered Grid layout
  - Automatic column adjustment based on screen width (2 columns on mobile, 3–4 on tablets, 5 on desktop, or custom user overrides)
  - Aspect-ratio thumbnail rendering with rating indicators (G / S / Q / E) and video / GIF badges
- **High-Resolution Media Viewer**:
  - Gesture-driven smooth pinch-to-zoom, double-tap zoom, and pan powered by PhotoView
  - Dynamic switching between Original and Sample resolutions
  - Comprehensive details sheet: dimensions, file size, rating, score, uploader, and source links
  - Categorized tag system: color-coded by Artist, Copyright, Character, Circle, and General with one-tap copy
  - Comments sheet: inspect community discussions on individual posts
  - Reverse image search: one-tap lookup on SauceNAO
- **Offline & Cross-Platform Utilities**:
  - Full-resolution image and video downloading with real-time progress indicators
  - **Native Folder Browser Dialog**: invoke the OS-native directory chooser (Windows STA / macOS / Linux) with path writability verification and quick presets
  - **In-App Update Checker**: automated and manual release checking via GitHub API with changelog display
  - Local favorites library with persistent offline storage
  - Tag blacklist: filter unwanted tags globally or per site
  - Search autosuggestion with real-time tag completion and search history
- **Design & Personalization**:
  - Material 3 aesthetic with pervasive theme accent color integration across AppBar, navigation, list icons, section headers, and controls
  - Light and Dark modes plus **AMOLED Pure Black** mode designed for OLED screens
  - Multiple accent palette choices (Indigo, Blue, Teal, Green, Orange, Pink, Purple, Blue Grey)
  - Customizable User-Agent (applied to both API and image requests) and Referer headers

---

### Bug Fixes & Modernization Summary

| Component | Issue in Legacy Implementation | Resolution in This Version |
| --- | --- | --- |
| **Danbooru** | Default browser UA triggered Cloudflare challenge; custom UA was saved but never attached to requests | Replaced with client identity `Flexbooru/2.0`, auto-migrated legacy Chrome UA, and properly propagated UA to API, image, and download requests |
| **Gelbooru** | 401 Unauthorized threw raw Dio error strings; tags and comments omitted auth parameters | Enforced complete User ID / API Key validation, included credentials across posts, tags, and comments, and added direct credential configuration prompts |
| **Rule34.xxx** | Mixed web and API hostnames; wrong safe rating query; HTTP 200 auth errors were swallowed into empty results | Standardized on `api.rule34.xxx`, used `rating:safe`, detected auth failures, malformed responses, and unexpected structures; maintained backward compatibility with legacy saved URLs |
| **Sankaku** | Legacy API domain returned nginx 403; new endpoints returned alphanumeric IDs; pagination omitted cursor tokens | Migrated to `sankakuapi.com` with matched UA and Bearer Token; supported opaque string IDs, serialized favorites, and keyset pagination using `meta.next` |
| **Error Handling** | All 403 responses were misidentified as Cloudflare challenges; network errors were conflated with empty results | Distinguished authentication (401), authorization (403), Cloudflare challenges, validation (422), rate limits (429), timeouts, and DNS failures with bilingual diagnostics and browser verification links |
| **Post Loading** | Outdated asynchronous requests could overwrite fresher results upon fast site switching; safe mode empty states were ambiguous | Discarded stale request responses, added informative safe mode empty explanations, and enforced safe rating filters on popular queries |
| **Lolibooru** | Persistent connection timeouts | Removed obsolete defaults; automatically sanitized saved Lolibooru site configurations on launch and migrated to active presets |
| **Accent Colors** | Theme color was restricted to minor UI controls | Expanded primary accent color across AppBar themes, navigation indicators, ListTile icons, section headers, active pills, and input borders |
| **Download Path** | Manual text entry was error-prone on desktop | Added native OS folder picker invocation (PowerShell STA on Windows, AppleScript on macOS, Zenity on Linux) alongside quick presets and writability checks |
| **Updates** | No built-in version discovery | Implemented GitHub Release API update checks with redirect fallback, startup detection, and release notes modal |
| **Testing & Provenance** | Missing regression coverage for modernized API behaviors and attribution | Added unit and widget tests covering API parsing, host resolution, credentials, downloader, and localization; added complete GPL-3.0 attribution and bilingual documentation |

---

### Connection & Authentication Notes

- **Danbooru**: By default, requests use `Flexbooru/2.0 (Flutter; Booru client)`. Legacy desktop Chrome UAs are automatically migrated. Custom UAs configured in Settings are applied to all API, media, and download requests. Certain networks may still encounter Cloudflare challenges; customizing the UA does not bypass all firewall rules.
- **Gelbooru**: The service requires API authentication for search queries. In **Manage Boorus → Edit Site**, provide your numerical `user_id` and alphanumeric `api_key` found in your account settings (not your login password). See [Official Gelbooru API Wiki](https://gelbooru.com/index.php?page=wiki&s=view&id=18780).
- **Rule34.xxx**: Requests automatically route to `api.rule34.xxx`. Please provide your User ID and API Key from your profile. Safe mode uses `rating:safe`. Authentication failures returning HTTP 200 are surfaced as actionable errors. See [Rule34 API Documentation](https://api.rule34.xxx/).
- **Sankaku**: Default and saved legacy endpoints route to `sankakuapi.com`. Enter your valid Bearer Token if authenticated access is desired. The client does not perform automated token refreshes.

---

### 🚀 Build and Run

#### Prerequisites
- Flutter SDK >= 3.38 (verified on 3.38.5)
- Dart SDK >= 3.10.4
- Platform toolchains (Visual Studio C++ & CMake for Windows; JDK 17 & Android SDK for Android)

#### Install Dependencies
```bash
flutter pub get
```

#### Run Tests and Static Analysis
```bash
flutter analyze
flutter test
```

#### Run Locally
```bash
# Windows Desktop
flutter run -d windows

# Android Device / Emulator
flutter run -d android
```

#### Build Release Binaries
```bash
# Android Universal APK
flutter build apk --release

# Windows x64 Executable
flutter build windows --release
```
Compiled artifacts are located in `build/windows/x64/runner/Release/` and `build/app/outputs/flutter-apk/app-release.apk`.

---

### Automated CI/CD & Releases (GitHub Actions)

Workflow configuration: [.github/workflows/build-release.yml](.github/workflows/build-release.yml). Runs on Flutter 3.38.5 and Java 17 to execute code analysis, automated test suites, and cross-platform artifact builds.

| Trigger | Actions Behavior |
| --- | --- |
| Push to `master` / PR | Runs analysis and test suites, packages APK, AAB, and Windows ZIP, and stores artifacts for 14 days without creating a Release |
| Push tag matching `v*` (e.g., `v1.0.1`) | Upon successful builds, automatically generates or updates the GitHub Release, uploading universal APK, AAB, Windows ZIP, and SHA-256 checksums |
| Manual workflow dispatch | Trigger manual builds with an optional `publish` flag and release `tag` |

Release packages:
- `flexbooru-flutter-<version>-android-universal.apk`: Installable Android APK.
- `flexbooru-flutter-<version>-android.aab`: Android App Bundle.
- `flexbooru-flutter-<version>-windows-x64.zip`: Standalone Windows distribution including executable, runtime libraries, and data directory (requires Microsoft Visual C++ 2015–2022 x64 Redistributable).
- `android-SHA256SUMS.txt` / `windows-SHA256SUMS.txt`: Cryptographic SHA-256 verification files.

#### Android Keystore Signing Secrets
Configure the following Repository Secrets under **Settings → Secrets and variables → Actions**:
- `ANDROID_KEYSTORE_BASE64`: Base64 string of your release `.jks` file
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_PASSWORD`: Key password
- `ANDROID_KEY_ALIAS`: Key alias
