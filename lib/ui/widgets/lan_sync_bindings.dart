import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/sync/sync_preferences.dart';
import '../../core/sync/sync_state.dart';
import '../../providers/blacklist_provider.dart';
import '../../providers/booru_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/lan_sync_service.dart';
import '../../services/google_drive_sync_service.dart';

/// Refresh in-memory models before telling browsing views to refresh requests.
class LanSyncBindings extends StatefulWidget {
  const LanSyncBindings({super.key, required this.child});
  final Widget child;
  @override
  State<LanSyncBindings> createState() => _LanSyncBindingsState();
}

class _LanSyncBindingsState extends State<LanSyncBindings>
    with WidgetsBindingObserver {
  StreamSubscription<Set<String>>? _subscription;
  Future<void> _reloadTail = Future.value();
  LanSyncService? _service;
  GoogleDriveSyncService? _drive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _service = context.read<LanSyncService>();
      try {
        _drive = context.read<GoogleDriveSyncService>();
      } on ProviderNotFoundException {
        /* Standalone sync widgets. */
      }
      _subscription = SyncPreferences.remoteChanges.stream.listen((keys) {
        _reloadTail = _reloadTail.then((_) => _reload(keys)).catchError((
          Object _,
        ) {
          _service?.error = 'data';
        });
      });
      if (kIsWeb ||
          (!Platform.isAndroid && !Platform.isWindows) ||
          Platform.environment.containsKey('FLUTTER_TEST')) {
        return;
      }
      try {
        await Future.wait([
          context.read<BooruProvider>().ready,
          context.read<FavoritesProvider>().ready,
          context.read<BlacklistProvider>().ready,
          context.read<SettingsProvider>().ready,
        ]);
        if (mounted) await _service!.resumeSavedMode();
        if (mounted) await _drive?.resumeSaved();
      } catch (_) {
        // The sync settings page displays the storage or connection failure.
      }
    });
  }

  Future<void> _reload(Set<String> keys) async {
    if (!mounted) return;
    final booru = context.read<BooruProvider>();
    final favorites = context.read<FavoritesProvider>();
    final blacklist = context.read<BlacklistProvider>();
    final settings = context.read<SettingsProvider>();
    await Future.wait([
      booru.ready,
      favorites.ready,
      blacklist.ready,
      settings.ready,
    ]);
    if (!mounted) return;
    if (keys.contains(sitesPreference) ||
        keys.contains('flexbooru_active_site_id')) {
      await booru.loadSites();
    }
    if (keys.contains(favoritesPreference)) await favorites.loadFavorites();
    if (keys.contains(blacklistPreference)) await blacklist.loadBlacklist();
    if (keys.any(syncedSettings.contains)) await settings.loadSettings();
    if (mounted) SyncPreferences.appliedChanges.add(keys);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || !Platform.isAndroid || _service == null) return;
    if (state == AppLifecycleState.resumed) {
      _drive?.pause(false);
      unawaited(_service!.pauseClient(false));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _drive?.pause(true);
      unawaited(_service!.pauseClient(true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
