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
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const FlexbooruApp());
}

class FlexbooruApp extends StatelessWidget {
  const FlexbooruApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => BlacklistProvider()),
        ChangeNotifierProvider(create: (_) => BooruProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProv, _) {
          return MaterialApp(
            title: 'Flexbooru',
            debugShowCheckedModeBanner: false,
            locale: settingsProv.locale,
            supportedLocales: const [
              Locale('zh'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: settingsProv.themeMode,
            theme: AppTheme.lightTheme(settingsProv.accentColor),
            darkTheme: AppTheme.darkTheme(
              settingsProv.accentColor,
              amoled: settingsProv.amoled,
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
