# Flexbooru Flutter

[![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10%2B-0175C2.svg)](https://dart.dev)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-orange.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux-green.svg)]()

基于原生 Android Kotlin 项目 [flexbooru/flexbooru](https://github.com/flexbooru/flexbooru) 重写的 Flutter Booru 客户端，由 YunariCloud 在独立仓库维护。

- **本项目**：[YunariCloud/flexbooru-flutter](https://github.com/YunariCloud/flexbooru-flutter)。使用不同仓库名，便于区分原项目与 Flutter 版本。
- **原项目地址**：[https://github.com/flexbooru/flexbooru](https://github.com/flexbooru/flexbooru)。原仓库已于 2024 年 6 月 16 日归档。
- **项目关系**：本仓库是独立维护的 Flutter 重写与接口适配版本，不是原作者的官方发布；原项目及贡献者的工作在此致谢。
- **许可证**：沿用 GPL-3.0，完整许可证见 [LICENSE](LICENSE)，从原项目保留。

## Flutter 版本的实现与扩展

使用 Flutter/Dart 实现统一的 Material 3 界面，包含 Android、Windows、iOS、macOS 和 Linux 平台工程；新增桌面端适配、响应式瀑布流列数、中文/英文界面、AMOLED 主题、跨平台下载路径、本地收藏与可配置网络请求头。下面列出当前实现的功能；本次针对站点加载失败的修复单独列在后文。

---

## 🌟 功能特性 (Features)

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
  - 高清大图/视频本地下载与进度展示 (适配 Android 13/14+ 分区存储与 Windows 下载路径)
  - 收藏夹：本地收藏作品离线持久化存储
  - 标签黑名单：全局与单个站点黑名单标签过滤
  - 搜索建议：实时标签联想与补全，搜索历史记录
- **外观与定制**:
  - Material 3 风格设计
  - 明暗主题与专为 OLED 屏幕设计的 **AMOLED 纯黑模式**
  - 多种强调色切换
  - 自定义 User-Agent（同时用于 API 与图片）与站点 Referer 请求头

---

## 本次修复与新增内容

| 范围 | 问题 | 修复或新增行为 |
| --- | --- | --- |
| Danbooru | 默认浏览器 UA 触发 Cloudflare；自定义 UA 仅保存、未用于请求 | 使用客户端默认标识，迁移旧默认 UA；设置同时用于 API、图片和下载请求 |
| Gelbooru | 401 认证错误显示 Dio 长串异常；标签和评论未发送凭据 | 校验完整 User ID/API Key，作品、标签、评论请求均携带认证；增加认证提示和编辑入口 |
| Rule34.xxx | 网页域名与 API 域名混用；错误安全分级参数；HTTP 200 的认证错误被吞成空结果 | 使用 `api.rule34.xxx`、`rating:safe`，识别认证错误、非法 JSON/XML 和异常响应结构；兼容旧保存域名 |
| Sankaku | 旧域名返回 nginx 403；新接口 ID 为字符串；分页未使用真实游标 | 使用 `sankakuapi.com`、匹配站点的默认 UA、Bearer Token；支持作品及上传者字符串 ID、收藏序列化和 `meta.next` 分页 |
| 错误处理 | 所有 403 都被误判为 Cloudflare，接口错误与没有作品混淆 | 分别处理认证、普通 403、Cloudflare challenge、422、429、超时与连接失败，提供中文/英文说明及浏览器检查入口 |
| 作品加载 | 切换站点或刷新时旧请求可能覆盖新结果；安全模式空结果原因不明确 | 忽略过期请求结果，增加安全模式空结果说明，热门结果也执行安全分级过滤 |
| Lolibooru | 持续连接超时 | 移除默认预设与专用超时配置；升级时清理已保存的 Lolibooru 站点，自动切换到可用预设 |
| 验证与来源 | 缺少针对上述接口变化的回归覆盖与清晰来源说明 | 新增请求/解析/迁移回归测试，README 与应用关于页同时标明本项目、原项目和修复内容，补齐原项目 GPL-3.0 许可证 |

已有兼容实现包括协议相对图片 URL 规范化、Gelbooru 多种 JSON 包装及 XML 解析、Shimmie API，以及原 Flexbooru 的 Base64 `booru://` 站点导入/导出。Danbooru 的安全模式在添加分级标签会超限时使用客户端过滤；用户自己输入的多标签查询仍受站点账号等级限制。

## 站点连接与认证

- **Danbooru**：API 默认发送 `Flexbooru/2.0 (Flutter; Booru client)`。旧的默认 Chrome UA 会自动迁移；自定义 UA 会真正用于请求。部分网络仍可能被站点要求完成浏览器验证，修改 UA 不保证通过所有防护规则。
- **Gelbooru**：站点可能要求 API 认证。请在「管理 Booru 网站 → 编辑」填写账户设置页的数字 `user_id` 和 `api_key`，而非登录密码。作品、标签、评论请求均发送这组凭据。参见 [官方 API 文档](https://gelbooru.com/index.php?page=wiki&s=view&id=18780)。
- **Rule34.xxx**：请求自动使用 `api.rule34.xxx`，旧保存配置无需重置。请填写账户设置页的 User ID 和 API Key。安全查询使用 `rating:safe`；HTTP 200 返回的认证错误也会作为加载错误提示。参见 [官方 API 文档](https://api.rule34.xxx/)。
- **Sankaku**：默认及已保存的旧 API 域名均使用新接口；需要登录权限时填写有效 Bearer Token。客户端不会自动登录或刷新失效 Token。

401、普通 403、Cloudflare challenge、超时和接口数据错误分别显示中文/英文说明。只有合法空列表或空 XML 才显示「未找到相关作品」；安全模式导致的空结果也会给出提示。

实测 Danbooru 能解析作品，Sankaku 能连续获取两页不同作品。Gelbooru 与 Rule34 的未认证请求会显示认证提示；成功认证访问需要用户自己的有效凭据。以上结果不保证站点未来可用，或所有地区/网络均可访问。

---

## 🚀 运行与构建 (Build & Run)

### 前置环境
- Flutter SDK >= 3.38（本地验证使用 3.38.5）
- Dart SDK >= 3.10.4（以 `pubspec.yaml` 为准）
- 相应平台构建工具链；包含平台工程不代表已在所有平台完成运行验证。

### 依赖安装
```bash
flutter pub get
```

### 运行单元测试
```bash
flutter test
```

静态检查：`flutter analyze`。回归测试覆盖域名迁移、自定义 UA、认证参数、JSON/XML 错误与合法空结果、字符串 ID、游标分页、旧 Lolibooru 配置清理及现有基础功能。

### 本地调试运行
```bash
# Windows
flutter run -d windows

# Android
flutter run -d android
```

### 生产版本构建
```bash
# 构建 Android APK
flutter build apk --release

# 构建 Windows 可执行程序
flutter build windows --release
```
编译产物位于 `build/windows/x64/runner/Release/` 或 `build/app/outputs/flutter-apk/app-release.apk`。
