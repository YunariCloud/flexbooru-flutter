# Google Drive 加密同步配置

适用于 Android 和 Windows。使用同一个 Google Cloud 项目、同一个 Google 账号及同一个独立同步密码。首次连接自动合并已有数据，后续前台每 30 秒检查远端修改，本地修改合并后自动上传。Android 进入后台暂停，返回前台恢复。

同步内容包括站点配置及登录凭据、收藏、黑名单、设置、搜索草稿、历史、预设和搜图引擎。已下载图片/视频、缓存、下载目录、Google 授权令牌及局域网配对密钥留在本机。

## 1. 创建 Google Cloud 项目

1. 打开 [Google Cloud Console](https://console.cloud.google.com/)，创建或选择一个项目。
2. 在 API 库启用 **Google Drive API**。
3. 在 Google Auth Platform 配置应用名称、支持邮箱和受众。个人 Google 账号通常使用 External。
4. 测试阶段把自己要登录的 Google 邮箱添加为测试用户。
5. 在数据访问权限中添加 `https://www.googleapis.com/auth/drive.appdata`。Windows 同时请求 `openid`、`email` 用于显示登录账号。

`drive.appdata` 仅访问该应用的隐藏数据目录，不读取普通 Drive 文件。说明见 [Google 官方 appDataFolder 文档](https://developers.google.com/workspace/drive/api/guides/appdata)。

## 2. Android 配置

在同一项目创建两个 OAuth 客户端：

| 类型 | 配置 |
| --- | --- |
| Android | 包名 `com.flexbooru.app.flexbooru`；填写安装包的签名 SHA-1 |
| Web application | 创建后复制 **Client ID**，作为应用里的 **Android Server Client ID**；不填写 Web Secret |

当前官方发布签名的 SHA-1：

```text
92:4A:41:89:DA:2D:56:0A:31:FD:46:A4:7C:82:C2:17:67:1E:93:F1
```

自己构建的 debug 包或更换签名的 release 包需要注册相应签名的 Android 客户端，可使用 Android SDK 的 `apksigner verify --print-certs <APK路径>` 查看。Android 使用原生 Google 登录，需要设备上的 Google Play 服务。原生 SDK 配置要求见 [google_sign_in_android 说明](https://pub.dev/packages/google_sign_in_android)。

打开应用 **设置 → Google Drive 同步**，填写 Web 客户端的 ID，点击「保存 OAuth 配置」。如果已经初始化过另一个 Android 客户端 ID，先重启应用，再修改配置。

## 3. Windows 配置

在同一个项目创建 **Desktop app** OAuth 客户端。复制其 **Client ID** 和 **Client Secret** 到应用的 Windows 配置字段，然后保存。

登录使用系统浏览器、PKCE 和随机本机回调端口。Windows 防火墙/VPN 应允许本机 `127.0.0.1` 回调。不要使用 Web 客户端替代 Desktop app 客户端，也无需配置固定的互联网回调域名。参考 [Google 桌面登录说明](https://developers.google.com/identity/protocols/oauth2/native-app)。

## 4. 连接与加密

1. 两端分别配置各自的 OAuth 客户端。
2. 在「独立同步密码」输入同一密码，至少 12 字符，建议使用较长随机密码或口令。
3. 点击「Google 登录并开始同步」，选择同一个 Google 账号并授权。
4. 状态显示已连接后，使用「立即同步 / 重试」验证两端合并。

同步密码与 Google 账号密码无关。云端使用 PBKDF2-HMAC-SHA256（210,000 次）派生密钥、AES-256-GCM 加密及校验。OAuth 令牌和同步密码仅存入本机平台安全存储，不上传、不参与局域网同步。忘记同步密码无法解密原云端信息。

每台设备写自己的加密快照，避免同时修改一个云端文件造成覆盖。同步使用现有条目版本合并及删除标记；删除标记压缩保存，继续阻止离线设备恢复旧记录。快照只包含应用数据记录，不包含本机同步主机地址、授权设备或密钥。

断开连接会停止同步、清除本机云端登录及同步密码，并保留已有应用数据和云端文件。若要删除云端隐藏数据，先在所有设备断开同步，再使用 Drive 的应用管理功能处理。

## 常见问题

- **客户端配置错误**：确认 Drive API 已启用、三种客户端属于同一项目；Android 包名和签名必须匹配，Server Client ID 使用 Web 客户端的 ID。
- **登录被阻止**：检查 Google 同意屏幕是否把当前账号加入测试用户，并确认 Google 服务可访问。
- **几天后需要重新登录**：External 项目处于 Testing 时，包含 Drive 权限的刷新令牌通常 7 天过期。可按 Google 要求发布为 Production，或重新登录。参见 [OAuth 令牌有效期说明](https://developers.google.com/identity/protocols/oauth2)。
- **密码/校验失败**：使用与另一台设备相同的同步密码。校验失败时不会用错误密文覆盖本机或云端内容。
- **数据没有出现**：确认账号和项目一致，两个设备都在前台，尝试「立即同步」。隐藏目录不会显示在普通 Drive 文件列表中。

真实账号验证需要先完成上述 Google Cloud 配置。项目不内置共享 OAuth 客户端或服务账号。

---

# Google Drive sync setup (English)

Use OAuth clients from the **same Google Cloud project**, the same Google account and the same independent sync password on Android and Windows. Enable Drive API, configure OAuth consent and add your account as a test user. Request `drive.appdata`; Windows also requests `openid` and `email` for the account label.

- **Android:** register an Android OAuth client with package `com.flexbooru.app.flexbooru` and your installed APK's signing SHA-1. Create a Web OAuth client in the same project, and enter its ID as **Android Server Client ID**. No Web secret is needed. Google Play services are required. The official release SHA-1 is listed above; self-signed/debug APKs need their own registration.
- **Windows:** create a **Desktop app** client and enter its ID and secret. The system browser returns to a random loopback port through `127.0.0.1`; PKCE protects the authorization code. Do not substitute a Web client.

Open **Settings → Google Drive sync**, save OAuth configuration, enter the same independent password (12+ characters) and sign in on both devices. Initial sync merges data. Foreground polling runs every 30 seconds; local changes upload after debouncing. Android pauses in the background.

Settings, favorites, searches, site credentials and deletions sync through encrypted per-device snapshots. Downloads, caches, device paths, OAuth tokens and LAN pairing keys stay local. PBKDF2-HMAC-SHA256 and AES-256-GCM protect cloud content. Tokens and the sync password use platform secure storage. A forgotten password cannot recover the encrypted cloud data.

Testing-mode OAuth refresh tokens with Drive scopes normally expire after seven days; publish the OAuth app according to Google's requirements or sign in again. Disconnect keeps app/cloud data but removes local cloud credentials. Disconnect all devices before deleting hidden app data from Drive's app management page.

The OAuth clients must be configured before real-account verification. No shared OAuth client or service account is embedded in this app.
