# Flexbooru (Flutter Edition)

[![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10%2B-0175C2.svg)](https://dart.dev)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-orange.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux-green.svg)]()

> 基于原生 Android Kotlin 项目 [flexbooru/flexbooru](https://github.com/flexbooru/flexbooru) 重构的跨平台 Flutter 现代 Booru 客户端，修复了原项目在各 Booru 引擎 API 变更以及高版本系统下的多处已知 Bug。

---

## 🌟 功能特性 (Features)

- **多引擎支持**:
  - **Danbooru** (Danbooru 2.x API 及 e621)
  - **Moebooru** (Yande.re, Konachan, Lolibooru 等)
  - **Gelbooru** (Gelbooru 0.2.x 现代 JSON API 及 Legacy XML，Safebooru, Rule34.xxx)
  - **Sankaku Complex** (API v2 Keyset 分页及认证)
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
  - 自定义 User-Agent 与防屏蔽 Referer 请求头

---

## 🛠️ 原项目 Bug 修复清单 (Bug Fixes)

1. **Danbooru 422 Unprocessable Entity 错误与 2 标签限制**:
   - 原项目在发起 Danbooru 搜索时，会将查询词、安全模式标签 (`rating:general`) 和黑名单标签直接拼接入 `tags=` 参数中。Danbooru 匿名/非金牌用户限制每次查询最多 2 个标签，多于 2 个标签即报错 HTTP 422。
   - **修复**：当查询标签超过限制时自动启用**客户端标签过滤**（在客户端执行黑名单过滤与安全分级筛选），杜绝触发 422 异常。
2. **Moebooru / Yande.re 协议相对 URL 崩溃问题**:
   - Yande.re 等站点返回的图片地址常以 `//assets.yande.re/...` 开头（协议相对链接），未做处理会导致图片组件报 URL 格式非法无法加载。
   - **修复**：全量 URL 规范化过滤，自动识别并补全协议与主机前缀。
3. **Gelbooru JSON 响应外层结构变化与 XML 混用报错**:
   - 现代 Gelbooru 提供 `&json=1`，但返回结构可能为 `{"post": [...]}`、`{"@attributes": ..., "post": [...]}`、直接列表 `[...]`、或者只有单条数据时返回单个对象而非数组，亦或在某些端点下忽略参数返回 XML。
   - **修复**：实现智能解析器，同时兼容多种 JSON 封装层级，并在 JSON 解析失败时自动降级至 XML DOM 解析。
4. **Sankaku Complex API v2 协议与鉴权失效**:
   - Sankaku 升级到了新版 API 架构，强制要求带齐桌面端 `Origin` 与 `Referer`，原项目常遭遇 401/403 阻拦。
   - **修复**：更新请求头配置，补充 `Origin: https://sankaku.app` 与 `Referer: https://sankaku.app/`，支持 Keyset 游标式分页。
5. **Android 13/14+ 存储与文件下载崩溃**:
   - 原项目在 Android 13/14 上因访问外部公共目录权限变更引发崩溃。
   - **修复**：基于现代 `path_provider` 标准规范，将下载内容规范存储至公开 Download/Pictures 目录，并适配跨平台路径（Windows、macOS、Linux 等）。
6. **站点分享 `booru://` URI 编解码兼容**:
   - 保持与原 Flexbooru 客户端定义的 Base64 `booru://` 协议完全兼容，支持在应用内无缝导入/导出旧版站点分享链接。

---

## 🚀 运行与构建 (Build & Run)

### 前置环境
- Flutter SDK >= 3.20 (推荐 3.38+)
- Dart SDK >= 3.4

### 依赖安装
```bash
flutter pub get
```

### 运行单元测试
```bash
flutter test
```

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
