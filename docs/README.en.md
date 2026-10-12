<p align="center">
  <img src="../assets/icons/app_icon.png" alt="Flexbooru app icon" width="120" height="120">
</p>

<h1 align="center">Flexbooru Flutter</h1>

<p align="center">
  <strong>A Booru client built with Flutter</strong><br>
  Android · Windows · Media browsing · Live LAN sync
</p>

<p align="center">
  <a href="https://github.com/YunariCloud/flexbooru-flutter/releases/latest"><strong>Download</strong></a> ·
  <a href="https://github.com/YunariCloud/flexbooru-flutter/releases">Release notes</a> ·
  <a href="../README.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/YunariCloud/flexbooru-flutter/actions/workflows/build-release.yml"><img src="https://github.com/YunariCloud/flexbooru-flutter/actions/workflows/build-release.yml/badge.svg" alt="Build and Release"></a>
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows-3F51B5" alt="Android and Windows">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="#download-and-install">Installation</a> · <a href="#features">Features</a> · <a href="#lan-sync">LAN sync</a> · <a href="#automatic-updates">Updates</a> · <a href="#development">Development</a>
</p>

---

## Download and install

Choose one package from [Releases](https://github.com/YunariCloud/flexbooru-flutter/releases/latest):

| Platform | File | Installation |
| --- | --- | --- |
| Android | `flexbooru-flutter-<version>-android-universal.apk` | Install the APK. Current releases require Android 7.0 or later; check the package requirement |
| Windows x64 | `flexbooru-flutter-<version>-windows-x64.zip` | Extract the complete ZIP and run `flexbooru.exe`; keep DLLs and `data` |

Windows needs the Microsoft Visual C++ 2015–2022 x64 runtime. Uploaded release assets contain only the APK and Windows ZIP. The ZIP includes runtime files and the GPL-3.0 license. GitHub also displays its automatic Source code ZIP/TAR.GZ links.

## Features

| Feature | Details |
| --- | --- |
| Multiple sites | Danbooru/e621, Moebooru (Yande.re, Konachan), Gelbooru/Rule34, Sankaku and Shimmie |
| Search and filters | Tag suggestions, history, safe mode, global and per-site blacklists |
| Media viewer | Responsive masonry grid, zoom, quality selection, categorized tags, comments and source links |
| Favorites and downloads | Favorites metadata, image/video downloads and a local download folder |
| Personalization | Chinese/English UI, light/dark and AMOLED themes, accent colors and gradients |
| Live LAN sync | Settings, favorites and site credentials across Windows and Android |
| In-app updates | Automatic downloads with progress, cancellation and retry |

## Sites and credentials

Add or edit sites in **Manage Boorus**. Configure safe mode, image quality and the download folder in **Settings**.

| Site | Credentials |
| --- | --- |
| Danbooru | Username and API key when required by the site |
| Gelbooru / Rule34 | Numerical User ID and API Key from account settings; use the API key rather than a password |
| Sankaku | A valid Bearer Token when authentication is needed; expired tokens are not refreshed automatically |

Saved legacy Rule34 and Sankaku hosts remain compatible. Authentication errors, site protection, timeouts and legitimate empty results have separate messages. Custom User-Agent settings apply to API and image requests.

## LAN sync

1. Connect both devices to the same LAN.
2. On Windows, open **Settings → LAN sync**, enable the host and select its real LAN IP.
3. On Android, open the same page and scan the pairing code or paste the pairing link.
4. Approve the phone on Windows. First pairing merges existing data; subsequent edits sync both ways without import/export.

| Synced | Kept local |
| --- | --- |
| Site configuration, usernames, API keys and tokens | Downloaded images, videos and update packages |
| Active site, favorites metadata and blacklists | Image caches and the tag database |
| Last 20 searches, theme, language, safe mode, image quality and other settings | Download folders and device paths |

Keep Windows running. Android syncs in the foreground, pauses in the background, and reconnects after resume or network recovery to merge offline edits. If the host IP changes, edit it on Android without pairing again.

<details>
<summary>Sync behavior and security</summary>

AES-256-GCM encrypts traffic and the local journal. Keys use Android Keystore / Windows secure storage. Pairing codes expire after five minutes and require host approval. Revoke devices from the Windows sync page. Field conflicts resolve by version order; usernames/tokens update together and deletions retain sync markers.

</details>

### Connection troubleshooting

- Choose the physical Wi-Fi or Ethernet IP, avoiding WSL, Hyper-V and VPN adapter addresses.
- Keep the app and host enabled. Allow inbound **TCP 45873** for Flexbooru on the LAN through Windows Firewall.
- With VPN/TUN on either device, bypass the actual LAN subnet or route it directly. FlClash Android offers a network route mode for bypassing private addresses.
- With Ethernet and Wi-Fi both connected, temporarily keep only the phone's Wi-Fi network to isolate routing issues.
- Avoid guest Wi-Fi, AP isolation and client isolation.
- Scan a valid pairing code and approve on Windows. Update the host IP first when a paired device's address changes.

## Automatic updates

Startup checks and automatic downloads are enabled by default and can be disabled separately in Settings. Manual checks remain available. Closing the progress dialog leaves the download running. Only complete, verified packages can be opened.

- **Android**: tap **Install Update** to open the system installer. Grant permission to install apps from Flexbooru when prompted, return and tap again.
- **Windows**: tap **Open Update Package**, close Flexbooru and extract the ZIP into the existing program folder.

Downloads use this project's GitHub Releases and validate size, format and GitHub's SHA-256 asset digest. Checksum files from older releases remain supported. Valid cached packages are reused; update packages stay local.

## Development

Use Flutter **3.38.5 or later** and Dart **3.10.4 or later**. Android needs JDK 17 and the Android SDK; Windows needs Visual Studio Desktop development with C++ and CMake.

```bash
flutter pub get
flutter analyze
flutter test

# Replace DEVICE_ID with an ID from flutter devices
flutter run -d DEVICE_ID

flutter build apk --release
flutter build windows --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`. Windows runtime: `build/windows/x64/runner/Release/`. Distribute the complete runtime files.

<details>
<summary>GitHub Actions and release signing</summary>

See [.github/workflows/build-release.yml](../.github/workflows/build-release.yml). Analysis and tests run before both platform builds.

| Trigger | Result |
| --- | --- |
| Push to `master` / `main` or a PR | APK and Windows ZIP in Actions Artifacts for 14 days; no Release |
| Push a `v*` version tag | Publish a Release after both builds succeed, uploading only APK and Windows ZIP |
| Manual dispatch | Build by default; set `publish` and `tag` to publish. Existing tags must point to the selected commit |

Android publishing requires Repository Secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`. Keep the signing key consistent so existing installations can upgrade.

</details>

---

## Attribution and license

Independently maintained by YunariCloud as a Flutter rewrite and API adaptation of [flexbooru/flexbooru](https://github.com/flexbooru/flexbooru). Thanks to the upstream authors and contributors.

Licensed under [GNU GPL-3.0](../LICENSE). iOS, macOS and Linux projects remain in the source; automated releases currently target Android and Windows.
