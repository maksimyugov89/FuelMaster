import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'fuel_calculator_page.dart';
import 'car_list_page.dart';
import 'registration_page.dart';
import 'splash_screen.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'theme.dart';
import 'package:fuelmaster/utils/ad_manager.dart';
import 'package:fuelmaster/providers/car_provider.dart';
import 'package:fuelmaster/utils/app_initializer.dart';
import 'package:fuelmaster/providers/app_settings_provider.dart';
import 'package:fuelmaster/utils/constants.dart';
import 'package:fuelmaster/providers/history_provider.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:fuelmaster/services/map_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final initialData = await AppInitializer.initialize();
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

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
  });

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (mounted) {
      setState(() {
        _initializePages();
      });
    }
  }

  void _initializePages() {
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);

    _pages = [
      MainMenuPage(
        history: historyProvider.history,
      ),
      HistoryPage(
        history: historyProvider.history,
        cars: carProvider.cars,
        locale: appSettings.locale,
        isDarkMode: appSettings.isDarkMode,
      ),
      const MapPage(), // <--- ШАГ 2: СТРАНИЦА ДОБАВЛЕНА В СПИСОК
      const SettingsPage(),
    ];
  }

  @override
  void dispose() {
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
    if (!appSettings.isPremium) {
      AdManager.dispose();
    }
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
                color: Colors.black.withOpacity(.2),
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
              // v--- ШАГ 3: ДОБАВЛЕНА НОВАЯ КНОПКА ---v
              GButton(
                icon: Icons.map,
                text: l10n.map,
              ),
              // ^--- КОНЕЦ НОВОГО БЛОКА ---^
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
            rippleColor: isDarkMode ? Colors.grey[800]! : Colors.white.withOpacity(0.2),
            hoverColor: isDarkMode ? Colors.grey[700]! : Colors.white.withOpacity(0.1),
            gap: 5,
            activeColor: isDarkMode ? const Color(0xFF007BFF) : Colors.white,
            iconSize: 24,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            duration: const Duration(milliseconds: 400),
            tabBackgroundColor: isDarkMode ? const Color(0xFF007BFF).withOpacity(0.15) : Colors.white.withOpacity(0.15),
            color: isDarkMode ? Colors.grey[500]! : Colors.white.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = Provider.of<AppSettingsProvider>(context);

    return MaterialApp(
      scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
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
                        body: _pages[_selectedIndex],
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
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
          final carProvider = Provider.of<CarProvider>(context, listen: false);
          return CarListPage(
            cars: args?['cars'] as List<CarData>? ?? carProvider.cars,
            locale: args?['locale'] as Locale? ?? appSettings.locale,
          );
        },
        '/history': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
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
                            body: _pages[0],
                            bottomNavigationBar: _buildBottomNavigationBar(context),
                          ),
          );
        }
        return null;
      },
    );
  }
}