# Flexbooru Flutter

基于 Flutter 的 Booru 客户端，支持 Android 与 Windows，提供作品浏览、收藏、下载和局域网实时同步。

[English](docs/README.en.md) · [下载最新版](https://github.com/YunariCloud/flexbooru-flutter/releases/latest) · [更新记录](https://github.com/YunariCloud/flexbooru-flutter/releases)

[![Build and Release](https://github.com/YunariCloud/flexbooru-flutter/actions/workflows/build-release.yml/badge.svg)](https://github.com/YunariCloud/flexbooru-flutter/actions/workflows/build-release.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

## 下载与安装

在 [Releases](https://github.com/YunariCloud/flexbooru-flutter/releases/latest) 中，按设备选择一个文件：

| 设备 | 下载文件 | 安装方式 |
| --- | --- | --- |
| Android | `flexbooru-flutter-<版本>-android-universal.apk` | 下载后安装；当前发布包要求 Android 7.0 或更高，具体以安装包要求为准 |
| Windows x64 | `flexbooru-flutter-<版本>-windows-x64.zip` | 完整解压后运行 `flexbooru.exe`，保留 DLL 和 `data` 目录 |

Windows 需要 Microsoft Visual C++ 2015–2022 x64 运行库。发布附件仅保留 APK 和 Windows ZIP；ZIP 包含运行所需文件及 GPL-3.0 许可证。GitHub 页面自动显示的 Source code ZIP/TAR.GZ 是源码下载入口。

## 主要功能

- **多站点浏览**：支持 Danbooru/e621、Moebooru（Yande.re、Konachan）、Gelbooru/Rule34、Sankaku 和 Shimmie。
- **搜索与过滤**：标签联想、搜索历史、安全模式、全局与站点黑名单。
- **作品查看**：响应式瀑布流、图片缩放、图片质量切换、标签分类、评论和来源链接。
- **收藏与下载**：收藏作品信息，下载图片和视频，自定义本机下载目录。
- **界面定制**：中文/英文、明暗主题、AMOLED 黑色主题、强调色与渐变色。
- **跨端同步**：同一局域网内同步设置、收藏及站点登录信息。
- **应用内更新**：检查新版本、自动下载更新包、显示进度，支持取消和重试。

## 站点与登录信息

通过「管理 Booru 网站」添加或编辑站点，在「设置」调整安全模式、图片质量和下载目录。

| 站点 | 认证配置 |
| --- | --- |
| Danbooru | 按站点要求填写用户名和 API Key |
| Gelbooru / Rule34 | 填写账户设置页的数字 User ID 和 API Key，API Key 不等于登录密码 |
| Sankaku | 需要认证时填写有效 Bearer Token；客户端不会自动刷新失效 Token |

客户端兼容旧保存的 Rule34 / Sankaku 域名，并区分认证失败、站点防护、超时与合法空结果。自定义 User-Agent 会用于 API 和图片请求。

## Windows ↔ Android 实时同步

1. 两台设备连接同一局域网。
2. Windows 打开「设置 → 局域网同步」，开启同步主机，选择手机能访问的实际局域网 IP。
3. Android 打开同一页面，扫描配对码；也可以粘贴配对链接。
4. 在 Windows 确认手机。首次配对合并两端已有数据，之后修改自动双向同步，无需导入导出。

| 会同步 | 保留在各自设备 |
| --- | --- |
| 站点配置及用户名、API Key、Token | 已下载的图片、视频和更新安装包 |
| 当前站点、收藏作品信息、黑名单 | 图片缓存、标签数据库 |
| 最近 20 条搜索历史、主题、语言、安全模式、图片质量等设置 | 下载目录和本机路径 |

Windows 主机需要保持运行。Android 在前台实时同步，进入后台暂停连接，回到前台或恢复网络时自动重连并合并离线修改。主机 IP 改变后，在手机同步页修改地址即可，无需重新配对。

传输和本地同步日志使用 AES-256-GCM 加密，密钥由 Android Keystore / Windows 安全存储保护。配对码 5 分钟内有效，首次连接需主机确认；Windows 同步页可撤销设备授权。同一字段发生冲突时按版本顺序合并，用户名与 Token 作为一组更新，删除会保留同步标记。

### 无法连接主机时

- **检查 IP**：选择物理 Wi-Fi 或网线网卡地址，避免 WSL、Hyper-V 或 VPN 虚拟网卡地址。
- **检查端口**：Windows 应用需运行并开启主机，防火墙应允许该程序在局域网接收 **TCP 45873**。
- **检查 VPN**：两端使用 VPN/TUN 时，让实际局域网网段绕过 VPN 或直连。例如 FlClash Android 可尝试「网络 → 路由模式 → 绕过私有路由地址」。
- **检查双网卡**：同时连接网线与 Wi-Fi 时，可临时只保留与手机相同的 Wi-Fi 排查路由。
- **检查路由器**：手机应连接普通 Wi-Fi；访客网络、AP 隔离或客户端隔离可能阻止设备互访。
- **检查配对**：在有效期内扫码，并在 Windows 确认新设备；已配对设备地址变化时先修改主机 IP。

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

### GitHub Actions

配置见 [.github/workflows/build-release.yml](.github/workflows/build-release.yml)。分析与测试通过后才构建两端安装包。

| 触发方式 | 结果 |
| --- | --- |
| 推送 `master` / `main` 或提交 PR | 构建 APK 与 Windows ZIP，Actions Artifacts 保留 14 天，不发布 Release |
| 推送 `v*` 版本标签 | 两端构建成功后发布同名 Release，仅上传 APK 和 Windows ZIP |
| 手动运行工作流 | 默认只构建；开启 `publish` 并填写 `tag` 可发布，已有标签需指向当前提交 |

Android 发布需配置四个 Repository Secrets：`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_PASSWORD`、`ANDROID_KEY_ALIAS`。发布版本必须使用固定签名密钥，才能覆盖升级。

## 来源与许可证

本项目由 YunariCloud 独立维护，是 [flexbooru/flexbooru](https://github.com/flexbooru/flexbooru) 的 Flutter 重写与接口适配版本。感谢原作者及贡献者。

采用 [GNU GPL-3.0](LICENSE)。iOS、macOS 和 Linux 平台工程保留在源码中，当前自动发布面向 Android 和 Windows。
