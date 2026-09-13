import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuelmaster/utils/env_config.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'onboarding_page.dart';
import 'settings_page.dart';
import 'main_menu_page.dart';
import 'history_page.dart';
import 'car_info_page.dart';
import 'car_list_page.dart';
import 'registration_page.dart';
import 'splash_screen.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'theme.dart';
import 'package:fuelmaster/providers/car_provider.dart';
import 'package:fuelmaster/utils/app_initializer.dart';
import 'package:fuelmaster/providers/app_settings_provider.dart';
import 'package:fuelmaster/providers/history_provider.dart';
import 'package:fuelmaster/services/premium_service.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:fuelmaster/services/map_page.dart';
import 'package:fuelmaster/services/account_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _activateAppCheck();

  final initialData = await AppInitializer.initialize();
  // Премиум-статус: prefs + восстановление покупок в магазине при старте
  // (после AppInitializer, чтобы не мешать миграциям prefs).
  await PremiumService.instance.init();
  // B-10 аудита: аккаунт мог создаться без профиля в Firestore — восстанавливаем.
  final User? restoredUser = FirebaseAuth.instance.currentUser;
  if (restoredUser != null) {
    AccountService.ensureUserProfile(restoredUser.uid);
  }
  final SharedPreferences prefs = initialData['sharedPreferences'] as SharedPreferences;
  final Locale initialLocale = initialData['initialLocale'] as Locale;
  final bool initialDarkMode = initialData['isDarkMode'] as bool;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CarProvider()),
        ChangeNotifierProvider(create: (context) => HistoryProvider()),
        ChangeNotifierProvider(
          create: (context) => AppSettingsProvider(prefs, initialLocale, initialDarkMode),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// Включает Firebase App Check один раз на старте приложения.
///
/// Раньше вызов жил в initState экрана регистрации: до него (и после, при
/// повторных запросах) Firebase-трафик уходил без attestation, а асинхронный
/// вызов не дожидался результата. В debug-сборках используется debug-провайдер,
/// иначе Play Integrity на неподписанном релизным ключом APK всегда падает.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
    logger.d('App Check активирован (${kDebugMode ? 'debug' : 'release'})');
  } catch (e) {
    logger.e('Не удалось активировать App Check: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<User?>? _authSubscription;

  /// Страницы собираются на каждой сборке из провайдеров (B-8 аудита).
  ///
  /// Раньше список строился один раз в `postFrameCallback`: после смены языка,
  /// темы или добавления авто экраны держали старые `locale`/`cars`, а список
  /// истории передавался по ссылке. `List.of` отдаёт копию — страница больше
  /// не может мутировать состояние провайдера.
  /// `listen: false` нужен для вызова вне фазы сборки (маршруты).
  List<Widget> _buildPages({bool listen = true}) {
    final appSettings = listen
        ? context.watch<AppSettingsProvider>()
        : context.read<AppSettingsProvider>();
    final carProvider =
        listen ? context.watch<CarProvider>() : context.read<CarProvider>();
    final historyProvider = listen
        ? context.watch<HistoryProvider>()
        : context.read<HistoryProvider>();

    return [
      MainMenuPage(history: historyProvider.history),
      HistoryPage(
        history: List<Map<String, dynamic>>.of(historyProvider.history),
        cars: List<CarData>.of(carProvider.cars),
        locale: appSettings.locale,
        isDarkMode: appSettings.isDarkMode,
      ),
      const MapPage(),
      const SettingsPage(),
    ];
  }

  // Реклама живёт жизнью приложения: SDK больше не гасится в dispose экранов
  // (иначе после ухода с истории он не оживал до перезапуска — B-8).

  @override
  void initState() {
    super.initState();
    // B-11 аудита: источник правды о сессии — FirebaseAuth, а не флаг в prefs.
    // Раньше выход на другом устройстве и отзыв токена не отражались: приложение
    // продолжало считать пользователя зарегистрированным.
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      context.read<AppSettingsProvider>().setRegistered(user != null);
      if (user != null) {
        AccountService.ensureUserProfile(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDarkMode = theme.brightness == Brightness.dark;

    final navBarDecoration = BoxDecoration(
      color: isDarkMode ? const Color(0xFF1D2939) : null,
      gradient: isDarkMode ? null : primaryActionGradient,
      borderRadius: BorderRadius.circular(25),
      boxShadow: isDarkMode
          ? null
          : [
              BoxShadow(
                blurRadius: 20,
                color: Colors.black.withValues(alpha: 0.2),
              )
            ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: navBarDecoration,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
          child: GNav(
            tabs: [
              GButton(
                icon: Icons.home,
                text: l10n.home,
              ),
              GButton(
                icon: Icons.history,
                text: l10n.history,
              ),
              GButton(
                icon: Icons.map,
                text: l10n.map,
              ),
              GButton(
                icon: Icons.settings,
                text: l10n.settings,
              ),
            ],
            selectedIndex: _selectedIndex,
            onTabChange: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            rippleColor: isDarkMode ? Colors.grey[800]! : Colors.white.withValues(alpha: 0.2),
            hoverColor: isDarkMode ? Colors.grey[700]! : Colors.white.withValues(alpha: 0.1),
            gap: 5,
            activeColor: isDarkMode ? const Color(0xFF007BFF) : Colors.white,
            iconSize: 24,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            duration: const Duration(milliseconds: 400),
            tabBackgroundColor: isDarkMode ? const Color(0xFF007BFF).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.15),
            color: isDarkMode ? Colors.grey[500]! : Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettingsProvider>();

    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      locale: appSettings.locale,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: appSettings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ru')],
      home: _isLoading
          ? SplashScreen(
              onDataLoaded: () {
                setState(() {
                  _isLoading = false;
                });
              },
            )
          : !appSettings.onboardingCompleted
              ? OnboardingPage(onFinish: () => appSettings.setOnboardingCompleted(true))
              : !appSettings.isRegistered
                  ? RegistrationPage(onRegistered: () => appSettings.setRegistered(true), locale: appSettings.locale)
                  : Builder(
                      builder: (context) => Scaffold(
                        body: _buildPages()[_selectedIndex],
                        bottomNavigationBar: _buildBottomNavigationBar(context),
                      ),
                    ),
      routes: {
        '/car_info': (context) {
          final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
          final carProvider = Provider.of<CarProvider>(context, listen: false);
          return CarInfoPage(
            cars: carProvider.cars,
            locale: appSettings.locale,
          );
        },
        '/car_list': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
          final carProvider = Provider.of<CarProvider>(context, listen: false);
          return CarListPage(
            cars: args?['cars'] as List<CarData>? ?? carProvider.cars,
            locale: args?['locale'] as Locale? ?? appSettings.locale,
          );
        },
        '/history': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
          final carProvider = Provider.of<CarProvider>(context, listen: false);
          final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
          return HistoryPage(
            history: args?['history'] as List<Map<String, dynamic>>? ?? historyProvider.history,
            cars: carProvider.cars,
            locale: args?['locale'] as Locale? ?? appSettings.locale,
            isDarkMode: appSettings.isDarkMode,
          );
        },
        '/main_menu': (context) {
          final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
          return MainMenuPage(
            history: historyProvider.history,
          );
        },
      },
      onGenerateRoute: (settings) {
        final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
        if (settings.name == Navigator.defaultRouteName) {
          return MaterialPageRoute(
            builder: (context) => _isLoading
                ? SplashScreen(
                    onDataLoaded: () {
                      setState(() {
                        _isLoading = false;
                      });
                    },
                  )
                : !appSettings.onboardingCompleted
                    ? OnboardingPage(onFinish: () => appSettings.setOnboardingCompleted(true))
                    : !appSettings.isRegistered
                        ? RegistrationPage(onRegistered: () => appSettings.setRegistered(true), locale: appSettings.locale)
                        : Scaffold(
                            body: _buildPages(listen: false)[0],
                            bottomNavigationBar: _buildBottomNavigationBar(context),
                          ),
          );
        }
        return null;
      },
    );
  }
}