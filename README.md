<p align="center">
  <img src="assets/icons/app_icon.png" alt="Flexbooru 软件图标" width="120" height="120">
</p>

<h1 align="center">Flexbooru Flutter</h1>

<p align="center">
  <strong>基于 Flutter 的 Booru 客户端</strong><br>
  Android · Windows · 作品浏览 · 局域网实时同步
</p>

<p align="center">
  <a href="https://github.com/YunariCloud/flexbooru-flutter/releases/latest"><strong>下载最新版</strong></a> ·
  <a href="https://github.com/YunariCloud/flexbooru-flutter/releases">更新记录</a> ·
  <a href="docs/README.en.md">English</a>
</p>

<p align="center">
  <a href="https://github.com/YunariCloud/flexbooru-flutter/actions/workflows/build-release.yml"><img src="https://github.com/YunariCloud/flexbooru-flutter/actions/workflows/build-release.yml/badge.svg" alt="Build and Release"></a>
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows-3F51B5" alt="Android and Windows">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="#下载与安装">下载与安装</a> · <a href="#主要功能">主要功能</a> · <a href="#局域网实时同步">实时同步</a> · <a href="#自动下载更新">自动更新</a> · <a href="#开发与构建">开发构建</a>
</p>

---

## 下载与安装

在 [Releases](https://github.com/YunariCloud/flexbooru-flutter/releases/latest) 中，按设备选择一个文件：

| 设备 | 下载文件 | 安装方式 |
| --- | --- | --- |
| Android | `flexbooru-flutter-<版本>-android-universal.apk` | 下载后安装；当前发布包要求 Android 7.0 或更高，具体以安装包要求为准 |
| Windows x64 | `flexbooru-flutter-<版本>-windows-x64.zip` | 完整解压后运行 `flexbooru.exe`，保留 DLL 和 `data` 目录 |

Windows 需要 Microsoft Visual C++ 2015–2022 x64 运行库。发布附件仅保留 APK 和 Windows ZIP；ZIP 包含运行所需文件及 GPL-3.0 许可证。GitHub 页面自动显示的 Source code ZIP/TAR.GZ 是源码下载入口。

## 主要功能

| 功能 | 说明 |
| --- | --- |
| 多站点浏览 | Danbooru/e621、Moebooru（Yande.re、Konachan）、Gelbooru/Rule34、Sankaku、Shimmie |
| 搜索与过滤 | 各站点搜索草稿、最近 20 条历史、命名预设、Danbooru 快捷条件、标签联想与黑名单 |
| 作品查看 | 独立搜索页面、逐级返回、左右切图、缩放与全屏、质量切换、标签、评论和来源链接 |
| 以图搜图 | Google Lens、Bing、Yandex、TinEye、SauceNAO、IQDB，支持启停、排序和批量打开 |
| 收藏与下载 | 收藏作品信息，下载图片和视频，自定义本机下载目录 |
| 界面定制 | 中文/英文、明暗主题、AMOLED 黑色主题、强调色与渐变色 |
| 跨端同步 | 同一局域网内实时同步设置、收藏及站点登录信息 |
| Google Drive 同步 | Android / Windows 跨网络合并，独立密码加密，前台自动同步 |
| 应用内更新 | 检查新版本，自动下载更新包，查看进度、取消和重试 |

## 搜索与图片浏览

- **搜索记忆**：普通搜索入口恢复当前站点未完成的条件，供继续调整，不会自动执行。提交后在本页更新结果；展开条件面板可查看已执行查询与待提交草稿。
- **快捷条件**：Danbooru 提供八种排序、四种分级和四种时间范围。同类条件互斥，再次点击取消，保留其他标签、排除标签及引号参数。分级条件不会关闭安全模式。e621 和其他引擎保留自由输入与预设，不显示未适配条件。
- **预设与历史**：保存当前条件为命名预设，支持重命名、更新和删除。每站点保留最近 20 条完整查询，重复查询置顶；可执行、回填编辑、删除或清空。原全局历史保留在「旧版历史（未分类）」。
- **自动搜索**：默认手动提交。开启「快捷条件自动搜索」后，快捷条件和预设的连续操作合并为一次搜索；文字输入仍只请求标签建议。
- **逐级返回**：详情内点按标签打开独立结果页，长按显示复制等操作。返回依次回到详情及原列表，保留图片、查询和滚动位置。
- **切图与全屏**：正常比例时左右滑动切图，放大后拖动图片；恢复正常比例可继续翻页。Windows 可用前后按钮或方向键。点按图片隐藏工具栏，返回键先退出全屏。接近末尾自动加载下一页，失败可重试，到末尾停止。收藏按收藏顺序浏览，并使用每张图片所属站点。
- **多引擎搜图**：详情右上角的搜图按钮打开引擎面板；在「设置 → 搜图引擎」启停和拖动排序，至少保留一个，也可使用全部已启用引擎。在外部浏览器发送样本图网址，缺失时使用预览图或原图；视频只使用静态图。不会附加应用保存的登录凭据。打不开时可复制搜索链接。

## 站点与登录信息

通过「管理 Booru 网站」添加或编辑站点，在「设置」调整安全模式、图片质量和下载目录。

| 站点 | 认证配置 |
| --- | --- |
| Danbooru | 按站点要求填写用户名和 API Key |
| Gelbooru / Rule34 | 填写账户设置页的数字 User ID 和 API Key，API Key 不等于登录密码 |
| Sankaku | 需要认证时填写有效 Bearer Token；客户端不会自动刷新失效 Token |

客户端兼容旧保存的 Rule34 / Sankaku 域名，并区分认证失败、站点防护、超时与合法空结果。自定义 User-Agent 会用于 API 和图片请求。

## 局域网实时同步

1. 两台设备连接同一局域网。
2. Windows 打开「设置 → 局域网同步」，开启同步主机，选择手机能访问的实际局域网 IP。
3. Android 打开同一页面，扫描配对码；也可以粘贴配对链接。
4. 在 Windows 确认手机。首次配对合并两端已有数据，之后修改自动双向同步，无需导入导出。

| 会同步 | 保留在各自设备 |
| --- | --- |
| 站点配置及用户名、API Key、Token | 已下载的图片、视频和更新安装包 |
| 当前站点、收藏作品信息、黑名单 | 图片缓存、标签数据库 |
| 各站点搜索草稿、命名预设、最近 20 条历史、搜图引擎与自动搜索设置 | 下载目录和本机路径 |
| 旧版搜索历史、主题、语言、安全模式、图片质量等设置 | 页面列表、滚动位置和当前图片索引 |

Windows 主机需要保持运行。Android 在前台实时同步，进入后台暂停连接，回到前台或恢复网络时自动重连并合并离线修改。主机 IP 改变后，在手机同步页修改地址即可，无需重新配对。

v1.3.0 的预设和历史按条目合并，草稿按站点合并，删除也会同步。远端更新不替换当前正在编辑的条件，下次打开时读取合并结果。新增搜索数据在加密连接中协商能力；与旧客户端连接时继续同步原有数据，两端都升级后再同步新增内容。

<details>
<summary>同步机制与安全</summary>

传输和本地同步日志使用 AES-256-GCM 加密，密钥由 Android Keystore / Windows 安全存储保护。配对码 5 分钟内有效，首次连接需主机确认；Windows 同步页可撤销设备授权。同一字段发生冲突时按版本顺序合并，用户名与 Token 作为一组更新，删除会保留同步标记。

</details>

### 无法连接主机时

- **检查 IP**：选择物理 Wi-Fi 或网线网卡地址，避免 WSL、Hyper-V 或 VPN 虚拟网卡地址。
- **检查端口**：Windows 应用需运行并开启主机，防火墙应允许该程序在局域网接收 **TCP 45873**。
- **检查 VPN**：两端使用 VPN/TUN 时，让实际局域网网段绕过 VPN 或直连。例如 FlClash Android 可尝试「网络 → 路由模式 → 绕过私有路由地址」。
- **检查双网卡**：同时连接网线与 Wi-Fi 时，可临时只保留与手机相同的 Wi-Fi 排查路由。
- **检查路由器**：手机应连接普通 Wi-Fi；访客网络、AP 隔离或客户端隔离可能阻止设备互访。
- **检查配对**：在有效期内扫码，并在 Windows 确认新设备；已配对设备地址变化时先修改主机 IP。

## Google Drive 加密同步

在「设置 → Google Drive 同步」配置 OAuth 客户端，然后在两端使用同一 Google 账号和独立同步密码。前台每 30 秒检查，本地修改自动上传；Android 进入后台暂停。同步站点登录信息、收藏、设置和搜索数据，下载文件及本机路径继续留在各设备。

需要先创建 Google Cloud 项目并启用 Drive API。应用提供配置入口与首次配置说明，完整步骤见 [Google Drive 同步配置](docs/GOOGLE_DRIVE_SYNC.md)。云端采用隐藏应用目录及加密快照；密码丢失无法恢复原密文。

## 自动下载更新

启动检查和自动下载默认开启，可在「设置」分别关闭，也可以手动检查更新。下载窗口显示进度，关闭窗口后下载继续；完整下载并通过校验后才提供安装入口。

- **Android**：点击「安装更新」打开系统安装器。首次需要允许 Flexbooru 安装应用，授权后返回再次点击安装。
- **Windows**：点击「打开更新包」，退出 Flexbooru，再将 ZIP 内文件解压到原程序目录。

更新包来自本项目 GitHub Releases，校验文件大小、格式和 GitHub 提供的 SHA-256 摘要；兼容旧版本的校验文件。已下载的有效包会复用，更新包不参与局域网同步。

## 开发与构建

使用 Flutter **3.38.5 或更新版本**、Dart **3.10.4 或更新版本**。Android 需要 JDK 17 和 Android SDK；Windows 需要 Visual Studio C++ 桌面开发工具及 CMake。

```bash
flutter pub get
flutter analyze
flutter test

# 将 DEVICE_ID 替换为 flutter devices 中的设备 ID
flutter run -d DEVICE_ID

flutter build apk --release
flutter build windows --release
```

APK 位于 `build/app/outputs/flutter-apk/app-release.apk`。Windows 运行目录为 `build/windows/x64/runner/Release/`，分发时必须保留完整运行文件。

<details>
<summary>GitHub Actions 与发布签名配置</summary>

配置见 [.github/workflows/build-release.yml](.github/workflows/build-release.yml)。分析与测试通过后才构建两端安装包。

| 触发方式 | 结果 |
| --- | --- |
| 推送 `master` / `main` 或提交 PR | 构建 APK 与 Windows ZIP，Actions Artifacts 保留 14 天，不发布 Release |
| 推送 `v*` 版本标签 | 两端构建成功后发布同名 Release，仅上传 APK 和 Windows ZIP |
| 手动运行工作流 | 默认只构建；开启 `publish` 并填写 `tag` 可发布，已有标签需指向当前提交 |

Android 发布需配置四个 Repository Secrets：`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_PASSWORD`、`ANDROID_KEY_ALIAS`。发布版本必须使用固定签名密钥，才能覆盖升级。

</details>

---

## 来源与许可证

本项目由 YunariCloud 独立维护，是 [flexbooru/flexbooru](https://github.com/flexbooru/flexbooru) 的 Flutter 重写与接口适配版本。感谢原作者及贡献者。

多引擎搜图的网址方式和配置交互参考 [quick-reverse-image-search](https://github.com/YunariCloud/quick-reverse-image-search)。

采用 [GNU GPL-3.0](LICENSE)。iOS、macOS 和 Linux 平台工程保留在源码中，当前自动发布面向 Android 和 Windows。
