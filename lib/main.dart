import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/i18n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'providers/blacklist_provider.dart';
import 'providers/booru_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/posts_provider.dart';
import 'providers/settings_provider.dart';
import 'services/tag_translation_service.dart';
import 'services/lan_sync_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/widgets/lan_sync_bindings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize tag translation service (loads embedded dictionary and sqlite if available)
  TagTranslationService().init();

  final sync = LanSyncService();
  if (!kIsWeb && (Platform.isAndroid || Platform.isWindows)) {
    try {
      await sync.initialize();
    } catch (_) {
      // Keep encrypted data intact; the settings page exposes retry.
    }
  }
  runApp(FlexbooruApp(syncService: sync));
}

class FlexbooruApp extends StatelessWidget {
  const FlexbooruApp({super.key, this.syncService});
  final LanSyncService? syncService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => BlacklistProvider()),
        ChangeNotifierProvider(create: (_) => BooruProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => syncService ?? LanSyncService()),
      ],
      child: LanSyncBindings(
        child: Consumer<SettingsProvider>(
          builder: (context, settingsProv, _) {
            return MaterialApp(
              title: 'Flexbooru',
              debugShowCheckedModeBanner: false,
              locale: settingsProv.locale,
              supportedLocales: const [Locale('zh'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              themeMode: settingsProv.themeMode,
              theme: AppTheme.lightTheme(
                settingsProv.accentColor,
                gradient: settingsProv.useGradient
                    ? settingsProv.primaryGradient
                    : null,
              ),
              darkTheme: AppTheme.darkTheme(
                settingsProv.accentColor,
                amoled: settingsProv.amoled,
                gradient: settingsProv.useGradient
                    ? settingsProv.primaryGradient
                    : null,
              ),
              home: const HomeScreen(),
            );
          },
        ),
      ),
    );
  }
}
